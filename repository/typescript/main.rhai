// Doc-first formatter entrypoint for TypeScript/JavaScript.
import "typescript/kinds.rhai" as kinds;
import "typescript/configuration.rhai" as configuration;
import "shared/whitespace.rhai" as whitespace;
import "shared/comments.rhai" as comments;

fn doc_concat_list(docs) {
	if docs.len() == 0 {
		return doc_text("");
	}
	if docs.len() == 1 {
		return docs[0];
	}
	doc_concat(docs)
}

fn leaf_tokens(node) {
	let out = [];
	let stack = [node];
	while stack.len() > 0 {
		let current = stack.pop();
		let kids = children(current);
		if kids.len() == 0 {
			out.push(current);
		}
		else {
			let i = kids.len() - 1;
			while i >= 0 {
				stack.push(kids[i]);
				if i == 0 {
					break;
				}
				i -= 1;
			}
		}
	}
	out
}

fn doc_for_boolean_operand(node, allow_wrap, indent_size, force_wrap) {
	if node == () {
		return doc_empty();
	}
	if node.kind_id() == kinds::parenthesized_expression {
		let doc = doc_for_node(node);
		if doc != () {
			return doc;
		}
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	let doc = doc_for_node(node);
	if doc != () {
		return doc;
	}
	let r = byte_range(node);
	doc_range(start(r), end(r))
}

fn doc_for_boolean_binary(node, allow_wrap, indent_size, force_wrap) {
	let raw = text(node);
	let max_width = configuration::values["max_width"];
	let should_wrap = force_wrap || (allow_wrap && (raw.len() > max_width || raw.index_of("\n") >= 0 || raw.index_of("\r") >= 0));
	let parts = [];
	let ops = [];
	let current = node;
	while current != () && current.kind_id() == kinds::binary_expression {
		let kids = children(current);
		if kids == () || kids.len() == 0 {
			break;
		}
		let op_idx = -1;
		let op_text = "";
		let left = ();
		let right = ();
		let last_non_comment = ();
		let i = 0;
		while i < kids.len() {
			let child = kids[i];
			if child != () {
				let ck = child.kind_id();
				let is_comment = ck == kinds::comment;
				let is_op = ck == kinds::and_and || ck == kinds::or_or || ck == kinds::amp || ck == kinds::pipe || ck == kinds::caret;
				if !is_comment {
					if op_idx < 0 {
						if is_op {
							op_idx = i;
							op_text = slice(byte_range(child)).trim();
							left = last_non_comment;
						}
						else {
							last_non_comment = child;
						}
					}
					else if right == () && !is_op {
						right = child;
						break;
					}
				}
			}
			i += 1;
		}
		if op_idx < 0 {
			if ops.len() == 0 {
				return doc_for_node_raw(node);
			}
			break;
		}
		if left == () || right == () {
			break;
		}
		let current_range = byte_range(current);
		let left_range = byte_range(left);
		if start(current_range) == start(left_range) && end(current_range) == end(left_range) {
			return doc_for_node_raw(node);
		}
		parts.push(right);
		ops.push(op_text);
		current = left;
	}
	parts.push(current);
	parts.reverse();
	ops.reverse();
	if parts.len() == 0 {
		return doc_empty();
	}
	let first_doc = doc_for_boolean_operand(parts[0], allow_wrap, indent_size, should_wrap);
	if ops.len() == 0 {
		return first_doc;
	}
	if should_wrap {
		let rest = [];
		let j = 0;
		while j < ops.len() {
			rest.push(doc_hardline());
			rest.push(doc_text(ops[j]));
			rest.push(doc_text(" "));
			rest.push(doc_for_boolean_operand(parts[j + 1], allow_wrap, indent_size, should_wrap));
			j += 1;
		}
		return doc_concat_list(
			[
				first_doc,
				doc_indent(indent_size, doc_concat_list(rest))
			]
		);
	}
	let out = [first_doc];
	let j = 0;
	while j < ops.len() {
		out.push(doc_text(" "));
		out.push(doc_text(ops[j]));
		out.push(doc_text(" "));
		out.push(doc_for_boolean_operand(parts[j + 1], allow_wrap, indent_size, should_wrap));
		j += 1;
	}
	doc_concat_list(out)
}

fn doc_for_boolean_expression(node, allow_wrap, indent_size, force_wrap) {
	if node == () {
		return doc_empty();
	}
	if node.kind_id() == kinds::binary_expression {
		return doc_for_boolean_binary(node, allow_wrap, indent_size, force_wrap);
	}
	doc_for_boolean_operand(node, allow_wrap, indent_size, force_wrap)
}

fn normalize_comparison_ops(text) {
	let ops = ["===", "!==", "==", "!=", "<=", ">=", "<", ">"];
	let out = "";
	let i = 0;
	while i < text.len() {
		let matched = "";
		let j = 0;
		while j < ops.len() {
			let op = ops[j];
			if text.len() - i >= op.len() && text.sub_string(i, op.len()) == op {
				matched = op;
				break;
			}
			j += 1;
		}
		if matched != "" {
			if out.len() > 0 {
				let prev = out.sub_string(out.len() - 1, 1);
				if prev != " " && prev != "\t" {
					out += " ";
				}
			}
			out += matched;
			let next_idx = i + matched.len();
			if next_idx < text.len() {
				let next = text.sub_string(next_idx, 1);
				if next != " " && next != "\t" {
					out += " ";
				}
			}
			i += matched.len();
		}
		else {
			out += text.sub_string(i, 1);
			i += 1;
		}
	}
	out
}

fn has_ancestor_kind(node, target) {
	let p = node.parent();
	while p != () {
		if p.kind_id() == target {
			return true;
		}
		p = p.parent();
	}
	false
}

fn is_block_condition(node) {
	let p = node.parent();
	if p == () || p.kind_id() != kinds::parenthesized_expression {
		return false;
	}
	let gp = p.parent();
	if gp == () {
		return false;
	}
	let k = gp.kind_id();
	k == kinds::if_statement || k == kinds::while_statement || k == kinds::for_statement || k == kinds::for_in_statement || k == kinds::do_statement || k == kinds::switch_statement
}

fn is_nested_block_condition(node) {
	let p = node.parent();
	if p == () || p.kind_id() != kinds::parenthesized_expression {
		return false;
	}
	let gp = p.parent();
	while gp != () {
		let k = gp.kind_id();
		if k == kinds::if_statement || k == kinds::while_statement || k == kinds::for_statement || k == kinds::for_in_statement || k == kinds::do_statement || k == kinds::switch_statement || k == kinds::ternary_expression {
			return true;
		}
		if k != kinds::binary_expression && k != kinds::assignment_expression && k != kinds::parenthesized_expression {
			break;
		}
		gp = gp.parent();
	}
	false
}

fn doc_for_child(children, idx) {
	let d = children.doc(idx);
	if d == () {
		let r = children.range(idx);
		return doc_range(start(r), end(r));
	}
	d
}

fn doc_for_child_or_build(parent, children, idx) {
	let d = children.doc(idx);
	if d != () {
		return d;
	}
	let node_children = children(parent);
	if node_children == () || idx < 0 || idx >= node_children.len() {
		return doc_empty();
	}
	let n = node_children[idx];
	if n == () {
		return doc_empty();
	}
	let cached = doc_for_node(n);
	if cached != () {
		return cached;
	}
	build_doc(n, children(n))
}

fn doc_for_node_raw(node) {
	if node == () {
		return doc_empty();
	}
	let cached = doc_for_node(node);
	if cached != () {
		return cached;
	}
	let r = byte_range(node);
	doc_range(start(r), end(r))
}

fn node_has_comment(node) {
	let matches = query("typescript", "(comment) @c", byte_range(node));
	let i = 0;
	while i < matches.len() {
		let c = matches[i].captures()
		["c"];
		if c != () {
			return true;
		}
		i += 1;
	}
	false
}

fn chain_root_info(node) {
	let r = node;
	let saw_args = false;
	let p = node.parent();
	while p != () {
		let pk = p.kind_id();
		if pk == kinds::arguments {
			saw_args = true;
			p = p.parent();
			continue;
		}
		if pk == kinds::call_expression || pk == kinds::member_expression {
			r = p;
			p = p.parent();
			continue;
		}
		break;
	}
	[r, saw_args]
}

fn chain_root(node) {
	let info = chain_root_info(node);
	info
	[0]
}

fn chain_should_wrap(node) {
	let root = chain_root(node);
	root.token_len() > configuration::values
	["max_width"]
}

fn doc_program(node, children) {
	if children.len == 0 {
		return doc_text(text(node));
	}
	let pieces = [];
	let node_range = byte_range(node);
	let cursor = start(node_range);
	let i = 0;
	while i < children.len {
		let child_range = children.range(i);
		if cursor < start(child_range) {
			let gap = slice(range(cursor, start(child_range)));
			if gap.index_of("\n") >= 0 || gap.index_of("\r") >= 0 {
				pieces.push(doc_hardline());
			}
			else if i > 0 {
				pieces.push(doc_hardline());
			}
		}
		else if i > 0 {
			pieces.push(doc_hardline());
		}
		pieces.push(doc_for_child(children, i));
		cursor = end(child_range);
		i += 1;
	}
	doc_concat_list(pieces)
}

fn doc_block(node, children) {
	let k_lbrace = kinds::lbrace;
	let k_rbrace = kinds::rbrace;
	let inner = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_lbrace || k == k_rbrace {
			i += 1;
			continue;
		}
		inner.push(doc_for_child(children, i));
		i += 1;
	}
	if inner.len() == 0 {
		return doc_text("{}");
	}
	let indent_size = configuration::values["tab_width"];
	let inner_doc = [];
	let j = 0;
	while j < inner.len() {
		inner_doc.push(inner[j]);
		if j < inner.len() - 1 {
			inner_doc.push(doc_hardline());
		}
		j += 1;
	}
	doc_concat_list([
		doc_text("{"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner_doc)])),
		doc_hardline(),
		doc_text("}")
	])
}

fn doc_switch_case(node, children, is_default) {
	let k_case = kinds::kw_case;
	let k_default = kinds::kw_default;
	let k_colon = kinds::colon;
	let k_break = kinds::break_statement;
	let k_continue = kinds::continue_statement;
	let colon_idx = -1;
	let expr_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_colon && colon_idx < 0 {
			colon_idx = i;
		}
		else if !is_default && expr_idx < 0 && k != k_case && k != k_colon {
			expr_idx = i;
		}
		else if is_default && k != k_default && k != k_colon {
			expr_idx = i;
		}
		i += 1;
	}
	let header_doc = if is_default {
		doc_text("default:")
	}
	else if expr_idx >= 0 {
		doc_concat_list([doc_text("case "), doc_for_child(children, expr_idx), doc_text(":")])
	}
	else {
		doc_text(text(node))
	};
	if colon_idx < 0 {
		return header_doc;
	}
	let body_indices = [];
	i = colon_idx + 1;
	while i < children.len {
		let k = children.kind(i);
		if k != k_colon && k != k_case && k != k_default {
			body_indices.push(i);
		}
		i += 1;
	}
	if body_indices.len() == 0 {
		return header_doc;
	}
	let indent_size = configuration::values["tab_width"];
	let last_idx = body_indices[body_indices.len() - 1];
	let last_kind = children.kind(last_idx);
	let last_is_break = last_kind == k_break || last_kind == k_continue;
	if last_is_break {
		if body_indices.len() == 1 {
			return doc_concat_list(
				[
					header_doc,
					doc_hardline(),
					doc_for_child(children, last_idx)
				]
			);
		}
		let inner = [];
		i = 0;
		while i < body_indices.len() - 1 {
			inner.push(doc_for_child(children, body_indices[i]));
			if i < body_indices.len() - 2 {
				inner.push(doc_hardline());
			}
			i += 1;
		}
		return doc_concat_list(
			[
				header_doc,
				doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)])),
				doc_hardline(),
				doc_for_child(children, last_idx)
			]
		);
	}
	let inner = [];
	i = 0;
	while i < body_indices.len() {
		inner.push(doc_for_child(children, body_indices[i]));
		if i < body_indices.len() - 1 {
			inner.push(doc_hardline());
		}
		i += 1;
	}
	doc_concat_list([
		header_doc,
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)]))
	])
}

fn doc_switch_body(node, children) {
	let k_lbrace = kinds::lbrace;
	let k_rbrace = kinds::rbrace;
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_lbrace || k == k_rbrace {
			i += 1;
			continue;
		}
		parts.push(doc_for_child(children, i));
		i += 1;
	}
	if parts.len() == 0 {
		return doc_text("{}");
	}
	let inner = [];
	i = 0;
	while i < parts.len() {
		inner.push(parts[i]);
		if i < parts.len() - 1 {
			inner.push(doc_hardline());
		}
		i += 1;
	}
	let indent_size = configuration::values["tab_width"];
	doc_concat_list([
		doc_text("{"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)])),
		doc_hardline(),
		doc_text("}")
	])
}

fn doc_switch_statement(node, children) {
	let k_switch = kinds::kw_switch;
	let k_body = kinds::switch_body;
	let body_idx = -1;
	let cond_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_body {
			body_idx = i;
			break;
		}
		if cond_idx < 0 && k != k_switch {
			cond_idx = i;
		}
		i += 1;
	}
	if body_idx < 0 || cond_idx < 0 {
		return doc_text(text(node));
	}
	let cond_doc = doc_for_child(children, cond_idx);
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([doc_text("switch "), cond_doc, doc_text(" "), body_doc])
}

fn doc_expression_statement(node, children) {
	let k_semi = kinds::semi;
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_semi {
			parts.push(doc_text(";"));
		}
		else {
			parts.push(doc_for_child_or_build(node, children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_return_statement(node, children) {
	let k_return = kinds::kw_return;
	let k_semi = kinds::semi;
	let expr_doc = ();
	let saw_semi = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_semi {
			saw_semi = true;
		}
		else if k != k_return {
			expr_doc = doc_for_child_or_build(node, children, i);
		}
		i += 1;
	}
	if expr_doc == () {
		if saw_semi {
			return doc_text("return;");
		}
		return doc_text("return");
	}
	if saw_semi {
		return doc_concat_list([doc_text("return "), expr_doc, doc_text(";")]);
	}
	doc_concat_list([doc_text("return "), expr_doc])
}

fn doc_variable_declarator(node, children) {
	let k_eq = kinds::assign;
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_eq {
			parts.push(doc_text(" = "));
		}
		else {
			parts.push(doc_for_child_or_build(node, children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_variable_declaration(children) {
	let k_comma = kinds::comma;
	let k_semi = kinds::semi;
	let k_const = kinds::kw_const;
	let k_let = kinds::kw_let;
	let k_var = kinds::kw_var;
	let parts = [];
	let i = 0;
	let prev_kind = -1;
	while i < children.len {
		let k = children.kind(i);
		if k == k_comma {
			parts.push(doc_text(", "));
			prev_kind = k;
			i += 1;
			continue;
		}
		if k == k_semi {
			parts.push(doc_text(";"));
			prev_kind = k;
			i += 1;
			continue;
		}
		if prev_kind == k_const || prev_kind == k_let || prev_kind == k_var {
			parts.push(doc_text(" "));
		}
		parts.push(doc_for_child(children, i));
		prev_kind = k;
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_function_declaration(node, children) {
	let k_identifier = kinds::identifier;
	let k_params = kinds::formal_parameters;
	let k_block = kinds::statement_block;
	let k_function = kinds::kw_function;
	let k_async = kinds::kw_async;
	let name_doc = ();
	let params_doc = ();
	let block_doc = ();
	let function_idx = -1;
	let has_async = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		let token_text = slice(children.range(i)).trim();
		if function_idx < 0 {
			if k == k_function || token_text == "function" {
				function_idx = i;
			}
			else if k == k_async || token_text == "async" {
				has_async = true;
			}
		}
		if k == k_identifier && name_doc == () {
			name_doc = doc_for_child(children, i);
		}
		else if k == k_params {
			params_doc = doc_for_child_or_build(node, children, i);
		}
		else if k == k_block {
			block_doc = doc_for_child_or_build(node, children, i);
		}
		i += 1;
	}
	if params_doc == () || block_doc == () {
		return doc_text(text(node));
	}
	let prefix = if has_async {
		"async "
	}
	else {
		""
	};
	if name_doc != () {
		return doc_concat_list([doc_text(prefix + "function "), name_doc, params_doc, doc_text(" "), block_doc]);
	}
	doc_concat_list([doc_text(prefix + "function"), params_doc, doc_text(" "), block_doc])
}

fn doc_if_statement(node, children) {
	let block_idx = -1;
	let else_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::statement_block && block_idx < 0 {
			block_idx = i;
		}
		else if k == kinds::else_clause {
			else_idx = i;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_text(text(node));
	}
	let cond_idx = -1;
	i = 0;
	while i < block_idx {
		let k = children.kind(i);
		if k != kinds::kw_if {
			cond_idx = i;
			break;
		}
		i += 1;
	}
	if cond_idx < 0 {
		return doc_text(text(node));
	}
	let cond_doc = doc_for_child(children, cond_idx);
	let block_doc = doc_for_child(children, block_idx);
	if else_idx >= 0 {
		let else_doc = doc_for_child(children, else_idx);
		return doc_concat_list(
			[
				doc_text("if "),
				cond_doc,
				doc_text(" "),
				block_doc,
				doc_hardline(),
				doc_text("else "),
				else_doc
			]
		);
	}
	doc_concat_list([doc_text("if "), cond_doc, doc_text(" "), block_doc])
}

fn doc_while_statement(node, children) {
	let k_while = kinds::kw_while;
	let k_block = kinds::statement_block;
	let block_idx = -1;
	let cond_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_block {
			block_idx = i;
			break;
		}
		if cond_idx < 0 && k != k_while {
			cond_idx = i;
		}
		i += 1;
	}
	if block_idx < 0 || cond_idx < 0 {
		return doc_text(text(node));
	}
	let cond_doc = doc_for_child(children, cond_idx);
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([doc_text("while "), cond_doc, doc_text(" "), block_doc])
}

fn doc_for_header_children(node, children, start_idx, end_idx) {
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_semi = kinds::semi;
	let k_comma = kinds::comma;
	let parts = [];
	let i = start_idx;
	while i < end_idx {
		let k = children.kind(i);
		let token = slice(children.range(i)).trim();
		if k == k_lparen || k == k_rparen || token == "(" || token == ")" {
			i += 1;
			continue;
		}
		if k == k_semi || token == ";" {
			let j = i + 1;
			let has_next = false;
			while j < end_idx {
				let nk = children.kind(j);
				let nt = slice(children.range(j)).trim();
				if nk != k_semi && nk != k_lparen && nk != k_rparen && nt != ";" {
					has_next = true;
					break;
				}
				j += 1;
			}
			parts.push(
				doc_text(
					if has_next {
						"; "
					}
					else {
						";"
					}
				)
			);
			i += 1;
			continue;
		}
		if k == k_comma || token == "," {
			parts.push(doc_text(", "));
			i += 1;
			continue;
		}
		parts.push(doc_for_child(children, i));
		if token.ends_with(";") {
			let j = i + 1;
			let has_next = false;
			while j < end_idx {
				let nk = children.kind(j);
				let nt = slice(children.range(j)).trim();
				if nk != k_semi && nk != k_lparen && nk != k_rparen && nt != ";" {
					has_next = true;
					break;
				}
				j += 1;
			}
			if has_next {
				parts.push(doc_text(" "));
			}
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_for_header(node, children) {
	doc_for_header_children(node, children, 0, children.len())
}

fn doc_for_statement(node, children) {
	let k_for = kinds::kw_for;
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_block = kinds::statement_block;
	let block_idx = -1;
	let lparen_idx = -1;
	let rparen_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_block {
			block_idx = i;
			break;
		}
		if k == k_lparen {
			lparen_idx = i;
		}
		else if k == k_rparen {
			rparen_idx = i;
		}
		i += 1;
	}
	if block_idx < 0 || lparen_idx < 0 || rparen_idx < 0 || rparen_idx <= lparen_idx {
		return doc_text(text(node));
	}
	let k_for_header = kinds::_for_header;
	let header_idx = -1;
	i = lparen_idx + 1;
	while i < rparen_idx {
		if children.kind(i) == k_for_header {
			header_idx = i;
			break;
		}
		i += 1;
	}
	let header_doc = if header_idx >= 0 {
		doc_concat_list(
			[
				doc_text("("),
				doc_for_child_or_build(node, children, header_idx),
				doc_text(")")
			]
		)
	}
	else {
		doc_concat_list(
			[
				doc_text("("),
				doc_for_header_children(node, children, lparen_idx + 1, rparen_idx),
				doc_text(")")
			]
		)
	};
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([doc_text("for "), header_doc, doc_text(" "), block_doc])
}

fn doc_for_in_statement(node, children) {
	let k_for = kinds::kw_for;
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_block = kinds::statement_block;
	let k_in = kinds::kw_in;
	let k_of = kinds::kw_of;
	let block_idx = -1;
	let lparen_idx = -1;
	let rparen_idx = -1;
	let op_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_block {
			block_idx = i;
			break;
		}
		if k == k_lparen {
			lparen_idx = i;
		}
		else if k == k_rparen {
			rparen_idx = i;
		}
		else if k == k_in || k == k_of {
			op_idx = i;
		}
		i += 1;
	}
	if block_idx < 0 || lparen_idx < 0 || rparen_idx < 0 || op_idx < 0 {
		return doc_text(text(node));
	}
	let left_indices = [];
	let right_indices = [];
	i = lparen_idx + 1;
	while i < op_idx {
		let k = children.kind(i);
		if k != k_for && k != k_lparen && k != k_rparen {
			left_indices.push(i);
		}
		i += 1;
	}
	i = op_idx + 1;
	while i < rparen_idx {
		let k = children.kind(i);
		if k != k_for && k != k_lparen && k != k_rparen {
			right_indices.push(i);
		}
		i += 1;
	}
	if left_indices.len() == 0 || right_indices.len() == 0 {
		return doc_text(text(node));
	}
	let op_text = slice(children.range(op_idx)).trim();
	let left_parts = [];
	i = 0;
	while i < left_indices.len() {
		left_parts.push(doc_for_child(children, left_indices[i]));
		if i < left_indices.len() - 1 {
			left_parts.push(doc_text(" "));
		}
		i += 1;
	}
	let right_parts = [];
	i = 0;
	while i < right_indices.len() {
		right_parts.push(doc_for_child(children, right_indices[i]));
		if i < right_indices.len() - 1 {
			right_parts.push(doc_text(" "));
		}
		i += 1;
	}
	let left_doc = doc_concat_list(left_parts);
	let right_doc = doc_concat_list(right_parts);
	let header_doc = doc_concat_list(
		[
			doc_text("("),
			left_doc,
			doc_text(" " + op_text + " "),
			right_doc,
			doc_text(")")
		]
	);
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([doc_text("for "), header_doc, doc_text(" "), block_doc])
}

fn doc_do_statement(node, children) {
	let k_do = kinds::kw_do;
	let k_while = kinds::kw_while;
	let k_semi = kinds::semi;
	let k_block = kinds::statement_block;
	let block_idx = -1;
	let cond_idx = -1;
	let seen_while = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_block && block_idx < 0 {
			block_idx = i;
		}
		else if k == k_while {
			seen_while = true;
		}
		else if seen_while && k != k_semi {
			cond_idx = i;
			break;
		}
		i += 1;
	}
	if block_idx < 0 || cond_idx < 0 {
		return doc_text(text(node));
	}
	let block_doc = doc_for_child(children, block_idx);
	let cond_doc = doc_for_child(children, cond_idx);
	doc_concat_list([
		doc_text("do "),
		block_doc,
		doc_hardline(),
		doc_text("while "),
		cond_doc,
		doc_text(";")
	])
}

fn doc_catch_clause(node, children) {
	let k_catch = kinds::kw_catch;
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_block = kinds::statement_block;
	let block_idx = -1;
	let lparen_idx = -1;
	let rparen_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_block {
			block_idx = i;
			break;
		}
		if k == k_lparen {
			lparen_idx = i;
		}
		else if k == k_rparen {
			rparen_idx = i;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_text(text(node));
	}
	let block_doc = doc_for_child(children, block_idx);
	if lparen_idx >= 0 && rparen_idx >= 0 && rparen_idx > lparen_idx + 1 {
		let param_parts = [];
		i = lparen_idx + 1;
		while i < rparen_idx {
			let k = children.kind(i);
			if k != k_lparen && k != k_rparen {
				param_parts.push(doc_for_child(children, i));
				if i < rparen_idx - 1 {
					param_parts.push(doc_text(" "));
				}
			}
			i += 1;
		}
		let param_doc = doc_concat_list([doc_text("("), doc_concat_list(param_parts), doc_text(")")]);
		return doc_concat_list([doc_text("catch "), param_doc, doc_text(" "), block_doc]);
	}
	doc_concat_list([doc_text("catch "), block_doc])
}

fn doc_finally_clause(node, children) {
	let k_finally = kinds::finally_clause;
	let k_block = kinds::statement_block;
	let block_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_block {
			block_idx = i;
			break;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_text(text(node));
	}
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([doc_text("finally "), block_doc])
}

fn doc_try_statement(node, children) {
	let k_try = kinds::kw_try;
	let k_block = kinds::statement_block;
	let k_catch = kinds::catch_clause;
	let k_finally = kinds::finally_clause;
	let block_idx = -1;
	let catch_idx = -1;
	let finally_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_block && block_idx < 0 {
			block_idx = i;
		}
		else if k == k_catch {
			catch_idx = i;
		}
		else if k == k_finally {
			finally_idx = i;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_text(text(node));
	}
	let parts = [doc_text("try "), doc_for_child(children, block_idx)];
	if catch_idx >= 0 {
		parts.push(doc_hardline());
		parts.push(doc_for_child(children, catch_idx));
	}
	if finally_idx >= 0 {
		parts.push(doc_hardline());
		parts.push(doc_for_child(children, finally_idx));
	}
	doc_concat_list(parts)
}

fn doc_call_expression(node, children) {
	if node_has_comment(node) {
		return doc_text(text(node));
	}
	let k_args = kinds::arguments;
	let args_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_args {
			args_idx = i;
			break;
		}
		i += 1;
	}
	if args_idx < 0 {
		return doc_text(text(node));
	}
	let callee_parts = [];
	i = 0;
	while i < args_idx {
		let k = children.kind(i);
		if k != k_args {
			callee_parts.push(doc_for_child_or_build(node, children, i));
		}
		i += 1;
	}
	if callee_parts.len() == 0 {
		return doc_text(text(node));
	}
	let callee_doc = doc_concat_list(callee_parts);
	let args_doc = doc_for_child_or_build(node, children, args_idx);
	doc_concat_list([callee_doc, args_doc])
}

fn doc_member_expression(node, children) {
	if node_has_comment(node) {
		return doc_text(text(node));
	}
	let k_dot = kinds::dot;
	let k_qdot = kinds::qdot;
	let dot_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_dot || k == k_qdot {
			dot_idx = i;
			break;
		}
		i += 1;
	}
	if dot_idx < 0 {
		return doc_text(text(node));
	}
	let receiver_idx = -1;
	i = dot_idx - 1;
	while i >= 0 {
		let k = children.kind(i);
		if k != k_dot && k != k_qdot {
			receiver_idx = i;
			break;
		}
		i -= 1;
	}
	if receiver_idx < 0 {
		return doc_text(text(node));
	}
	let receiver_doc = doc_for_child_or_build(node, children, receiver_idx);
	let property_parts = [];
	i = dot_idx + 1;
	while i < children.len {
		let k = children.kind(i);
		if k != k_dot && k != k_qdot {
			property_parts.push(doc_for_child_or_build(node, children, i));
		}
		i += 1;
	}
	if property_parts.len() == 0 {
		return doc_text(text(node));
	}
	let property_doc = doc_concat_list(property_parts);
	let op_text = if children.kind(dot_idx) == k_qdot {
		"?."
	}
	else {
		"."
	};
	let info = chain_root_info(node);
	let root = info[0];
	let saw_args = info[1];
	let wrap_chain = root.token_len() > configuration::values["max_width"];
	let root_range = byte_range(root);
	let receiver_range = children.range(receiver_idx);
	let receiver_kind = children.kind(receiver_idx);
	let receiver_is_chain = receiver_kind == kinds::call_expression || receiver_kind == kinds::member_expression;
	let break_chain = wrap_chain && (receiver_is_chain || start(receiver_range) != start(root_range));
	if break_chain {
		let base_indent = configuration::values["tab_width"];
		let indent_size = if saw_args {
			base_indent * 2
		}
		else {
			base_indent
		};
		return doc_concat_list(
			[
				receiver_doc,
				doc_indent(
					indent_size,
					doc_concat_list(
						[
							doc_hardline(),
							doc_concat_list([doc_text(op_text), property_doc])
						]
					)
				)
			]
		);
	}
	doc_concat_list([receiver_doc, doc_text(op_text), property_doc])
}

fn doc_arguments(node, children) {
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_comma = kinds::comma;
	let args = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k != k_lparen && k != k_rparen && k != k_comma {
			args.push(doc_for_child_or_build(node, children, i));
		}
		i += 1;
	}
	if args.len() == 0 {
		return doc_text("()");
	}
	let raw = text(node);
	let max_width = configuration::values["max_width"];
	let should_break = raw.len() > max_width || raw.index_of("\n") >= 0 || raw.index_of("\r") >= 0;
	let parts = [];
	let j = 0;
	while j < args.len() {
		parts.push(args[j]);
		if j < args.len() - 1 {
			if should_break {
				parts.push(doc_text(","));
				parts.push(doc_hardline());
			}
			else {
				parts.push(doc_text(", "));
			}
		}
		j += 1;
	}
	if should_break {
		let indent_size = configuration::values["tab_width"];
		return doc_concat_list(
			[
				doc_text("("),
				doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)])),
				doc_hardline(),
				doc_text(")")
			]
		);
	}
	doc_concat_list([doc_text("("), doc_concat_list(parts), doc_text(")")])
}

fn doc_string_literal(node) {
	let literal_text = text(node);
	if literal_text.len() < 2 {
		return doc_text(literal_text);
	}
	let quote = literal_text.sub_string(0, 1);
	let end_quote = literal_text.sub_string(literal_text.len() - 1, 1);
	if (quote != "\"" && quote != "'") || end_quote != quote {
		return doc_text(literal_text);
	}
	let inner = literal_text.sub_string(1, literal_text.len() - 2);
	if inner.index_of("\\") >= 0 {
		return doc_text(literal_text);
	}
	if inner.index_of("\n") >= 0 || inner.index_of("\r") >= 0 {
		return doc_text(literal_text);
	}
	let tab_width = configuration::values["tab_width"];
	let max_width = configuration::values["max_width"];
	if inner.len() + 2 <= max_width {
		return doc_text(literal_text);
	}
	let r = byte_range(node);
	let line_info = line_at(start(r));
	let line_start = start_offset(line_info);
	let prefix = if start(r) > line_start {
		slice(range(line_start, start(r)))
	}
	else {
		""
	};
	let prefix_cols_raw = whitespace::text_cols(prefix, tab_width);
	let indent_levels = {
		let levels = 0;
		let p = node.parent();
		while p != () {
			let k = p.kind_id();
			if k == kinds::statement_block || k == kinds::switch_body {
				levels += 1;
			}
			p = p.parent();
		}
		levels
	};
	let base_cols = indent_levels * tab_width;
	let prefix_cols = base_cols + prefix_cols_raw;
	let first_max = max_width - prefix_cols - 2;
	if first_max < 1 {
		return doc_text(literal_text);
	}
	let cont_cols = base_cols + tab_width;
	let cont_max = max_width - cont_cols - 4;
	if cont_max < 1 {
		return doc_text(literal_text);
	}
	let parts = [];
	let remaining = inner;
	let first = true;
	while !remaining.is_empty() {
		let take = if first {
			first_max
		}
		else {
			cont_max
		};
		if remaining.len() <= take {
			parts.push(remaining);
			break;
		}
		let chunk = remaining.sub_string(0, take);
		parts.push(chunk);
		remaining = remaining.sub_string(take, remaining.len() - take);
		first = false;
	}
	if parts.len() <= 1 {
		return doc_text(literal_text);
	}
	let indent_size = tab_width;
	let doc = doc_text(quote + parts[0] + quote);
	let i = 1;
	while i < parts.len() {
		doc = doc_concat_list(
			[
				doc,
				doc_indent(
					indent_size,
					doc_concat_list(
						[
							doc_hardline(),
							doc_text("+ " + quote + parts[i] + quote)
						]
					)
				)
			]
		);
		i += 1;
	}
	doc
}

fn doc_formal_parameters(node, children) {
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_comma = kinds::comma;
	let params = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k != k_lparen && k != k_rparen && k != k_comma {
			params.push(doc_for_child(children, i));
		}
		i += 1;
	}
	let parts = [];
	let j = 0;
	while j < params.len() {
		parts.push(params[j]);
		if j < params.len() - 1 {
			parts.push(doc_text(", "));
		}
		j += 1;
	}
	doc_concat_list([doc_text("("), doc_concat_list(parts), doc_text(")")])
}

fn doc_binary_expression(node, children) {
	let op_ids = [
		kinds::assign,
		kinds::plus_assign,
		kinds::minus_assign,
		kinds::star_assign,
		kinds::slash_assign,
		kinds::percent_assign,
		kinds::eq_eq,
		kinds::not_eq,
		kinds::eq_eq_eq,
		kinds::not_eq_eq,
		kinds::lt,
		kinds::gt,
		kinds::lt_eq,
		kinds::gt_eq,
		kinds::plus,
		kinds::minus,
		kinds::star,
		kinds::slash,
		kinds::percent,
		kinds::and_and,
		kinds::or_or,
		kinds::amp,
		kinds::pipe,
		kinds::caret,
		kinds::shl,
		kinds::shr
	];
	let raw = text(node);
	let max_width = configuration::values["max_width"];
	let tab_width = configuration::values["tab_width"];
	let head = [];
	let tail = [];
	let i = 0;
	let wrap_logic = raw.len() > max_width || raw.index_of("\n") >= 0 || raw.index_of("\r") >= 0;
	let is_nested = is_nested_block_condition(node);
	let indent_size = if wrap_logic && is_block_condition(node) {
		tab_width * 2
	}
	else if wrap_logic && is_nested {
		tab_width * 3
	}
	else {
		tab_width
	};
	let parent = node.parent();
	let parent_is_ternary = parent != () && parent.kind_id() == kinds::ternary_expression;
	let in_ternary = parent_is_ternary || has_ancestor_kind(node, kinds::ternary_expression);
	let allow_logic_wrap = wrap_logic && !in_ternary && (is_block_condition(node) || is_nested);
	if allow_logic_wrap {
		let kids = node.children();
		let has_logical = false;
		if kids != () {
			let j = 0;
			while j < kids.len() {
				let child = kids[j];
				if child != () {
					let ck = child.kind_id();
					if ck == kinds::and_and || ck == kinds::or_or || ck == kinds::amp || ck == kinds::pipe || ck == kinds::caret {
						has_logical = true;
						break;
					}
				}
				j += 1;
			}
		}
		if has_logical {
			return doc_for_boolean_expression(node, true, indent_size, false);
		}
	}
	let wrapped = false;
	while i < children.len {
		let k = children.kind(i);
		if op_ids.index_of(k) >= 0 {
			let op_text = slice(children.range(i)).trim();
			let should_wrap_op = allow_logic_wrap && (op_text == "&&" || op_text == "||" || op_text == "&" || op_text == "|" || op_text == "^");
			if should_wrap_op {
				wrapped = true;
				tail.push(doc_hardline());
				tail.push(doc_text(op_text));
				tail.push(doc_text(" "));
			}
			else {
				if wrapped {
					tail.push(doc_text(" "));
					tail.push(doc_text(op_text));
					tail.push(doc_text(" "));
				}
				else {
					head.push(doc_text(" "));
					head.push(doc_text(op_text));
					head.push(doc_text(" "));
				}
			}
		}
		else {
			if wrapped {
				tail.push(doc_for_child(children, i));
			}
			else {
				head.push(doc_for_child(children, i));
			}
		}
		i += 1;
	}
	if wrapped {
		return doc_concat_list(
			[
				doc_concat_list(head),
				doc_indent(indent_size, doc_concat_list(tail))
			]
		);
	}
	doc_concat_list(head)
}

fn doc_ternary_expression(node, children) {
	let k_q = kinds::qmark;
	let k_colon = kinds::colon;
	let q_idx = -1;
	let colon_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_q {
			q_idx = i;
		}
		else if k == k_colon {
			colon_idx = i;
		}
		i += 1;
	}
	if q_idx < 0 || colon_idx < 0 {
		let parts = [];
		i = 0;
		while i < children.len {
			let k = children.kind(i);
			if k == k_q {
				parts.push(doc_text(" ? "));
			}
			else if k == k_colon {
				parts.push(doc_text(" : "));
			}
			else {
				parts.push(doc_for_child(children, i));
			}
			i += 1;
		}
		return doc_concat_list(parts);
	}
	let cond_idx = 0;
	let then_idx = -1;
	let else_idx = -1;
	i = q_idx + 1;
	while i < colon_idx {
		let k = children.kind(i);
		if k != k_q && k != k_colon {
			then_idx = i;
			break;
		}
		i += 1;
	}
	i = colon_idx + 1;
	while i < children.len {
		let k = children.kind(i);
		if k != k_q && k != k_colon {
			else_idx = i;
			break;
		}
		i += 1;
	}
	if then_idx < 0 || else_idx < 0 {
		let parts = [];
		i = 0;
		while i < children.len {
			let k = children.kind(i);
			if k == k_q {
				parts.push(doc_text(" ? "));
			}
			else if k == k_colon {
				parts.push(doc_text(" : "));
			}
			else {
				parts.push(doc_for_child(children, i));
			}
			i += 1;
		}
		return doc_concat_list(parts);
	}
	let max_width = configuration::values["max_width"];
	let tab_width = configuration::values["tab_width"];
	let r = byte_range(node);
	let line_info = line_at(start(r));
	let line_start = start_offset(line_info);
	let prefix = if start(r) > line_start {
		slice(range(line_start, start(r)))
	}
	else {
		()
	};
	let prefix_cols_raw = if prefix == () {
		0
	}
	else {
		whitespace::text_cols(prefix, tab_width)
	};
	let indent_levels = {
		let levels = 0;
		let p = node.parent();
		while p != () {
			let k = p.kind_id();
			if k == kinds::statement_block || k == kinds::switch_body {
				levels += 1;
			}
			p = p.parent();
		}
		levels
	};
	let prefix_cols = prefix_cols_raw + indent_levels * tab_width;
	let node_children = node.children();
	let cond_node = if cond_idx >= 0 && cond_idx < node_children.len() {
		node_children[cond_idx]
	}
	else {
		()
	};
	let cond_raw = slice(children.range(cond_idx)).trim();
	let logical_ops = {
		let count = 0;
		let current = cond_node;
		while current != () && current.kind_id() == kinds::binary_expression {
			let kids = children(current);
			if kids == () || kids.len() == 0 {
				break;
			}
			let op_idx = -1;
			let left = ();
			let last_non_comment = ();
			let i = 0;
			while i < kids.len() {
				let child = kids[i];
				if child != () {
					let ck = child.kind_id();
					let is_comment = ck == kinds::comment;
					let is_op = ck == kinds::and_and || ck == kinds::or_or || ck == kinds::amp || ck == kinds::pipe || ck == kinds::caret;
					if !is_comment {
						if op_idx < 0 {
							if is_op {
								op_idx = i;
								left = last_non_comment;
								break;
							}
							else {
								last_non_comment = child;
							}
						}
					}
				}
				i += 1;
			}
			if op_idx < 0 || left == () {
				break;
			}
			let current_range = byte_range(current);
			let left_range = byte_range(left);
			if start(current_range) == start(left_range) && end(current_range) == end(left_range) {
				break;
			}
			count += 1;
			current = left;
		}
		count
	};
	let should_break = cond_raw.index_of("\n") >= 0 || prefix_cols + cond_raw.len() > max_width || logical_ops >= 3;
	let cond_doc = if cond_node != () && cond_node.kind_id() == kinds::binary_expression {
		let force_wrap_ternary_condition = true;
		let force_wrap = should_break && force_wrap_ternary_condition;
		doc_for_boolean_expression(cond_node, true, tab_width * 2, force_wrap)
	}
	else if should_break {
		doc_text(cond_raw)
	}
	else {
		doc_for_child(children, cond_idx)
	};
	let then_doc = doc_for_child(children, then_idx);
	let else_doc = doc_for_child(children, else_idx);
	if !should_break {
		return doc_concat_list(
			[
				cond_doc,
				doc_text(" ? "),
				then_doc,
				doc_text(" : "),
				else_doc
			]
		);
	}
	let indent_size = tab_width;
	doc_concat_list([
		cond_doc,
		doc_indent(
			indent_size,
			doc_concat_list(
				[
					doc_hardline(),
					doc_text("? "),
					then_doc,
					doc_hardline(),
					doc_text(": "),
					else_doc
				]
			)
		)
	])
}

fn doc_unary_expression(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::plus || k == kinds::minus || k == kinds::bang {
			parts.push(doc_text(slice(children.range(i)).trim()));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_parenthesized_expression(node, children) {
	let node_children = node.children();
	if node_children != () {
		let inner = ();
		let i = 0;
		while i < node_children.len() {
			let child = node_children[i];
			if child != () {
				let k = child.kind_id();
				if k != kinds::lparen && k != kinds::rparen {
					inner = child;
					break;
				}
			}
			i += 1;
		}
		if inner != () && inner.kind_id() == kinds::binary_expression {
			let inner_kids = children(inner);
			let has_logical = false;
			if inner_kids != () {
				let j = 0;
				while j < inner_kids.len() {
					let op_child = inner_kids[j];
					if op_child != () {
						let ck = op_child.kind_id();
						if ck == kinds::and_and || ck == kinds::or_or || ck == kinds::amp || ck == kinds::pipe || ck == kinds::caret {
							has_logical = true;
							break;
						}
					}
					j += 1;
				}
			}
			if has_logical {
				let tab_width = configuration::values["tab_width"];
				let indent_size = if is_block_condition(inner) {
					tab_width * 2
				}
				else {
					tab_width
				};
				let inner_doc = doc_for_boolean_expression(inner, true, indent_size, false);
				return doc_concat_list([doc_text("("), inner_doc, doc_text(")")]);
			}
		}
	}
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k != kinds::lparen && k != kinds::rparen {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list([doc_text("("), doc_concat_list(parts), doc_text(")")])
}

fn doc_arrow_function(node, children) {
	let k_arrow = kinds::arrow;
	let arrow_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_arrow {
			arrow_idx = i;
			break;
		}
		i += 1;
	}
	if arrow_idx < 0 {
		return doc_text(text(node));
	}
	let left_parts = [];
	i = 0;
	while i < arrow_idx {
		if children.kind(i) != k_arrow {
			left_parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	let right_parts = [];
	i = arrow_idx + 1;
	while i < children.len {
		if children.kind(i) != k_arrow {
			right_parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list([
		doc_concat_list(left_parts),
		doc_text(" => "),
		doc_concat_list(right_parts)
	])
}

fn doc_array_expression(children) {
	let items = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::lbracket || k == kinds::rbracket || k == kinds::comma {
			i += 1;
			continue;
		}
		items.push(doc_for_child(children, i));
		i += 1;
	}
	if items.len() == 0 {
		return doc_text("[]");
	}
	let parts = [];
	let j = 0;
	while j < items.len() {
		parts.push(items[j]);
		if j < items.len() - 1 {
			parts.push(doc_text(", "));
		}
		j += 1;
	}
	doc_concat_list([doc_text("["), doc_concat_list(parts), doc_text("]")])
}

fn doc_object_field(children) {
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::colon {
			parts.push(doc_text(": "));
			need_space = false;
		}
		else {
			if need_space {
				parts.push(doc_text(" "));
			}
			parts.push(doc_for_child(children, i));
			need_space = true;
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_object_expression(children) {
	let fields = [];
	let field_texts = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::pair {
			fields.push(doc_for_child(children, i));
			field_texts.push(slice(children.range(i)).trim());
		}
		i += 1;
	}
	if fields.len() == 0 {
		return doc_text("{}");
	}
	let max_width = configuration::values["max_width"];
	let inline_len = {
		let len = 2;
		let j = 0;
		while j < field_texts.len() {
			len += field_texts[j].len();
			if j < fields.len() - 1 {
				len += 2;
			}
			j += 1;
		}
		len
	};
	let parts = [];
	let j = 0;
	while j < fields.len() {
		parts.push(fields[j]);
		if j < fields.len() - 1 {
			parts.push(doc_text(", "));
		}
		j += 1;
	}
	let inline_doc = doc_concat_list([doc_text("{ "), doc_concat_list(parts), doc_text(" }")]);
	if inline_len <= max_width {
		return inline_doc;
	}
	let indent_size = configuration::values["tab_width"];
	let inner = [];
	j = 0;
	while j < fields.len() {
		inner.push(doc_concat_list([fields[j], doc_text(",")]));
		if j < fields.len() - 1 {
			inner.push(doc_hardline());
		}
		j += 1;
	}
	doc_concat_list([
		doc_text("{"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)])),
		doc_hardline(),
		doc_text("}")
	])
}

fn build_doc(node, children) {
	let k = node.kind_id();
	if k == kinds::program {
		return doc_program(node, children);
	}
	if k == kinds::comment {
		let raw = text(node);
		if raw.starts_with("//") {
			return comments::doc_line_comment(node, "//");
		}
		return comments::doc_block_comment(node, "/*", "*/");
	}
	if k == kinds::statement_block {
		return doc_block(node, children);
	}
	if k == kinds::if_statement {
		return doc_if_statement(node, children);
	}
	if k == kinds::for_statement {
		return doc_for_statement(node, children);
	}
	if k == kinds::_for_header {
		return doc_for_header(node, children);
	}
	if k == kinds::for_in_statement {
		return doc_for_in_statement(node, children);
	}
	if k == kinds::while_statement {
		return doc_while_statement(node, children);
	}
	if k == kinds::do_statement {
		return doc_do_statement(node, children);
	}
	if k == kinds::try_statement {
		return doc_try_statement(node, children);
	}
	if k == kinds::catch_clause {
		return doc_catch_clause(node, children);
	}
	if k == kinds::finally_clause {
		return doc_finally_clause(node, children);
	}
	if k == kinds::switch_statement {
		return doc_switch_statement(node, children);
	}
	if k == kinds::switch_body {
		return doc_switch_body(node, children);
	}
	if k == kinds::switch_case {
		return doc_switch_case(node, children, false);
	}
	if k == kinds::switch_default {
		return doc_switch_case(node, children, true);
	}
	if k == kinds::else_clause {
		let k_else = kinds::kw_else;
		let i = 0;
		while i < children.len {
			let k = children.kind(i);
			if k != k_else {
				return doc_for_child(children, i);
			}
			i += 1;
		}
		return doc_text(text(node));
	}
	if k == kinds::expression_statement {
		return doc_expression_statement(node, children);
	}
	if k == kinds::return_statement {
		return doc_return_statement(node, children);
	}
	if k == kinds::lexical_declaration || k == kinds::variable_declaration {
		return doc_variable_declaration(children);
	}
	if k == kinds::function_declaration {
		return doc_function_declaration(node, children);
	}
	if k == kinds::variable_declarator {
		return doc_variable_declarator(node, children);
	}
	if k == kinds::call_expression {
		return doc_call_expression(node, children);
	}
	if k == kinds::member_expression {
		return doc_member_expression(node, children);
	}
	if k == kinds::arguments {
		return doc_arguments(node, children);
	}
	if k == kinds::formal_parameters {
		return doc_formal_parameters(node, children);
	}
	if k == kinds::binary_expression || k == kinds::assignment_expression {
		return doc_binary_expression(node, children);
	}
	if k == kinds::ternary_expression {
		return doc_ternary_expression(node, children);
	}
	if k == kinds::unary_expression || k == kinds::update_expression {
		return doc_unary_expression(children);
	}
	if k == kinds::parenthesized_expression {
		return doc_parenthesized_expression(node, children);
	}
	if k == kinds::arrow_function {
		return doc_arrow_function(node, children);
	}
	if k == kinds::array {
		return doc_array_expression(children);
	}
	if k == kinds::object {
		return doc_object_expression(children);
	}
	if k == kinds::pair {
		return doc_object_field(children);
	}
	if k == kinds::string || k == kinds::template_string {
		if k == kinds::string {
			return doc_string_literal(node);
		}
		return doc_text(text(node));
	}
	if k == kinds::number || k == kinds::lit_true || k == kinds::lit_false || k == kinds::lit_null {
		return doc_text(text(node));
	}
	doc_text(text(node))
}
let start_total = now_ms();
let start_docs = now_ms();
doc_reset();
let queries = [
	"(program) @n",
	"(statement_block) @n",
	"(expression_statement) @n",
	"(return_statement) @n",
	"(lexical_declaration) @n",
	"(variable_declaration) @n",
	"(function_declaration) @n",
	"(variable_declarator) @n",
	"(if_statement) @n",
	"(for_statement) @n",
	"(for_in_statement) @n",
	"(while_statement) @n",
	"(do_statement) @n",
	"(try_statement) @n",
	"(catch_clause) @n",
	"(finally_clause) @n",
	"(switch_statement) @n",
	"(switch_body) @n",
	"(switch_case) @n",
	"(switch_default) @n",
	"(ternary_expression) @n",
	"(arrow_function) @n",
	"(call_expression) @n",
	"(member_expression) @n",
	"(arguments) @n",
	"(formal_parameters) @n",
	"(binary_expression) @n",
	"(assignment_expression) @n",
	"(unary_expression) @n",
	"(update_expression) @n",
	"(parenthesized_expression) @n",
	"(array) @n",
	"(object) @n",
	"(pair) @n",
	"(string) @n",
	"(template_string) @n",
	"(number) @n",
	"(true) @n",
	"(false) @n",
	"(null) @n",
	"(comment) @n",
	"(else_clause) @n"
];
let root_doc = walk(
	"typescript",
	queries,
	|node, children| {
		build_doc(node, children)
	}
);
let end_docs = now_ms();
let start_render = now_ms();
let width = configuration::values["max_width"];
let indent_style = configuration::values["indent_style"];
let tab_width = configuration::values["tab_width"];
let output = doc_render_with_indent(root_doc, width, indent_style, tab_width);
let lines = output.split("\n");
let i = 0;
while i < lines.len() {
	let line = lines[i];
	if line.trim().is_empty() {
		lines[i] = "";
	}
	i += 1;
}
let output = whitespace::join_lines(lines);
while output.len() > 0 {
	let last = output.sub_string(output.len() - 1, 1);
	if last == "\n" || last == "\r" || last == " " || last == "\t" {
		output = output.sub_string(0, output.len() - 1);
	}
	else {
		break;
	}
}
let output = output + "\n";
let end_render = now_ms();
let start_apply = now_ms();
set_output(output);
let end_apply = now_ms();
let end_total = now_ms();

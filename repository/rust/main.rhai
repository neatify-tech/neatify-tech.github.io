// Doc-first formatter entrypoint for Rust.
// No source mutations are performed outside of Doc rendering.
import "rust/kinds.rhai" as kinds;
import "rust/configuration.rhai" as configuration;
import "shared/whitespace.rhai" as whitespace;
import "shared/comments.rhai" as comments;

fn doc_empty() {
	doc_text("")
}

fn doc_concat_list(docs) {
	if docs.len() == 0 {
		return doc_empty();
	}
	if docs.len() == 1 {
		return docs[0];
	}
	doc_concat(docs)
}

fn normalize_space(text) {
	let out = "";
	let in_space = false;
	let i = 0;
	while i < text.len() {
		let ch = text.sub_string(i, 1);
		if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
			if !in_space {
				out += " ";
				in_space = true;
			}
		}
		else {
			out += ch;
			in_space = false;
		}
		i += 1;
	}
	out.trim()
}

fn doc_use_tree(node) {
	if node == () {
		return doc_text("");
	}
	let k = node.kind_id();
	if k == kinds::scoped_identifier {
		return doc_scoped_identifier(node);
	}
	if k == kinds::use_list {
		let kids = node.children();
		let items = [];
		let has_comment = false;
		let i = 0;
		while i < kids.len() {
			let c = kids[i];
			if c != () {
				let ck = c.kind_id();
				if ck == kinds::line_comment || ck == kinds::block_comment {
					has_comment = true;
					break;
				}
				if ck != kinds::lbrace && ck != kinds::rbrace && ck != kinds::comma {
					items.push(doc_use_tree(c));
				}
			}
			i += 1;
		}
		if has_comment {
			return doc_for_node_raw(node);
		}
		if items.len() == 0 {
			return doc_text("{}");
		}
		let max_width = configuration::values["max_width"];
		let raw_len = text(node).len();
		let nested = {
			let found = false;
			let j = 0;
			while j < kids.len() {
				let c = kids[j];
				if c != () {
					let ck = c.kind_id();
					if ck == kinds::use_list || ck == kinds::scoped_use_list {
						found = true;
						break;
					}
				}
				j += 1;
			}
			found
		};
		let needs_multiline = items.len() > 1 && (nested || raw_len > max_width);
		if !needs_multiline {
			let parts = [];
			let j = 0;
			while j < items.len() {
				parts.push(items[j]);
				if j < items.len() - 1 {
					parts.push(doc_text(", "));
				}
				j += 1;
			}
			return doc_concat_list(
				[
					doc_text("{"),
					doc_concat_list(parts),
					doc_text("}")
				]
			);
		}
		let indent_size = configuration::values["tab_width"];
		let inner = [];
		let j = 0;
		while j < items.len() {
			inner.push(doc_concat_list([items[j], doc_text(",")]));
			if j < items.len() - 1 {
				inner.push(doc_hardline());
			}
			j += 1;
		}
		return doc_concat_list(
			[
				doc_text("{"),
				doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)])),
				doc_hardline(),
				doc_text("}")
			]
		);
	}
	if k == kinds::scoped_use_list {
		let kids = node.children();
		let path = ();
		let list = ();
		let i = 0;
		while i < kids.len() {
			let c = kids[i];
			if c != () {
				let ck = c.kind_id();
				if ck == kinds::use_list || ck == kinds::use_wildcard || ck == kinds::use_as_clause {
					list = c;
				}
				else if path == () && ck != kinds::colon_colon {
					path = c;
				}
			}
			i += 1;
		}
		if path == () {
			return doc_for_node_raw(node);
		}
		if list == () {
			return doc_for_node_raw(path);
		}
		return doc_concat_list(
			[
				if path.kind_id() == kinds::scoped_identifier {
					doc_scoped_identifier(path)
				}
				else {
					doc_for_node_raw(path)
				},
				doc_text("::"),
				doc_use_tree(list)
			]
		);
	}
	if k == kinds::use_as_clause {
		let kids = node.children();
		let parts = [];
		let i = 0;
		while i < kids.len() {
			let c = kids[i];
			if c != () {
				let ck = c.kind_id();
				if ck == kinds::kw_as {
					parts.push(doc_text(" as "));
				}
				else {
					parts.push(doc_for_node_raw(c));
				}
			}
			i += 1;
		}
		return doc_concat_list(parts);
	}
	if k == kinds::use_wildcard {
		let kids = node.children();
		let path = ();
		let i = 0;
		while i < kids.len() {
			let c = kids[i];
			if c != () {
				let ck = c.kind_id();
				if ck == kinds::scoped_identifier || ck == kinds::identifier || ck == kinds::type_identifier || ck == kinds::kw_crate || ck == kinds::kw_self || ck == kinds::kw_super {
					path = c;
					break;
				}
			}
			i += 1;
		}
		if path == () {
			return doc_text("*");
		}
		let path_doc = if path.kind_id() == kinds::scoped_identifier {
			doc_scoped_identifier(path)
		}
		else {
			doc_for_node_raw(path)
		};
		return doc_concat_list([path_doc, doc_text("::*")]);
	}
	doc_for_node_raw(node)
}

fn doc_scoped_identifier(node) {
	let kids = node.children();
	let parts = [];
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let ck = c.kind_id();
			if ck == kinds::colon_colon {
				parts.push(doc_text("::"));
			}
			else {
				parts.push(doc_for_node_raw(c));
			}
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_header_from_children(children, end_idx) {
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < end_idx {
		let k = children.kind(i);
		if k == kinds::arrow {
			parts.push(doc_text(" -> "));
			need_space = false;
		}
		else if k == kinds::parameters {
			parts.push(doc_for_child(children, i));
			need_space = false;
		}
		else if k == kinds::lparen || k == kinds::rparen || k == kinds::comma || k == kinds::colon || k == kinds::colon_colon {
			parts.push(doc_for_child(children, i));
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

fn is_structural_kind(k) {
	k == kinds::use_declaration || k == kinds::struct_item || k == kinds::impl_item || k == kinds::function_item || k == kinds::enum_item || k == kinds::trait_item || k == kinds::mod_item || k == kinds::const_item || k == kinds::static_item || k == kinds::type_item || k == kinds::foreign_mod_item || k == kinds::extern_crate_declaration || k == kinds::union_item || k == kinds::macro_definition
}

fn is_item_kind(k) {
	is_structural_kind(k) || k == kinds::attribute_item
}

fn desired_item_sep(prev_kind, curr_kind) {
	if !is_item_kind(prev_kind) || !is_item_kind(curr_kind) {
		return 0;
	}
	if prev_kind == kinds::use_declaration && curr_kind == kinds::use_declaration {
		return 1;
	}
	if prev_kind == kinds::mod_item && curr_kind == kinds::mod_item {
		return 1;
	}
	if prev_kind == kinds::attribute_item && curr_kind == kinds::attribute_item {
		return 1;
	}
	if prev_kind == kinds::attribute_item {
		return 1;
	}
	if curr_kind == kinds::attribute_item {
		return 2;
	}
	2
}

fn doc_for_child(children, idx) {
	let d = children.doc(idx);
	if d == () {
		let r = children.range(idx);
		return doc_range(start(r), end(r));
	}
	d
}

fn doc_for_node_or_range(node) {
	let d = doc_for_node(node);
	if d != () {
		return d;
	}
	let r = byte_range(node);
	doc_range(start(r), end(r))
}

fn doc_closure_parameters_child(node) {
	doc_for_node_or_range(node)
}

fn doc_closure_block_child(node, has_return_type) {
	if has_return_type {
		return doc_for_node_or_range(node);
	}
	let raw = text(node);
	if raw.index_of("\n") >= 0 || raw.index_of("\r") >= 0 {
		return doc_for_node_or_range(node);
	}
	let block_children = node.children();
	if block_children != () && block_children.len() == 3 {
		let middle = block_children[1];
		if middle != () {
			let k = middle.kind_id();
			if k != kinds::expression_statement && k != kinds::let_declaration && k != kinds::line_comment && k != kinds::block_comment && k != kinds::block {
				return doc_for_node_or_range(middle);
			}
		}
	}
	let cached = doc_for_node(node);
	if cached != () {
		return cached;
	}
	doc_for_node_or_range(node)
}

fn doc_closure_comment_child(node) {
	doc_for_node_or_range(node)
}

fn doc_closure_return_type_child(node) {
	doc_for_node_or_range(node)
}

fn doc_closure_keyword_child(node) {
	doc_for_node_or_range(node)
}

fn closure_needs_space(prev_kind, curr_kind) {
	if prev_kind < 0 {
		return false;
	}
	if curr_kind == kinds::line_comment || curr_kind == kinds::block_comment {
		return false;
	}
	if prev_kind == kinds::line_comment || prev_kind == kinds::block_comment {
		return false;
	}
	if prev_kind == kinds::closure_parameters {
		return true;
	}
	if curr_kind == kinds::closure_parameters {
		return prev_kind == kinds::kw_move || prev_kind == kinds::kw_async || prev_kind == kinds::kw_static;
	}
	if curr_kind == kinds::block {
		return true;
	}
	if curr_kind == kinds::arrow || prev_kind == kinds::arrow {
		return true;
	}
	false
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

fn is_punct_kind(k) {
	k == kinds::dot || k == kinds::lparen || k == kinds::rparen || k == kinds::comma || k == kinds::semi || k == kinds::colon
}

fn field_value_node(node) {
	let kids = node.children();
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let k = c.kind_id();
			if k != kinds::dot && k != kinds::field_identifier {
				return c;
			}
		}
		i += 1;
	}()
}

fn doc_source_file(node, children) {
	if children.len == 0 {
		return doc_text(text(node));
	}
	let pieces = [];
	let node_range = byte_range(node);
	let cursor = start(node_range);
	let node_children = node.children();
	let i = 0;
	while i < children.len {
		let child_range = children.range(i);
		let curr_kind = if node_children != () && i < node_children.len() {
			node_children[i].kind_id()
		}
		else {
			-1
		};
		let sep = 0;
		if cursor < start(child_range) {
			let gap = slice(range(cursor, start(child_range)));
			if gap.index_of("\n") >= 0 || gap.index_of("\r") >= 0 {
				sep = 1;
			}
		}
		if i > 0 {
			let prev_kind = if node_children != () && i - 1 < node_children.len() {
				node_children[i - 1].kind_id()
			}
			else {
				-1
			};
			let desired = desired_item_sep(prev_kind, curr_kind);
			if desired > sep {
				sep = desired;
			}
		}
		let s = 0;
		while s < sep {
			pieces.push(doc_hardline());
			s += 1;
		}
		pieces.push(doc_for_child(children, i));
		cursor = end(child_range);
		i += 1;
	}
	if cursor < end(node_range) {
		let tail = slice(range(cursor, end(node_range)));
		if (tail.index_of("\n") >= 0 || tail.index_of("\r") >= 0) && !tail.trim().is_empty() {
			pieces.push(doc_hardline());
		}
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
		if k == kinds::line_comment && inner.len() > 0 {
			let prev_idx = i - 1;
			if prev_idx >= 0 {
				let gap = slice(range(end(children.range(prev_idx)), start(children.range(i))));
				if gap.index_of("\n") < 0 && gap.index_of("\r") < 0 {
					let prev = inner.pop();
					inner.push(doc_concat_list([prev, doc_text(" "), doc_for_child(children, i)]));
					i += 1;
					continue;
				}
			}
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

fn doc_parenthesized_expression(node, children) {
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
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
				let indent_size = configuration::values["tab_width"];
				let inner_doc = doc_for_boolean_expression(inner, true, indent_size, false);
				return doc_concat_list([doc_text("("), inner_doc, doc_text(")")]);
			}
		}
	}
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k != k_lparen && k != k_rparen {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if parts.len() == 0 {
		return doc_text("()");
	}
	doc_concat_list([doc_text("("), doc_concat_list(parts), doc_text(")")])
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
			args.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if args.len() == 0 {
		return doc_text("()");
	}
	let raw = text(node);
	let max_width = configuration::values["max_width"];
	let should_break = raw.len() > max_width || raw.index_of("\n") >= 0 || raw.index_of("\r") >= 0;
	let force_break = if args.len() == 1 {
		count_chain_segments_in_text(raw) >= 4
	}
	else {
		false
	};
	let should_break = should_break || force_break;
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
		let compact_close = {
			let call_node = node.parent();
			if call_node != () && call_node.kind_id() == kinds::call_expression {
				let call_parent = call_node.parent();
				call_parent != () && call_parent.kind_id() == kinds::field_expression && args.len() == 1
			}
			else {
				false
			}
		};
		let indented = doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)]));
		if compact_close {
			return doc_concat_list(
				[
					doc_text("("),
					indented,
					doc_text(")")
				]
			);
		}
		return doc_concat_list(
			[
				doc_text("("),
				indented,
				doc_hardline(),
				doc_text(")")
			]
		);
	}
	doc_concat_list([doc_text("("), doc_concat_list(parts), doc_text(")")])
}

fn doc_parameters(node, children) {
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
	if params.len() == 0 {
		return doc_text("()");
	}
	let raw = text(node);
	let max_width = configuration::values["max_width"];
	let should_break = raw.len() > max_width || raw.index_of("\n") >= 0 || raw.index_of("\r") >= 0;
	let parts = [];
	let j = 0;
	while j < params.len() {
		parts.push(params[j]);
		if j < params.len() - 1 {
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
				doc_text(")")
			]
		);
	}
	doc_concat_list([doc_text("("), doc_concat_list(parts), doc_text(")")])
}

fn doc_parameter(children) {
	let k_colon = kinds::colon;
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_colon {
			parts.push(doc_text(": "));
			need_space = false;
		}
		else if k == kinds::mutable_specifier {
			if need_space {
				parts.push(doc_text(" "));
			}
			parts.push(doc_for_child(children, i));
			need_space = true;
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

fn doc_let_condition(children) {
	let k_let = kinds::kw_let;
	let k_colon = kinds::colon;
	let k_eq = kinds::assign;
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_let {
			parts.push(doc_text("let"));
			need_space = true;
		}
		else if k == k_colon {
			parts.push(doc_text(": "));
			need_space = false;
		}
		else if k == k_eq {
			parts.push(doc_text(" = "));
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

fn doc_let_declaration(children) {
	let k_let = kinds::kw_let;
	let k_colon = kinds::colon;
	let k_eq = kinds::assign;
	let k_semi = kinds::semi;
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_let {
			parts.push(doc_text("let"));
			need_space = true;
		}
		else if k == k_colon {
			parts.push(doc_text(": "));
			need_space = false;
		}
		else if k == k_eq {
			parts.push(doc_text(" = "));
			need_space = false;
		}
		else if k == k_semi {
			parts.push(doc_text(";"));
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

fn doc_operator_expression(node, children) {
	let op_ids = [
		kinds::assign,
		kinds::plus_assign,
		kinds::minus_assign,
		kinds::star_assign,
		kinds::slash_assign,
		kinds::percent_assign,
		kinds::shl_assign,
		kinds::shr_assign,
		kinds::plus,
		kinds::minus,
		kinds::star,
		kinds::slash,
		kinds::percent,
		kinds::eq_eq,
		kinds::not_eq,
		kinds::lt,
		kinds::gt,
		kinds::lt_eq,
		kinds::gt_eq,
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
	let wrap_logic = raw.len() > max_width || raw.index_of("\n") >= 0 || raw.index_of("\r") >= 0;
	if wrap_logic && node.kind_id() == kinds::binary_expression {
		let has_logical = {
			let found = false;
			let i = 0;
			while i < children.len {
				let k = children.kind(i);
				if k == kinds::and_and || k == kinds::or_or || k == kinds::amp || k == kinds::pipe || k == kinds::caret {
					found = true;
					break;
				}
				i += 1;
			}
			found
		};
		if has_logical {
			let indent_size = configuration::values["tab_width"];
			return doc_for_boolean_expression(node, true, indent_size, false);
		}
	}
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if op_ids.index_of(k) >= 0 {
			let op_text = slice(children.range(i)).trim();
			parts.push(doc_text(" " + op_text + " "));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
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
				let is_comment = ck == kinds::line_comment || ck == kinds::block_comment;
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

fn doc_unary_expression(children) {
	let op_text = "";
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::plus || k == kinds::minus || k == kinds::bang || k == kinds::star || k == kinds::amp {
			op_text += slice(children.range(i)).trim();
			i += 1;
			continue;
		}
		if k == kinds::mutable_specifier {
			op_text += slice(children.range(i)).trim();
			i += 1;
			continue;
		}
		break;
	}
	if i >= children.len {
		return doc_text(op_text);
	}
	let operand_doc = doc_for_child(children, i);
	if op_text.is_empty() {
		return operand_doc;
	}
	let needs_space = op_text.ends_with("mut") || op_text.ends_with("await") || op_text.ends_with("box");
	if needs_space {
		return doc_concat_list([doc_text(op_text + " "), operand_doc]);
	}
	doc_concat_list([doc_text(op_text), operand_doc])
}

fn doc_reference_expression(children) {
	let op_text = "";
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		let raw = slice(children.range(i)).trim();
		if k == kinds::amp {
			op_text += raw;
			i += 1;
			continue;
		}
		if k == kinds::mutable_specifier || raw == "mut" {
			op_text += raw;
			i += 1;
			continue;
		}
		break;
	}
	if i >= children.len {
		return doc_text(op_text);
	}
	let operand_doc = doc_for_child(children, i);
	if op_text.is_empty() {
		return operand_doc;
	}
	let needs_space = op_text.index_of("mut") >= 0;
	if needs_space {
		return doc_concat_list([doc_text(op_text + " "), operand_doc]);
	}
	doc_concat_list([doc_text(op_text), operand_doc])
}

fn doc_expression_statement(children) {
	let k_semi = kinds::semi;
	let k_line_comment = kinds::line_comment;
	let parts = [];
	let i = 0;
	let inline_comment = ();
	if children.len > 1 {
		let last = children.len - 1;
		if children.kind(last) == k_line_comment {
			let gap = slice(range(end(children.range(last - 1)), start(children.range(last))));
			if gap.index_of("\n") < 0 && gap.index_of("\r") < 0 {
				inline_comment = children.doc(last);
			}
		}
	}
	while i < children.len {
		if i == children.len - 1 && inline_comment != () {
			i += 1;
			continue;
		}
		let k = children.kind(i);
		if k == k_semi {
			parts.push(doc_text(";"));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if inline_comment != () {
		parts.push(doc_text(" "));
		parts.push(inline_comment);
	}
	doc_concat_list(parts)
}

fn doc_if_expression(node, children) {
	let k_block = kinds::block;
	let k_else = kinds::else_clause;
	let block_idx = -1;
	let else_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_block && block_idx < 0 {
			block_idx = i;
		}
		else if k == k_else {
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
	let block_doc = doc_for_child(children, block_idx);
	let cond_doc = doc_for_child(children, cond_idx);
	if else_idx >= 0 {
		let else_doc = doc_for_child(children, else_idx);
		return doc_concat_list(
			[
				doc_text("if "),
				cond_doc,
				doc_text(" "),
				block_doc,
				doc_hardline(),
				else_doc
			]
		);
	}
	doc_concat_list([doc_text("if "), cond_doc, doc_text(" "), block_doc])
}

fn doc_else_clause(children) {
	let k_else = kinds::kw_else;
	let body_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k != k_else {
			body_idx = i;
			break;
		}
		i += 1;
	}
	if body_idx < 0 {
		return doc_text("else");
	}
	doc_concat_list([doc_text("else "), doc_for_child(children, body_idx)])
}

fn doc_match_expression(node, children) {
	let k_block = kinds::match_block;
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
	let value_idx = -1;
	let i = 0;
	while i < block_idx {
		if children.kind(i) != kinds::kw_match {
			value_idx = i;
			break;
		}
		i += 1;
	}
	if value_idx < 0 {
		return doc_text(text(node));
	}
	let value_doc = doc_for_child(children, value_idx);
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([doc_text("match "), value_doc, doc_text(" "), block_doc])
}

fn doc_match_block(node, children) {
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

fn doc_match_arm(children) {
	let k_arrow = kinds::fat_arrow;
	let k_comma = kinds::comma;
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_arrow {
			parts.push(doc_text(" => "));
		}
		else if k == k_comma {
			parts.push(doc_text(","));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_type_parameters(node) {
	let kids = node.children();
	let params = [];
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let k = c.kind_id();
			if k != kinds::lt && k != kinds::gt && k != kinds::comma {
				if k == kinds::type_parameter {
					params.push(doc_type_parameter(c));
				}
				else {
					params.push(doc_for_node_raw(c));
				}
			}
		}
		i += 1;
	}
	if params.len() == 0 {
		return doc_text("<>");
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
	doc_concat_list([doc_text("<"), doc_concat_list(parts), doc_text(">")])
}

fn doc_type_parameter(node) {
	let kids = node.children();
	let name = ();
	let bounds = ();
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let k = c.kind_id();
			if k == kinds::trait_bounds {
				bounds = c;
			}
			else if name == () {
				name = c;
			}
		}
		i += 1;
	}
	if name == () {
		return doc_for_node_raw(node);
	}
	let name_doc = doc_for_node_raw(name);
	if bounds == () {
		return name_doc;
	}
	let bounds_doc = doc_trait_bounds(bounds);
	doc_concat_list([name_doc, doc_text(": "), bounds_doc])
}

fn doc_type_arguments(node) {
	let kids = node.children();
	let args = [];
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let k = c.kind_id();
			if k != kinds::lt && k != kinds::gt && k != kinds::comma {
				args.push(doc_for_node_raw(c));
			}
		}
		i += 1;
	}
	if args.len() == 0 {
		return doc_text("<>");
	}
	let parts = [];
	let j = 0;
	while j < args.len() {
		parts.push(args[j]);
		if j < args.len() - 1 {
			parts.push(doc_text(", "));
		}
		j += 1;
	}
	doc_concat_list([doc_text("<"), doc_concat_list(parts), doc_text(">")])
}

fn doc_generic_type(node) {
	let kids = node.children();
	let parts = [];
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let k = c.kind_id();
			if k == kinds::type_arguments {
				parts.push(doc_type_arguments(c));
			}
			else {
				parts.push(doc_for_node_raw(c));
			}
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_where_predicate(node) {
	let kids = node.children();
	let left = ();
	let bounds = ();
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let k = c.kind_id();
			if k == kinds::trait_bounds {
				bounds = c;
			}
			else if left == () {
				left = c;
			}
		}
		i += 1;
	}
	if left == () || bounds == () {
		return doc_for_node_raw(node);
	}
	let left_doc = doc_for_node_raw(left);
	let bounds_doc = doc_trait_bounds(bounds);
	doc_concat_list([left_doc, doc_text(": "), bounds_doc])
}

fn doc_trait_bounds(node) {
	let kids = node.children();
	let parts = [];
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let k = c.kind_id();
			if k == kinds::colon || k == kinds::comma {
				// skip
			}
			else if k == kinds::colon_colon {
				parts.push(doc_text("::"));
			}
			else if k == kinds::plus {
				parts.push(doc_text(" + "));
			}
			else {
				if k == kinds::generic_type {
					parts.push(doc_generic_type(c));
				}
				else {
					parts.push(doc_for_node_raw(c));
				}
			}
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_where_clause(node) {
	let kids = node.children();
	let preds = [];
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () && c.kind_id() == kinds::where_predicate {
			preds.push(doc_where_predicate(c));
		}
		i += 1;
	}
	if preds.len() == 0 {
		return doc_text("where");
	}
	let indent_size = configuration::values["tab_width"];
	let inner = [];
	let j = 0;
	while j < preds.len() {
		inner.push(doc_concat_list([preds[j], doc_text(",")]));
		if j < preds.len() - 1 {
			inner.push(doc_hardline());
		}
		j += 1;
	}
	doc_concat_list([
		doc_text("where"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)]))
	])
}

fn doc_where_clause_inline(node) {
	let kids = node.children();
	let preds = [];
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () && c.kind_id() == kinds::where_predicate {
			preds.push(doc_where_predicate(c));
		}
		i += 1;
	}
	if preds.len() == 0 {
		return doc_text("where");
	}
	let parts = [];
	let j = 0;
	while j < preds.len() {
		parts.push(preds[j]);
		if j < preds.len() - 1 {
			parts.push(doc_text(", "));
		}
		j += 1;
	}
	doc_concat_list([doc_text("where "), doc_concat_list(parts)])
}

fn doc_use_declaration(node, children) {
	let arg = ();
	let vis_doc = ();
	let node_children = node.children();
	let i = 0;
	while i < node_children.len() {
		let c = node_children[i];
		if c != () && c.kind_id() == kinds::visibility_modifier {
			vis_doc = doc_for_node_raw(c);
			break;
		}
		i += 1;
	}
	let matches = query("rust", "(use_declaration argument: (_) @a)", byte_range(node));
	for m in matches {
		let a = m.captures()
		["a"];
		if a != () {
			arg = a;
			break;
		}
	}
	if arg == () {
		let i = 0;
		while i < node_children.len() {
			let c = node_children[i];
			if c != () {
				let k = c.kind_id();
				if k == kinds::scoped_use_list || k == kinds::use_list || k == kinds::scoped_identifier || k == kinds::use_as_clause || k == kinds::use_wildcard {
					arg = c;
					break;
				}
			}
			i += 1;
		}
	}
	if arg == () {
		return doc_text(text(node));
	}
	let parts = [];
	if vis_doc != () {
		parts.push(vis_doc);
		parts.push(doc_text(" "));
	}
	parts.push(doc_text("use "));
	parts.push(doc_use_tree(arg));
	parts.push(doc_text(";"));
	doc_concat_list(parts)
}

fn doc_token_tree(node) {
	let node_children = node.children();
	let lbrace_idx = -1;
	let rbrace_idx = -1;
	let i = 0;
	while i < node_children.len() {
		let c = node_children[i];
		if c != () {
			let k = c.kind_id();
			if k == kinds::lbrace && lbrace_idx < 0 {
				lbrace_idx = i;
			}
			if k == kinds::rbrace {
				rbrace_idx = i;
			}
		}
		i += 1;
	}
	if lbrace_idx >= 0 && rbrace_idx > lbrace_idx {
		let indent_size = configuration::values["tab_width"];
		let lines = [];
		let current = [];
		let prev_end = -1;
		let i = lbrace_idx + 1;
		while i < rbrace_idx {
			let c = node_children[i];
			if c == () {
				i += 1;
				continue;
			}
			let r = byte_range(c);
			if prev_end >= 0 {
				let gap = slice(range(prev_end, start(r)));
				if gap.index_of("\n") >= 0 || gap.index_of("\r") >= 0 {
					if current.len() > 0 {
						lines.push(doc_concat_list(current));
						current = [];
					}
				}
				else if (gap.index_of(" ") >= 0 || gap.index_of("\t") >= 0) && current.len() > 0 {
					current.push(doc_text(" "));
				}
			}
			let text = slice(r).trim();
			if text.len() > 0 {
				current.push(doc_text(text));
			}
			prev_end = end(r);
			if text == ";" {
				if current.len() > 0 {
					lines.push(doc_concat_list(current));
					current = [];
				}
				prev_end = -1;
			}
			i += 1;
		}
		if current.len() > 0 {
			lines.push(doc_concat_list(current));
		}
		if lines.len() == 0 {
			return doc_text("{}");
		}
		let inner = [];
		let j = 0;
		while j < lines.len() {
			inner.push(lines[j]);
			if j < lines.len() - 1 {
				inner.push(doc_hardline());
			}
			j += 1;
		}
		return doc_concat_list(
			[
				doc_text("{"),
				doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)])),
				doc_hardline(),
				doc_text("}")
			]
		);
	}
	let raw = text(node).trim();
	if raw.starts_with("{") && raw.ends_with("}") {
		let inner_raw = raw.sub_string(1, raw.len() - 2);
		let lines = [];
		let line = "";
		let i = 0;
		while i < inner_raw.len() {
			let ch = inner_raw.sub_string(i, 1);
			if ch == "\n" || ch == "\r" {
				let trimmed = line.trim();
				if !trimmed.is_empty() {
					lines.push(trimmed);
				}
				line = "";
			}
			else {
				line += ch;
			}
			i += 1;
		}
		let trimmed = line.trim();
		if !trimmed.is_empty() {
			lines.push(trimmed);
		}
		if lines.len() > 0 {
			let indent_size = configuration::values["tab_width"];
			let inner = [];
			let j = 0;
			while j < lines.len() {
				inner.push(doc_text(lines[j]));
				if j < lines.len() - 1 {
					inner.push(doc_hardline());
				}
				j += 1;
			}
			return doc_concat_list(
				[
					doc_text("{"),
					doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)])),
					doc_hardline(),
					doc_text("}")
				]
			);
		}
	}
	let parts = [];
	let lparen_idx = -1;
	let rparen_idx = -1;
	let i = 0;
	while i < node_children.len() {
		let c = node_children[i];
		if c != () {
			let k = c.kind_id();
			if k == kinds::lparen && lparen_idx < 0 {
				lparen_idx = i;
			}
			if k == kinds::rparen {
				rparen_idx = i;
			}
		}
		i += 1;
	}
	if lparen_idx >= 0 && rparen_idx > lparen_idx {
		let has_newline = false;
		let prev_end = -1;
		let i = lparen_idx + 1;
		while i < rparen_idx {
			let c = node_children[i];
			if c != () {
				let r = byte_range(c);
				if prev_end >= 0 {
					let gap = slice(range(prev_end, start(r)));
					if gap.index_of("\n") >= 0 || gap.index_of("\r") >= 0 {
						has_newline = true;
						break;
					}
				}
				prev_end = end(r);
			}
			i += 1;
		}
		if has_newline {
			let indent_size = configuration::values["tab_width"];
			let inner_parts = [];
			let prev_end = -1;
			let i = lparen_idx + 1;
			while i < rparen_idx {
				let c = node_children[i];
				if c != () {
					let k = c.kind_id();
					let r = byte_range(c);
					let gap_has_newline = false;
					let gap_has_space = false;
					if prev_end >= 0 {
						let gap = slice(range(prev_end, start(r)));
						if gap.index_of("\n") >= 0 || gap.index_of("\r") >= 0 {
							inner_parts.push(doc_hardline());
							gap_has_newline = true;
						}
						else if gap.index_of(" ") >= 0 || gap.index_of("\t") >= 0 {
							inner_parts.push(doc_text(" "));
							gap_has_space = true;
						}
					}
					if k == kinds::comma {
						let next = if i + 1 < rparen_idx {
							node_children[i + 1]
						}
						else {
							()
						};
						if next != () {
							let next_r = byte_range(next);
							let gap_after = slice(range(end(r), start(next_r)));
							if gap_after.index_of("\n") >= 0 || gap_after.index_of("\r") >= 0 {
								inner_parts.push(doc_text(","));
							}
							else if gap_after.index_of(" ") >= 0 || gap_after.index_of("\t") >= 0 {
								inner_parts.push(doc_text(","));
							}
							else {
								inner_parts.push(doc_text(", "));
							}
						}
						else {
							inner_parts.push(doc_text(","));
						}
					}
					else if k == kinds::assign {
						if gap_has_newline || gap_has_space {
							inner_parts.push(doc_text("="));
						}
						else {
							inner_parts.push(doc_text(" = "));
						}
					}
					else if k == kinds::colon_colon {
						inner_parts.push(doc_text("::"));
					}
					else if k == kinds::lparen || k == kinds::rparen || k == kinds::lbracket || k == kinds::rbracket || k == kinds::lbrace || k == kinds::rbrace {
						inner_parts.push(doc_text(slice(byte_range(c)).trim()));
					}
					else {
						inner_parts.push(doc_for_node_raw(c));
					}
					prev_end = end(r);
				}
				i += 1;
			}
			return doc_concat_list(
				[
					doc_text("("),
					doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner_parts)])),
					doc_hardline(),
					doc_text(")")
				]
			);
		}
	}
	let i = 0;
	let prev_end = -1;
	while i < node_children.len() {
		let c = node_children[i];
		if c != () {
			let k = c.kind_id();
			let r = byte_range(c);
			let gap_has_newline = false;
			let gap_has_space = false;
			if prev_end >= 0 {
				let gap = slice(range(prev_end, start(r)));
				if gap.index_of("\n") >= 0 || gap.index_of("\r") >= 0 {
					parts.push(doc_hardline());
					gap_has_newline = true;
				}
				else if gap.index_of(" ") >= 0 || gap.index_of("\t") >= 0 {
					if k != kinds::rparen && k != kinds::rbracket && k != kinds::rbrace {
						parts.push(doc_text(" "));
					}
					gap_has_space = true;
				}
			}
			if k == kinds::comma {
				let next = if i + 1 < node_children.len() {
					node_children[i + 1]
				}
				else {
					()
				};
				if next != () {
					let next_r = byte_range(next);
					let gap_after = slice(range(end(r), start(next_r)));
					if gap_after.index_of("\n") >= 0 || gap_after.index_of("\r") >= 0 {
						parts.push(doc_text(","));
					}
					else if gap_after.index_of(" ") >= 0 || gap_after.index_of("\t") >= 0 {
						parts.push(doc_text(","));
					}
					else {
						parts.push(doc_text(", "));
					}
				}
				else {
					parts.push(doc_text(","));
				}
			}
			else if k == kinds::assign {
				if gap_has_newline || gap_has_space {
					parts.push(doc_text("="));
				}
				else {
					parts.push(doc_text(" = "));
				}
			}
			else if k == kinds::colon_colon {
				parts.push(doc_text("::"));
			}
			else if k == kinds::lparen || k == kinds::rparen || k == kinds::lbracket || k == kinds::rbracket || k == kinds::lbrace || k == kinds::rbrace {
				parts.push(doc_text(slice(byte_range(c)).trim()));
			}
			else {
				parts.push(doc_for_node_raw(c));
			}
			prev_end = end(r);
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_attribute(node) {
	let node_children = node.children();
	let parts = [];
	let i = 0;
	while i < node_children.len() {
		let child = node_children[i];
		if child != () {
			let k = child.kind_id();
			if k == kinds::token_tree {
				parts.push(doc_token_tree(child));
			}
			else {
				parts.push(doc_for_node_raw(child));
			}
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_attribute_item(node, children) {
	let attr_idx = -1;
	let node_children = node.children();
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::attribute {
			attr_idx = i;
			break;
		}
		i += 1;
	}
	if attr_idx < 0 {
		return doc_text(text(node));
	}
	let attr_node = if node_children != () && attr_idx < node_children.len() {
		node_children[attr_idx]
	}
	else {
		()
	};
	let attr_doc = doc_attribute(attr_node);
	doc_concat_list([doc_text("#"), doc_text("["), attr_doc, doc_text("]")])
}

fn doc_macro_invocation(node, children) {
	let node_children = node.children();
	let name_doc = ();
	let tt_doc = ();
	let tt_node = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::token_tree {
			let child = if node_children != () && i < node_children.len() {
				node_children[i]
			}
			else {
				()
			};
			tt_node = child;
			tt_doc = doc_token_tree(child);
		}
		else if name_doc == () {
			name_doc = doc_for_child(children, i);
		}
		i += 1;
	}
	if name_doc == () || tt_doc == () {
		return doc_text(text(node));
	}
	let raw = text(node).trim();
	if raw.starts_with("macro_rules!") {
		let lbrace = raw.index_of("{");
		let rbrace = last_index_of(raw, "}");
		if lbrace >= 0 && rbrace > lbrace {
			let header = normalize_space(raw.sub_string(0, lbrace));
			let inner_raw = raw.sub_string(lbrace + 1, rbrace - lbrace - 1);
			let lines = [];
			let line = "";
			let j = 0;
			while j < inner_raw.len() {
				let ch = inner_raw.sub_string(j, 1);
				if ch == "\n" || ch == "\r" {
					let trimmed = line.trim();
					if !trimmed.is_empty() {
						let lead = 0;
						let k = 0;
						while k < line.len() {
							let c = line.sub_string(k, 1);
							if c == " " {
								lead += 1;
							}
							else if c == "\t" {
								lead += configuration::values["tab_width"];
							}
							else {
								break;
							}
							k += 1;
						}
						lines.push([trimmed, lead]);
					}
					line = "";
				}
				else {
					line += ch;
				}
				j += 1;
			}
			let trimmed = line.trim();
			if !trimmed.is_empty() {
				let lead = 0;
				let k = 0;
				while k < line.len() {
					let c = line.sub_string(k, 1);
					if c == " " {
						lead += 1;
					}
					else if c == "\t" {
						lead += configuration::values["tab_width"];
					}
					else {
						break;
					}
					k += 1;
				}
				lines.push([trimmed, lead]);
			}
			if lines.len() == 0 {
				return doc_concat_list([doc_text(header), doc_text(" {}")]);
			}
			let base_indent = lines
			[0][1];
			let k = 1;
			while k < lines.len() {
				if lines[k][1] < base_indent {
					base_indent = lines[k]
					[1];
				}
				k += 1;
			}
			let indent_size = configuration::values["tab_width"];
			let inner = [];
			let k = 0;
			while k < lines.len() {
				let text = lines[k]
				[0];
				let lead = lines
				[k][1];
				let extra = if lead > base_indent {
					lead - base_indent
				}
				else {
					0
				};
				let tabs = extra / indent_size;
				let rem = extra - tabs * indent_size;
				let prefix = "";
				let t = 0;
				while t < tabs {
					prefix += "\t";
					t += 1;
				}
				let s = 0;
				while s < rem {
					prefix += " ";
					s += 1;
				}
				inner.push(doc_text(prefix + text));
				if k < lines.len() - 1 {
					inner.push(doc_hardline());
				}
				k += 1;
			}
			return doc_concat_list(
				[
					doc_text(header),
					doc_text(" {"),
					doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)])),
					doc_hardline(),
					doc_text("}")
				]
			);
		}
	}
	let needs_space = {
		let first = ();
		let kids = if tt_node != () {
			children(tt_node)
		}
		else {
			()
		};
		if kids != () {
			let j = 0;
			while j < kids.len() {
				if kids[j] != () {
					first = kids[j];
					break;
				}
				j += 1;
			}
		}
		first != () && first.kind_id() == kinds::lbrace
	};
	if needs_space {
		return doc_concat_list([name_doc, doc_text("! "), tt_doc]);
	}
	doc_concat_list([name_doc, doc_text("!"), tt_doc])
}

fn doc_field_declaration(children) {
	let k_colon = kinds::colon;
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_colon {
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

fn doc_field_declaration_list(node, children) {
	let fields = [];
	let pending_attrs = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::attribute_item {
			pending_attrs.push(doc_for_child(children, i));
		}
		else if k == kinds::line_comment || k == kinds::block_comment {
			pending_attrs.push(doc_for_child(children, i));
		}
		else if k == kinds::field_declaration {
			let field_doc = doc_for_child(children, i);
			if pending_attrs.len() > 0 {
				let parts = [];
				let j = 0;
				while j < pending_attrs.len() {
					parts.push(pending_attrs[j]);
					parts.push(doc_hardline());
					j += 1;
				}
				parts.push(field_doc);
				fields.push(doc_concat_list(parts));
				pending_attrs = [];
			}
			else {
				fields.push(field_doc);
			}
		}
		i += 1;
	}
	if pending_attrs.len() > 0 {
		let j = 0;
		while j < pending_attrs.len() {
			fields.push(pending_attrs[j]);
			j += 1;
		}
	}
	if fields.len() == 0 {
		return doc_text("{}");
	}
	let indent_size = configuration::values["tab_width"];
	let inner = [];
	let j = 0;
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

fn doc_struct_item(node, children) {
	let list_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::field_declaration_list {
			list_idx = i;
			break;
		}
		i += 1;
	}
	if list_idx < 0 {
		return doc_text(text(node));
	}
	let header_doc = doc_header_from_children(children, list_idx);
	let list_doc = doc_for_child(children, list_idx);
	doc_concat_list([header_doc, doc_text(" "), list_doc])
}

fn doc_enum_variant_list(node) {
	let kids = node.children();
	let lines = [];
	let prev = ();
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c == () {
			i += 1;
			continue;
		}
		let k = c.kind_id();
		if k == kinds::attribute_item {
			lines.push(doc_for_node_raw(c));
			prev = c;
		}
		else if k == kinds::enum_variant {
			let variant_doc = doc_for_node_raw(c);
			lines.push(doc_concat_list([variant_doc, doc_text(",")]));
			prev = c;
		}
		else if k == kinds::line_comment || k == kinds::block_comment {
			if lines.len() > 0 && prev != () {
				let gap = slice(range(end(byte_range(prev)), start(byte_range(c))));
				if gap.index_of("\n") < 0 && gap.index_of("\r") < 0 {
					let last = lines.pop();
					lines.push(doc_concat_list([last, doc_text(" "), doc_for_node_raw(c)]));
				}
				else {
					lines.push(doc_for_node_raw(c));
				}
			}
			else {
				lines.push(doc_for_node_raw(c));
			}
			prev = c;
		}
		i += 1;
	}
	if lines.len() == 0 {
		return doc_text("{}");
	}
	let indent_size = configuration::values["tab_width"];
	let inner = [];
	let j = 0;
	while j < lines.len() {
		inner.push(lines[j]);
		if j < lines.len() - 1 {
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

fn doc_enum_item(node, children) {
	let body_idx = -1;
	let node_children = node.children();
	let i = 0;
	while i < children.len {
		if node_children != () && i < node_children.len() {
			let c = node_children[i];
			if c != () && c.kind_id() == kinds::enum_variant_list {
				body_idx = i;
				break;
			}
		}
		i += 1;
	}
	if body_idx < 0 {
		return doc_text(text(node));
	}
	let body_node = if node_children != () && body_idx < node_children.len() {
		node_children[body_idx]
	}
	else {
		()
	};
	let header = normalize_space(slice(range(start(byte_range(node)), start(byte_range(body_node)))));
	let body_doc = doc_enum_variant_list(body_node);
	doc_concat_list([doc_text(header), doc_text(" "), body_doc])
}
// doc_where_clause moved to AST-based implementation above
fn doc_trait_item(node, children)
{
	let body_idx = -1;
	let node_children = node.children();
	let i = 0;
	while i < children.len {
		if node_children != () && i < node_children.len() {
			let c = node_children[i];
			if c != () && c.kind_id() == kinds::declaration_list {
				body_idx = i;
				break;
			}
		}
		i += 1;
	}
	if body_idx < 0 {
		return doc_text(text(node));
	}
	let header = normalize_space(slice(range(start(byte_range(node)), start(children.range(body_idx)))));
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([doc_text(header), doc_text(" "), body_doc])
}

fn doc_declaration_list(children) {
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

fn doc_field_initializer(children) {
	let k_colon = kinds::colon;
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_colon {
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

fn doc_field_initializer_list(node, children) {
	let fields = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::field_initializer || k == kinds::shorthand_field_initializer || k == kinds::base_field_initializer {
			fields.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if fields.len() == 0 {
		return doc_text("{}");
	}
	let raw = text(node);
	let max_width = configuration::values["max_width"];
	let should_break = raw.len() > max_width || raw.index_of("\n") >= 0 || raw.index_of("\r") >= 0;
	let parts = [];
	let j = 0;
	while j < fields.len() {
		parts.push(fields[j]);
		if j < fields.len() - 1 {
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
				doc_text("{"),
				doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)])),
				doc_hardline(),
				doc_text("}")
			]
		);
	}
	doc_concat_list([doc_text("{ "), doc_concat_list(parts), doc_text(" }")])
}

fn doc_struct_expression(node, children) {
	let list_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::field_initializer_list {
			list_idx = i;
			break;
		}
		i += 1;
	}
	if list_idx < 0 {
		return doc_text(text(node));
	}
	let header_doc = doc_header_from_children(children, list_idx);
	let list_doc = doc_for_child(children, list_idx);
	doc_concat_list([header_doc, doc_text(" "), list_doc])
}

fn doc_impl_item(node, children) {
	let list_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::declaration_list || k == kinds::block {
			list_idx = i;
			break;
		}
		i += 1;
	}
	if list_idx < 0 {
		return doc_text(text(node));
	}
	let header_doc = doc_header_from_children(children, list_idx);
	let list_doc = doc_for_child(children, list_idx);
	doc_concat_list([header_doc, doc_text(" "), list_doc])
}

fn doc_for_expression(node, children) {
	let block_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::block {
			block_idx = i;
			break;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_text(text(node));
	}
	let header_doc = doc_header_from_children(children, block_idx);
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([header_doc, doc_text(" "), block_doc])
}

fn doc_while_expression(node, children) {
	let block_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::block {
			block_idx = i;
			break;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_text(text(node));
	}
	let header_doc = doc_header_from_children(children, block_idx);
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([header_doc, doc_text(" "), block_doc])
}

fn doc_loop_expression(node, children) {
	let block_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::block {
			block_idx = i;
			break;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_text(text(node));
	}
	let header_doc = doc_header_from_children(children, block_idx);
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([header_doc, doc_text(" "), block_doc])
}

fn doc_block_with_keyword(node, children, keyword) {
	let block_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::block {
			block_idx = i;
			break;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_text(text(node));
	}
	let block_range = children.range(block_idx);
	let inline = inline_block_expression_doc(block_range);
	if inline != () {
		return doc_concat_list([doc_text(keyword), doc_text(" { "), inline, doc_text(" }")]);
	}
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([doc_text(keyword), doc_text(" "), block_doc])
}

fn doc_break_expression(children) {
	let k_break = kinds::kw_break;
	let k_semi = kinds::semi;
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_break {
			parts.push(doc_text("break"));
			need_space = true;
		}
		else if k == k_semi {
			parts.push(doc_text(";"));
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

fn doc_continue_expression(children) {
	let k_continue = kinds::kw_continue;
	let k_semi = kinds::semi;
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_continue {
			parts.push(doc_text("continue"));
			need_space = true;
		}
		else if k == k_semi {
			parts.push(doc_text(";"));
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

fn doc_await_expression(node, children) {
	let expr_doc = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k != kinds::kw_await && k != kinds::dot {
			expr_doc = doc_for_child(children, i);
			break;
		}
		i += 1;
	}
	if expr_doc == () {
		return doc_text(text(node));
	}
	doc_concat_list([expr_doc, doc_text(".await")])
}

fn doc_index_expression(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::lbracket {
			parts.push(doc_text("["));
		}
		else if k == kinds::rbracket {
			parts.push(doc_text("]"));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_range_expression(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::range || k == kinds::range_eq {
			let op = slice(children.range(i)).trim();
			parts.push(doc_text(op));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_bracket_list(node, children, open_bracket, close_bracket, k_open, k_close) {
	let k_comma = kinds::comma;
	let items = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k != k_open && k != k_close && k != k_comma {
			items.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if items.len() == 0 {
		return doc_text(open_bracket + close_bracket);
	}
	let raw = text(node);
	let max_width = configuration::values["max_width"];
	let should_break = raw.len() > max_width || raw.index_of("\n") >= 0 || raw.index_of("\r") >= 0;
	let parts = [];
	let j = 0;
	while j < items.len() {
		parts.push(items[j]);
		if j < items.len() - 1 {
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
				doc_text(open_bracket),
				doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)])),
				doc_hardline(),
				doc_text(close_bracket)
			]
		);
	}
	doc_concat_list([doc_text(open_bracket), doc_concat_list(parts), doc_text(close_bracket)])
}

fn doc_array_expression(node, children) {
	doc_bracket_list(node, children, "[", "]", kinds::lbracket, kinds::rbracket)
}

fn doc_tuple_expression(node, children) {
	doc_bracket_list(node, children, "(", ")", kinds::lparen, kinds::rparen)
}

fn doc_tuple_pattern(node, children) {
	doc_bracket_list(node, children, "(", ")", kinds::lparen, kinds::rparen)
}

fn doc_type_cast_expression(children) {
	let k_as = kinds::kw_as;
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_as {
			parts.push(doc_text(" as "));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_simple_item_declaration(children, keyword, keyword_kind) {
	let k_colon = kinds::colon;
	let k_eq = kinds::assign;
	let k_semi = kinds::semi;
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == keyword_kind {
			if need_space {
				parts.push(doc_text(" "));
			}
			parts.push(doc_text(keyword));
			need_space = true;
		}
		else if k == k_colon {
			parts.push(doc_text(": "));
			need_space = false;
		}
		else if k == k_eq {
			parts.push(doc_text(" = "));
			need_space = false;
		}
		else if k == k_semi {
			parts.push(doc_text(";"));
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

fn doc_array_type(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::lbracket {
			parts.push(doc_text("["));
		}
		else if k == kinds::rbracket {
			parts.push(doc_text("]"));
		}
		else if k == kinds::semi {
			parts.push(doc_text("; "));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_const_item(children) {
	doc_simple_item_declaration(children, "const", kinds::kw_const)
}

fn doc_static_item(children) {
	doc_simple_item_declaration(children, "static", kinds::kw_static)
}

fn doc_type_item(children) {
	doc_simple_item_declaration(children, "type", kinds::kw_type)
}

fn doc_mod_item(node, children) {
	let body_idx = -1;
	let node_children = node.children();
	let i = 0;
	while i < children.len {
		if node_children != () && i < node_children.len() {
			let c = node_children[i];
			if c != () && (c.kind_id() == kinds::declaration_list || c.kind_id() == kinds::block) {
				body_idx = i;
				break;
			}
		}
		i += 1;
	}
	if body_idx < 0 {
		return doc_text(normalize_space(text(node)));
	}
	let header = normalize_space(slice(range(start(byte_range(node)), start(children.range(body_idx)))));
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([doc_text(header), doc_text(" "), body_doc])
}

fn doc_union_item(node, children) {
	let list_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::field_declaration_list {
			list_idx = i;
			break;
		}
		i += 1;
	}
	if list_idx < 0 {
		return doc_text(text(node));
	}
	let header_doc = doc_header_from_children(children, list_idx);
	let list_doc = doc_for_child(children, list_idx);
	doc_concat_list([header_doc, doc_text(" "), list_doc])
}

fn doc_extern_crate_declaration(node) {
	doc_text(normalize_space(text(node)))
}

fn doc_foreign_mod_item(node, children) {
	let body_idx = -1;
	let node_children = node.children();
	let i = 0;
	while i < children.len {
		if node_children != () && i < node_children.len() {
			let c = node_children[i];
			if c != () && c.kind_id() == kinds::declaration_list {
				body_idx = i;
				break;
			}
		}
		i += 1;
	}
	if body_idx < 0 {
		return doc_text(text(node));
	}
	let header = normalize_space(slice(range(start(byte_range(node)), start(children.range(body_idx)))));
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([doc_text(header), doc_text(" "), body_doc])
}

fn macro_needs_space(tt_node) {
	if tt_node == () {
		return false;
	}
	let kids = children(tt_node);
	if kids == () {
		return false;
	}
	let i = 0;
	while i < kids.len() {
		if kids[i] != () {
			return kids[i].kind_id() == kinds::lbrace;
		}
		i += 1;
	}
	false
}

fn doc_macro_definition(node, children) {
	let raw = text(node).trim();
	if raw.starts_with("macro_rules!") {
		let lbrace = raw.index_of("{");
		let rbrace = last_index_of(raw, "}");
		if lbrace >= 0 && rbrace > lbrace {
			let header = normalize_space(raw.sub_string(0, lbrace));
			let inner_raw = raw.sub_string(lbrace + 1, rbrace - lbrace - 1);
			let lines = [];
			let line = "";
			let i = 0;
			while i < inner_raw.len() {
				let ch = inner_raw.sub_string(i, 1);
				if ch == "\n" || ch == "\r" {
					let trimmed = line.trim();
					if !trimmed.is_empty() {
						let lead = 0;
						let j = 0;
						while j < line.len() {
							let c = line.sub_string(j, 1);
							if c == " " {
								lead += 1;
							}
							else if c == "\t" {
								lead += configuration::values["tab_width"];
							}
							else {
								break;
							}
							j += 1;
						}
						lines.push([trimmed, lead]);
					}
					line = "";
				}
				else {
					line += ch;
				}
				i += 1;
			}
			let trimmed = line.trim();
			if !trimmed.is_empty() {
				let lead = 0;
				let j = 0;
				while j < line.len() {
					let c = line.sub_string(j, 1);
					if c == " " {
						lead += 1;
					}
					else if c == "\t" {
						lead += configuration::values["tab_width"];
					}
					else {
						break;
					}
					j += 1;
				}
				lines.push([trimmed, lead]);
			}
			if lines.len() == 0 {
				return doc_concat_list([doc_text(header), doc_text(" {}")]);
			}
			let base_indent = lines
			[0][1];
			let j = 1;
			while j < lines.len() {
				if lines[j][1] < base_indent {
					base_indent = lines[j]
					[1];
				}
				j += 1;
			}
			let indent_size = configuration::values["tab_width"];
			let inner = [];
			let j = 0;
			while j < lines.len() {
				let text = lines[j]
				[0];
				let lead = lines
				[j][1];
				let extra = if lead > base_indent {
					lead - base_indent
				}
				else {
					0
				};
				let tabs = extra / indent_size;
				let rem = extra - tabs * indent_size;
				let prefix = "";
				let t = 0;
				while t < tabs {
					prefix += "\t";
					t += 1;
				}
				let s = 0;
				while s < rem {
					prefix += " ";
					s += 1;
				}
				inner.push(doc_text(prefix + text));
				if j < lines.len() - 1 {
					inner.push(doc_hardline());
				}
				j += 1;
			}
			return doc_concat_list(
				[
					doc_text(header),
					doc_text(" {"),
					doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)])),
					doc_hardline(),
					doc_text("}")
				]
			);
		}
	}
	let node_children = node.children();
	let tt_node = ();
	let tt_doc = ();
	let tt_range = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::token_tree {
			if node_children != () && i < node_children.len() {
				tt_node = node_children[i];
			}
			tt_doc = doc_for_child(children, i);
			tt_range = children.range(i);
			break;
		}
		i += 1;
	}
	if tt_doc == () || tt_range == () {
		return doc_text(text(node));
	}
	let header = normalize_space(slice(range(start(byte_range(node)), start(tt_range))));
	if header.starts_with("macro_rules!") {
		let raw = text(node).trim();
		let lbrace = raw.index_of("{");
		let rbrace = last_index_of(raw, "}");
		if lbrace >= 0 && rbrace > lbrace {
			let inner_raw = raw.sub_string(lbrace + 1, rbrace - lbrace - 1);
			let lines = [];
			let line = "";
			let i = 0;
			while i < inner_raw.len() {
				let ch = inner_raw.sub_string(i, 1);
				if ch == "\n" || ch == "\r" {
					let trimmed = line.trim();
					if !trimmed.is_empty() {
						lines.push(trimmed);
					}
					line = "";
				}
				else {
					line += ch;
				}
				i += 1;
			}
			let trimmed = line.trim();
			if !trimmed.is_empty() {
				lines.push(trimmed);
			}
			let indent_size = configuration::values["tab_width"];
			let inner = [];
			let j = 0;
			while j < lines.len() {
				inner.push(doc_text(lines[j]));
				if j < lines.len() - 1 {
					inner.push(doc_hardline());
				}
				j += 1;
			}
			return doc_concat_list(
				[
					doc_text(header),
					doc_text(" "),
					doc_text("{"),
					doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)])),
					doc_hardline(),
					doc_text("}")
				]
			);
		}
	}
	if macro_needs_space(tt_node) {
		return doc_concat_list([doc_text(header), doc_text(" "), tt_doc]);
	}
	doc_concat_list([doc_text(header), tt_doc])
}

fn doc_macro_rule(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::fat_arrow {
			parts.push(doc_text(" => "));
		}
		else if k == kinds::semi {
			parts.push(doc_text(";"));
		}
		else if k == kinds::token_tree {
			parts.push(doc_for_child(children, i));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_macro_rules_definition(node, children) {
	let node_children = node.children();
	let tt_node = ();
	let tt_doc = ();
	let tt_range = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::token_tree {
			if node_children != () && i < node_children.len() {
				tt_node = node_children[i];
			}
			tt_doc = doc_for_child(children, i);
			tt_range = children.range(i);
			break;
		}
		i += 1;
	}
	if tt_doc == () || tt_range == () {
		return doc_text(text(node));
	}
	let header = normalize_space(slice(range(start(byte_range(node)), start(tt_range))));
	if macro_needs_space(tt_node) {
		return doc_concat_list([doc_text(header), doc_text(" "), tt_doc]);
	}
	doc_concat_list([doc_text(header), tt_doc])
}

fn doc_try_expression(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::qmark {
			parts.push(doc_text("?"));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_return_expression(children) {
	let parts = [];
	let i = 0;
	let saw_return = false;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::kw_return {
			parts.push(doc_text("return"));
			saw_return = true;
		}
		else {
			if saw_return {
				parts.push(doc_text(" "));
				saw_return = false;
			}
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_closure_expression(node, children) {
	let node_children = node.children();
	if node_children == () || node_children.len() == 0 {
		return doc_text(text(node));
	}
	let parts = [];
	let prev_kind = "";
	let has_return_type = node_children.find(|c| c != () && c.kind_id() == kinds::arrow) != ();
	let i = 0;
	while i < node_children.len() {
		let child = node_children[i];
		if child != () {
			let k = child.kind_id();
			if closure_needs_space(prev_kind, k) {
				parts.push(doc_text(" "));
			}
			if k == kinds::block {
				parts.push(doc_closure_block_child(child, has_return_type));
			}
			else {
				let cached = doc_for_node(child);
				if cached != () {
					parts.push(cached);
				}
				else if k == kinds::closure_parameters {
					parts.push(doc_closure_parameters(child.children()));
				}
				else if k == kinds::line_comment || k == kinds::block_comment {
					parts.push(doc_closure_comment_child(child));
				}
				else if k == kinds::type_identifier || k == kinds::generic_type || k == kinds::reference_type || k == kinds::tuple_type || k == kinds::array_type {
					parts.push(doc_closure_return_type_child(child));
				}
				else if k == kinds::kw_move || k == kinds::kw_async || k == kinds::kw_static || k == kinds::pipe || k == kinds::arrow {
					parts.push(doc_closure_keyword_child(child));
				}
				else {
					parts.push(doc_for_node_or_range(child));
				}
			}
			prev_kind = k;
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_closure_parameters(children) {
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let cached = children.doc(i);
		if cached != () {
			parts.push(cached);
			need_space = false;
			i += 1;
			continue;
		}
		let k = children.kind(i);
		if k == kinds::pipe {
			parts.push(doc_text("|"));
			need_space = false;
		}
		else if k == kinds::comma {
			parts.push(doc_text(", "));
			need_space = false;
		}
		else if k == kinds::line_comment || k == kinds::block_comment {
			if parts.len() > 0 {
				parts.push(doc_text(" "));
			}
			parts.push(doc_for_child(children, i));
			need_space = true;
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

fn normalize_commas(text) {
	let out = "";
	let i = 0;
	let in_string = false;
	let in_char = false;
	let escape = false;
	while i < text.len() {
		let ch = text.sub_string(i, 1);
		if in_string {
			out += ch;
			if escape {
				escape = false;
			}
			else if ch == "\\" {
				escape = true;
			}
			else if ch == "\"" {
				in_string = false;
			}
			i += 1;
			continue;
		}
		if in_char {
			out += ch;
			if escape {
				escape = false;
			}
			else if ch == "\\" {
				escape = true;
			}
			else if ch == "'" {
				in_char = false;
			}
			i += 1;
			continue;
		}
		if ch == "\"" {
			out += ch;
			in_string = true;
			i += 1;
			continue;
		}
		if ch == "'" {
			out += ch;
			in_char = true;
			i += 1;
			continue;
		}
		if ch == "," {
			out = out.trim_end();
			out += ",";
			i += 1;
			while i < text.len() {
				let ws = text.sub_string(i, 1);
				if ws == " " || ws == "\t" || ws == "\n" || ws == "\r" {
					i += 1;
				}
				else {
					break;
				}
			}
			if i < text.len() {
				let next = text.sub_string(i, 1);
				if next != ")" && next != "]" && next != "}" && next != ">" {
					out += " ";
				}
			}
			continue;
		}
		out += ch;
		i += 1;
	}
	out
}

fn count_chain_segments_in_text(text) {
	let count = 0;
	let i = 0;
	let in_string = false;
	while i < text.len() {
		let ch = text.sub_string(i, 1);
		if ch == "\"" {
			in_string = !in_string;
			i += 1;
			continue;
		}
		if !in_string && ch == "." {
			if i + 1 < text.len() {
				let next = text.sub_string(i + 1, 1);
				let is_ident = (next >= "a" && next <= "z") || (next >= "A" && next <= "Z") || next == "_";
				if is_ident {
					count += 1;
				}
			}
		}
		i += 1;
	}
	count
}

fn inline_block_expression_doc(block_range) {
	if block_range == () {
		return ();
	}
	let raw = slice(block_range).trim();
	if raw.len() < 2 || !raw.starts_with("{") || !raw.ends_with("}") {
		return ();
	}
	let inner = raw.sub_string(1, raw.len() - 2).trim();
	if inner.is_empty() {
		return ();
	}
	if inner.index_of(";") >= 0 || inner.index_of("\n") >= 0 || inner.index_of("\r") >= 0 {
		return ();
	}
	let ref_matches = query("rust", "(reference_expression) @r", block_range);
	for m in ref_matches {
		let rnode = m.captures()
		["r"];
		if rnode == () {
			continue;
		}
		let p = rnode.parent();
		if p == () || p.kind_id() != kinds::block {
			continue;
		}
		let kids = children(rnode);
		if kids.len() == 0 {
			continue;
		}
		let prefix = "";
		let operand = "";
		let i = 0;
		while i < kids.len() {
			let c = kids[i];
			if c == () {
				i += 1;
				continue;
			}
			let k = c.kind_id();
			if k == kinds::amp || k == kinds::mutable_specifier {
				prefix += slice(byte_range(c)).trim();
			}
			else {
				operand = slice(byte_range(c)).trim();
				break;
			}
			i += 1;
		}
		if !prefix.is_empty() && !operand.is_empty() {
			let needs_space = prefix.index_of("mut") >= 0;
			let text = if needs_space {
				prefix + " " + operand
			}
			else {
				prefix + operand
			};
			return doc_text(text);
		}
	}
	let unary_matches = query("rust", "(unary_expression) @u", block_range);
	for m in unary_matches {
		let u = m.captures()
		["u"];
		if u == () {
			continue;
		}
		let p = u.parent();
		if p == () || p.kind_id() != kinds::block {
			continue;
		}
		let kids = children(u);
		if kids.len() == 0 {
			continue;
		}
		let prefix = "";
		let operand = "";
		let i = 0;
		while i < kids.len() {
			let c = kids[i];
			if c == () {
				i += 1;
				continue;
			}
			let k = c.kind_id();
			if k == kinds::plus || k == kinds::minus || k == kinds::bang || k == kinds::star || k == kinds::amp || k == kinds::mutable_specifier {
				prefix += slice(byte_range(c)).trim();
			}
			else {
				operand = slice(byte_range(c)).trim();
				break;
			}
			i += 1;
		}
		if !prefix.is_empty() && !operand.is_empty() {
			let needs_space = prefix.ends_with("mut") || prefix.ends_with("await") || prefix.ends_with("box");
			let text = if needs_space {
				prefix + " " + operand
			}
			else {
				prefix + operand
			};
			return doc_text(text);
		}
	}
	let bin_matches = query("rust", "(binary_expression) @b", block_range);
	for m in bin_matches {
		let b = m.captures()
		["b"];
		if b == () {
			continue;
		}
		let p = b.parent();
		if p == () || p.kind_id() != kinds::block {
			continue;
		}
		let kids = children(b);
		if kids.len() == 0 {
			continue;
		}
		let parts = [];
		let i = 0;
		while i < kids.len() {
			let c = kids[i];
			if c == () {
				i += 1;
				continue;
			}
			let k = c.kind_id();
			if k == kinds::plus || k == kinds::minus || k == kinds::star || k == kinds::slash || k == kinds::percent || k == kinds::eq_eq || k == kinds::not_eq || k == kinds::lt || k == kinds::gt || k == kinds::lt_eq || k == kinds::gt_eq || k == kinds::and_and || k == kinds::or_or || k == kinds::amp || k == kinds::pipe || k == kinds::caret || k == kinds::shl || k == kinds::shr {
				parts.push(doc_text(" " + slice(byte_range(c)).trim() + " "));
			}
			else {
				parts.push(doc_text(slice(byte_range(c)).trim()));
			}
			i += 1;
		}
		return doc_concat_list(parts);
	}
	let call_matches = query("rust", "(call_expression) @c", block_range);
	for m in call_matches {
		let cnode = m.captures()
		["c"];
		if cnode == () {
			continue;
		}
		let p = cnode.parent();
		if p == () || p.kind_id() != kinds::block {
			continue;
		}
		let kids = children(cnode);
		if kids.len() == 0 {
			continue;
		}
		let fn_idx = -1;
		let args_idx = -1;
		let i = 0;
		while i < kids.len() {
			let k = kids[i].kind_id();
			if k == kinds::arguments {
				args_idx = i;
			}
			else if fn_idx < 0 && k != kinds::lparen && k != kinds::rparen && k != kinds::comma {
				fn_idx = i;
			}
			i += 1;
		}
		if fn_idx >= 0 && args_idx >= 0 {
			let fn_text = slice(byte_range(kids[fn_idx])).trim();
			let args_text = slice(byte_range(kids[args_idx])).trim();
			return doc_text(fn_text + args_text);
		}
	}
	let field_matches = query("rust", "(field_expression) @f", block_range);
	for m in field_matches {
		let fnode = m.captures()
		["f"];
		if fnode == () {
			continue;
		}
		let p = fnode.parent();
		if p == () || p.kind_id() != kinds::block {
			continue;
		}
		let kids = children(fnode);
		if kids.len() == 0 {
			continue;
		}
		let value_idx = -1;
		let field_idx = -1;
		let i = 0;
		while i < kids.len() {
			let k = kids[i].kind_id();
			if k == kinds::field_identifier {
				field_idx = i;
			}
			else if value_idx < 0 && k != kinds::dot {
				value_idx = i;
			}
			i += 1;
		}
		if value_idx >= 0 && field_idx >= 0 {
			let value_text = slice(byte_range(kids[value_idx])).trim();
			let field_text = slice(byte_range(kids[field_idx])).trim();
			return doc_text(value_text + "." + field_text);
		}
	}
	let expr_matches = query("rust", "(block (_) @e)", block_range);
	for m in expr_matches {
		let e = m.captures()
		["e"];
		if e == () {
			continue;
		}
		let p = e.parent();
		if p == () || p.kind_id() != kinds::block {
			continue;
		}
		let r = byte_range(e);
		return doc_range(start(r), end(r));
	}
	doc_text(inner)
}

fn doc_function_item(node, children) {
	let k_block = kinds::block;
	let block_idx = -1;
	let where_idx = -1;
	let node_children = node.children();
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_block {
			block_idx = i;
			break;
		}
		i += 1;
	}
	i = 0;
	while i < children.len {
		if node_children != () && i < node_children.len() {
			let c = node_children[i];
			if c != () && c.kind_id() == kinds::where_clause {
				where_idx = i;
				break;
			}
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_text(text(node));
	}
	let parts = [];
	let need_space = false;
	let i = 0;
	let header_end = if where_idx >= 0 && where_idx < block_idx {
		where_idx
	}
	else {
		block_idx
	};
	while i < header_end {
		let k = children.kind(i);
		let node_kind = if node_children != () && i < node_children.len() {
			node_children[i].kind_id()
		}
		else {
			""
		};
		if node_kind == kinds::type_parameters {
			parts.push(doc_type_parameters(node_children[i]));
			need_space = false;
		}
		else if node_kind == kinds::generic_type {
			parts.push(doc_generic_type(node_children[i]));
			need_space = true;
		}
		else if node_kind == kinds::type_arguments {
			parts.push(doc_type_arguments(node_children[i]));
			need_space = true;
		}
		else if k == kinds::arrow {
			parts.push(doc_text(" -> "));
			need_space = false;
		}
		else if k == kinds::parameters {
			parts.push(doc_for_child(children, i));
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
	let block_doc = doc_for_child(children, block_idx);
	if where_idx >= 0 && where_idx < block_idx {
		let where_node = node_children[where_idx];
		let pred_count = {
			let kids = children(where_node);
			let count = 0;
			let i = 0;
			while i < kids.len() {
				let c = kids[i];
				if c != () && c.kind_id() == kinds::where_predicate {
					count += 1;
				}
				i += 1;
			}
			count
		};
		if pred_count <= 1 {
			let where_inline = doc_where_clause_inline(where_node);
			return doc_concat_list(
				[
					doc_concat_list(parts),
					doc_hardline(),
					where_inline,
					doc_text(" "),
					block_doc
				]
			);
		}
		let where_doc = doc_where_clause(where_node);
		return doc_concat_list(
			[
				doc_concat_list(parts),
				doc_hardline(),
				where_doc,
				doc_text(" "),
				block_doc
			]
		);
	}
	doc_concat_list([doc_concat_list(parts), doc_text(" "), block_doc])
}

fn is_chain_kind(k) {
	k == kinds::call_expression || k == kinds::field_expression
}

fn same_node(a, b) {
	if a == () || b == () {
		return false;
	}
	let ra = byte_range(a);
	let rb = byte_range(b);
	start(ra) == start(rb) && end(ra) == end(rb)
}

fn chain_root(node) {
	let root = node;
	let p = node.parent();
	while p != () {
		let k = p.kind_id();
		if k == kinds::call_expression || k == kinds::field_expression {
			root = p;
			p = p.parent();
		}
		else {
			break;
		}
	}
	root
}

fn chain_segment_count(node) {
	let count = 0;
	let current = node;
	while current != () && is_chain_kind(current.kind_id()) {
		let ck = current.kind_id();
		if ck == kinds::call_expression {
			let kids = children(current);
			let fn_node = ();
			let args_node = ();
			if kids != () {
				let i = 0;
				while i < kids.len() {
					let k = kids[i].kind_id();
					if k == kinds::arguments {
						args_node = kids[i];
					}
					else if fn_node == () && !is_punct_kind(k) {
						fn_node = kids[i];
					}
					i += 1;
				}
			}
			if fn_node == () || args_node == () {
				break;
			}
			current = fn_node;
			continue;
		}
		if ck == kinds::field_expression {
			let kids = children(current);
			let value_node = ();
			let field_node = ();
			if kids != () {
				let i = 0;
				while i < kids.len() {
					let k = kids[i].kind_id();
					if k == kinds::field_identifier {
						field_node = kids[i];
					}
					else if k != kinds::dot && value_node == () {
						value_node = kids[i];
					}
					i += 1;
				}
			}
			if value_node == () || field_node == () {
				break;
			}
			count += 1;
			current = value_node;
			continue;
		}
		break;
	}
	count
}

fn chain_base_node(node) {
	let current = node;
	while current != () && is_chain_kind(current.kind_id()) {
		let ck = current.kind_id();
		let kids = children(current);
		if ck == kinds::call_expression {
			let fn_node = ();
			let i = 0;
			while kids != () && i < kids.len() {
				let k = kids[i].kind_id();
				if k != kinds::arguments && !is_punct_kind(k) {
					fn_node = kids[i];
					break;
				}
				i += 1;
			}
			if fn_node == () {
				break;
			}
			current = fn_node;
			continue;
		}
		if ck == kinds::field_expression {
			let value_node = ();
			let i = 0;
			while kids != () && i < kids.len() {
				let k = kids[i].kind_id();
				if k != kinds::dot && k != kinds::field_identifier {
					value_node = kids[i];
					break;
				}
				i += 1;
			}
			if value_node == () {
				break;
			}
			current = value_node;
			continue;
		}
		break;
	}
	current
}

fn is_simple_identifier_kind(k) {
	k == kinds::identifier || k == kinds::kw_self || k == kinds::kw_super || k == kinds::kw_crate
}

fn chain_should_wrap(node) {
	node.token_len() > configuration::values["max_width"]
}

fn doc_chain_expression(root) {
	let segments = [];
	let pending_args = ();
	let current = root;
	while current != () && is_chain_kind(current.kind_id()) {
		let ck = current.kind_id();
		if ck == kinds::call_expression {
			let kids = children(current);
			let fn_node = ();
			let args_node = ();
			if kids != () {
				let i = 0;
				while i < kids.len() {
					let k = kids[i].kind_id();
					if k == kinds::arguments {
						args_node = kids[i];
					}
					else if fn_node == () && !is_punct_kind(k) {
						fn_node = kids[i];
					}
					i += 1;
				}
			}
			if fn_node == () || args_node == () {
				return doc_for_node_raw(root);
			}
			pending_args = args_node;
			current = fn_node;
			continue;
		}
		if ck == kinds::field_expression {
			let kids = children(current);
			let value_node = ();
			let field_node = ();
			if kids != () {
				let i = 0;
				while i < kids.len() {
					let k = kids[i].kind_id();
					if k == kinds::field_identifier {
						field_node = kids[i];
					}
					else if k != kinds::dot && value_node == () {
						value_node = kids[i];
					}
					i += 1;
				}
			}
			if value_node == () || field_node == () {
				return doc_for_node_raw(root);
			}
			segments.push([field_node, pending_args]);
			pending_args = ();
			current = value_node;
			continue;
		}
		break;
	}
	let base_has_args = pending_args != ();
	let base_doc = if pending_args != () {
		let fn_doc = doc_for_node_raw(current);
		let args_doc = if doc_for_node(pending_args) != () {
			doc_for_node(pending_args)
		}
		else {
			doc_for_node_raw(pending_args)
		};
		pending_args = ();
		doc_concat_list([fn_doc, args_doc])
	}
	else {
		doc_for_node_raw(current)
	};
	if segments.len() == 0 {
		return base_doc;
	}
	segments.reverse();
	let wrap = chain_should_wrap(root) || segments.len() >= 3;
	if segments.len() == 0 {
		return base_doc;
	}
	if !wrap {
		let out = [base_doc];
		let i = 0;
		while i < segments.len() {
			let seg = segments[i];
			let field_doc = doc_for_node_raw(seg[0]);
			let args_doc = if seg[1] != () {
				let cached = doc_for_node(seg[1]);
				if cached != () {
					cached
				}
				else {
					doc_for_node_raw(seg[1])
				}
			}
			else {
				doc_empty()
			};
			out.push(doc_text("."));
			out.push(field_doc);
			if seg[1] != () {
				out.push(args_doc);
			}
			i += 1;
		}
		return doc_concat_list(out);
	}
	let indent_size = configuration::values["tab_width"];
	let head = base_doc;
	let tail = [];
	let start_idx = 0;
	if !base_has_args && segments.len() > 0 {
		let seg = segments[0];
		let field_doc = doc_for_node_raw(seg[0]);
		let args_doc = if seg[1] != () {
			let cached = doc_for_node(seg[1]);
			if cached != () {
				cached
			}
			else {
				doc_for_node_raw(seg[1])
			}
		}
		else {
			doc_empty()
		};
		let inline = [head, doc_text("."), field_doc];
		if seg[1] != () {
			inline.push(args_doc);
		}
		head = doc_concat_list(inline);
		start_idx = 1;
	}
	let i = start_idx;
	while i < segments.len() {
		let seg = segments[i];
		let field_doc = doc_for_node_raw(seg[0]);
		let args_doc = if seg[1] != () {
			let cached = doc_for_node(seg[1]);
			if cached != () {
				cached
			}
			else {
				doc_for_node_raw(seg[1])
			}
		}
		else {
			doc_empty()
		};
		tail.push(doc_hardline());
		tail.push(doc_text("."));
		tail.push(field_doc);
		if seg[1] != () {
			tail.push(args_doc);
		}
		i += 1;
	}
	if tail.len() == 0 {
		return head;
	}
	doc_concat_list([
		head,
		doc_indent(indent_size, doc_concat_list(tail))
	])
}

fn doc_call_expression_simple(node, children) {
	let k_args = kinds::arguments;
	let fn_idx = -1;
	let args_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_args {
			args_idx = i;
		}
		else if fn_idx < 0 && !is_punct_kind(k) {
			fn_idx = i;
		}
		i += 1;
	}
	if args_idx < 0 || fn_idx < 0 {
		return doc_text(text(node));
	}
	let fn_doc = doc_for_child(children, fn_idx);
	let args_doc = doc_for_child(children, args_idx);
	doc_concat_list([fn_doc, args_doc])
}

fn doc_call_expression(node, children) {
	let root = chain_root(node);
	if same_node(root, node) {
		return doc_chain_expression(root);
	}
	doc_call_expression_simple(node, children)
}

fn doc_field_expression_simple(node, children) {
	let value_idx = -1;
	let field_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::field_identifier {
			field_idx = i;
		}
		else if k != kinds::dot && value_idx < 0 {
			value_idx = i;
		}
		i += 1;
	}
	if value_idx < 0 || field_idx < 0 {
		return doc_text(text(node));
	}
	doc_concat_list([
		doc_for_child(children, value_idx),
		doc_text("."),
		doc_for_child(children, field_idx)
	])
}

fn doc_field_expression(node, children) {
	let root = chain_root(node);
	if same_node(root, node) {
		return doc_chain_expression(root);
	}
	doc_field_expression_simple(node, children)
}

fn build_doc(node, children) {
	let k = node.kind_id();
	if k == kinds::source_file {
		return doc_source_file(node, children);
	}
	if k == kinds::line_comment {
		let comment_text = text(node);
		if comment_text.starts_with("///") {
			return comments::doc_line_comment(node, "///");
		}
		if comment_text.starts_with("//!") {
			return comments::doc_line_comment(node, "//!");
		}
		return comments::doc_line_comment(node, "//");
	}
	if k == kinds::block_comment {
		return comments::doc_block_comment(node, "/*", "*/");
	}
	if k == kinds::string_literal || k == kinds::raw_string_literal {
		return doc_text(text(node));
	}
	if k == kinds::block {
		return doc_block(node, children);
	}
	if k == kinds::if_expression {
		return doc_if_expression(node, children);
	}
	if k == kinds::else_clause {
		return doc_else_clause(children);
	}
	if k == kinds::match_expression {
		return doc_match_expression(node, children);
	}
	if k == kinds::match_block {
		return doc_match_block(node, children);
	}
	if k == kinds::match_arm {
		return doc_match_arm(children);
	}
	if k == kinds::attribute_item {
		return doc_attribute_item(node, children);
	}
	if k == kinds::macro_invocation {
		return doc_macro_invocation(node, children);
	}
	if k == kinds::token_tree {
		return doc_token_tree(node);
	}
	if k == kinds::use_declaration {
		return doc_use_declaration(node, children);
	}
	if k == kinds::struct_item {
		return doc_struct_item(node, children);
	}
	if k == kinds::enum_item {
		return doc_enum_item(node, children);
	}
	if k == kinds::trait_item {
		return doc_trait_item(node, children);
	}
	if k == kinds::mod_item {
		return doc_mod_item(node, children);
	}
	if k == kinds::const_item {
		return doc_const_item(children);
	}
	if k == kinds::static_item {
		return doc_static_item(children);
	}
	if k == kinds::type_item {
		return doc_type_item(children);
	}
	if k == kinds::union_item {
		return doc_union_item(node, children);
	}
	if k == kinds::extern_crate_declaration {
		return doc_extern_crate_declaration(node);
	}
	if k == kinds::foreign_mod_item {
		return doc_foreign_mod_item(node, children);
	}
	if k == kinds::macro_definition {
		return doc_macro_definition(node, children);
	}
	if k == kinds::declaration_list {
		return doc_declaration_list(children);
	}
	if k == kinds::field_declaration_list {
		return doc_field_declaration_list(node, children);
	}
	if k == kinds::field_declaration {
		return doc_field_declaration(children);
	}
	if k == kinds::struct_expression {
		return doc_struct_expression(node, children);
	}
	if k == kinds::field_initializer_list {
		return doc_field_initializer_list(node, children);
	}
	if k == kinds::field_initializer {
		return doc_field_initializer(children);
	}
	if k == kinds::impl_item {
		return doc_impl_item(node, children);
	}
	if k == kinds::for_expression {
		return doc_for_expression(node, children);
	}
	if k == kinds::while_expression {
		return doc_while_expression(node, children);
	}
	if k == kinds::loop_expression {
		return doc_loop_expression(node, children);
	}
	if k == kinds::break_expression {
		return doc_break_expression(children);
	}
	if k == kinds::continue_expression {
		return doc_continue_expression(children);
	}
	if k == kinds::return_expression {
		return doc_return_expression(children);
	}
	if k == kinds::call_expression {
		return doc_call_expression(node, children);
	}
	if k == kinds::field_expression {
		return doc_field_expression(node, children);
	}
	if k == kinds::generic_type {
		return doc_generic_type(node);
	}
	if k == kinds::type_arguments {
		return doc_type_arguments(node);
	}
	if k == kinds::arguments {
		return doc_arguments(node, children);
	}
	if k == kinds::parameters {
		return doc_parameters(node, children);
	}
	if k == kinds::closure_parameters {
		return doc_closure_parameters(children);
	}
	if k == kinds::parameter {
		return doc_parameter(children);
	}
	if k == kinds::let_condition {
		return doc_let_condition(children);
	}
	if k == kinds::let_declaration {
		return doc_let_declaration(children);
	}
	if k == kinds::binary_expression || k == kinds::assignment_expression || k == kinds::compound_assignment_expr {
		return doc_operator_expression(node, children);
	}
	if k == kinds::unary_expression {
		return doc_unary_expression(children);
	}
	if k == kinds::reference_expression {
		return doc_reference_expression(children);
	}
	if k == kinds::await_expression {
		return doc_await_expression(node, children);
	}
	if k == kinds::index_expression {
		return doc_index_expression(children);
	}
	if k == kinds::range_expression {
		return doc_range_expression(children);
	}
	if k == kinds::array_expression {
		return doc_array_expression(node, children);
	}
	if k == kinds::tuple_expression {
		return doc_tuple_expression(node, children);
	}
	if k == kinds::tuple_pattern {
		return doc_tuple_pattern(node, children);
	}
	if k == kinds::type_cast_expression {
		return doc_type_cast_expression(children);
	}
	if k == kinds::array_type {
		return doc_array_type(children);
	}
	if k == kinds::expression_statement {
		return doc_expression_statement(children);
	}
	if k == kinds::parenthesized_expression {
		return doc_parenthesized_expression(node, children);
	}
	if k == kinds::try_expression {
		return doc_try_expression(children);
	}
	if k == kinds::unsafe_block {
		return doc_block_with_keyword(node, children, "unsafe");
	}
	if k == kinds::async_block {
		return doc_block_with_keyword(node, children, "async");
	}
	if k == kinds::try_block {
		return doc_block_with_keyword(node, children, "try");
	}
	if k == kinds::closure_expression {
		return doc_closure_expression(node, children);
	}
	if k == kinds::function_item {
		return doc_function_item(node, children);
	}
	doc_text(text(node))
}
let start_total = now_ms();
let start_docs = now_ms();
doc_reset();
let queries = [
	"(source_file) @n",
	"(line_comment) @n",
	"(block_comment) @n",
	"(string_literal) @n",
	"(raw_string_literal) @n",
	"(block) @n",
	"(if_expression) @n",
	"(else_clause) @n",
	"(match_expression) @n",
	"(match_block) @n",
	"(match_arm) @n",
	"(attribute_item) @n",
	"(macro_invocation) @n",
	"(token_tree) @n",
	"(use_declaration) @n",
	"(struct_item) @n",
	"(enum_item) @n",
	"(trait_item) @n",
	"(mod_item) @n",
	"(const_item) @n",
	"(static_item) @n",
	"(type_item) @n",
	"(union_item) @n",
	"(extern_crate_declaration) @n",
	"(foreign_mod_item) @n",
	"(macro_definition) @n",
	"(declaration_list) @n",
	"(field_declaration_list) @n",
	"(field_declaration) @n",
	"(struct_expression) @n",
	"(field_initializer_list) @n",
	"(field_initializer) @n",
	"(impl_item) @n",
	"(for_expression) @n",
	"(while_expression) @n",
	"(loop_expression) @n",
	"(break_expression) @n",
	"(continue_expression) @n",
	"(return_expression) @n",
	"(call_expression) @n",
	"(field_expression) @n",
	"(generic_type) @n",
	"(type_arguments) @n",
	"(arguments) @n",
	"(parameters) @n",
	"(parameter) @n",
	"(let_declaration) @n",
	"(assignment_expression) @n",
	"(compound_assignment_expr) @n",
	"(binary_expression) @n",
	"(unary_expression) @n",
	"(reference_expression) @n",
	"(await_expression) @n",
	"(index_expression) @n",
	"(range_expression) @n",
	"(array_expression) @n",
	"(tuple_expression) @n",
	"(tuple_pattern) @n",
	"(type_cast_expression) @n",
	"(array_type) @n",
	"(unsafe_block) @n",
	"(async_block) @n",
	"(try_block) @n",
	"(try_expression) @n",
	"(closure_expression) @n",
	"(closure_parameters) @n",
	"(expression_statement) @n",
	"(function_item) @n",
	"(let_condition) @n",
	"(parenthesized_expression) @n"
];
let root_doc = walk(
	"rust",
	kinds::list,
	// queries,
	|node, children| {
		build_doc(node, children)
	}
);
let end_docs = now_ms();
log("doc build: " + (end_docs - start_docs) + "ms");
let start_render = now_ms();
let width = configuration::values["max_width"];
let indent_style = configuration::values["indent_style"];
let tab_width = configuration::values["tab_width"];
let output = doc_render_with_indent(root_doc, width, indent_style, tab_width);
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
log("doc render: " + (end_render - start_render) + "ms");
let start_apply = now_ms();
set_output(output);
let end_apply = now_ms();
log("apply output: " + (end_apply - start_apply) + "ms");
let end_total = now_ms();
log("total: " + (end_total - start_total) + "ms");

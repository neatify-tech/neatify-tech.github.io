// Doc-first formatter entrypoint for Rhai.
import "rhai/kinds.rhai" as kinds;
import "rhai/configuration.rhai" as configuration;
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

fn doc_for_child(children, idx) {
	let d = children.doc(idx);
	if d == () {
		let r = children.range(idx);
		return doc_range(start(r), end(r));
	}
	d
}

fn doc_for_node_raw(node) {
	if node == () {
		return doc_text("");
	}
	let cached = doc_for_node(node);
	if cached != () {
		return cached;
	}
	let r = byte_range(node);
	doc_range(start(r), end(r))
}

fn doc_for_node_if_ready(node) {
	doc_for_node_raw(node)
}

fn trace_call(name, f) {
	let span = trace(name);
	let out = f.call();
	span.end();
	out
}

fn is_punct_kind(k) {
	k == kinds::dot || k == kinds::qdot || k == kinds::lparen || k == kinds::rparen || k == kinds::comma
}

fn is_chain_parent(parent, child) {
	if parent == () || child == () {
		return false;
	}
	let pk = parent.kind_id();
	if pk != kinds::ExprCall && pk != kinds::ExprDotAccess {
		return false;
	}
	let kids = children(parent);
	if kids == () || kids.len() == 0 {
		return false;
	}
	let child_node = unwrap_expr(child);
	let child_range = byte_range(child_node);
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let ck = c.kind_id();
			if !is_punct_kind(ck) {
				let r = byte_range(unwrap_expr(c));
				return start(r) == start(child_range) && end(r) == end(child_range);
			}
		}
		i += 1;
	}
	false
}

fn unwrap_expr(node) {
	let n = node;
	while n != () {
		let k = n.kind_id();
		if k != kinds::Expr && k != kinds::ExprNoDecl {
			break;
		}
		let kids = n.children();
		if kids == () || kids.len() != 1 {
			break;
		}
		n = kids[0];
	}
	n
}

fn chain_root(node) {
	let r = unwrap_expr(node);
	let p = r.parent();
	while p != () {
		let pk = p.kind_id();
		if pk == kinds::ArgList || pk == kinds::ExprBlock {
			break;
		}
		if !is_chain_parent(p, r) {
			break;
		}
		r = p;
		p = r.parent();
	}
	r
}

fn dot_value_node(node) {
	let kids = node.children();
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let k = c.kind_id();
			if k != kinds::dot && k != kinds::qdot {
				return unwrap_expr(c);
			}
		}
		i += 1;
	}()
}

fn dot_access_nodes(node) {
	let kids = node.children();
	let value = ();
	let field = ();
	let dot_text = ".";
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let k = c.kind_id();
			if k == kinds::dot {
				dot_text = ".";
			}
			else if k == kinds::qdot {
				dot_text = "?.";
			}
			else if value == () {
				value = unwrap_expr(c);
			}
			else if field == () {
				field = unwrap_expr(c);
			}
		}
		i += 1;
	}
	[value, dot_text, field]
}

fn chain_parts(root) {
	let segments = [];
	let current = root;
	let base = ();
	while true {
		let current_node = unwrap_expr(current);
		let k = current_node.kind_id();
		if k == kinds::ExprCall {
			let kids = children(current_node);
			let args_node = ();
			let fn_node = ();
			let args_doc = ();
			let i = 0;
			while i < kids.len() {
				let c = kids[i];
				if c != () {
					let ck = c.kind_id();
					if ck == kinds::ArgList {
						args_node = c;
						i += 1;
						continue;
					}
					if is_punct_kind(ck) {
						i += 1;
						continue;
					}
					if fn_node == () {
						fn_node = unwrap_expr(c);
					}
				}
				i += 1;
			}
			if fn_node != () && fn_node.kind_id() == kinds::ExprDotAccess {
				let dot_parts = dot_access_nodes(fn_node);
				let value_node = dot_parts[0];
				let dot_text = dot_parts[1];
				let field_node = dot_parts[2];
				if value_node == () {
					base = fn_node;
					break;
				}
				let field_doc = if field_node != () {
					doc_for_node_raw(field_node)
				}
				else {
					doc_text("")
				};
				let args_doc = if args_node != () {
					doc_for_node_raw(args_node)
				}
				else {
					doc_empty()
				};
				let seg_doc = doc_concat_list(
					[
						doc_text(dot_text),
						field_doc,
						if args_node != () {
							args_doc
						}
						else {
							doc_empty()
						}
					]
				);
				segments.push(seg_doc);
				current = value_node;
				continue;
			}
			base = current_node;
			break;
		}
		else if k == kinds::ExprDotAccess {
			let dot_parts = dot_access_nodes(current_node);
			let value_node = dot_parts[0];
			let dot_text = dot_parts[1];
			let field_node = dot_parts[2];
			if value_node == () {
				base = current_node;
				break;
			}
			let field_doc = if field_node != () {
				doc_for_node_raw(field_node)
			}
			else {
				doc_text("")
			};
			segments.push(doc_concat_list([doc_text(dot_text), field_doc]));
			current = value_node;
			continue;
		}
		base = current_node;
		break;
	}
	segments.reverse();
	[base, segments]
}

fn doc_chain_root(node, base_node, segments, force_break) {
	let root_range = byte_range(node);
	let chain_text = slice(root_range);
	if chain_text.index_of("\n") >= 0 || chain_text.index_of("\r") >= 0 {
		return doc_text(chain_text);
	}
	if base_node == () || segments.len() == 0 {
		return doc_text(chain_text);
	}
	let base_text = slice(byte_range(base_node)).trim();
	if base_text.index_of("\n") >= 0 || base_text.index_of("\r") >= 0 {
		return doc_text(chain_text);
	}
	let max_width = configuration::values["max_width"];
	let base_doc = doc_for_node_raw(base_node);
	let parts = [base_doc];
	let i = 0;
	while i < segments.len() {
		parts.push(segments[i]);
		i += 1;
	}
	let inline_doc = doc_concat_list(parts);
	let max_width = configuration::values["max_width"];
	let chain_len = node.token_len();
	if !force_break && chain_len <= max_width {
		return inline_doc;
	}
	let indent_size = configuration::values["tab_width"];
	let tail = [];
	let i = 0;
	while i < segments.len() {
		tail.push(doc_hardline());
		tail.push(segments[i]);
		i += 1;
	}
	doc_concat_list([
		doc_text(base_text),
		doc_indent(indent_size, doc_concat_list(tail))
	])
}

fn doc_chain_root_with_base(base_doc, base_len, segments, force_break) {
	let max_width = configuration::values["max_width"];
	if !force_break && base_len <= max_width {
		let parts = [base_doc];
		let i = 0;
		while i < segments.len() {
			parts.push(segments[i]);
			i += 1;
		}
		return doc_concat_list(parts);
	}
	let indent_size = configuration::values["tab_width"];
	let tail = [];
	let i = 0;
	while i < segments.len() {
		tail.push(doc_hardline());
		tail.push(segments[i]);
		i += 1;
	}
	doc_concat_list([
		base_doc,
		doc_indent(indent_size, doc_concat_list(tail))
	])
}

fn should_break_chain_with_text(node) {
	let max_width = configuration::values["max_width"];
	// let chain_len = chain_text.len();
	let chain_len = node.token_len();
	if chain_len > max_width {
		return true;
	}
	let target = trace_call(
		"doc_expr_chain::should_break::scan",
		|| node.ancestor(
			[
				kinds::Stmt
			],
			#{
				boundary: true,
				furthest: true,
				allow: [
					kinds::Expr,
					kinds::ExprNoDecl,
					kinds::ExprCall,
					kinds::ExprDotAccess,
					kinds::ArgList,
					kinds::ExprClosure,
					kinds::ExprDeclareVar,
					kinds::Item,
					kinds::Stmt,
					kinds::ExprBlock,
					kinds::ExprChain,
					kinds::ChainSegment
				],
			}
		)
	);
	if target == () {
		return chain_len > max_width;
	}
	let target_len = trace_call(
		"doc_expr_chain::should_break::target_len",
		|| {
			target.token_len()
		}
	);
	if target_len > max_width {
		return true;
	}
	chain_len > max_width
}

fn segment_starts_with_call_or_index(segment_node) {
	if segment_node == () {
		return false;
	}
	let kids = segment_node.children();
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let k = c.kind_id();
			if k == kinds::dot || k == kinds::qdot {
				return false;
			}
			if k == kinds::ArgList || k == kinds::ExprIndex || k == kinds::ExprCall || k == kinds::lparen || k == kinds::lbracket {
				return true;
			}
			return false;
		}
		i += 1;
	}
	false
}

fn segment_starts_with_dot(segment_node) {
	if segment_node == () {
		return false;
	}
	let kids = segment_node.children();
	let i = 0;
	while i < kids.len() {
		let c = kids[i];
		if c != () {
			let k = c.kind_id();
			return k == kinds::dot || k == kinds::qdot;
		}
		i += 1;
	}
	false
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
		else if k == kinds::ParamList || k == kinds::ClosureParamList || k == kinds::TypedParamList {
			parts.push(doc_for_child(children, i));
			need_space = false;
		}
		else if k == kinds::lparen || k == kinds::rparen || k == kinds::comma || k == kinds::colon || k == kinds::colon_colon {
			parts.push(doc_for_child(children, i));
			need_space = false;
		}
		else {
			if need_space && k != kinds::lparen {
				parts.push(doc_text(" "));
			}
			parts.push(doc_for_child(children, i));
			need_space = true;
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn stmt_payload_kind(stmt) {
	let n = stmt;
	while n != () {
		let k = n.kind_id();
		if k != kinds::Stmt && k != kinds::Item && k != kinds::Expr && k != kinds::ExprNoDecl {
			return k;
		}
		let kids = children(n);
		if kids == () || kids.len() == 0 {
			return k;
		}
		let next = ();
		let i = 0;
		while i < kids.len() {
			let c = kids[i];
			if c != () {
				let ck = c.kind_id();
				if ck != kinds::semi && ck != kinds::lbrace && ck != kinds::rbrace && ck != kinds::lparen && ck != kinds::rparen && ck != kinds::comma {
					next = c;
					break;
				}
			}
			i += 1;
		}
		if next == () {
			return k;
		}
		n = next;
	} - 1
}

fn is_import_kind(k) {
	k == kinds::ExprImport
}

fn is_block_kind(k) {
	k == kinds::ExprFn || k == kinds::DefFn || k == kinds::DefModuleInline || k == kinds::DefModule || k == kinds::ExprBlock
}

fn doc_source_file(node, children) {
	if children.len == 0 {
		return doc_for_node_raw(node);
	}
	let nodes = node.children();
	let pieces = [];
	let i = 0;
	while i < children.len {
		pieces.push(doc_for_child(children, i));
		if i < children.len - 1 {
			let current = if nodes.len() > i {
				nodes[i]
			}
			else {
				()
			};
			let next = if nodes.len() > i + 1 {
				nodes[i + 1]
			}
			else {
				()
			};
			if current != () && next != () {
				let current_kind = stmt_payload_kind(current);
				let next_kind = stmt_payload_kind(next);
				let needs_blank = (is_import_kind(current_kind) && !is_import_kind(next_kind)) || (is_block_kind(current_kind) && is_block_kind(next_kind));
				if needs_blank {
					pieces.push(doc_hardline());
					pieces.push(doc_hardline());
				}
				else {
					pieces.push(doc_hardline());
				}
			}
		}
		i += 1;
	}
	doc_concat_list(pieces)
}

fn doc_block(node, children) {
	let k_lbrace = kinds::lbrace;
	let k_rbrace = kinds::rbrace;
	let inner_idx = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_lbrace || k == k_rbrace {
			i += 1;
			continue;
		}
		inner_idx.push(i);
		i += 1;
	}
	if inner_idx.len() == 0 {
		return doc_text("{}");
	}
	let indent_size = configuration::values["tab_width"];
	let inner_doc = [];
	let j = 0;
	while j < inner_idx.len() {
		let idx = inner_idx[j];
		inner_doc.push(doc_for_child(children, idx));
		if j < inner_idx.len() - 1 {
			let next_idx = inner_idx[j + 1];
			let current_text = slice(children.range(idx)).trim();
			let next_text = slice(children.range(next_idx)).trim();
			if !(current_text.ends_with(";") || !next_text.starts_with("(")) {
				// No separator: likely a split call like `foo` + `(bar)`
			}
			else {
				inner_doc.push(doc_hardline());
			}
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

fn doc_if_expression(node, children) {
	let block_idx = -1;
	let else_token_idx = -1;
	let else_body_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::ExprBlock && block_idx < 0 {
			block_idx = i;
		}
		else if k == kinds::kw_else {
			else_token_idx = i;
		}
		else if else_token_idx >= 0 && else_body_idx < 0 {
			else_body_idx = i;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_for_node_raw(node);
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
		return doc_for_node_raw(node);
	}
	let cond_doc = doc_for_child(children, cond_idx);
	let block_doc = doc_for_child(children, block_idx);
	if else_body_idx >= 0 {
		let else_doc = doc_for_child(children, else_body_idx);
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

fn doc_for_expression(node, children) {
	let block_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::ExprBlock {
			block_idx = i;
			break;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_for_node_raw(node);
	}
	let header_doc = doc_header_from_children(children, block_idx);
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([header_doc, doc_text(" "), block_doc])
}

fn doc_while_expression(node, children) {
	let block_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::ExprBlock {
			block_idx = i;
			break;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_for_node_raw(node);
	}
	let header_doc = doc_header_from_children(children, block_idx);
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([header_doc, doc_text(" "), block_doc])
}

fn doc_loop_expression(node, children) {
	let block_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::ExprBlock {
			block_idx = i;
			break;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_for_node_raw(node);
	}
	let header_doc = doc_header_from_children(children, block_idx);
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([header_doc, doc_text(" "), block_doc])
}

fn doc_do_expression(node, children) {
	let block_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::ExprBlock {
			block_idx = i;
			break;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_for_node_raw(node);
	}
	let block_doc = doc_for_child(children, block_idx);
	let tail_idx = block_idx + 1;
	if tail_idx >= children.len {
		return doc_concat_list([doc_text("do "), block_doc]);
	}
	let tail_parts = [];
	i = tail_idx;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::kw_while {
			tail_parts.push(doc_text("while "));
		}
		else if k == kinds::kw_until {
			tail_parts.push(doc_text("until "));
		}
		else {
			tail_parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list([doc_text("do "), block_doc, doc_hardline(), doc_concat_list(tail_parts)])
}

fn doc_switch_arm(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::fat_arrow {
			parts.push(doc_text(" => "));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_switch_arm_list(children) {
	let arms = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::SwitchArm {
			arms.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if arms.len() == 0 {
		return doc_text("{}");
	}
	let indent_size = configuration::values["tab_width"];
	let inner = [];
	let j = 0;
	while j < arms.len() {
		if j < arms.len() - 1 {
			inner.push(doc_concat_list([arms[j], doc_text(",")]));
		}
		else {
			inner.push(arms[j]);
		}
		if j < arms.len() - 1 {
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

fn doc_switch_expression(node, children) {
	let list_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::SwitchArmList {
			list_idx = i;
			break;
		}
		i += 1;
	}
	if list_idx < 0 {
		return doc_for_node_raw(node);
	}
	let header_doc = doc_header_from_children(children, list_idx);
	let list_doc = doc_for_child(children, list_idx);
	doc_concat_list([header_doc, doc_text(" "), list_doc])
}

fn doc_return_expression(children) {
	let parts = [];
	let saw_return = false;
	let i = 0;
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

fn doc_break_expression(children) {
	let parts = [];
	let saw_break = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::kw_break {
			parts.push(doc_text("break"));
			saw_break = true;
		}
		else {
			if saw_break {
				parts.push(doc_text(" "));
				saw_break = false;
			}
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_throw_expression(children) {
	let parts = [];
	let saw_throw = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::kw_throw {
			parts.push(doc_text("throw"));
			saw_throw = true;
		}
		else {
			if saw_throw {
				parts.push(doc_text(" "));
				saw_throw = false;
			}
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_try_expression(node, children) {
	let block_idx = -1;
	let catch_idx = -1;
	let catch_params_idx = -1;
	let catch_block_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::ExprBlock && block_idx < 0 {
			block_idx = i;
		}
		else if k == kinds::kw_catch {
			catch_idx = i;
		}
		else if catch_idx >= 0 && catch_params_idx < 0 && k == kinds::ParamList {
			catch_params_idx = i;
		}
		else if catch_idx >= 0 && k == kinds::ExprBlock {
			catch_block_idx = i;
		}
		i += 1;
	}
	if block_idx < 0 {
		return doc_for_node_raw(node);
	}
	let try_block = doc_for_child(children, block_idx);
	if catch_idx < 0 || catch_block_idx < 0 {
		return doc_concat_list([doc_text("try "), try_block]);
	}
	let catch_parts = [];
	if catch_params_idx >= 0 {
		catch_parts.push(doc_text("catch "));
		catch_parts.push(doc_for_child(children, catch_params_idx));
	}
	else {
		catch_parts.push(doc_text("catch"));
	}
	let catch_block = doc_for_child(children, catch_block_idx);
	doc_concat_list([
		doc_text("try "),
		try_block,
		doc_hardline(),
		doc_concat_list(catch_parts),
		doc_text(" "),
		catch_block
	])
}

fn doc_fn_expression(node, children) {
	let body_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::ExprBlock {
			body_idx = i;
			break;
		}
		i += 1;
	}
	if body_idx < 0 {
		let header_doc = doc_header_from_children(children, children.len);
		return header_doc;
	}
	let header_doc = doc_header_from_children(children, body_idx);
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([header_doc, doc_text(" "), body_doc])
}

fn doc_import_expression(children) {
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::kw_as {
			parts.push(doc_text(" as "));
			need_space = false;
		}
		else if k == kinds::semi {
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

fn doc_export_ident(children) {
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::kw_as {
			parts.push(doc_text(" as "));
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

fn doc_declare_var(children) {
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::colon {
			parts.push(doc_text(": "));
			need_space = false;
		}
		else if k == kinds::assign {
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

fn doc_type(children) {
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::TypeIdent || k == kinds::TypeTuple || k == kinds::TypeArray || k == kinds::TypeObject || k == kinds::TypeUnknown || k == kinds::TypeUnion || k == kinds::TypeLit {
			return doc_for_child(children, i);
		}
		i += 1;
	}
	doc_text("")
}

fn doc_type_ident(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		parts.push(doc_for_child(children, i));
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_type_generics(children) {
	let types = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::Type {
			types.push(doc_for_child(children, i));
		}
		i += 1;
	}
	let parts = [];
	let j = 0;
	while j < types.len() {
		parts.push(types[j]);
		if j < types.len() - 1 {
			parts.push(doc_text(", "));
		}
		j += 1;
	}
	doc_concat_list([doc_text("<"), doc_concat_list(parts), doc_text(">")])
}

fn doc_type_tuple(children) {
	let types = [];
	let type_texts = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::Type {
			types.push(doc_for_child(children, i));
			type_texts.push(slice(children.range(i)).trim());
		}
		i += 1;
	}
	let parts = [];
	let j = 0;
	while j < types.len() {
		parts.push(types[j]);
		if j < types.len() - 1 {
			parts.push(doc_text(", "));
		}
		j += 1;
	}
	let max_width = configuration::values["max_width"];
	let inline_len = {
		let len = 2;
		let j = 0;
		while j < type_texts.len() {
			len += type_texts[j].len();
			if j < type_texts.len() - 1 {
				len += 2;
			}
			j += 1;
		}
		len
	};
	let inline_doc = doc_concat_list([doc_text("("), doc_concat_list(parts), doc_text(")")]);
	if inline_len <= max_width {
		return inline_doc;
	}
	let indent_size = configuration::values["tab_width"];
	let inner = [];
	j = 0;
	while j < types.len() {
		inner.push(types[j]);
		if j < types.len() - 1 {
			inner.push(doc_text(","));
			inner.push(doc_hardline());
		}
		j += 1;
	}
	doc_concat_list([
		doc_text("("),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)])),
		doc_hardline(),
		doc_text(")")
	])
}

fn doc_type_list(children) {
	return doc_type_tuple(children);
}

fn doc_type_array(children) {
	let types = [];
	let type_texts = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::Type {
			types.push(doc_for_child(children, i));
			type_texts.push(slice(children.range(i)).trim());
		}
		i += 1;
	}
	let parts = [];
	let j = 0;
	while j < types.len() {
		parts.push(types[j]);
		if j < types.len() - 1 {
			parts.push(doc_text(", "));
		}
		j += 1;
	}
	let max_width = configuration::values["max_width"];
	let inline_len = {
		let len = 2;
		let j = 0;
		while j < type_texts.len() {
			len += type_texts[j].len();
			if j < type_texts.len() - 1 {
				len += 2;
			}
			j += 1;
		}
		len
	};
	let inline_doc = doc_concat_list([doc_text("["), doc_concat_list(parts), doc_text("]")]);
	if inline_len <= max_width {
		return inline_doc;
	}
	let indent_size = configuration::values["tab_width"];
	let inner = [];
	j = 0;
	while j < types.len() {
		inner.push(types[j]);
		if j < types.len() - 1 {
			inner.push(doc_text(","));
			inner.push(doc_hardline());
		}
		j += 1;
	}
	doc_concat_list([
		doc_text("["),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)])),
		doc_hardline(),
		doc_text("]")
	])
}

fn doc_type_object_field(children) {
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::colon {
			parts.push(doc_text(": "));
			need_space = false;
		}
		else if k == kinds::Doc {
			i += 1;
			continue;
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

fn doc_type_object(children) {
	let fields = [];
	let field_texts = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::TypeObjectField {
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
		let len = 3;
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

fn doc_type_union(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::pipe {
			parts.push(doc_text(" | "));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_arg_list(node, children) {
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_comma = kinds::comma;
	let args = [];
	let arg_is_comment = [];
	let has_comment = false;
	let first_kind = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k != k_lparen && k != k_rparen && k != k_comma {
			let is_comment = k == kinds::comment_line_doc || k == kinds::comment_block_doc;
			args.push(doc_for_child(children, i));
			arg_is_comment.push(is_comment);
			if is_comment {
				has_comment = true;
			}
			if first_kind == () && !is_comment {
				first_kind = k;
			}
		}
		i += 1;
	}
	if args.len() == 0 {
		return doc_text("()");
	}
	let raw = text(node);
	let max_width = configuration::values["max_width"];
	let should_break = raw.len() > max_width || raw.index_of("\n") >= 0 || raw.index_of("\r") >= 0;
	if has_comment {
		should_break = true;
	}
	if should_break && args.len() == 1 && first_kind == kinds::ExprArray {
		return doc_concat_list([doc_text("("), args[0], doc_text(")")]);
	}
	let parts = [];
	let last_non_comment = -1;
	let j = args.len() - 1;
	while j >= 0 {
		if !arg_is_comment[j] {
			last_non_comment = j;
			break;
		}
		if j == 0 {
			break;
		}
		j -= 1;
	}
	let j = 0;
	while j < args.len() {
		parts.push(args[j]);
		if j < args.len() - 1 {
			if should_break {
				if !arg_is_comment[j] && j != last_non_comment {
					parts.push(doc_text(","));
				}
				parts.push(doc_hardline());
			}
			else {
				if !arg_is_comment[j] && j != last_non_comment {
					parts.push(doc_text(", "));
				}
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

fn doc_call_expression(node, children) {
	let root = chain_root(node);
	let is_root = start(byte_range(root)) == start(byte_range(node)) && end(byte_range(root)) == end(byte_range(node));
	if is_root {
		let parts = chain_parts(node);
		let segments = parts[1];
		if segments.len() > 0 && should_break_chain(node) {
			if start(byte_range(parts[0])) == start(byte_range(node)) && end(byte_range(parts[0])) == end(byte_range(node)) {
				let args_idx = -1;
				let fn_idx = -1;
				let j = 0;
				while j < children.len {
					let k = children.kind(j);
					if k == kinds::ArgList {
						args_idx = j;
					}
					else if fn_idx < 0 {
						fn_idx = j;
					}
					j += 1;
				}
				if fn_idx >= 0 && args_idx >= 0 {
					let fn_doc = doc_for_child(children, fn_idx);
					let args_doc = doc_for_child(children, args_idx);
					let base_doc = doc_concat_list([fn_doc, args_doc]);
					let base_len = node.token_len();
					return doc_chain_root_with_base(base_doc, base_len, segments, true);
				}
			}
			return doc_chain_root(node, parts[0], segments, true);
		}
	}
	let args_idx = -1;
	let fn_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::ArgList {
			args_idx = i;
		}
		else if fn_idx < 0 {
			fn_idx = i;
		}
		i += 1;
	}
	if fn_idx < 0 || args_idx < 0 {
		return doc_for_node_raw(node);
	}
	let fn_doc = doc_for_child(children, fn_idx);
	let args_doc = doc_for_child(children, args_idx);
	doc_concat_list([fn_doc, args_doc])
}

fn doc_dot_access_expression(node, children) {
	let root = chain_root(node);
	let is_root = start(byte_range(root)) == start(byte_range(node)) && end(byte_range(root)) == end(byte_range(node));
	if is_root {
		let parts = chain_parts(node);
		let segments = parts[1];
		if segments.len() > 0 && should_break_chain(node) {
			return doc_chain_root(node, parts[0], segments, true);
		}
	}
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::dot || k == kinds::qdot {
			parts.push(doc_text("."));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_binary_expression(node, children) {
	let parts = [];
	let i = 0;
	let raw = text(node);
	let max_width = configuration::values["max_width"];
	let wrap_logic = raw.len() > max_width || raw.index_of("\n") >= 0 || raw.index_of("\r") >= 0;
	if wrap_logic && node.kind_id() == kinds::ExprBinary {
		let has_logical = false;
		let j = 0;
		while j < children.len {
			let k = children.kind(j);
			if k == kinds::and_and || k == kinds::or_or || k == kinds::amp || k == kinds::pipe || k == kinds::caret {
				has_logical = true;
				break;
			}
			j += 1;
		}
		if has_logical {
			let indent_size = configuration::values["tab_width"];
			return doc_for_boolean_expression(node, true, indent_size, false);
		}
	}
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::assign || k == kinds::plus_assign || k == kinds::minus_assign || k == kinds::star_assign || k == kinds::slash_assign || k == kinds::percent_assign || k == kinds::eq_eq || k == kinds::not_eq || k == kinds::lt || k == kinds::gt || k == kinds::lt_eq || k == kinds::gt_eq || k == kinds::plus || k == kinds::minus || k == kinds::star || k == kinds::slash || k == kinds::percent || k == kinds::and_and || k == kinds::or_or || k == kinds::amp || k == kinds::pipe || k == kinds::caret || k == kinds::shl || k == kinds::shr || k == kinds::range || k == kinds::range_eq || k == kinds::null_coalesce || k == kinds::binop {
			let op = slice(children.range(i)).trim();
			parts.push(doc_text(" " + op + " "));
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
	if node.kind_id() == kinds::ExprParen {
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
	while current != () && current.kind_id() == kinds::ExprBinary {
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
				let is_comment = ck == kinds::comment_line_doc || ck == kinds::comment_block_doc;
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
	if node.kind_id() == kinds::ExprBinary {
		return doc_for_boolean_binary(node, allow_wrap, indent_size, force_wrap);
	}
	doc_for_boolean_operand(node, allow_wrap, indent_size, force_wrap)
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

fn doc_paren_expression(node, children) {
	let parts = [];
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
		if inner != () && inner.kind_id() == kinds::ExprBinary {
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

fn doc_array_expression(node, children) {
	let items = [];
	let item_is_comment = [];
	let has_comment = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::lbracket || k == kinds::rbracket || k == kinds::comma {
			i += 1;
			continue;
		}
		let is_comment = k == kinds::comment_line_doc || k == kinds::comment_block_doc;
		items.push(doc_for_child(children, i));
		item_is_comment.push(is_comment);
		if is_comment {
			has_comment = true;
		}
		i += 1;
	}
	if items.len() == 0 {
		return doc_text("[]");
	}
	let raw = text(node);
	let max_width = configuration::values["max_width"];
	let should_break = raw.len() > max_width || raw.index_of("\n") >= 0 || raw.index_of("\r") >= 0;
	if has_comment {
		should_break = true;
	}
	let parts = [];
	let last_non_comment = -1;
	let j = items.len() - 1;
	while j >= 0 {
		if !item_is_comment[j] {
			last_non_comment = j;
			break;
		}
		if j == 0 {
			break;
		}
		j -= 1;
	}
	let j = 0;
	while j < items.len() {
		parts.push(items[j]);
		if should_break {
			if !item_is_comment[j] && j != last_non_comment {
				parts.push(doc_text(","));
			}
			if j < items.len() - 1 {
				parts.push(doc_hardline());
			}
		}
		else if !item_is_comment[j] && j != last_non_comment {
			parts.push(doc_text(", "));
		}
		j += 1;
	}
	if !should_break {
		return doc_concat_list([doc_text("["), doc_concat_list(parts), doc_text("]")]);
	}
	let indent_size = configuration::values["tab_width"];
	doc_concat_list([
		doc_text("["),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)])),
		doc_hardline(),
		doc_text("]")
	])
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
		if children.kind(i) == kinds::ObjectField {
			fields.push(doc_for_child(children, i));
			field_texts.push(slice(children.range(i)).trim());
		}
		i += 1;
	}
	if fields.len() == 0 {
		return doc_text("#{}");
	}
	let max_width = configuration::values["max_width"];
	let inline_len = {
		let len = 5;
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
	let inline_doc = doc_concat_list([doc_text("#{"), doc_text(" "), doc_concat_list(parts), doc_text(" }")]);
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
		doc_text("#{"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner)])),
		doc_hardline(),
		doc_text("}")
	])
}

fn doc_index_expression(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		parts.push(doc_for_child(children, i));
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_closure_expression(node, children) {
	let params_idx = -1;
	let body_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::ClosureParamList {
			params_idx = i;
		}
		else {
			body_idx = i;
		}
		i += 1;
	}
	if params_idx < 0 || body_idx < 0 {
		return doc_for_node_raw(node);
	}
	let params_doc = doc_for_child(children, params_idx);
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([params_doc, doc_text(" "), body_doc])
}

fn doc_expr_chain(node, children) {
	if children.len == 0 {
		return doc_for_node_raw(node);
	}
	let max_width = configuration::values["max_width"];
	let base_doc = trace_call("doc_expr_chain::base_doc", || doc_for_child(children, 0));
	let node_children = trace_call("doc_expr_chain::node_children", || node.children());
	let segments = [];
	let i = 1;
	while i < children.len {
		let k = children.kind(i);
		let merged = false;
		if k == kinds::ChainSegment {
			let segment_node = if node_children != () && i < node_children.len() {
				node_children[i]
			}
			else {
				()
			};
			if trace_call(
				"doc_expr_chain::segment_starts_with_call_or_index",
				|| segment_starts_with_call_or_index(segment_node)
			) {
				if segments.len() == 0 {
					let segment_doc = trace_call("doc_expr_chain::segment_doc", || doc_for_child(children, i));
					base_doc = doc_concat_list([base_doc, segment_doc]);
				}
				else {
					let prev = segments.pop();
					let segment_doc = trace_call("doc_expr_chain::segment_doc", || doc_for_child(children, i));
					segments.push(doc_concat_list([prev, segment_doc]));
				}
				merged = true;
			}
		}
		if !merged {
			segments.push(trace_call("doc_expr_chain::segment_doc", || doc_for_child(children, i)));
		}
		i += 1;
	}
	let base_is_simple = trace_call(
		"doc_expr_chain::base_is_simple",
		|| {
			if node_children == () || node_children.len() == 0 {
				false
			}
			else {
				let base_node = node_children[0];
				let base_kids = base_node.children();
				if base_kids != () && base_kids.len() > 0 {
					let bk = base_kids[0].kind_id();
					bk == kinds::ExprPath || bk == kinds::ExprIdent
				}
				else {
					false
				}
			}
		}
	);
	if base_is_simple && segments.len() > 0 {
		let first_segment = if node_children != () && node_children.len() > 1 {
			node_children[1]
		}
		else {
			()
		};
		if trace_call("doc_expr_chain::segment_starts_with_dot", || segment_starts_with_dot(first_segment)) {
			let merged_segments = [];
			let idx = 1;
			while idx < segments.len() {
				merged_segments.push(segments[idx]);
				idx += 1;
			}
			base_doc = doc_concat_list([base_doc, segments[0]]);
			segments = merged_segments;
		}
	}
	let parts = [base_doc];
	i = 0;
	while i < segments.len() {
		parts.push(segments[i]);
		i += 1;
	}
	let inline_doc = trace_call("doc_expr_chain::inline_doc", || doc_concat_list(parts));
	let should_break = trace_call("doc_expr_chain::should_break", || should_break_chain_with_text(node));
	if !should_break {
		return inline_doc;
	}
	let indent_size = configuration::values["tab_width"];
	let tail = [];
	i = 0;
	while i < segments.len() {
		tail.push(doc_hardline());
		tail.push(segments[i]);
		i += 1;
	}
	doc_concat_list([
		base_doc,
		doc_indent(indent_size, trace_call("doc_expr_chain::tail", || doc_concat_list(tail)))
	])
}

fn doc_param_list(children) {
	let params = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::lparen || k == kinds::rparen || k == kinds::comma {
			i += 1;
			continue;
		}
		params.push(doc_for_child(children, i));
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

fn doc_closure_param_list(children) {
	let params = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::Param {
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
	doc_concat_list([doc_text("|"), doc_concat_list(parts), doc_text("|")])
}

fn doc_expression_statement(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::semi {
			parts.push(doc_text(";"));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_def_module_inline(node, children) {
	let lbrace_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::lbrace {
			lbrace_idx = i;
			break;
		}
		i += 1;
	}
	if lbrace_idx < 0 {
		return doc_for_node_raw(node);
	}
	let header_doc = doc_header_from_children(children, lbrace_idx);
	let inner = [];
	i = lbrace_idx + 1;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::rbrace {
			break;
		}
		if k == kinds::DefStmt {
			let stmt_text = slice(children.range(i)).trim();
			if stmt_text == ";" {
				if inner.len() > 0 {
					let prev = inner.pop();
					inner.push(doc_concat_list([prev, doc_text(";")]));
				}
			}
			else {
				let d = doc_for_child(children, i);
				if d != () {
					inner.push(d);
				}
			}
		}
		i += 1;
	}
	if inner.len() == 0 {
		return doc_concat_list([header_doc, doc_text(" {}")]);
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
		header_doc,
		doc_text(" {"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(inner_doc)])),
		doc_hardline(),
		doc_text("}")
	])
}

fn doc_def_stmt(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::semi {
			parts.push(doc_text(";"));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_def_item(children) {
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::Def {
			return doc_for_child(children, i);
		}
		if k == kinds::DefLet || k == kinds::DefConst || k == kinds::DefFn {
			return doc_for_child(children, i);
		}
		i += 1;
	}
	if children.len > 0 {
		return doc_for_child(children, 0);
	}
	doc_text("")
}

fn doc_def_const(children) {
	let parts = [];
	let need_space = false;
	let saw_assign = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		let d = children.doc(i);
		if k == kinds::colon {
			parts.push(doc_text(": "));
			need_space = false;
		}
		else if k == kinds::assign {
			parts.push(doc_text(" = "));
			need_space = false;
			saw_assign = true;
		}
		else {
			if need_space {
				parts.push(doc_text(" "));
			}
			if k == kinds::ExprNoDecl && !saw_assign {
				parts.push(doc_text(" = "));
				saw_assign = true;
			}
			if d != () {
				parts.push(d);
			}
			else {
				parts.push(doc_for_child(children, i));
			}
			need_space = true;
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_def_let(children) {
	let parts = [];
	let need_space = false;
	let saw_assign = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		let d = children.doc(i);
		if k == kinds::colon {
			parts.push(doc_text(": "));
			need_space = false;
		}
		else if k == kinds::assign {
			parts.push(doc_text(" = "));
			need_space = false;
			saw_assign = true;
		}
		else {
			if need_space {
				parts.push(doc_text(" "));
			}
			if k == kinds::ExprNoDecl && !saw_assign {
				parts.push(doc_text(" = "));
				saw_assign = true;
			}
			if d != () {
				parts.push(d);
			}
			else {
				parts.push(doc_for_child(children, i));
			}
			need_space = true;
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_typed_param(children) {
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::colon {
			parts.push(doc_text(": "));
			need_space = false;
		}
		else if k == kinds::comma {
			i += 1;
			continue;
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

fn doc_typed_param_list(children) {
	let params = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::TypedParam {
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

fn doc_def_fn(children) {
	let parts = [];
	let need_space = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::TypedParamList {
			parts.push(doc_for_child(children, i));
			need_space = false;
		}
		else if k == kinds::arrow {
			parts.push(doc_text(" -> "));
			need_space = false;
		}
		else if k == kinds::comma {
			i += 1;
			continue;
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

fn doc_item(children) {
	let parts = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::Doc {
			parts.push(doc_for_child(children, i));
			parts.push(doc_hardline());
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn build_doc(node, children) {
	let k = node.kind_id();
	if k == kinds::Rhai {
		return trace_call("doc_source_file", || doc_source_file(node, children));
	}
	if k == kinds::comment_line_doc {
		return trace_call("comments::doc_line_comment", || comments::doc_line_comment(node, "//"));
	}
	if k == kinds::comment_block_doc {
		return trace_call("comments::doc_block_comment", || comments::doc_block_comment(node, "/*", "*/"));
	}
	if k == kinds::Doc {
		return trace_call("doc_for_child", || doc_for_child(children, 0));
	}
	if k == kinds::Item {
		return trace_call("doc_item", || doc_item(children));
	}
	if k == kinds::Expr {
		return trace_call("doc_expr", || doc_expr(children));
	}
	if k == kinds::ExprNoDecl {
		return trace_call("doc_expr", || doc_expr(children));
	}
	if k == kinds::DefModuleInline {
		return trace_call("doc_def_module_inline", || doc_def_module_inline(node, children));
	}
	if k == kinds::DefStmt {
		return trace_call("doc_def_stmt", || doc_def_stmt(children));
	}
	if k == kinds::DefItem {
		return trace_call("doc_def_item", || doc_def_item(children));
	}
	if k == kinds::Def {
		return trace_call("doc_def_item", || doc_def_item(children));
	}
	if k == kinds::DefConst {
		return trace_call("doc_def_const", || doc_def_const(children));
	}
	if k == kinds::DefLet {
		return trace_call("doc_def_let", || doc_def_let(children));
	}
	if k == kinds::DefFn {
		return trace_call("doc_def_fn", || doc_def_fn(children));
	}
	if k == kinds::TypedParamList {
		return trace_call("doc_typed_param_list", || doc_typed_param_list(children));
	}
	if k == kinds::TypedParam {
		return trace_call("doc_typed_param", || doc_typed_param(children));
	}
	if k == kinds::Type {
		return trace_call("doc_type", || doc_type(children));
	}
	if k == kinds::TypeIdent {
		return trace_call("doc_type_ident", || doc_type_ident(children));
	}
	if k == kinds::TypeGenerics {
		return trace_call("doc_type_generics", || doc_type_generics(children));
	}
	if k == kinds::TypeTuple {
		return trace_call("doc_type_tuple", || doc_type_tuple(children));
	}
	if k == kinds::TypeList {
		return trace_call("doc_type_list", || doc_type_list(children));
	}
	if k == kinds::TypeArray {
		return trace_call("doc_type_array", || doc_type_array(children));
	}
	if k == kinds::TypeObject {
		return trace_call("doc_type_object", || doc_type_object(children));
	}
	if k == kinds::TypeObjectField {
		return trace_call("doc_type_object_field", || doc_type_object_field(children));
	}
	if k == kinds::TypeUnion {
		return trace_call("doc_type_union", || doc_type_union(children));
	}
	if k == kinds::ExprBlock {
		return trace_call("doc_block", || doc_block(node, children));
	}
	if k == kinds::ExprIf {
		return trace_call("doc_if_expression", || doc_if_expression(node, children));
	}
	if k == kinds::ExprFor {
		return trace_call("doc_for_expression", || doc_for_expression(node, children));
	}
	if k == kinds::ExprWhile {
		return trace_call("doc_while_expression", || doc_while_expression(node, children));
	}
	if k == kinds::ExprLoop {
		return trace_call("doc_loop_expression", || doc_loop_expression(node, children));
	}
	if k == kinds::ExprDo {
		return trace_call("doc_do_expression", || doc_do_expression(node, children));
	}
	if k == kinds::ExprSwitch {
		return trace_call("doc_switch_expression", || doc_switch_expression(node, children));
	}
	if k == kinds::SwitchArmList {
		return trace_call("doc_switch_arm_list", || doc_switch_arm_list(children));
	}
	if k == kinds::SwitchArm {
		return trace_call("doc_switch_arm", || doc_switch_arm(children));
	}
	if k == kinds::ExprReturn {
		return trace_call("doc_return_expression", || doc_return_expression(children));
	}
	if k == kinds::ExprBreak {
		if trim(text(node)) == "" {
			return doc_text("");
		}
		return trace_call("doc_break_expression", || doc_break_expression(children));
	}
	if k == kinds::ExprContinue {
		return doc_text("continue");
	}
	if k == kinds::ExprThrow {
		return trace_call("doc_throw_expression", || doc_throw_expression(children));
	}
	if k == kinds::ExprTry {
		return trace_call("doc_try_expression", || doc_try_expression(node, children));
	}
	if k == kinds::ExprFn {
		return trace_call("doc_fn_expression", || doc_fn_expression(node, children));
	}
	if k == kinds::ExprImport {
		return trace_call("doc_import_expression", || doc_import_expression(children));
	}
	if k == kinds::ExprExportIdent {
		return trace_call("doc_export_ident", || doc_export_ident(children));
	}
	if k == kinds::ExprDeclareVar {
		return trace_call("doc_declare_var", || doc_declare_var(children));
	}
	if k == kinds::ExprCall {
		return trace_call("doc_call_expression", || doc_call_expression(node, children));
	}
	if k == kinds::ExprDotAccess {
		return trace_call("doc_dot_access_expression", || doc_dot_access_expression(node, children));
	}
	if k == kinds::ExprBinary {
		return trace_call("doc_binary_expression", || doc_binary_expression(node, children));
	}
	if k == kinds::ExprUnary {
		return trace_call("doc_unary_expression", || doc_unary_expression(children));
	}
	if k == kinds::ExprParen {
		return trace_call("doc_paren_expression", || doc_paren_expression(node, children));
	}
	if k == kinds::ExprArray {
		return trace_call("doc_array_expression", || doc_array_expression(node, children));
	}
	if k == kinds::ExprObject {
		return trace_call("doc_object_expression", || doc_object_expression(children));
	}
	if k == kinds::ObjectField {
		return trace_call("doc_object_field", || doc_object_field(children));
	}
	if k == kinds::ExprIndex {
		return trace_call("doc_index_expression", || doc_index_expression(children));
	}
	if k == kinds::ExprClosure {
		return trace_call("doc_closure_expression", || doc_closure_expression(node, children));
	}
	if k == kinds::ExprChain {
		return trace_call("doc_expr_chain", || doc_expr_chain(node, children));
	}
	if k == kinds::ChainSegment {
		let parts = [];
		let i = 0;
		while i < children.len {
			let ck = children.kind(i);
			if ck == kinds::dot || ck == kinds::qdot {
				parts.push(doc_text("."));
			}
			else {
				parts.push(doc_for_child(children, i));
			}
			i += 1;
		}
		return trace_call("doc_concat_list", || doc_concat_list(parts));
	}
	if k == kinds::ArgList {
		return trace_call("doc_arg_list", || doc_arg_list(node, children));
	}
	if k == kinds::ParamList {
		return trace_call("doc_param_list", || doc_param_list(children));
	}
	if k == kinds::ClosureParamList {
		return trace_call("doc_closure_param_list", || doc_closure_param_list(children));
	}
	if k == kinds::expression_statement || k == kinds::Stmt {
		return trace_call("doc_expression_statement", || doc_expression_statement(children));
	}
	if k == kinds::lit_str || k == kinds::lit_int || k == kinds::lit_float || k == kinds::lit_bool {
		return trace_call("doc_for_node_raw", || doc_for_node_raw(node));
	}
	if k == kinds::LitUnit {
		return doc_text("()");
	}
	if k == kinds::ident || k == kinds::Path || k == kinds::ExprIdent || k == kinds::ExprPath {
		return trace_call("doc_for_node_raw", || doc_for_node_raw(node));
	}
	trace_call("doc_for_node_raw", || doc_for_node_raw(node))
}
let start_total = now_ms();
let start_docs = now_ms();
doc_reset();
let queries = [
	"(Rhai) @n",
	"(Item) @n",
	"(Doc) @n",
	"(DefModuleInline) @n",
	"(DefStmt) @n",
	"(Def) @n",
	"(DefItem) @n",
	"(DefConst) @n",
	"(DefLet) @n",
	"(DefFn) @n",
	"(TypedParamList) @n",
	"(TypedParam) @n",
	"(Type) @n",
	"(TypeIdent) @n",
	"(TypeGenerics) @n",
	"(TypeTuple) @n",
	"(TypeList) @n",
	"(TypeArray) @n",
	"(TypeObject) @n",
	"(TypeObjectField) @n",
	// "(TypeUnion) @n",
	"(comment_line_doc) @n",
	"(comment_block_doc) @n",
	"(ExprBlock) @n",
	"(ExprIf) @n",
	"(ExprFor) @n",
	"(ExprWhile) @n",
	"(ExprLoop) @n",
	"(ExprDo) @n",
	"(ExprSwitch) @n",
	"(SwitchArmList) @n",
	"(SwitchArm) @n",
	"(ExprReturn) @n",
	"(ExprBreak) @n",
	"(ExprContinue) @n",
	"(ExprThrow) @n",
	"(ExprTry) @n",
	"(ExprFn) @n",
	"(ExprImport) @n",
	"(ExprExportIdent) @n",
	"(ExprDeclareVar) @n",
	"(ChainSegment) @n",
	"(ExprBinary) @n",
	"(binop) @n",
	"(ExprUnary) @n",
	"(ExprParen) @n",
	"(ExprArray) @n",
	"(ExprObject) @n",
	"(ObjectField) @n",
	"(ChainSegment) @n",
	"(ExprClosure) @n",
	"(ExprChain) @n",
	"(ArgList) @n",
	"(ParamList) @n",
	"(ClosureParamList) @n",
	"(Stmt) @n"
];
let root_doc = walk(
	"rhai",
	queries,
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
log("doc render: " + (end_render - start_render) + "ms");
let start_apply = now_ms();
set_output(output);
let end_apply = now_ms();
log("apply output: " + (end_apply - start_apply) + "ms");
let end_total = now_ms();
log("total: " + (end_total - start_total) + "ms");

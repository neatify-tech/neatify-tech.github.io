// Switch formatting.
import "java/kinds.rhai" as kinds;
import "java/comment_helpers.rhai" as comment_helpers;
import "java/configuration.rhai" as configuration;

fn doc_switch_statement(node, children) {
	let k_switch_block = kinds::switch_block;
	let k_paren_expr = kinds::parenthesized_expression;
	let k_line_comment = kinds::line_comment;
	let k_block_comment = kinds::block_comment;
	let body_idx = -1;
	let paren_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_switch_block {
			body_idx = i;
			break;
		}
		if k == k_paren_expr && paren_idx < 0 {
			paren_idx = i;
		}
		i += 1;
	}
	if body_idx < 0 {
		return doc_text(text(node));
	}
	let body_doc = doc_for_child(children, body_idx);
	if paren_idx >= 0 {
		return doc_concat_list(
			[
				doc_text("switch "),
				doc_for_child(children, paren_idx),
				doc_text(" "),
				body_doc
			]
		);
	}
	let header_parts = [doc_text("switch")];
	let j = 0;
	while j < body_idx {
		let k = children.kind(j);
		if k == k_line_comment || k == k_block_comment {
			header_parts.push(doc_text(" "));
			header_parts.push(doc_for_child(children, j));
		}
		j += 1;
	}
	doc_concat_list([
		doc_concat_list(header_parts),
		doc_text(" "),
		body_doc
	])
}

fn doc_switch_block(node, children) {
	let k_switch_group = kinds::switch_block_statement_group;
	let k_switch_rule = kinds::switch_rule;
	let k_lbrace = kinds::lbrace;
	let k_rbrace = kinds::rbrace;
	let prefix_comment_doc = ();
	let parent = node.parent();
	if parent != () {
		let parent_children = children(parent);
		let block_range = byte_range(node);
		let block_idx = -1;
		let i = 0;
		while i < parent_children.len() {
			let r = byte_range(parent_children[i]);
			if start(r) == start(block_range) && end(r) == end(block_range) {
				block_idx = i;
				break;
			}
			i += 1;
		}
		if block_idx > 0 {
			let prev = block_idx - 1;
			while prev >= 0 {
				let k = parent_children[prev].kind_id();
				if k != kinds::line_comment && k != kinds::block_comment {
					break;
				}
				if prev == 0 {
					prev = -1;
					break;
				}
				prev -= 1;
			}
			if prev >= 0 {
				let header_end = end(byte_range(parent_children[prev]));
				prefix_comment_doc = comment_helpers::inline_comment_doc_between("java", header_end, start(block_range));
			}
		}
	}
	let parts = [];
	let i = 0;
	let first = true;
	while i < children.len {
		let k = children.kind(i);
		if k == k_switch_group {
			if !first {
				parts.push(doc_hardline());
			}
			parts.push(doc_for_child(children, i));
			first = false;
		}
		else if k == k_switch_rule {
			if !first {
				parts.push(doc_hardline());
			}
			parts.push(doc_switch_rule(node, children, i));
			first = false;
		}
		else if k != k_lbrace && k != k_rbrace {
			if !first {
				parts.push(doc_hardline());
			}
			parts.push(doc_for_child(children, i));
			first = false;
		}
		i += 1;
	}
	let indent_size = configuration::values["tab_width"];
	if parts.len() == 0 {
		if prefix_comment_doc != () {
			return doc_concat_list(
				[
					doc_text("{"),
					doc_text(" "),
					prefix_comment_doc,
					doc_hardline(),
					doc_text("}")
				]
			);
		}
		return doc_concat_list(
			[
				doc_text("{"),
				doc_hardline(),
				doc_text("}")
			]
		);
	}
	let inner = doc_concat_list(parts);
	if prefix_comment_doc != () {
		return doc_concat_list(
			[
				doc_text("{"),
				doc_text(" "),
				prefix_comment_doc,
				doc_indent(indent_size, doc_concat_list([doc_hardline(), inner])),
				doc_hardline(),
				doc_text("}")
			]
		);
	}
	doc_concat_list([
		doc_text("{"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), inner])),
		doc_hardline(),
		doc_text("}")
	])
}

fn doc_switch_rule(node, children, idx) {
	doc_text(slice(children.range(idx)).trim())
}

fn doc_switch_group(node, children) {
	let k_switch_label = kinds::switch_label;
	let k_colon = kinds::colon;
	let k_lbrace = kinds::lbrace;
	let k_rbrace = kinds::rbrace;
	let labels = [];
	let stmt_indices = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_switch_label {
			labels.push(children.range(i));
		}
		else if k != k_colon && k != k_lbrace && k != k_rbrace {
			stmt_indices.push(i);
		}
		i += 1;
	}
	let label_parts = [];
	let i = 0;
	while i < labels.len() {
		let label_text = slice(labels[i]).trim();
		if label_text.ends_with(":") {
			label_parts.push(doc_text(label_text));
		}
		else {
			label_parts.push(doc_text(label_text + ":"));
		}
		if i < labels.len() - 1 {
			label_parts.push(doc_hardline());
		}
		i += 1;
	}
	let indent_size = configuration::values["tab_width"];
	let stmt_parts = [];
	let j = 0;
	while j < stmt_indices.len() {
		let idx = stmt_indices[j];
		let stmt_doc = children.doc(idx);
		let stmt_text = slice(children.range(idx)).trim();
		if stmt_doc == () {
			if !stmt_text.is_empty() {
				if stmt_text == "break;" || stmt_text == "continue;" {
					stmt_parts.push(doc_hardline());
					stmt_parts.push(doc_text(stmt_text));
				}
				else {
					stmt_parts.push(doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_text(stmt_text)])));
				}
			}
		}
		else {
			if stmt_text == "break;" || stmt_text == "continue;" {
				stmt_parts.push(doc_hardline());
				stmt_parts.push(stmt_doc);
			}
			else {
				stmt_parts.push(doc_indent(indent_size, doc_concat_list([doc_hardline(), stmt_doc])));
			}
		}
		j += 1;
	}
	if label_parts.len() == 0 {
		return doc_concat_list(stmt_parts);
	}
	doc_concat_list([
		doc_concat_list(label_parts),
		doc_concat_list(stmt_parts)
	])
}

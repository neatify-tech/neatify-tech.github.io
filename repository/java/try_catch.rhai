// Try / catch / resources formatting.
import "java/kinds.rhai" as kinds;
import "java/configuration.rhai" as configuration;
import "java/whitespace.rhai" as whitespace;

fn normalize_resource_piece(text) {
	let normalized = whitespace::normalize_inline_ws(text);
	if normalized.is_empty() {
		return normalized;
	}
	let out = "";
	let i = 0;
	while i < normalized.len() {
		let ch = normalized.sub_string(i, 1);
		if ch == "=" {
			let prev = if i > 0 {
				normalized.sub_string(i - 1, 1)
			}
			else {
				""
			};
			let next = if i + 1 < normalized.len() {
				normalized.sub_string(i + 1, 1)
			}
			else {
				""
			};
			if prev != "=" && prev != "!" && prev != ">" && prev != "<" && next != "=" {
				if !out.ends_with(" ") {
					out += " ";
				}
				out += "=";
				if next != " " {
					out += " ";
				}
				i += 1;
				continue;
			}
		}
		out += ch;
		i += 1;
	}
	out.trim()
}

fn doc_try_statement(node, children) {
	let k_block = kinds::block;
	let k_catch_clause = kinds::catch_clause;
	let k_finally_clause = kinds::finally_clause;
	let k_line_comment = kinds::line_comment;
	let k_block_comment = kinds::block_comment;
	let body_node = ();
	let body_idx = -1;
	let catch_indices = [];
	let finally_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_block && body_node == () {
			body_node = 1;
			body_idx = i;
		}
		else if k == k_catch_clause {
			catch_indices.push(i);
		}
		else if k == k_finally_clause {
			finally_idx = i;
		}
		i += 1;
	}
	if body_node == () {
		return doc_text(text(node));
	}
	let header_idx = -1;
	let scan = 0;
	while scan < body_idx {
		let k = children.kind(scan);
		if k != k_line_comment && k != k_block_comment {
			header_idx = scan;
		}
		scan += 1;
	}
	let body_doc = doc_for_child(children, body_idx);
	let parts = [doc_concat_list([doc_text("try "), body_doc])];
	let j = 0;
	while j < catch_indices.len() {
		let idx = catch_indices[j];
		parts.push(doc_hardline());
		parts.push(doc_for_child(children, idx));
		j += 1;
	}
	if finally_idx >= 0 {
		parts.push(doc_hardline());
		parts.push(doc_for_child(children, finally_idx));
	}
	doc_concat_list(parts)
}

fn doc_try_with_resources(node, children) {
	let k_resource = kinds::resource_specification;
	let k_block = kinds::block;
	let k_catch_clause = kinds::catch_clause;
	let k_finally_clause = kinds::finally_clause;
	let res_idx = -1;
	let body_node = ();
	let body_idx = -1;
	let catch_indices = [];
	let finally_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_resource && res_idx < 0 {
			res_idx = i;
		}
		else if k == k_block {
			body_node = 1;
			body_idx = i;
		}
		else if k == k_catch_clause {
			catch_indices.push(i);
		}
		else if k == k_finally_clause {
			finally_idx = i;
		}
		i += 1;
	}
	if res_idx < 0 || body_node == () {
		return doc_text(text(node));
	}
	let res_text = slice(children.range(res_idx)).trim();
	let body_doc = doc_for_child(children, body_idx);
	let inner = res_text.sub_string(1, res_text.len() - 2);
	let parts = inner.split(";");
	let items = [];
	let i = 0;
	while i < parts.len() {
		let piece = normalize_resource_piece(parts[i]);
		if i == 0 {
			if !piece.is_empty() {
				items.push(doc_text(piece));
			}
		}
		else {
			items.push(doc_hardline());
			if !piece.is_empty() {
				items.push(doc_text(piece));
			}
		}
		if i < parts.len() - 1 {
			items.push(doc_text(";"));
		}
		i += 1;
	}
	let indent_size = configuration::values["tab_width"] * 2;
	let res_doc = doc_concat_list(
		[
			doc_text("("),
			doc_concat_list(items),
			doc_text(")")
		]
	);
	let res_doc = if parts.len() > 1 {
		doc_concat_list(
			[
				doc_text("("),
				doc_indent(indent_size, doc_concat_list(items)),
				doc_text(")")
			]
		)
	}
	else {
		res_doc
	};
	let parts = [
		doc_concat_list(
			[
				doc_text("try "),
				res_doc,
				doc_text(" "),
				body_doc
			]
		)
	];
	if catch_indices.len() == 0 && finally_idx < 0 {
		return doc_concat_list(
			[
				doc_text("try "),
				res_doc,
				doc_text(" "),
				body_doc
			]
		);
	}
	let j = 0;
	while j < catch_indices.len() {
		let idx = catch_indices[j];
		parts.push(doc_hardline());
		parts.push(doc_for_child(children, idx));
		j += 1;
	}
	if finally_idx >= 0 {
		parts.push(doc_hardline());
		parts.push(doc_for_child(children, finally_idx));
	}
	doc_concat_list(parts)
}

fn doc_finally_clause(node, children) {
	let k_block = kinds::block;
	let body_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_block {
			body_idx = i;
			break;
		}
		i += 1;
	}
	if body_idx < 0 {
		return doc_text(text(node));
	}
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([
		doc_text("finally "),
		body_doc
	])
}

fn doc_catch_clause(node, children) {
	let k_param = kinds::catch_formal_parameter;
	let k_block = kinds::block;
	let k_line_comment = kinds::line_comment;
	let k_block_comment = kinds::block_comment;
	let param_idx = -1;
	let body_node = ();
	let body_idx = -1;
	let inline_comment_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_param && param_idx < 0 {
			param_idx = i;
		}
		else if k == k_block {
			body_node = 1;
			body_idx = i;
		}
		else if k == k_line_comment || k == k_block_comment {
			if param_idx >= 0 && body_idx < 0 {
				inline_comment_idx = i;
			}
		}
		i += 1;
	}
	if param_idx < 0 || body_node == () {
		return doc_text(text(node));
	}
	let param_text = slice(children.range(param_idx)).trim();
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([
		doc_text("catch ("),
		doc_text(param_text),
		doc_text(") "),
		body_doc
	])
}

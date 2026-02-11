// Loop and synchronized formatting.
import "java/kinds.rhai" as kinds;
import "java/whitespace.rhai" as whitespace;

fn doc_for_statement(node, children) {
	let k_for = kinds::kw_for;
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_semi = kinds::semi;
	let k_comma = kinds::comma;
	let k_colon = kinds::colon;
	let k_local_decl = kinds::local_variable_declaration;
	let k_block = kinds::block;
	let k_line_comment = kinds::line_comment;
	let k_block_comment = kinds::block_comment;
	let body_idx = {
		let idx = -1;
		let fallback = -1;
		let i = children.len - 1;
		while i >= 0 {
			let k = children.kind(i);
			if k == k_block {
				idx = i;
				break;
			}
			if fallback < 0 && k != k_line_comment && k != k_block_comment {
				fallback = i;
			}
			i -= 1;
		}
		if idx >= 0 {
			idx
		}
		else {
			fallback
		}
	};
	let header_parts = [];
	let i = 0;
	let in_paren = false;
	let skip_semi_once = false;
	if body_idx < 0 {
		return doc_text(text(node));
	}
	while i < children.len {
		if i == body_idx {
			break;
		}
		let k = children.kind(i);
		if k == k_for {
			i += 1;
			continue;
		}
		if k == k_lparen {
			in_paren = true;
			i += 1;
			continue;
		}
		if k == k_rparen {
			in_paren = false;
			i += 1;
			continue;
		}
		if !in_paren {
			i += 1;
			continue;
		}
		if k == k_semi {
			if skip_semi_once {
				skip_semi_once = false;
				i += 1;
				continue;
			}
			header_parts.push(doc_text("; "));
			i += 1;
			continue;
		}
		if k == k_comma {
			header_parts.push(doc_text(", "));
			i += 1;
			continue;
		}
		if k == k_colon {
			header_parts.push(doc_text(" : "));
			i += 1;
			continue;
		}
		if k == k_local_decl {
			header_parts.push(doc_for_child(children, i));
			let next_idx = {
				let idx = i + 1;
				let found = -1;
				let j = idx;
				while j < children.len {
					let nk = children.kind(j);
					if nk != k_line_comment && nk != k_block_comment {
						found = j;
						break;
					}
					j += 1;
				}
				found
			};
			if next_idx >= 0 {
				let nk = children.kind(next_idx);
				if nk != k_semi && nk != k_rparen {
					header_parts.push(doc_text(" "));
				}
			}
			i += 1;
			continue;
		}
		header_parts.push(doc_for_child(children, i));
		i += 1;
	}
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([
		doc_text("for ("),
		doc_concat_list(header_parts),
		doc_text(") "),
		body_doc
	])
}

fn doc_enhanced_for_statement(node, children) {
	let k_for = kinds::kw_for;
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_colon = kinds::colon;
	let k_block = kinds::block;
	let k_line_comment = kinds::line_comment;
	let k_block_comment = kinds::block_comment;
	let body_idx = {
		let idx = -1;
		let fallback = -1;
		let i = children.len - 1;
		while i >= 0 {
			let k = children.kind(i);
			if k == k_block {
				idx = i;
				break;
			}
			if fallback < 0 && k != k_line_comment && k != k_block_comment {
				fallback = i;
			}
			i -= 1;
		}
		if idx >= 0 {
			idx
		}
		else {
			fallback
		}
	};
	let header_parts = [];
	let i = 0;
	let in_paren = false;
	let prev_kind = -1;
	if body_idx < 0 {
		return doc_text(text(node));
	}
	while i < children.len {
		if i == body_idx {
			break;
		}
		let k = children.kind(i);
		if k == k_for {
			i += 1;
			continue;
		}
		if k == k_lparen {
			in_paren = true;
			i += 1;
			continue;
		}
		if k == k_rparen {
			in_paren = false;
			i += 1;
			continue;
		}
		if !in_paren {
			i += 1;
			continue;
		}
		if k == k_colon {
			header_parts.push(doc_text(" : "));
			prev_kind = k;
			i += 1;
			continue;
		}
		if prev_kind >= 0 && prev_kind != k_lparen && prev_kind != k_colon && k != k_rparen {
			header_parts.push(doc_text(" "));
		}
		header_parts.push(doc_for_child(children, i));
		prev_kind = k;
		i += 1;
	}
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([
		doc_text("for ("),
		doc_concat_list(header_parts),
		doc_text(") "),
		body_doc
	])
}

fn doc_while_statement(node, children) {
	let k_paren = kinds::parenthesized_expression;
	let cond_idx = -1;
	let k_block = kinds::block;
	let k_line_comment = kinds::line_comment;
	let k_block_comment = kinds::block_comment;
	let body_idx = {
		let idx = -1;
		let fallback = -1;
		let i = children.len - 1;
		while i >= 0 {
			let k = children.kind(i);
			if k == k_block {
				idx = i;
				break;
			}
			if fallback < 0 && k != k_line_comment && k != k_block_comment {
				fallback = i;
			}
			i -= 1;
		}
		if idx >= 0 {
			idx
		}
		else {
			fallback
		}
	};
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_paren {
			cond_idx = i;
			break;
		}
		i += 1;
	}
	if cond_idx < 0 {
		return doc_text("");
	}
	let cond_doc = doc_for_child(children, cond_idx);
	if body_idx < 0 {
		return doc_text(text(node));
	}
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([doc_text("while "), cond_doc, doc_text(" "), body_doc])
}

fn doc_do_statement(node, children) {
	let k_paren = kinds::parenthesized_expression;
	let cond_idx = -1;
	let k_block = kinds::block;
	let k_do = kinds::kw_do;
	let k_line_comment = kinds::line_comment;
	let k_block_comment = kinds::block_comment;
	let body_idx = {
		let idx = -1;
		let i = 0;
		while i < children.len {
			let k = children.kind(i);
			if k == k_block {
				idx = i;
				break;
			}
			if k != k_do && k != k_line_comment && k != k_block_comment {
				idx = i;
				break;
			}
			i += 1;
		}
		idx
	};
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_paren {
			cond_idx = i;
			break;
		}
		i += 1;
	}
	if cond_idx < 0 {
		return doc_text("");
	}
	if body_idx < 0 {
		return doc_text("");
	}
	let body_doc = doc_for_child(children, body_idx);
	let cond_doc = doc_for_child(children, cond_idx);
	doc_concat_list([
		doc_text("do "),
		body_doc,
		doc_hardline(),
		doc_text("while "),
		cond_doc,
		doc_text(";")
	])
}

fn doc_synchronized_statement(node, children) {
	let k_paren = kinds::parenthesized_expression;
	let expr_idx = -1;
	let k_block = kinds::block;
	let k_line_comment = kinds::line_comment;
	let k_block_comment = kinds::block_comment;
	let body_idx = {
		let idx = -1;
		let fallback = -1;
		let i = children.len - 1;
		while i >= 0 {
			let k = children.kind(i);
			if k == k_block {
				idx = i;
				break;
			}
			if fallback < 0 && k != k_line_comment && k != k_block_comment {
				fallback = i;
			}
			i -= 1;
		}
		if idx >= 0 {
			idx
		}
		else {
			fallback
		}
	};
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_paren {
			expr_idx = i;
			break;
		}
		i += 1;
	}
	if expr_idx < 0 {
		return doc_text("");
	}
	let expr_doc = doc_for_child(children, expr_idx);
	if body_idx < 0 {
		return doc_text(text(node));
	}
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([doc_text("synchronized "), expr_doc, doc_text(" "), body_doc])
}

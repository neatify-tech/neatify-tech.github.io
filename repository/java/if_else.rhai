// If / else-if / else formatting.
import "java/kinds.rhai" as kinds;
import "java/configuration.rhai" as configuration;

fn doc_if_statement(node, children) {
	let k_paren_expr = kinds::parenthesized_expression;
	let k_else = kinds::kw_else;
	let k_if = kinds::kw_if;
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_block = kinds::block;
	let k_line_comment = kinds::line_comment;
	let k_block_comment = kinds::block_comment;
	let is_else_if = {
		let parent = node.parent();
		if parent == () || parent.kind_id() != kinds::if_statement {
			false
		}
		else {
			let siblings = children(parent);
			let node_range = byte_range(node);
			let prev_non_comment = ();
			let i = 0;
			let is_else_if = false;
			while i < siblings.len() {
				let sib = siblings[i];
				let r = byte_range(sib);
				if start(r) == start(node_range) && end(r) == end(node_range) {
					let prev_kind = if prev_non_comment == () {
						-1
					}
					else {
						prev_non_comment.kind_id()
					};
					if prev_kind == kinds::kw_else {
						is_else_if = true;
					}
					break;
				}
				let k = sib.kind_id();
				if k != kinds::line_comment && k != kinds::block_comment {
					prev_non_comment = sib;
				}
				i += 1;
			}
			is_else_if
		}
	};
	let cond_doc = ();
	let cond_idx = -1;
	let then_idx = -1;
	let else_idx = -1;
	let i = 0;
	let after_cond = false;
	let after_else = false;
	while i < children.len {
		let k = children.kind(i);
		if k == k_line_comment || k == k_block_comment {
			i += 1;
			continue;
		}
		if k == k_paren_expr && cond_doc == () {
			cond_idx = i;
			cond_doc = doc_for_child(children, i);
			after_cond = true;
		}
		else if k == k_else {
			after_else = true;
		}
		else if k != k_if && k != k_lparen && k != k_rparen {
			if after_else {
				if else_idx < 0 {
					else_idx = i;
				}
			}
			else if after_cond && then_idx < 0 {
				then_idx = i;
			}
		}
		i += 1;
	}
	let inline_comment_doc = ();
	if cond_idx >= 0 {
		let next_idx = cond_idx + 1;
		if next_idx < children.len {
			let nk = children.kind(next_idx);
			if nk == k_line_comment {
				let gap = slice(range(end(children.range(cond_idx)), start(children.range(next_idx))));
				if gap.index_of("\n") < 0 && gap.index_of("\r") < 0 {
					inline_comment_doc = doc_for_child(children, next_idx);
				}
			}
		}
	}
	let then_doc = if then_idx < 0 {
		doc_text("")
	}
	else if children.kind(then_idx) == k_block {
		doc_for_child(children, then_idx)
	}
	else {
		let body = slice(children.range(then_idx)).trim();
		let indent_size = configuration::values["tab_width"];
		doc_concat_list([
			doc_text("{"),
			doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_text(body)])),
			doc_hardline(),
			doc_text("}")
		])
	};
	let base = doc_concat_list(
		[
			doc_text("if "),
			if cond_doc == () {
				doc_text("")
			}
			else {
				cond_doc
			},
			doc_text(" "),
			then_doc
		]
	);
	let base = if inline_comment_doc != () && then_idx >= 0 && children.kind(then_idx) != k_block {
		doc_concat_list(
			[
				doc_text("if "),
				if cond_doc == () {
					doc_text("")
				}
				else {
					cond_doc
				},
				doc_text(" "),
				inline_comment_doc,
				doc_text(" "),
				then_doc
			]
		)
	}
	else if inline_comment_doc != () && then_idx >= 0 && children.kind(then_idx) != k_block {
		doc_concat_list(
			[
				inline_comment_doc,
				doc_hardline(),
				base
			]
		)
	}
	else {
		base
	};
	if else_idx < 0 {
		return base;
	}
	let else_doc = if children.kind(else_idx) == kinds::if_statement {
		doc_for_child(children, else_idx)
	}
	else if children.kind(else_idx) == k_block {
		doc_for_child(children, else_idx)
	}
	else {
		let body = slice(children.range(else_idx)).trim();
		let indent_size = configuration::values["tab_width"];
		doc_concat_list([
			doc_text("{"),
			doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_text(body)])),
			doc_hardline(),
			doc_text("}")
		])
	};
	doc_concat_list([
		base,
		doc_hardline(),
		doc_text("else "),
		else_doc
	])
}

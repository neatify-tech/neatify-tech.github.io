// Shared helpers for inline comments between headers and blocks.
import "shared/comments.rhai" as comments;
fn inline_comment_doc_from_gap(gap, line_prefix, block_start, block_end) {
	let line_idx = if line_prefix.is_empty() {
		-1
	}
	else {
		gap.index_of(line_prefix)
	};
	let block_idx = if block_start.is_empty() {
		-1
	}
	else {
		gap.index_of(block_start)
	};
	if line_idx < 0 && block_idx < 0 {
		return ();
	}
	let use_line = if line_idx >= 0 && block_idx >= 0 {
		line_idx < block_idx
	}
	else if line_idx >= 0 {
		true
	}
	else {
		false
	};
	if use_line {
		let raw = gap.sub_string(line_idx + line_prefix.len(), gap.len() - line_idx - line_prefix.len());
		let lf = raw.index_of("\n");
		let cr = raw.index_of("\r");
		let cut = if lf >= 0 && cr >= 0 {
			if lf < cr {
				lf
			}
			else {
				cr
			}
		}
		else if lf >= 0 {
			lf
		}
		else if cr >= 0 {
			cr
		}
		else {
			raw.len()
		};
		let content = raw.sub_string(0, cut).trim();
		if content.is_empty() {
			return doc_text(line_prefix);
		}
		return doc_text(line_prefix + " " + content);
	}
	if block_idx >= 0 {
		let end_idx = gap.index_of(block_end);
		if end_idx >= 0 && end_idx > block_idx {
			let raw = gap.sub_string(block_idx, end_idx + block_end.len() - block_idx).trim();
			return doc_text(raw);
		}
	}()
}

fn node_for_range_kind(language, parent_node, target_range, kind_name) {
	if parent_node == () {
		return ();
	}
	let matches = query(language, "(" + kind_name + ") @n", byte_range(parent_node));
	for m in matches {
		let n = m.captures()
		["n"];
		if n == () {
			continue;
		}
		let r = byte_range(n);
		if start(r) == start(target_range) && end(r) == end(target_range) {
			return n;
		}
	}()
}

fn inline_comment_doc_between(language, header_end, block_start, line_comment_name, block_comment_name, line_prefix, block_prefix, block_suffix) {
	if header_end < 0 || block_start < 0 || header_end >= block_start {
		return ();
	}
	let gap = slice(range(header_end, block_start));
	if gap.trim().is_empty() {
		return ();
	}
	let comment_node = ();
	let comment_kind = "";
	let comment_start = -1;
	let search_range = range(header_end, block_start);
	let line_matches = query(language, "(" + line_comment_name + ") @c", search_range);
	let block_matches = query(language, "(" + block_comment_name + ") @c", search_range);
	for m in line_matches {
		let c = m.captures()
		["c"];
		if c == () {
			continue;
		}
		let r = byte_range(c);
		if comment_start < 0 || start(r) < comment_start {
			comment_node = c;
			comment_kind = line_comment_name;
			comment_start = start(r);
		}
	}
	for m in block_matches {
		let c = m.captures()
		["c"];
		if c == () {
			continue;
		}
		let r = byte_range(c);
		if comment_start < 0 || start(r) < comment_start {
			comment_node = c;
			comment_kind = block_comment_name;
			comment_start = start(r);
		}
	}
	if comment_node != () {
		let raw = text(comment_node).trim();
		if comment_kind == line_comment_name {
			return comments::doc_line_comment(comment_node, line_prefix);
		}
		return comments::doc_block_comment(comment_node, block_prefix, block_suffix);
	}()
}
// Exports are implicit via module import.

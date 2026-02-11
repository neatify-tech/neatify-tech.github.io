// Comment formatting helpers (shared).
import "shared/whitespace.rhai" as shared_ws;
fn strip_incidental_ws_block_comment(text) {
	let lines = text.split("\n");
	if lines.len() == 0 {
		return text;
	}
	let min_ws = if lines.len() > 1 {
		shared_ws::strip_incidental_ws_block(lines, 0, lines.len() - 1)
	}
	else {
		0
	};
	let out_lines = [];
	let i = 0;
	while i < lines.len() {
		let line = lines[i];
		let ws = shared_ws::leading_ws_len(line);
		let trimmed = if min_ws > 0 && ws >= min_ws && line.len() >= min_ws {
			line.sub_string(min_ws, line.len() - min_ws)
		}
		else {
			line
		};
		out_lines.push(trimmed);
		i += 1;
	}
	shared_ws::join_lines(out_lines)
}
// Line comment normalization: ensure a single space after //.
fn doc_line_comment(node, line_prefix)
{
	let comment_text = text(node);
	if comment_text.len() < line_prefix.len() {
		return doc_text(comment_text);
	}
	if comment_text.sub_string(0, line_prefix.len()) != line_prefix {
		return doc_text(comment_text);
	}
	let rest = comment_text.sub_string(line_prefix.len(), comment_text.len() - line_prefix.len())
		.trim();
	if rest.is_empty() {
		return doc_text(line_prefix);
	}
	doc_text(line_prefix + " " + rest)
}

fn doc_block_comment(node, block_start, block_end) {
	if block_start.is_empty() || block_end.is_empty() {
		return doc_text(text(node));
	}
	// the first line does NOT have its whitespace included, it starts at the start of the comment
	// we need that whitespace though to correctly calculate the incidental in case the first line _is_ the determining one (e.g. javadoc)
	let r = byte_range(node);
	let start_pos = start(r);
	let line = line_at(start_pos);
	let line_start = start_offset(line);
	let indent_prefix = if start_pos > line_start {
		slice(range(line_start, start_pos))
	}
	else {
		""
	};
	let full_text = indent_prefix + text(node);
	let raw = strip_incidental_ws_block_comment(full_text);
	let lines = raw.split("\n");
	let parts = [];
	let i = 0;
	while i < lines.len() {
		let line = lines[i];
		if i == 0 {
			parts.push(doc_text(shared_ws::strip_leading_ws(line)));
		}
		else if i == lines.len() - 1 {
			parts.push(doc_hardline());
			parts.push(doc_text(line));
		}
		else {
			parts.push(doc_hardline());
			parts.push(doc_text(line));
		}
		i += 1;
	}
	doc_concat_list(parts)
}
// Exports are implicit via module import.

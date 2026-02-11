fn doThis() {
	log("no!");
}
// Line comment normalization: ensure a single space after //.
fn doc_block_comment(node, block_start, block_end)
{
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

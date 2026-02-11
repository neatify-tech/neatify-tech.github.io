// Whitespace and indentation helpers (shared).
fn normalize_varargs(text) {
	let out = text;
	let idx = out.index_of("... ");
	while idx >= 0 {
		out = out.sub_string(0, idx + 3) + out.sub_string(idx + 4, out.len() - idx - 4);
		idx = out.index_of("... ");
	}
	idx = out.index_of(" ...");
	while idx >= 0 {
		out = out.sub_string(0, idx) + "..." + out.sub_string(idx + 4, out.len() - idx - 4);
		idx = out.index_of(" ...");
	}
	out
}
fn normalize_inline_ws(text) {
	let out = "";
	let i = 0;
	let in_ws = false;
	while i < text.len() {
		let ch = text.sub_string(i, 1);
		if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
			if !in_ws {
				out += " ";
				in_ws = true;
			}
		}
		else {
			out += ch;
			in_ws = false;
		}
		i += 1;
	}
	out.trim()
}

fn repeat_str(text, count) {
	if count <= 0 {
		return "";
	}
	let out = "";
	let i = 0;
	while i < count {
		out += text;
		i += 1;
	}
	out
}

fn leading_ws_len(text) {
	let i = 0;
	while i < text.len() {
		let ch = text.sub_string(i, 1);
		if ch != " " && ch != "\t" {
			break;
		}
		i += 1;
	}
	i
}

fn strip_leading_ws(text) {
	let ws = leading_ws_len(text);
	if ws == 0 {
		return text;
	}
	text.sub_string(ws, text.len() - ws)
}

fn join_lines(lines) {
	let out = "";
	let i = 0;
	while i < lines.len() {
		out += lines[i];
		if i < lines.len() - 1 {
			out += "\n";
		}
		i += 1;
	}
	out
}

fn strip_incidental_ws_block(lines, start_idx, end_idx) {
	let min_ws = -1;
	let i = start_idx;
	while i <= end_idx {
		let line = lines[i];
		if !line.trim().is_empty() {
			let ws = leading_ws_len(line);
			if min_ws < 0 || ws < min_ws {
				min_ws = ws;
			}
		}
		i += 1;
	}
	if min_ws < 0 {
		min_ws = 0;
	}
	min_ws
}

fn indent_cols_from_prefix(text, tab_width) {
	let col = 0;
	let i = 0;
	while i < text.len() {
		let ch = text.sub_string(i, 1);
		if ch == "\t" {
			let w = tab_width.max(1);
			let add = w - (col % w);
			col += add;
		}
		else if ch == " " {
			col += 1;
		}
		else {
			break;
		}
		i += 1;
	}
	col
}

fn text_cols(text, tab_width) {
	let col = 0;
	let i = 0;
	while i < text.len() {
		let ch = text.sub_string(i, 1);
		if ch == "\t" {
			let w = tab_width.max(1);
			let add = w - (col % w);
			col += add;
		}
		else if ch == "\n" || ch == "\r" {
			col = 0;
		}
		else {
			col += 1;
		}
		i += 1;
	}
	col
}
// Exports are implicit via module import.

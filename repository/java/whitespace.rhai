// Whitespace and indentation helpers.
import "shared/whitespace.rhai" as shared_ws;
import "java/configuration.rhai" as configuration;

fn normalize_varargs(text) {
	shared_ws::normalize_varargs(text)
}

fn normalize_inline_ws(text) {
	shared_ws::normalize_inline_ws(text)
}

fn repeat_str(text, count) {
	shared_ws::repeat_str(text, count)
}

fn leading_ws_len(text) {
	shared_ws::leading_ws_len(text)
}

fn strip_leading_ws(text) {
	shared_ws::strip_leading_ws(text)
}

fn join_lines(lines) {
	shared_ws::join_lines(lines)
}

fn strip_incidental_ws_block(lines, start_idx, end_idx) {
	shared_ws::strip_incidental_ws_block(lines, start_idx, end_idx)
}

fn indent_cols_from_prefix(text, tab_width) {
	shared_ws::indent_cols_from_prefix(text, tab_width)
}

fn indent_string_from_cols(cols) {
	let indent_style = configuration::values["indent_style"];
	let tab_width = configuration::values["tab_width"];
	if indent_style == "spaces" {
		return repeat_str(" ", cols);
	}
	let w = tab_width.max(1);
	let tabs = cols / w;
	let spaces = cols % w;
	repeat_str("\t", tabs) + repeat_str(" ", spaces)
}

fn indent_string(level, indent_style, tab_width) {
	if indent_style == "spaces" {
		return repeat_str(" ", level * tab_width);
	}
	repeat_str("\t", level)
}

fn text_cols(text, tab_width) {
	shared_ws::text_cols(text, tab_width)
}
// Exports are implicit via module import.

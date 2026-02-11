// Doc-first formatter entrypoint for Markdown.
import "markdown/kinds.rhai" as kinds;
import "markdown/configuration.rhai" as configuration;
import "shared/whitespace.rhai" as whitespace;

fn doc_concat_list(docs) {
	if docs.len() == 0 {
		return doc_text("");
	}
	if docs.len() == 1 {
		return docs[0];
	}
	doc_concat(docs)
}

fn doc_block_children(children) {
	let parts = [];
	let prev_kind = -1;
	let i = 0;
	while i < children.len {
		let kind_id = children.kind(i);
		let d = doc_for_child(children, i);
		if d != () {
			if parts.len() > 0 {
				let sep = 2;
				if prev_kind == kinds::link_reference_definition && kind_id == kinds::block_quote {
					sep = 1;
				}
				let s = 0;
				while s < sep {
					parts.push(doc_hardline());
					s += 1;
				}
			}
			parts.push(d);
			prev_kind = kind_id;
		}
		i += 1;
	}
	if parts.len() == 0 {
		return ();
	}
	doc_concat_list(parts)
}

fn doc_for_child(children, idx) {
	let d = children.doc(idx);
	if d == () {
		let r = children.range(idx);
		return doc_range(start(r), end(r));
	}
	d
}

fn normalize_block_quote(text) {
	let lines = text.split("\n");
	let i = 0;
	while i < lines.len() {
		let line = lines[i];
		let trimmed = line.trim();
		if trimmed.starts_with(">") {
			let rest = trimmed.sub_string(1, trimmed.len() - 1);
			let rest_trim = rest.trim();
			if rest_trim == "" {
				lines[i] = ">";
			}
			else {
				lines[i] = "> " + rest_trim;
			}
		}
		i += 1;
	}
	whitespace::join_lines(lines)
}

fn trim_trailing_newlines(text) {
	let out = text;
	while out.len() > 0 {
		let last = out.sub_string(out.len() - 1, 1);
		if last == "\n" || last == "\r" {
			out = out.sub_string(0, out.len() - 1);
		}
		else {
			break;
		}
	}
	out
}

fn doc_fenced_code_block(node, children) {
	let k_info = kinds::info_string;
	let k_lang = kinds::language;
	let k_content = kinds::code_fence_content;
	let info = "";
	let content_range = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_info || k == k_lang {
			let r = children.range(i);
			let raw = slice(r).trim();
			if raw != "" {
				info = raw;
			}
		}
		else if k == k_content {
			content_range = children.range(i);
		}
		i += 1;
	}
	let fence = "```";
	let header = if info != "" {
		fence + info
	}
	else {
		fence
	};
	let body_doc = doc_text("");
	if content_range != () {
		let content_start = start(content_range);
		let content_end = end(content_range);
		let raw = slice(content_range);
		let raw_trim = raw.trim();
		if !raw_trim.ends_with(";") {
			let tail = slice(range(content_end, source_len()));
			let j = 0;
			while j < tail.len() {
				let ch = tail.sub_string(j, 1);
				if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
					j += 1;
					continue;
				}
				if ch == ";" {
					content_end = content_end + j + 1;
				}
				break;
			}
		}
		let content_for_format = range(content_start, content_end);
		let formatted = ();
		let lang = info.to_lower();
		if lang != "" {
			formatted = format_fragment_doc(lang, content_for_format);
		}
		if formatted != () {
			body_doc = formatted;
		}
		else {
			let raw = slice(content_for_format);
			body_doc = doc_text(trim_trailing_newlines(raw));
		}
	}
	doc_concat_list([
		doc_text(header),
		doc_hardline(),
		body_doc,
		doc_hardline(),
		doc_text(fence)
	])
}

fn build_doc(node, children) {
	let k = node.kind_id();
	if k == kinds::document {
		let doc = doc_block_children(children);
		if doc != () {
			return doc;
		}
		return doc_text("");
	}
	if k == kinds::section {
		let doc = doc_block_children(children);
		if doc != () {
			return doc;
		}
		return doc_text("");
	}
	if k == kinds::block_quote {
		let r = byte_range(node);
		let raw = slice(r);
		let normalized = normalize_block_quote(raw);
		return doc_text(normalized);
	}
	if k == kinds::fenced_code_block {
		return doc_fenced_code_block(node, children);
	}
	if k == kinds::paragraph || k == kinds::atx_heading || k == kinds::setext_heading || k == kinds::list || k == kinds::list_item || k == kinds::link_reference_definition || k == kinds::thematic_break {
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	let r = byte_range(node);
	doc_range(start(r), end(r))
}
doc_reset();
let queries = [
	"(document) @n",
	"(paragraph) @n",
	"(section) @n",
	"(atx_heading) @n",
	"(setext_heading) @n",
	"(list) @n",
	"(list_item) @n",
	"(block_quote) @n",
	"(fenced_code_block) @n",
	"(link_reference_definition) @n",
	"(thematic_break) @n"
];
let root_doc = walk(
	"markdown",
	queries,
	|node, children| {
		build_doc(node, children)
	}
);
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
let cleaned = [];
let prev_empty = true;
let i = 0;
while i < lines.len() {
	let line = lines[i];
	if line == "" {
		if !prev_empty {
			cleaned.push("");
			prev_empty = true;
		}
	}
	else {
		cleaned.push(line);
		prev_empty = false;
	}
	i += 1;
}
let output = whitespace::join_lines(cleaned);
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
set_output(output);

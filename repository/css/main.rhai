// Doc-first formatter entrypoint for CSS.
import "css/kinds.rhai" as kinds;
import "css/configuration.rhai" as configuration;
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

fn doc_for_child(children, idx) {
	let d = children.doc(idx);
	if d == () {
		let r = children.range(idx);
		return doc_range(start(r), end(r));
	}
	d
}

fn trim_trailing_space(text) {
	let out = text;
	while out.len() > 0 {
		let last = out.sub_string(out.len() - 1, 1);
		if last == " " || last == "\t" {
			out = out.sub_string(0, out.len() - 1);
		}
		else {
			break;
		}
	}
	out
}

fn normalize_css_text(text, space_after_colon, space_after_comma, space_before_paren) {
	let i = 0;
	let out = "";
	let in_string = false;
	let quote = "";
	let pending_space = false;
	let last_was_colon = false;
	while i < text.len() {
		let ch = text.sub_string(i, 1);
		if in_string {
			out = out + ch;
			if ch == quote {
				in_string = false;
			}
			last_was_colon = false;
			i += 1;
			continue;
		}
		if ch == "\"" || ch == "'" {
			if pending_space && out.len() > 0 {
				out = out + " ";
			}
			pending_space = false;
			in_string = true;
			quote = ch;
			out = out + ch;
			last_was_colon = false;
			i += 1;
			continue;
		}
		if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
			if !last_was_colon {
				pending_space = true;
			}
			i += 1;
			continue;
		}
		if ch == "," {
			out = trim_trailing_space(out);
			out = out + ",";
			if space_after_comma {
				out = out + " ";
			}
			pending_space = false;
			last_was_colon = false;
			i += 1;
			continue;
		}
		if ch == ":" {
			out = trim_trailing_space(out);
			out = out + ":";
			if space_after_colon {
				out = out + " ";
			}
			pending_space = false;
			last_was_colon = true;
			i += 1;
			continue;
		}
		if ch == "(" {
			out = trim_trailing_space(out);
			if space_before_paren {
				if out.len() > 0 {
					let last = out.sub_string(out.len() - 1, 1);
					if last != " " && last != "(" {
						out = out + " ";
					}
				}
			}
			out = out + "(";
			pending_space = false;
			last_was_colon = false;
			i += 1;
			continue;
		}
		if ch == ")" {
			out = trim_trailing_space(out);
			out = out + ")";
			pending_space = false;
			last_was_colon = false;
			i += 1;
			continue;
		}
		if pending_space {
			if out.len() > 0 {
				out = out + " ";
			}
			pending_space = false;
		}
		out = out + ch;
		last_was_colon = false;
		i += 1;
	}
	trim(out)
}

fn split_selectors(text) {
	let list = [];
	let buf = "";
	let i = 0;
	let depth_paren = 0;
	let depth_bracket = 0;
	let in_string = false;
	let quote = "";
	while i < text.len() {
		let ch = text.sub_string(i, 1);
		if in_string {
			buf = buf + ch;
			if ch == quote {
				in_string = false;
			}
			i += 1;
			continue;
		}
		if ch == "\"" || ch == "'" {
			in_string = true;
			quote = ch;
			buf = buf + ch;
			i += 1;
			continue;
		}
		if ch == "(" {
			depth_paren += 1;
			buf = buf + ch;
			i += 1;
			continue;
		}
		if ch == ")" {
			if depth_paren > 0 {
				depth_paren -= 1;
			}
			buf = buf + ch;
			i += 1;
			continue;
		}
		if ch == "[" {
			depth_bracket += 1;
			buf = buf + ch;
			i += 1;
			continue;
		}
		if ch == "]" {
			if depth_bracket > 0 {
				depth_bracket -= 1;
			}
			buf = buf + ch;
			i += 1;
			continue;
		}
		if ch == "," && depth_paren == 0 && depth_bracket == 0 {
			let item = trim(buf);
			if item != "" {
				list.push(item);
			}
			buf = "";
			i += 1;
			continue;
		}
		buf = buf + ch;
		i += 1;
	}
	let item = trim(buf);
	if item != "" {
		list.push(item);
	}
	list
}

fn doc_selectors(node) {
	let raw = slice(byte_range(node));
	let list = split_selectors(raw);
	if list.len() == 0 {
		return doc_text(trim(raw));
	}
	let joined = "";
	let i = 0;
	while i < list.len() {
		if i > 0 {
			joined = joined + ", ";
		}
		joined = joined + list[i];
		i += 1;
	}
	let max_width = configuration::values["max_width"];
	if joined.len() <= max_width {
		return doc_text(joined);
	}
	let indent_size = configuration::values["tab_width"] * 2;
	let tail = [];
	i = 1;
	while i < list.len() {
		if tail.len() > 0 {
			tail.push(doc_hardline());
		}
		let item = if i < list.len() - 1 {
			list[i] + ","
		}
		else {
			list[i]
		};
		tail.push(doc_text(item));
		i += 1;
	}
	let first = doc_text(list[0] + ",");
	if tail.len() == 0 {
		return first;
	}
	doc_concat_list([
		first,
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(tail)]))
	])
}

fn doc_declaration(node, children) {
	let prop_id = kinds::property_name;
	let prop_range = ();
	let i = 0;
	while i < children.len {
		if children.kind(i) == prop_id {
			prop_range = children.range(i);
			break;
		}
		i += 1;
	}
	if prop_range == () {
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	let prop_text = trim(slice(prop_range));
	let r = byte_range(node);
	let value_range = range(end(prop_range), end(r));
	let value_raw = trim(slice(value_range));
	if value_raw.starts_with(":") {
		value_raw = trim(value_raw.sub_string(1, value_raw.len() - 1));
	}
	if value_raw.ends_with(";") {
		value_raw = trim(value_raw.sub_string(0, value_raw.len() - 1));
	}
	let value_text = normalize_css_text(value_raw, false, true, false);
	doc_concat_list([
		doc_text(prop_text),
		doc_text(": "),
		doc_text(value_text),
		doc_text(";")
	])
}

fn doc_block(node, children) {
	let items = [];
	let allowed = [
		kinds::declaration,
		kinds::rule_set,
		kinds::at_rule,
		kinds::media_statement,
		kinds::supports_statement,
		kinds::scope_statement,
		kinds::keyframes_statement,
		kinds::import_statement,
		kinds::charset_statement,
		kinds::namespace_statement,
		kinds::postcss_statement
	];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		let j = 0;
		let allowed_item = false;
		while j < allowed.len() {
			if k == allowed[j] {
				allowed_item = true;
				break;
			}
			j += 1;
		}
		if allowed_item {
			items.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if items.len() == 0 {
		return doc_text("{}");
	}
	let joined = [];
	i = 0;
	while i < items.len() {
		joined.push(items[i]);
		if i < items.len() - 1 {
			joined.push(doc_hardline());
		}
		i += 1;
	}
	let indent_size = configuration::values["tab_width"];
	doc_concat_list([
		doc_text("{"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(joined)])),
		doc_hardline(),
		doc_text("}")
	])
}

fn doc_keyframe_block(node, children) {
	let block_id = kinds::block;
	let block_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == block_id {
			block_idx = i;
			break;
		}
		i += 1;
	}
	if block_idx < 0 {
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	let block_range = children.range(block_idx);
	let header_range = range(start(byte_range(node)), start(block_range));
	let header = trim(slice(header_range));
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([doc_text(header), doc_text(" "), block_doc])
}

fn doc_keyframe_block_list(node, children) {
	let items = [];
	let keyframe_id = kinds::keyframe_block;
	let i = 0;
	while i < children.len {
		if children.kind(i) == keyframe_id {
			items.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if items.len() == 0 {
		return doc_text("{}");
	}
	let joined = [];
	i = 0;
	while i < items.len() {
		joined.push(items[i]);
		if i < items.len() - 1 {
			joined.push(doc_hardline());
		}
		i += 1;
	}
	let indent_size = configuration::values["tab_width"];
	doc_concat_list([
		doc_text("{"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(joined)])),
		doc_hardline(),
		doc_text("}")
	])
}

fn doc_at_rule(node, children, block_kind_id) {
	let block_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == block_kind_id {
			block_idx = i;
			break;
		}
		i += 1;
	}
	if block_idx < 0 {
		let raw = trim(slice(byte_range(node)));
		let normalized = normalize_css_text(raw, true, true, true);
		if normalized.ends_with(";") {
			return doc_text(normalized);
		}
		return doc_text(normalized + ";");
	}
	let block_range = children.range(block_idx);
	let header_range = range(start(byte_range(node)), start(block_range));
	let header = normalize_css_text(trim(slice(header_range)), true, true, true);
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([doc_text(header), doc_text(" "), block_doc])
}

fn doc_rule_set(node, children) {
	let selector_id = kinds::selectors;
	let block_id = kinds::block;
	let selectors_doc = ();
	let block_doc = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == selector_id {
			selectors_doc = doc_for_child(children, i);
		}
		else if k == block_id {
			block_doc = doc_for_child(children, i);
		}
		i += 1;
	}
	if selectors_doc == () || block_doc == () {
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	doc_concat_list([selectors_doc, doc_text(" "), block_doc])
}

fn doc_stylesheet(children) {
	let items = [];
	let allowed = [
		kinds::rule_set,
		kinds::at_rule,
		kinds::media_statement,
		kinds::supports_statement,
		kinds::scope_statement,
		kinds::keyframes_statement,
		kinds::import_statement,
		kinds::charset_statement,
		kinds::namespace_statement,
		kinds::postcss_statement,
		kinds::declaration
	];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		let j = 0;
		let allowed_item = false;
		while j < allowed.len() {
			if k == allowed[j] {
				allowed_item = true;
				break;
			}
			j += 1;
		}
		if allowed_item {
			items.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if items.len() == 0 {
		return doc_text("");
	}
	let joined = [];
	i = 0;
	while i < items.len() {
		joined.push(items[i]);
		if i < items.len() - 1 {
			joined.push(doc_hardline());
			joined.push(doc_hardline());
		}
		i += 1;
	}
	doc_concat_list(joined)
}

fn build_doc(node, children) {
	let k = node.kind_id();
	if k == kinds::stylesheet {
		return doc_stylesheet(children);
	}
	if k == kinds::selectors {
		return doc_selectors(node);
	}
	if k == kinds::declaration {
		return doc_declaration(node, children);
	}
	if k == kinds::block {
		return doc_block(node, children);
	}
	if k == kinds::keyframe_block_list {
		return doc_keyframe_block_list(node, children);
	}
	if k == kinds::keyframe_block {
		return doc_keyframe_block(node, children);
	}
	if k == kinds::rule_set {
		return doc_rule_set(node, children);
	}
	if k == kinds::media_statement {
		return doc_at_rule(node, children, kinds::block);
	}
	if k == kinds::supports_statement {
		return doc_at_rule(node, children, kinds::block);
	}
	if k == kinds::scope_statement {
		return doc_at_rule(node, children, kinds::block);
	}
	if k == kinds::keyframes_statement {
		return doc_at_rule(node, children, kinds::keyframe_block_list);
	}
	if k == kinds::at_rule {
		return doc_at_rule(node, children, kinds::block);
	}
	if k == kinds::import_statement || k == kinds::charset_statement || k == kinds::namespace_statement || k == kinds::postcss_statement {
		return doc_at_rule(node, children, -1);
	}
	let r = byte_range(node);
	doc_range(start(r), end(r))
}
doc_reset();
let queries = [
	"(stylesheet) @n",
	"(selectors) @n",
	"(rule_set) @n",
	"(block) @n",
	"(declaration) @n",
	"(keyframe_block_list) @n",
	"(keyframe_block) @n",
	"(media_statement) @n",
	"(supports_statement) @n",
	"(scope_statement) @n",
	"(keyframes_statement) @n",
	"(at_rule) @n",
	"(import_statement) @n",
	"(charset_statement) @n",
	"(namespace_statement) @n",
	"(postcss_statement) @n"
];
let root_doc = walk(
	"css",
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
let output = whitespace::join_lines(lines);
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

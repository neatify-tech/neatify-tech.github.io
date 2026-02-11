// Doc-first formatter entrypoint for JSON.
import "json/kinds.rhai" as kinds;
import "json/configuration.rhai" as configuration;
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

fn is_value_kind(kind_id) {
	if kind_id == kinds::value {
		return true;
	}
	if kind_id == kinds::object {
		return true;
	}
	if kind_id == kinds::array {
		return true;
	}
	if kind_id == kinds::string {
		return true;
	}
	if kind_id == kinds::number {
		return true;
	}
	if kind_id == kinds::lit_true {
		return true;
	}
	if kind_id == kinds::lit_false {
		return true;
	}
	if kind_id == kinds::lit_null {
		return true;
	}
	false
}

fn doc_value(node, children) {
	let k = node.kind_id();
	if k == kinds::object {
		return doc_object(children);
	}
	if k == kinds::array {
		return doc_array(children);
	}
	if k == kinds::string || k == kinds::number || k == kinds::lit_true || k == kinds::lit_false || k == kinds::lit_null {
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	if k == kinds::value {
		let i = 0;
		while i < children.len {
			let d = doc_for_child(children, i);
			if d != () {
				return d;
			}
			i += 1;
		}
	}
	let r = byte_range(node);
	doc_range(start(r), end(r))
}

fn doc_pair(children) {
	let k_string = kinds::string;
	let key_doc = ();
	let value_doc = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_string && key_doc == () {
			key_doc = doc_for_child(children, i);
		}
		else if value_doc == () && is_value_kind(k) {
			value_doc = doc_for_child(children, i);
		}
		i += 1;
	}
	if key_doc == () || value_doc == () {
		return doc_text("");
	}
	doc_concat_list([key_doc, doc_text(": "), value_doc])
}

fn doc_object(children) {
	let items = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::pair {
			items.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if items.len() == 0 {
		return doc_text("{}");
	}
	let parts = [];
	let i = 0;
	while i < items.len() {
		let item = items[i];
		if i < items.len() - 1 {
			parts.push(doc_concat_list([item, doc_text(",")]))
		}
		else {
			parts.push(item)
		}
		if i < items.len() - 1 {
			parts.push(doc_hardline());
		}
		i += 1;
	}
	let indent_size = configuration::values["tab_width"];
	doc_concat_list([
		doc_text("{"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)])),
		doc_hardline(),
		doc_text("}")
	])
}

fn doc_array(children) {
	let items = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if is_value_kind(k) {
			items.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if items.len() == 0 {
		return doc_text("[]");
	}
	let parts = [];
	let i = 0;
	while i < items.len() {
		let item = items[i];
		if i < items.len() - 1 {
			parts.push(doc_concat_list([item, doc_text(",")]))
		}
		else {
			parts.push(item)
		}
		if i < items.len() - 1 {
			parts.push(doc_hardline());
		}
		i += 1;
	}
	let indent_size = configuration::values["tab_width"];
	doc_concat_list([
		doc_text("["),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)])),
		doc_hardline(),
		doc_text("]")
	])
}

fn build_doc(node, children) {
	let k = node.kind_id();
	if k == kinds::document {
		let i = 0;
		while i < children.len {
			let d = doc_for_child(children, i);
			if d != () {
				return d;
			}
			i += 1;
		}
		return doc_text("");
	}
	if k == kinds::object {
		return doc_object(children);
	}
	if k == kinds::array {
		return doc_array(children);
	}
	if k == kinds::pair {
		return doc_pair(children);
	}
	if k == kinds::value {
		return doc_value(node, children);
	}
	let r = byte_range(node);
	doc_range(start(r), end(r))
}
doc_reset();
let queries = [
	"(document) @n",
	"(object) @n",
	"(array) @n",
	"(pair) @n",
	"(_value) @n"
];
let root_doc = walk(
	"json",
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

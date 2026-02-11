// Doc-first formatter entrypoint for Java.
// No source mutations are performed outside of Doc rendering.
import "java/kinds.rhai" as kinds;
import "java/if_else.rhai" as if_else;
import "java/try_catch.rhai" as try_catch;
import "java/loop_sync.rhai" as loop_sync;
import "java/switch.rhai" as switch_fmt;
import "java/comment_helpers.rhai" as comment_helpers;
import "java/configuration.rhai" as configuration;
import "java/whitespace.rhai" as whitespace;
import "java/comments.rhai" as comments;

fn doc_empty() {
	doc_text("")
}

fn doc_concat_list(docs) {
	if docs.len() == 0 {
		return doc_empty();
	}
	if docs.len() == 1 {
		return docs[0];
	}
	doc_concat(docs)
}

fn node_len(node) {
	let r = range(node);
	end(r) - start(r)
}

fn node_is_multiline(node) {
	let start_pos = start_position(node);
	let end_pos = end_position(node);
	row(end_pos) > row(start_pos)
}

fn is_block_condition(node) {
	let p = node.parent();
	if p == () || p.kind_id() != kinds::parenthesized_expression {
		return false;
	}
	let gp = p.parent();
	if gp == () {
		return false;
	}
	let k = gp.kind_id();
	k == kinds::if_statement || k == kinds::while_statement || k == kinds::for_statement || k == kinds::do_statement || k == kinds::synchronized_statement || k == kinds::switch_statement || k == kinds::switch_expression
}

fn has_ancestor_kind(node, target) {
	node.ancestor([target]) != ()
}

fn header_keyword(kind_id) {
	if kind_id == kinds::if_statement {
		kinds::kw_if
	}
	else if kind_id == kinds::for_statement || kind_id == kinds::enhanced_for_statement {
		kinds::kw_for
	}
	else if kind_id == kinds::while_statement {
		kinds::kw_while
	}
	else if kind_id == kinds::do_statement {
		kinds::kw_do
	}
	else if kind_id == kinds::synchronized_statement {
		kinds::kw_synchronized
	}
	else if kind_id == kinds::switch_statement || kind_id == kinds::switch_expression {
		kinds::kw_switch
	}
	else if kind_id == kinds::try_statement || kind_id == kinds::try_with_resources_statement {
		kinds::kw_try
	}
	else if kind_id == kinds::catch_clause {
		kinds::kw_catch
	}
	else if kind_id == kinds::finally_clause {
		kinds::kw_finally
	}
	else {
		-1
	}
}

fn inline_comment_from_keyword_gap(parent_children, keyword_kind, stop_idx) {
	if keyword_kind < 0 || stop_idx <= 0 {
		return ();
	}
	let key_idx = -1;
	let i = 0;
	while i < stop_idx {
		if parent_children[i].kind_id() == keyword_kind {
			key_idx = i;
			break;
		}
		i += 1;
	}
	if key_idx < 0 {
		return ();
	}
	let next_idx = -1;
	i = key_idx + 1;
	while i < stop_idx {
		let k = parent_children[i].kind_id();
		if k != kinds::line_comment && k != kinds::block_comment {
			next_idx = i;
			break;
		}
		i += 1;
	}
	if next_idx < 0 {
		return ();
	}
	let key_end = end(byte_range(parent_children[key_idx]));
	let next_start = start(byte_range(parent_children[next_idx]));
	if next_start <= key_end {
		return ();
	}
	let gap = slice(range(key_end, next_start));
	if gap.trim().is_empty() {
		return ();
	}
	let doc = comment_helpers::inline_comment_doc_between("java", key_end, next_start);
	if doc != () {
		doc
	}
	else {
		comment_helpers::inline_comment_doc_from_gap(gap)
	}
}

fn first_line_text(raw) {
	let idx = raw.index_of("\n");
	if idx < 0 {
		raw
	}
	else {
		raw.sub_string(0, idx)
	}
}

fn normalize_generic_text(raw) {
	let out = "";
	let i = 0;
	let in_line = false;
	let in_block = false;
	let in_string = false;
	let in_char = false;
	let escape = false;
	while i < raw.len() {
		let ch = raw.sub_string(i, 1);
		let next = if i + 1 < raw.len() {
			raw.sub_string(i + 1, 1)
		}
		else {
			""
		};
		if in_line {
			out += ch;
			if ch == "\n" || ch == "\r" {
				in_line = false;
			}
			i += 1;
			continue;
		}
		if in_block {
			out += ch;
			if ch == "*" && next == "/" {
				out += "/";
				i += 2;
				in_block = false;
				continue;
			}
			i += 1;
			continue;
		}
		if in_string {
			out += ch;
			if escape {
				escape = false;
			}
			else if ch == "\\" {
				escape = true;
			}
			else if ch == "\"" {
				in_string = false;
			}
			i += 1;
			continue;
		}
		if in_char {
			out += ch;
			if escape {
				escape = false;
			}
			else if ch == "\\" {
				escape = true;
			}
			else if ch == "'" {
				in_char = false;
			}
			i += 1;
			continue;
		}
		if ch == "/" && next == "/" {
			out += "//";
			in_line = true;
			i += 2;
			continue;
		}
		if ch == "/" && next == "*" {
			out += "/*";
			in_block = true;
			i += 2;
			continue;
		}
		if ch == "\"" {
			out += ch;
			in_string = true;
			i += 1;
			continue;
		}
		if ch == "'" {
			out += ch;
			in_char = true;
			i += 1;
			continue;
		}
		if ch == "<" {
			out = out.trim_end();
			out += "<";
			i += 1;
			while i < raw.len() {
				let ws = raw.sub_string(i, 1);
				if ws == " " || ws == "\t" || ws == "\n" || ws == "\r" {
					i += 1;
				}
				else {
					break;
				}
			}
			continue;
		}
		if ch == "," {
			out = out.trim_end();
			out += ",";
			i += 1;
			while i < raw.len() {
				let ws = raw.sub_string(i, 1);
				if ws == " " || ws == "\t" || ws == "\n" || ws == "\r" {
					i += 1;
				}
				else {
					break;
				}
			}
			if i < raw.len() {
				let peek = raw.sub_string(i, 1);
				if peek != ">" {
					out += " ";
				}
			}
			continue;
		}
		if ch == ">" {
			out = out.trim_end();
			out += ">";
			i += 1;
			continue;
		}
		out += ch;
		i += 1;
	}
	out
}

fn text_type_arguments(node) {
	normalize_generic_text(slice(byte_range(node)))
}

fn text_type_parameters(node) {
	normalize_generic_text(slice(byte_range(node)))
}

fn text_generic_type(node) {
	let kids = node.children();
	if kids.len() == 0 {
		return slice(byte_range(node)).trim();
	}
	let out = "";
	let i = 0;
	while i < kids.len() {
		let child = kids[i];
		if child != () {
			let k = child.kind_id();
			if k == kinds::type_arguments {
				out = out.trim_end();
				out += normalize_generic_text(slice(byte_range(child)));
			}
			else {
				out += slice(byte_range(child));
			}
		}
		i += 1;
	}
	out.trim()
}

fn header_with_generic_text(node, end_pos) {
	let node_children = node.children();
	let cursor = start(byte_range(node));
	let out = "";
	let prev_kind = -1;
	let i = 0;
	while i < node_children.len() {
		let child = node_children[i];
		if child == () {
			i += 1;
			continue;
		}
		let r = byte_range(child);
		if start(r) >= end_pos {
			break;
		}
		let gap_had_ws = false;
		if cursor < start(r) {
			let gap = slice(range(cursor, start(r)));
			gap_had_ws = gap.len() > 0 && gap.trim().is_empty();
			if child.kind_id() == kinds::type_parameters {
				if prev_kind == kinds::identifier || prev_kind == kinds::type_identifier || prev_kind == kinds::scoped_identifier {
					// do not preserve space before class/interface/record type params
				}
				else if gap_had_ws {
					if !out.is_empty() && !out.ends_with(" ") && !out.ends_with("\t") {
						out += " ";
					}
				}
				else {
					out += gap;
				}
			}
			else {
				out += gap;
			}
		}
		let k = child.kind_id();
		if k == kinds::generic_type {
			out += text_generic_type(child);
		}
		else if k == kinds::type_parameters {
			if prev_kind != kinds::identifier && prev_kind != kinds::type_identifier && prev_kind != kinds::scoped_identifier {
				if !out.is_empty() && !out.ends_with(" ") && !out.ends_with("\t") {
					out += " ";
				}
			}
			out += text_type_parameters(child);
		}
		else {
			out += slice(r);
		}
		cursor = end(r);
		prev_kind = k;
		i += 1;
	}
	if cursor < end_pos {
		out += slice(range(cursor, end_pos));
	}
	out
}

fn has_anonymous_class_body(range) {
	if range == () {
		return false;
	}
	let matches = query(
		"java",
		"(object_creation_expression (class_body)) @o",
		range
	);
	let range_start = start(range);
	let range_end = end(range);
	for m in matches {
		let o = m.captures()
		["o"];
		if o == () {
			continue;
		}
		let r = byte_range(o);
		if start(r) < range_start || end(r) > range_end {
			continue;
		}
		return true;
	}
	false
}

fn split_enum_constants_text(body_text) {
	let text = body_text.trim();
	let inner = if text.starts_with("{") && text.ends_with("}") && text.len() >= 2 {
		text.sub_string(1, text.len() - 2)
	}
	else {
		text
	};
	let parts = [];
	let leading_blank_line = false;
	let start_idx = 0;
	let i = 0;
	let paren = 0;
	let brace = 0;
	while i < inner.len() {
		let ch = inner.sub_string(i, 1);
		if ch == "(" {
			paren += 1;
		}
		else if ch == ")" && paren > 0 {
			paren -= 1;
		}
		else if ch == "{" {
			brace += 1;
		}
		else if ch == "}" && brace > 0 {
			brace -= 1;
		}
		else if ch == "," && paren == 0 && brace == 0 {
			let seg = inner.sub_string(start_idx, i - start_idx).trim();
			if !seg.is_empty() {
				parts.push(seg);
			}
			start_idx = i + 1;
		}
		i += 1;
	}
	let tail = inner.sub_string(start_idx, inner.len() - start_idx).trim();
	if !tail.is_empty() {
		parts.push(tail);
	}
	parts
}

fn next_member_info(children, start_idx, k_lbrace, k_rbrace, k_line_comment, k_block_comment) {
	let idx = start_idx;
	let comment_start = -1;
	while idx < children.len {
		let k = children.kind(idx);
		if k == k_lbrace || k == k_rbrace {
			idx += 1;
			continue;
		}
		if k == k_line_comment || k == k_block_comment {
			if comment_start < 0 {
				comment_start = idx;
			}
			idx += 1;
			continue;
		}
		let member_idx = idx;
		let first_idx = if comment_start >= 0 {
			comment_start
		}
		else {
			member_idx
		};
		return [first_idx, member_idx];
	}
	[-1, -1]
}

fn group_for_kind(k, k_field, k_method, k_ctor, k_compact_ctor, k_class, k_interface, k_enum, k_record, k_anno, k_static_init, k_instance_init) {
	if k == k_field {
		1
	}
	else if k == k_method || k == k_ctor || k == k_compact_ctor {
		2
	}
	else if k == k_class || k == k_interface || k == k_enum || k == k_record || k == k_anno {
		3
	}
	else if k == k_static_init || k == k_instance_init {
		4
	}
	else {
		0
	}
}

fn leaf_tokens(node) {
	let out = [];
	let stack = [node];
	while stack.len() > 0 {
		let current = stack.pop();
		let kids = children(current);
		if kids.len() == 0 {
			out.push(current);
		}
		else {
			let i = kids.len() - 1;
			while i >= 0 {
				stack.push(kids[i]);
				if i == 0 {
					break;
				}
				i -= 1;
			}
		}
	}
	out
}

fn doc_for_boolean_operand(node, allow_wrap, indent_size, force_wrap) {
	if node == () {
		return doc_empty();
	}
	let k = node.kind_id();
	if k == kinds::parenthesized_expression {
		let doc = doc_for_node(node);
		if doc != () {
			return doc;
		}
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	let doc = doc_for_node(node);
	if doc != () {
		return doc;
	}
	let r = byte_range(node);
	doc_range(start(r), end(r))
}

fn root_wrap_should_wrap(node) {
	if node == () {
		return false;
	}
	let max_width = configuration::values["max_width"];
	if node_len(node) > max_width || node_is_multiline(node) {
		return true;
	}
	let parent = node.parent();
	let parent_first = if parent != () {
		first_line_text(text(parent))
	}
	else {
		()
	};
	if parent_first != () && parent_first.len() > max_width {
		return true;
	}
	let binary_node = if parent != () {
		parent.ancestor([kinds::binary_expression], #{ self: true })
	}
	else {
		()
	};
	let binary_first = if binary_node != () {
		first_line_text(text(binary_node))
	}
	else {
		()
	};
	if binary_first != () && binary_first.len() > max_width {
		return true;
	}
	let paren_node = if parent != () {
		parent.ancestor([kinds::parenthesized_expression], #{ self: true })
	}
	else {
		()
	};
	let paren_first = if paren_node != () {
		first_line_text(text(paren_node))
	}
	else {
		()
	};
	if paren_first != () && paren_first.len() > max_width {
		return true;
	}
	false
}

fn doc_for_boolean_binary(node, allow_wrap, indent_size, force_wrap) {
	let max_width = configuration::values["max_width"];
	let should_wrap = force_wrap || (allow_wrap && root_wrap_should_wrap(node));
	let parts = [];
	let ops = [];
	let current = node;
	while current != () && current.kind_id() == kinds::binary_expression {
		let kids = children(current);
		if kids == () || kids.len() == 0 {
			break;
		}
		let op_idx = -1;
		let op_text = "";
		let left = ();
		let right = ();
		let last_non_comment = ();
		let i = 0;
		while i < kids.len() {
			let child = kids[i];
			if child != () {
				let ck = child.kind_id();
				let is_comment = ck == kinds::line_comment || ck == kinds::block_comment;
				let is_op = ck == kinds::and_and || ck == kinds::or_or || ck == kinds::amp || ck == kinds::pipe || ck == kinds::caret;
				if !is_comment {
					if op_idx < 0 {
						if is_op {
							op_idx = i;
							op_text = slice(byte_range(child)).trim();
							left = last_non_comment;
						}
						else {
							last_non_comment = child;
						}
					}
					else if right == () && !is_op {
						right = child;
						break;
					}
				}
			}
			i += 1;
		}
		if op_idx < 0 {
			if ops.len() == 0 {
				let dbg = "";
				let di = 0;
				while di < kids.len() {
					let c = kids[di];
					if c != () {
						if !dbg.is_empty() {
							dbg = dbg + ",";
						}
						dbg = dbg + c.kind_id();
					}
					di += 1;
				}
				return doc_for_node_no_chain(node);
			}
			break;
		}
		if left == () || right == () {
			break;
		}
		let current_range = byte_range(current);
		let left_range = byte_range(left);
		if start(current_range) == start(left_range) && end(current_range) == end(left_range) {
			return doc_for_node_no_chain(node);
		}
		parts.push(right);
		ops.push(op_text);
		current = left;
	}
	parts.push(current);
	parts.reverse();
	ops.reverse();
	if parts.len() == 0 {
		return doc_empty();
	}
	let first_doc = doc_for_boolean_operand(parts[0], allow_wrap, indent_size, should_wrap);
	if ops.len() == 0 {
		return first_doc;
	}
	if should_wrap {
		let rest = [];
		let j = 0;
		while j < ops.len() {
			rest.push(doc_hardline());
			rest.push(doc_text(ops[j]));
			rest.push(doc_text(" "));
			rest.push(doc_for_boolean_operand(parts[j + 1], allow_wrap, indent_size, should_wrap));
			j += 1;
		}
		return doc_concat_list(
			[
				first_doc,
				doc_indent(indent_size, doc_concat_list(rest))
			]
		);
	}
	let out = [first_doc];
	let j = 0;
	while j < ops.len() {
		out.push(doc_text(" "));
		out.push(doc_text(ops[j]));
		out.push(doc_text(" "));
		out.push(doc_for_boolean_operand(parts[j + 1], allow_wrap, indent_size, should_wrap));
		j += 1;
	}
	doc_concat_list(out)
}

fn doc_for_boolean_expression(node, allow_wrap, indent_size, force_wrap) {
	if node == () {
		return doc_empty();
	}
	let k = node.kind_id();
	if k == kinds::binary_expression {
		return doc_for_boolean_binary(node, allow_wrap, indent_size, force_wrap);
	}
	doc_for_boolean_operand(node, allow_wrap, indent_size, force_wrap)
}

fn doc_for_node_no_chain(node) {
	if node == () {
		return doc_empty();
	}
	let doc = doc_for_node(node);
	if doc != () {
		return doc;
	}
	let r = byte_range(node);
	doc_range(start(r), end(r))
}

fn strip_incidental_ws_text_block(text) {
	let lines = text.split("\n");
	if lines.len() < 3 {
		return whitespace::strip_leading_ws(text);
	}
	let last = lines.len() - 1;
	let min_ws = whitespace::strip_incidental_ws_block(lines, 1, last - 1);
	let indent_style = configuration::values["indent_style"];
	let tab_width = configuration::values["tab_width"];
	let indent_unit = if indent_style == "spaces" {
		whitespace::repeat_str(" ", tab_width)
	}
	else {
		"\t"
	};
	let out_lines = [];
	let i = 0;
	while i < lines.len() {
		let line = lines[i];
		let trimmed = if i == 0 {
			whitespace::strip_leading_ws(line)
		}
		else if i == last {
			indent_unit + whitespace::strip_leading_ws(line)
		}
		else if min_ws > 0 && line.len() >= min_ws {
			line.sub_string(min_ws, line.len() - min_ws)
		}
		else {
			line
		};
		out_lines.push(trimmed);
		i += 1;
	}
	whitespace::join_lines(out_lines)
}

fn format_text_block(node) {
	let raw = text(node);
	let lines = raw.split("\n");
	if lines.len() < 3 {
		return whitespace::strip_leading_ws(raw);
	}
	let r = byte_range(node);
	let s = start(r);
	let line_info = line_at(s);
	let line_start = start_offset(line_info);
	let line_prefix = if line_start < s {
		slice(range(line_start, s))
	}
	else {
		""
	};
	let tab_width = configuration::values["tab_width"];
	let base_cols = whitespace::indent_cols_from_prefix(line_prefix, tab_width);
	let base_indent = whitespace::indent_string_from_cols(base_cols);
	let indent_unit = whitespace::indent_string_from_cols(tab_width.max(1));
	let content_indent = base_indent + indent_unit;
	let last = lines.len() - 1;
	let min_ws = whitespace::strip_incidental_ws_block(lines, 1, last - 1);
	let out_lines = [];
	let i = 0;
	while i < lines.len() {
		let line = lines[i];
		let trimmed = if i == 0 {
			whitespace::strip_leading_ws(line)
		}
		else if i == last {
			content_indent + whitespace::strip_leading_ws(line)
		}
		else if min_ws > 0 && line.len() >= min_ws {
			content_indent + line.sub_string(min_ws, line.len() - min_ws)
		}
		else {
			content_indent + line
		};
		out_lines.push(trimmed);
		i += 1;
	}
	whitespace::join_lines(out_lines)
}

fn doc_text_block(node) {
	let raw = text(node);
	let lines = raw.split("\n");
	if lines.len() < 2 {
		return doc_text(whitespace::strip_leading_ws(raw));
	}
	let last = lines.len() - 1;
	let min_ws = if last > 1 {
		whitespace::strip_incidental_ws_block(lines, 1, last - 1)
	}
	else {
		0
	};
	let content_parts = [];
	let i = 1;
	while i < last {
		let line = lines[i];
		let trimmed = if min_ws > 0 && line.len() >= min_ws {
			line.sub_string(min_ws, line.len() - min_ws)
		}
		else {
			line
		};
		content_parts.push(doc_text(trimmed));
		if i < last - 1 {
			content_parts.push(doc_hardline());
		}
		i += 1;
	}
	let closing = whitespace::strip_leading_ws(lines[last]);
	let inner_parts = [doc_hardline()];
	if content_parts.len() > 0 {
		inner_parts.push(doc_concat_list(content_parts));
		inner_parts.push(doc_hardline());
	}
	inner_parts.push(doc_text(closing));
	let tab_width = configuration::values["tab_width"];
	doc_concat_list([
		doc_text(first),
		doc_indent(tab_width, doc_concat_list(inner_parts))
	])
}

fn doc_text_block_from_text(raw) {
	let lines = raw.split("\n");
	if lines.len() < 2 {
		return doc_text(whitespace::strip_leading_ws(raw));
	}
	let first = whitespace::strip_leading_ws(lines[0]);
	let last = lines.len() - 1;
	let min_ws = if last > 1 {
		whitespace::strip_incidental_ws_block(lines, 1, last - 1)
	}
	else {
		0
	};
	let content_parts = [];
	let i = 1;
	while i < last {
		let line = lines[i];
		let trimmed = if min_ws > 0 && line.len() >= min_ws {
			line.sub_string(min_ws, line.len() - min_ws)
		}
		else {
			line
		};
		content_parts.push(doc_text(trimmed));
		if i < last - 1 {
			content_parts.push(doc_hardline());
		}
		i += 1;
	}
	let closing = whitespace::strip_leading_ws(lines[last]);
	let inner_parts = [doc_hardline()];
	if content_parts.len() > 0 {
		inner_parts.push(doc_concat_list(content_parts));
		inner_parts.push(doc_hardline());
	}
	inner_parts.push(doc_text(closing));
	let tab_width = configuration::values["tab_width"];
	doc_concat_list([
		doc_text(first),
		doc_indent(tab_width, doc_concat_list(inner_parts))
	])
}

fn doc_string_literal(node) {
	let literal_text = text(node);
	if literal_text.len() < 2 || literal_text.sub_string(0, 1) != "\"" || literal_text.sub_string(literal_text.len() - 1, 1) != "\"" {
		return doc_text(literal_text);
	}
	if literal_text.len() >= 3 && literal_text.sub_string(0, 3) == "\"\"\"" {
		return doc_text(literal_text);
	}
	let inner = literal_text.sub_string(1, literal_text.len() - 2);
	if inner.index_of("\\") >= 0 {
		return doc_text(literal_text);
	}
	if inner.index_of("\n") >= 0 || inner.index_of("\r") >= 0 {
		return doc_text(literal_text);
	}
	let tab_width = configuration::values["tab_width"];
	let max_width = configuration::values["max_width"];
	if inner.len() + 2 <= max_width {
		return doc_text(literal_text);
	}
	let r = byte_range(node);
	let line_info = line_at(start(r));
	let line_start = start_offset(line_info);
	let prefix = if start(r) > line_start {
		slice(range(line_start, start(r)))
	}
	else {
		""
	};
	let prefix_cols_raw = whitespace::text_cols(prefix, tab_width);
	let indent_levels = {
		let levels = 0;
		let p = node.parent();
		while p != () {
			let k = p.kind_id();
			if k == kinds::block || k == kinds::switch_block || k == kinds::class_body || k == kinds::enum_body {
				levels += 1;
			}
			p = p.parent();
		}
		levels
	};
	let base_cols = indent_levels * tab_width;
	let prefix_cols = base_cols + prefix_cols_raw;
	let first_max = max_width - prefix_cols - 2;
	if first_max < 1 {
		return doc_text(literal_text);
	}
	let cont_cols = base_cols + tab_width;
	let cont_max = max_width - cont_cols - 4;
	if cont_max < 1 {
		return doc_text(literal_text);
	}
	let parts = [];
	let remaining = inner;
	let first = true;
	while !remaining.is_empty() {
		let take = if first {
			first_max
		}
		else {
			cont_max
		};
		if remaining.len() <= take {
			parts.push(remaining);
			break;
		}
		let chunk = remaining.sub_string(0, take);
		parts.push(chunk);
		remaining = remaining.sub_string(take, remaining.len() - take);
		first = false;
	}
	if parts.len() <= 1 {
		return doc_text(literal_text);
	}
	let indent_size = tab_width;
	let doc = doc_text("\"" + parts[0] + "\"");
	let i = 1;
	while i < parts.len() {
		doc = doc_concat_list(
			[
				doc,
				doc_indent(
					indent_size,
					doc_concat_list(
						[
							doc_hardline(),
							doc_text("+ \"" + parts[i] + "\"")
						]
					)
				)
			]
		);
		i += 1;
	}
	doc
}
// Program-level assembly: preserve original gaps but insert a
// blank line between import groups, matching the old behavior.
fn doc_program(node, children)
{
	let k_import = kinds::import_declaration;
	if children.len == 0 {
		return doc_text(text(node));
	}
	let pieces = [];
	let node_range = byte_range(node);
	let cursor = start(node_range);
	let i = 0;
	while i < children.len {
		let child_range = children.range(i);
		if i == 0 {
			if cursor < start(child_range) {
				let gap = slice(range(cursor, start(child_range)));
				if gap.index_of("\n") >= 0 || gap.index_of("\r") >= 0 {
					pieces.push(doc_hardline());
				}
			}
		}
		else {
			let prev_kind = children.kind(i - 1);
			let next_kind = children.kind(i);
			if prev_kind == k_import && next_kind != k_import {
				pieces.push(doc_hardline());
				pieces.push(doc_hardline());
			}
			else {
				if cursor < start(child_range) {
					let gap = slice(range(cursor, start(child_range)));
					if gap.index_of("\n") >= 0 || gap.index_of("\r") >= 0 {
						pieces.push(doc_hardline());
					}
				}
			}
		}
		pieces.push(doc_for_child(children, i));
		cursor = end(child_range);
		i += 1;
	}
	if cursor < end(node_range) {
		let tail = slice(range(cursor, end(node_range)));
		if tail.index_of("\n") >= 0 || tail.index_of("\r") >= 0 {
			pieces.push(doc_hardline());
		}
	}
	doc_concat_list(pieces)
}
// Enum formatting: one constant per line when there is no body.
fn doc_enum_body(node, children)
{
	let k_enum_const = kinds::enum_constant;
	let body_text = text(node);
	let has_body_decls = false;
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::semi {
			has_body_decls = true;
			break;
		}
		i += 1;
	}
	if has_body_decls {
		return doc_text(body_text);
	}
	let constants = [];
	let inner_parts = [];
	let k = 0;
	while k < children.len {
		if children.kind(k) == k_enum_const {
			constants.push(children.range(k));
		}
		k += 1;
	}
	if constants.len() == 0 {
		return doc_text(body_text);
	}
	let constants_texts = [];
	let i = 0;
	while i < constants.len() {
		let constant_text = slice(constants[i]).trim();
		if !constant_text.is_empty() {
			inner_parts.push(doc_text(constant_text));
		}
		if i < constants.len() - 1 {
			inner_parts.push(doc_text(","));
			inner_parts.push(doc_hardline());
		}
		i += 1;
	}
	let indent_size = configuration::values["tab_width"];
	let parent = node.parent();
	if parent != () && parent.kind_id() == kinds::lambda_expression {
		indent_size = indent_size * 2;
	}
	let inner_doc = doc_indent(indent_size, doc_concat_list(inner_parts));
	doc_concat_list([
		doc_text("{"),
		doc_hardline(),
		inner_doc,
		doc_hardline(),
		doc_text("}")
	])
}

fn doc_for_child(children, idx) {
	let d = children.doc(idx);
	if d == () {
		let r = children.range(idx);
		return doc_range(start(r), end(r));
	}
	d
}

fn doc_for_child_or_build(parent, children, idx) {
	let d = children.doc(idx);
	if d != () {
		return d;
	}
	let node_children = children(parent);
	if node_children == () || idx < 0 || idx >= node_children.len() {
		return doc_empty();
	}
	let n = node_children[idx];
	if n == () {
		return doc_empty();
	}
	let cached = doc_for_node(n);
	if cached != () {
		return cached;
	}
	build_doc(n, children(n))
}

fn doc_operator_expression(node, children) {
	doc_operator_expression_inner(node, children, true)
}

fn doc_operator_expression_inner(node, children, allow_chain_split) {
	let op_ids = [
		kinds::assign,
		kinds::plus_assign,
		kinds::minus_assign,
		kinds::star_assign,
		kinds::slash_assign,
		kinds::percent_assign,
		kinds::shl_assign,
		kinds::shr_assign,
		kinds::ushr_assign,
		kinds::and_assign,
		kinds::or_assign,
		kinds::xor_assign,
		kinds::plus,
		kinds::minus,
		kinds::star,
		kinds::slash,
		kinds::percent,
		kinds::eq_eq,
		kinds::not_eq,
		kinds::lt,
		kinds::gt,
		kinds::lt_eq,
		kinds::gt_eq,
		kinds::and_and,
		kinds::or_or,
		kinds::amp,
		kinds::pipe,
		kinds::caret,
		kinds::shl,
		kinds::shr,
		kinds::ushr,
		kinds::kw_instanceof
	];
	let max_width = configuration::values["max_width"];
	let tab_width = configuration::values["tab_width"];
	let head = [];
	let tail = [];
	let i = 0;
	let wrap_plus = node_len(node) > max_width || node_is_multiline(node);
	let wrap_logic = node_len(node) > max_width || node_is_multiline(node);
	let indent_size = if wrap_logic && is_block_condition(node) {
		tab_width * 2
	}
	else {
		tab_width
	};
	let parent = node.parent();
	let parent_is_ternary = parent != () && parent.kind_id() == kinds::ternary_expression;
	let in_ternary = parent_is_ternary || has_ancestor_kind(node, kinds::ternary_expression);
	let allow_logic_wrap = wrap_logic && !in_ternary;
	let in_args = has_ancestor_kind(node, kinds::argument_list);
	let allow_plus_wrap = wrap_plus && !in_ternary && !in_args;
	if allow_logic_wrap && allow_chain_split && node.kind_id() == kinds::binary_expression {
		let kids = node.children();
		let has_logical = false;
		if kids != () {
			let i = 0;
			while i < kids.len() {
				let child = kids[i];
				if child != () {
					let ck = child.kind_id();
					if ck == kinds::and_and || ck == kinds::or_or || ck == kinds::amp || ck == kinds::pipe || ck == kinds::caret {
						has_logical = true;
						break;
					}
				}
				i += 1;
			}
		}
		if has_logical {
			return doc_for_boolean_expression(node, true, indent_size, false);
		}
	}
	let wrapped = false;
	while i < children.len {
		let k = children.kind(i);
		if op_ids.index_of(k) >= 0 {
			let op_text = slice(children.range(i)).trim();
			let should_wrap_op = (allow_plus_wrap && op_text == "+") || (allow_logic_wrap && (op_text == "&&" || op_text == "||" || op_text == "&" || op_text == "|" || op_text == "^"));
			if should_wrap_op {
				wrapped = true;
				tail.push(doc_hardline());
				tail.push(doc_text(op_text));
				tail.push(doc_text(" "));
			}
			else {
				if wrapped {
					tail.push(doc_text(" "));
					tail.push(doc_text(op_text));
					tail.push(doc_text(" "));
				}
				else {
					head.push(doc_text(" "));
					head.push(doc_text(op_text));
					head.push(doc_text(" "));
				}
			}
		}
		else {
			if wrapped {
				tail.push(doc_for_child(children, i));
			}
			else {
				head.push(doc_for_child(children, i));
			}
		}
		i += 1;
	}
	if wrapped {
		return doc_concat_list(
			[
				doc_concat_list(head),
				doc_indent(indent_size, doc_concat_list(tail))
			]
		);
	}
	doc_concat_list(head)
}

fn doc_method_invocation(node, children) {
	let k_args = kinds::argument_list;
	let args_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_args {
			args_idx = i;
			break;
		}
		i += 1;
	}
	if args_idx < 0 {
		return doc_text(text(node));
	}
	let max_width = configuration::values["max_width"];
	if children.len >= 4 && children.kind(1) == kinds::dot {
		let receiver_text = slice(children.range(0));
		let receiver_doc = doc_for_child_or_build(node, children, 0);
		let node_children = node.children();
		let name_text = {
			let out = "";
			let idx = 2;
			while idx < args_idx {
				let child = node_children[idx];
				if child != () {
					let k = child.kind_id();
					if k == kinds::type_arguments {
						out = out.trim_end();
						out += text_type_arguments(child);
					}
					else {
						out += slice(byte_range(child)).trim();
					}
				}
				idx += 1;
			}
			if out.is_empty() {
				slice(children.range(2)).trim()
			}
			else {
				out
			}
		};
		let args_doc = doc_for_child_or_build(node, children, args_idx);
		let parent = node.parent();
		let parent_is_invocation = parent != () && parent.kind_id() == kinds::method_invocation;
		let parent_is_field_access = parent != () && parent.kind_id() == kinds::field_access;
		let root = node.ancestor(
			[kinds::method_invocation],
			#{ self: true, furthest: true, allow: [kinds::method_invocation] }
		);
		if root == () {
			root = node;
		}
		let is_root = start(byte_range(root)) == start(byte_range(node)) && end(byte_range(root)) == end(byte_range(node));
		// TODO: this can be querying the same root a _lot_
		// if we ever add a cache, this is a hot path that should be immediately stored in cache
		let root_range = byte_range(root);
		let receiver_range = children.range(0);
		let receiver_kind = children.kind(0);
		let receiver_is_invocation = receiver_kind == kinds::method_invocation;
		let receiver_has_invocation = false;
		if !receiver_is_invocation && !parent_is_invocation && !parent_is_field_access && receiver_kind != kinds::identifier && receiver_kind != kinds::scoped_identifier {
			let receiver_start = start(receiver_range);
			let receiver_end = end(receiver_range);
			let receiver_inv_matches = query("java", "(method_invocation) @m", receiver_range);
			for m in receiver_inv_matches {
				let c = m.captures()
				["m"];
				if c == () {
					continue;
				}
				let r = byte_range(c);
				if start(r) < receiver_start || end(r) > receiver_end {
					continue;
				}
				let self_r = byte_range(node);
				let is_self = start(r) == start(self_r) && end(r) == end(self_r);
				if !is_self {
					receiver_has_invocation = true;
					break;
				}
			}
		}
		let receiver_is_identifier = receiver_kind == kinds::identifier || receiver_kind == kinds::scoped_identifier;
		let chain_context = receiver_is_invocation || parent_is_invocation || receiver_has_invocation || parent_is_field_access;
		let chain_has_invocation = receiver_is_invocation || parent_is_invocation || receiver_has_invocation || parent_is_field_access;
		let args_range = if args_idx >= 0 {
			children.range(args_idx)
		}
		else {
			()
		};
		let base_wrap = false;
		if chain_context {
			let chain_text = slice(root_range);
			let chain_len = root.token_len();
			let parent_len = if parent != () {
				parent.token_len()
			}
			else {
				()
			};
			let args_len = if args_idx >= 0 {
				node_children[args_idx].token_len()
			}
			else {
				()
			};
			let args_too_long = args_len != () && args_len > max_width;
			let binary_node = if parent != () {
				parent.ancestor([kinds::binary_expression], #{ self: true })
			}
			else {
				()
			};
			let binary_len = if binary_node != () {
				binary_node.token_len()
			}
			else {
				()
			};
			let binary_too_long = binary_len != () && binary_len > max_width;
			let paren_node = if parent != () {
				parent.ancestor([kinds::parenthesized_expression], #{ self: true })
			}
			else {
				()
			};
			let paren_len = if paren_node != () {
				paren_node.token_len()
			}
			else {
				()
			};
			let paren_too_long = paren_len != () && paren_len > max_width;
			base_wrap = chain_len > max_width || ((chain_text.index_of("\n") >= 0 || chain_text.index_of("\r") >= 0) && chain_has_invocation) || (parent_len != () && parent_len > max_width) || args_too_long || binary_too_long || paren_too_long;
		}
		let chain_lambda = false;
		let chain_has_class_body = false;
		if !base_wrap && chain_context && chain_has_invocation {
			let lambda_matches = query("java", "(lambda_expression) @l", root_range);
			let range_start = start(root_range);
			let range_end = end(root_range);
			for m in lambda_matches {
				let l = m.captures()
				["l"];
				if l == () {
					continue;
				}
				let r = byte_range(l);
				if start(r) >= range_start && end(r) <= range_end {
					chain_lambda = true;
					break;
				}
			}
			if !chain_lambda {
				chain_has_class_body = has_anonymous_class_body(root_range);
			}
		}
		let wrap_chain = base_wrap || (chain_has_invocation && (chain_lambda || chain_has_class_body));
		if parent_is_invocation && receiver_is_identifier {
			wrap_chain = false;
		}
		if wrap_chain {
			let indent_size = configuration::values["tab_width"];
			return doc_concat_list(
				[
					receiver_doc,
					doc_indent(
						indent_size,
						doc_concat_list(
							[
								doc_hardline(),
								doc_concat_list([doc_text("."), doc_text(name_text)]),
								args_doc
							]
						)
					)
				]
			);
		}
		return doc_concat_list(
			[
				receiver_doc,
				doc_text("."),
				doc_text(name_text),
				args_doc
			]
		);
	}
	let header = slice(range(start(byte_range(node)), start(children.range(args_idx)))).trim();
	let args_doc = doc_for_child_or_build(node, children, args_idx);
	doc_concat_list([doc_text(header), args_doc])
}

fn doc_lambda_expression(node, children) {
	let k_block = kinds::block;
	let k_arrow = kinds::arrow;
	let block_idx = -1;
	let arrow_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_block {
			block_idx = i;
			break;
		}
		if children.kind(i) == k_arrow {
			arrow_idx = i;
		}
		i += 1;
	}
	if block_idx < 0 {
		if arrow_idx >= 0 {
			let header = slice(range(start(byte_range(node)), start(children.range(arrow_idx)))).trim();
			let body_idx = -1;
			i = arrow_idx + 1;
			while i < children.len {
				let k = children.kind(i);
				if k != k_arrow {
					body_idx = i;
					break;
				}
				i += 1;
			}
			if body_idx >= 0 {
				let body_doc = doc_for_child_or_build(node, children, body_idx);
				return doc_concat_list([doc_text(header), doc_text(" -> "), body_doc]);
			}
		}
		return doc_text(text(node));
	}
	let header = slice(range(start(byte_range(node)), start(children.range(block_idx)))).trim();
	let block_doc = doc_for_child(children, block_idx);
	doc_concat_list([
		doc_text(header),
		doc_text(" "),
		block_doc
	])
}

fn doc_argument_list(node, children) {
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_comma = kinds::comma;
	let max_width = configuration::values["max_width"];
	let should_break = node_len(node) > max_width;
	if configuration::values["preserve_arg_newlines"] {
		should_break = should_break || node_is_multiline(node);
	}
	let args = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k != k_lparen && k != k_rparen && k != k_comma {
			args.push(doc_for_child_or_build(node, children, i));
		}
		i += 1;
	}
	if args.len() == 0 {
		return doc_text("()");
	}
	let parts = [];
	let j = 0;
	while j < args.len() {
		parts.push(args[j]);
		if j < args.len() - 1 {
			if should_break {
				parts.push(doc_text(","));
				parts.push(doc_hardline());
			}
			else {
				parts.push(doc_text(", "));
			}
		}
		j += 1;
	}
	if should_break {
		let indent_size = configuration::values["tab_width"];
		return doc_concat_list(
			[
				doc_text("("),
				doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)])),
				doc_hardline(),
				doc_text(")")
			]
		);
	}
	doc_concat_list([
		doc_text("("),
		doc_concat_list(parts),
		doc_text(")")
	])
}

fn doc_element_value_pair(node, children) {
	doc_text(normalize_element_value_pair_text(text(node)))
}

fn normalize_element_value_pair_text(raw) {
	let idx = raw.index_of("=");
	if idx < 0 {
		return raw.trim();
	}
	let left = raw.sub_string(0, idx).trim();
	let right = raw.sub_string(idx + 1, raw.len() - idx - 1).trim();
	left + " = " + right
}

fn doc_annotation_argument_list(node, force_break) {
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_comma = kinds::comma;
	let node_children = node.children();
	let args = [];
	let i = 0;
	while i < node_children.len() {
		let child = node_children[i];
		if child != () {
			let k = child.kind_id();
			if k != k_lparen && k != k_rparen && k != k_comma {
				if k == kinds::element_value_pair {
					args.push(doc_text(normalize_element_value_pair_text(text(child))));
				}
				else {
					let doc = doc_for_node(child);
					if doc != () {
						args.push(doc);
					}
					else {
						let r = byte_range(child);
						args.push(doc_range(start(r), end(r)));
					}
				}
			}
		}
		i += 1;
	}
	if args.len() == 0 {
		return doc_text("()");
	}
	let max_width = configuration::values["max_width"];
	let should_break = force_break || node_len(node) > max_width || node_is_multiline(node);
	if args.len() <= 1 {
		should_break = false;
	}
	if !should_break {
		let parts = [];
		let j = 0;
		while j < args.len() {
			parts.push(args[j]);
			if j < args.len() - 1 {
				parts.push(doc_text(", "));
			}
			j += 1;
		}
		return doc_concat_list(
			[
				doc_text("("),
				doc_concat_list(parts),
				doc_text(")")
			]
		);
	}
	let indent_size = configuration::values["tab_width"];
	let rest_parts = [];
	let j = 1;
	while j < args.len() {
		rest_parts.push(args[j]);
		if j < args.len() - 1 {
			rest_parts.push(doc_text(","));
			rest_parts.push(doc_hardline());
		}
		j += 1;
	}
	doc_concat_list([
		doc_text("("),
		args[0],
		doc_text(","),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(rest_parts)])),
		doc_text(")")
	])
}

fn doc_annotation(node, children) {
	let args_idx = -1;
	let node_children = node.children();
	let i = 0;
	while i < node_children.len() {
		let child = node_children[i];
		if child != () {
			let k = child.kind_id();
			if k == kinds::annotation_argument_list || k == kinds::argument_list {
				args_idx = i;
				break;
			}
		}
		i += 1;
	}
	if args_idx < 0 {
		return doc_text(text(node));
	}
	let args_node = node_children[args_idx];
	let header = slice(range(start(byte_range(node)), start(byte_range(args_node)))).trim();
	let args_text = text(args_node);
	let max_width = configuration::values["max_width"];
	let force_break = header.len() + args_text.len() > max_width;
	let args_doc = doc_annotation_argument_list(args_node, force_break);
	doc_concat_list([doc_text(header), args_doc])
}

fn doc_object_creation_expression(node, children) {
	let k_class_body = kinds::class_body;
	let class_body_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_class_body {
			class_body_idx = i;
			break;
		}
		i += 1;
	}
	if class_body_idx < 0 {
		return doc_text(text(node));
	}
	let header = slice(range(start(byte_range(node)), start(children.range(class_body_idx)))).trim();
	let class_body_doc = doc_for_child(children, class_body_idx);
	doc_concat_list([
		doc_text(header),
		doc_text(" "),
		class_body_doc
	])
}

fn doc_formal_parameters(node, children) {
	let raw = slice(byte_range(node));
	let k_dotdotdot = kinds::dotdotdot;
	let has_varargs = false;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_dotdotdot {
			has_varargs = true;
			break;
		}
		i += 1;
	}
	if has_varargs && raw.index_of(",") < 0 {
		return doc_text(whitespace::normalize_varargs(raw));
	}
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let k_comma = kinds::comma;
	let params = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k != k_lparen && k != k_rparen && k != k_comma {
			params.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if params.len() == 0 {
		return doc_text(raw.trim());
	}
	let max_width = configuration::values["max_width"];
	let should_break = node_len(node) > max_width || node_is_multiline(node);
	let parts = [];
	let j = 0;
	while j < params.len() {
		parts.push(params[j]);
		if j < params.len() - 1 {
			if should_break {
				parts.push(doc_text(","));
				parts.push(doc_hardline());
			}
			else {
				parts.push(doc_text(", "));
			}
		}
		j += 1;
	}
	if should_break {
		let indent_size = configuration::values["tab_width"];
		return doc_concat_list(
			[
				doc_text("("),
				doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)])),
				doc_text(")")
			]
		);
	}
	doc_concat_list([
		doc_text("("),
		doc_concat_list(parts),
		doc_text(")")
	])
}

fn doc_formal_parameters_with_indent(node, children_nodes, indent_size) {
	let raw = slice(byte_range(node));
	let k_dotdotdot = kinds::dotdotdot;
	let has_varargs = false;
	let i = 0;
	while i < children_nodes.len() {
		if children_nodes[i].kind_id() == k_dotdotdot {
			has_varargs = true;
			break;
		}
		i += 1;
	}
	if has_varargs && raw.index_of(",") < 0 {
		return doc_text(whitespace::normalize_varargs(raw));
	}
	let params = [];
	let i = 0;
	while i < children_nodes.len() {
		let child = children_nodes[i];
		let k = child.kind_id();
		if k != kinds::lparen && k != kinds::rparen && k != kinds::comma {
			let r = byte_range(child);
			params.push(doc_range(start(r), end(r)));
		}
		i += 1;
	}
	if params.len() == 0 {
		return doc_text(raw.trim());
	}
	let max_width = configuration::values["max_width"];
	let should_break = node_len(node) > max_width || node_is_multiline(node);
	let parts = [];
	let j = 0;
	while j < params.len() {
		parts.push(params[j]);
		if j < params.len() - 1 {
			if should_break {
				parts.push(doc_text(","));
				parts.push(doc_hardline());
			}
			else {
				parts.push(doc_text(", "));
			}
		}
		j += 1;
	}
	if should_break {
		return doc_concat_list(
			[
				doc_text("("),
				doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)])),
				doc_text(")")
			]
		);
	}
	doc_concat_list([
		doc_text("("),
		doc_concat_list(parts),
		doc_text(")")
	])
}

fn doc_formal_parameter(node, children) {
	let k_dotdotdot = kinds::dotdotdot;
	let node_children = node.children();
	let k_dotdotdot = kinds::dotdotdot;
	let has_varargs = false;
	let varargs_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_dotdotdot {
			has_varargs = true;
			varargs_idx = i;
			break;
		}
		i += 1;
	}
	let raw = if children.len > 0 {
		slice(range(start(children.range(0)), end(children.range(children.len - 1))))
	}
	else {
		text(node)
	};
	if has_varargs {
		let normalized = whitespace::normalize_varargs(raw);
		return doc_text(normalized.trim());
	}
	let parts = [];
	let leading_blank_line = false;
	let i = 0;
	let prev_kind = -1;
	let prev_idx = -1;
	while i < children.len {
		let k = children.kind(i);
		if parts.len() > 0 && prev_kind != k_dotdotdot && k != k_dotdotdot {
			let suppress_space = (varargs_idx == prev_idx) || (varargs_idx == i);
			if !suppress_space {
				parts.push(doc_text(" "));
			}
		}
		if node_children != () && i < node_children.len() && node_children[i] != () && node_children[i].kind_id() == kinds::generic_type {
			parts.push(doc_text(text_generic_type(node_children[i])));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		prev_kind = k;
		prev_idx = i;
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_ternary_expression(node, children) {
	let k_q = kinds::qmark;
	let k_colon = kinds::colon;
	let q_idx = -1;
	let colon_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_q {
			q_idx = i;
		}
		else if k == k_colon {
			colon_idx = i;
		}
		i += 1;
	}
	if q_idx < 0 || colon_idx < 0 {
		let parts = [];
		i = 0;
		while i < children.len {
			let k = children.kind(i);
			if k == k_q {
				parts.push(doc_text(" ? "));
			}
			else if k == k_colon {
				parts.push(doc_text(" : "));
			}
			else {
				parts.push(doc_for_child(children, i));
			}
			i += 1;
		}
		return doc_concat_list(parts);
	}
	let cond_idx = 0;
	let then_idx = -1;
	let else_idx = -1;
	i = q_idx + 1;
	while i < colon_idx {
		let k = children.kind(i);
		if k != k_q && k != k_colon {
			then_idx = i;
			break;
		}
		i += 1;
	}
	i = colon_idx + 1;
	while i < children.len {
		let k = children.kind(i);
		if k != k_q && k != k_colon {
			else_idx = i;
			break;
		}
		i += 1;
	}
	if then_idx < 0 || else_idx < 0 {
		let parts = [];
		i = 0;
		while i < children.len {
			let k = children.kind(i);
			if k == k_q {
				parts.push(doc_text(" ? "));
			}
			else if k == k_colon {
				parts.push(doc_text(" : "));
			}
			else {
				parts.push(doc_for_child(children, i));
			}
			i += 1;
		}
		return doc_concat_list(parts);
	}
	let raw = text(node);
	let max_width = configuration::values["max_width"];
	let tab_width = configuration::values["tab_width"];
	let r = byte_range(node);
	let line_info = line_at(start(r));
	let line_start = start_offset(line_info);
	let prefix = if start(r) > line_start {
		slice(range(line_start, start(r)))
	}
	else {
		()
	};
	let prefix_cols_raw = if prefix == () {
		0
	}
	else {
		whitespace::text_cols(prefix, tab_width)
	};
	let indent_levels = {
		let levels = 0;
		let p = node.parent();
		while p != () {
			let k = p.kind_id();
			if k == kinds::block || k == kinds::switch_block || k == kinds::class_body || k == kinds::enum_body {
				levels += 1;
			}
			p = p.parent();
		}
		levels
	};
	let prefix_cols = prefix_cols_raw + indent_levels * tab_width;
	let node_children = node.children();
	let cond_node = if cond_idx >= 0 && cond_idx < node_children.len() {
		node_children[cond_idx]
	}
	else {
		()
	};
	let cond_raw = slice(children.range(cond_idx)).trim();
	let logical_ops = {
		let count = 0;
		let current = cond_node;
		while current != () && current.kind_id() == kinds::binary_expression {
			let kids = children(current);
			if kids == () || kids.len() == 0 {
				break;
			}
			let op_idx = -1;
			let left = ();
			let last_non_comment = ();
			let i = 0;
			while i < kids.len() {
				let child = kids[i];
				if child != () {
					let ck = child.kind_id();
					let is_comment = ck == kinds::line_comment || ck == kinds::block_comment;
					let is_op = ck == kinds::and_and || ck == kinds::or_or || ck == kinds::amp || ck == kinds::pipe || ck == kinds::caret;
					if !is_comment {
						if op_idx < 0 {
							if is_op {
								op_idx = i;
								left = last_non_comment;
								break;
							}
							else {
								last_non_comment = child;
							}
						}
					}
				}
				i += 1;
			}
			if op_idx < 0 || left == () {
				break;
			}
			let current_range = byte_range(current);
			let left_range = byte_range(left);
			if start(current_range) == start(left_range) && end(current_range) == end(left_range) {
				break;
			}
			count += 1;
			current = left;
		}
		count
	};
	let should_break = cond_raw.index_of("\n") >= 0 || prefix_cols + cond_raw.len() > max_width || logical_ops >= 3;
	let cond_doc = if cond_node != () && cond_node.kind_id() == kinds::binary_expression {
		// TODO: may want to make this into a configuration parameter, the overall question is: do we want to force the boolean condition to wrap if the ternary is long?
		// i think if the boolean condition is short but the ternary is long, the boolean can remain on one line
		let force_wrap_ternary_condition = false;
		let force_wrap = should_break && force_wrap_ternary_condition;
		doc_for_boolean_expression(cond_node, true, tab_width * 2, force_wrap)
	}
	else if should_break {
		doc_text(cond_raw)
	}
	else {
		doc_for_child(children, cond_idx)
	};
	let then_doc = doc_for_child(children, then_idx);
	let else_doc = doc_for_child(children, else_idx);
	if !should_break {
		return doc_concat_list(
			[
				cond_doc,
				doc_text(" ? "),
				then_doc,
				doc_text(" : "),
				else_doc
			]
		);
	}
	let indent_size = tab_width;
	doc_concat_list([
		cond_doc,
		doc_indent(
			indent_size,
			doc_concat_list(
				[
					doc_hardline(),
					doc_text("? "),
					then_doc,
					doc_hardline(),
					doc_text(": "),
					else_doc
				]
			)
		)
	])
}

fn doc_parenthesized_expression(node, children) {
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let node_children = node.children();
	if node_children != () {
		let inner = ();
		let i = 0;
		while i < node_children.len() {
			let child = node_children[i];
			if child != () {
				let k = child.kind_id();
				if k != kinds::lparen && k != kinds::rparen {
					inner = child;
					break;
				}
			}
			i += 1;
		}
		if inner != () && inner.kind_id() == kinds::binary_expression {
			let tab_width = configuration::values["tab_width"];
			let indent_size = tab_width * 2;
			let inner_doc = doc_for_boolean_expression(inner, true, indent_size, false);
			return doc_concat_list([doc_text("("), inner_doc, doc_text(")")]);
		}
	}
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k != k_lparen && k != k_rparen {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if parts.len() == 0 {
		return doc_text("()");
	}
	let max_width = configuration::values["max_width"];
	let should_break = node_len(node) > max_width || node_is_multiline(node);
	if should_break && parts.len() > 1 {
		let indent_size = configuration::values["tab_width"];
		let first = parts[0];
		let rest = parts.slice(1, parts.len());
		return doc_concat_list(
			[
				doc_text("("),
				first,
				doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(rest)])),
				doc_text(")")
			]
		);
	}
	doc_concat_list([doc_text("("), doc_concat_list(parts), doc_text(")")])
}

fn doc_cast_expression(node, children) {
	let k_lparen = kinds::lparen;
	let k_rparen = kinds::rparen;
	let rparen_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_rparen {
			rparen_idx = i;
			break;
		}
		i += 1;
	}
	if rparen_idx < 0 {
		return doc_text(text(node));
	}
	let type_parts = [];
	i = 0;
	while i < rparen_idx {
		if children.kind(i) != k_lparen {
			type_parts.push(doc_for_child_or_build(node, children, i));
		}
		i += 1;
	}
	let expr_idx = -1;
	i = rparen_idx + 1;
	while i < children.len {
		let k = children.kind(i);
		if k != k_lparen && k != k_rparen {
			expr_idx = i;
			break;
		}
		i += 1;
	}
	if expr_idx < 0 {
		return doc_text(text(node));
	}
	doc_concat_list([
		doc_text("("),
		doc_concat_list(type_parts),
		doc_text(")"),
		doc_text(" "),
		doc_for_child_or_build(node, children, expr_idx)
	])
}

fn doc_expression_statement(children) {
	let k_semi = kinds::semi;
	let k_line_comment = kinds::line_comment;
	let parts = [];
	let i = 0;
	let inline_comment = ();
	if children.len > 1 {
		let last = children.len - 1;
		if children.kind(last) == k_line_comment {
			let gap = slice(range(end(children.range(last - 1)), start(children.range(last))));
			if gap.index_of("\n") < 0 && gap.index_of("\r") < 0 {
				inline_comment = children.doc(last);
			}
		}
	}
	while i < children.len {
		if i == children.len - 1 && inline_comment != () {
			i += 1;
			continue;
		}
		let k = children.kind(i);
		if k == k_semi {
			parts.push(doc_text(";"));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if inline_comment != () {
		parts.push(doc_text(" "));
		parts.push(inline_comment);
	}
	doc_concat_list(parts)
}

fn doc_return_statement(children) {
	let k_return = kinds::kw_return;
	let k_semi = kinds::semi;
	let parts = [];
	let i = 0;
	let saw_return = false;
	while i < children.len {
		let k = children.kind(i);
		if k == k_return {
			parts.push(doc_text("return"));
			saw_return = true;
		}
		else if k == k_semi {
			parts.push(doc_text(";"));
		}
		else {
			if saw_return {
				parts.push(doc_text(" "));
				saw_return = false;
			}
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_throw_statement(children) {
	let k_throw = kinds::kw_throw;
	let k_semi = kinds::semi;
	let parts = [];
	let i = 0;
	let saw_throw = false;
	while i < children.len {
		let k = children.kind(i);
		if k == k_throw {
			parts.push(doc_text("throw"));
			saw_throw = true;
		}
		else if k == k_semi {
			parts.push(doc_text(";"));
		}
		else {
			if saw_throw {
				parts.push(doc_text(" "));
				saw_throw = false;
			}
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_variable_declarator(children) {
	let k_assign = kinds::assign;
	let parts = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_assign {
			parts.push(doc_text(" = "));
		}
		else {
			let raw = slice(children.range(i));
			if raw.index_of("\"\"\"") >= 0 {
				parts.push(doc_text_block_from_text(raw));
			}
			else {
				parts.push(doc_for_child(children, i));
			}
		}
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_local_variable_declaration(node, children) {
	let k_semi = kinds::semi;
	let k_comma = kinds::comma;
	let node_children = node.children();
	let parts = [];
	let i = 0;
	let need_space = false;
	while i < children.len {
		let k = children.kind(i);
		if k == k_semi {
			parts.push(doc_text(";"));
			need_space = false;
			i += 1;
			continue;
		}
		if k == k_comma {
			parts.push(doc_text(", "));
			need_space = false;
			i += 1;
			continue;
		}
		if need_space {
			parts.push(doc_text(" "));
		}
		if node_children != () && i < node_children.len() && node_children[i] != () && node_children[i].kind_id() == kinds::generic_type {
			parts.push(doc_text(text_generic_type(node_children[i])));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		need_space = true;
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_field_or_variable_declaration(node, children) {
	let k_semi = kinds::semi;
	let k_comma = kinds::comma;
	let node_children = node.children();
	let parts = [];
	let i = 0;
	let need_space = false;
	while i < children.len {
		let k = children.kind(i);
		if k == k_semi {
			parts.push(doc_text(";"));
			need_space = false;
			i += 1;
			continue;
		}
		if k == k_comma {
			parts.push(doc_text(", "));
			need_space = false;
			i += 1;
			continue;
		}
		if need_space {
			parts.push(doc_text(" "));
		}
		if node_children != () && i < node_children.len() && node_children[i] != () && node_children[i].kind_id() == kinds::generic_type {
			parts.push(doc_text(text_generic_type(node_children[i])));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		need_space = true;
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_block(node, children) {
	let k_line_comment = kinds::line_comment;
	let k_block_comment = kinds::block_comment;
	let k_lbrace = kinds::lbrace;
	let k_rbrace = kinds::rbrace;
	let prefix_comment_doc = ();
	let force_one_line_comment = false;
	let block_range = byte_range(node);
	let block_start = start(block_range);
	let header_parent = node.parent();
	if prefix_comment_doc == () {
		while header_parent != () {
			let pk = header_parent.kind_id();
			let header_kind = pk == kinds::if_statement || pk == kinds::for_statement || pk == kinds::enhanced_for_statement || pk == kinds::while_statement || pk == kinds::do_statement || pk == kinds::synchronized_statement || pk == kinds::switch_statement || pk == kinds::switch_expression || pk == kinds::try_statement || pk == kinds::try_with_resources_statement || pk == kinds::catch_clause || pk == kinds::finally_clause;
			if header_kind {
				let parent_children = children(header_parent);
				let block_idx = -1;
				let i = 0;
				while i < parent_children.len() {
					let r = byte_range(parent_children[i]);
					if start(r) == block_start && end(r) == end(block_range) {
						block_idx = i;
						break;
					}
					i += 1;
				}
				if block_idx > 0 {
					let keyword = header_keyword(pk);
					if prefix_comment_doc == () && keyword >= 0 {
						let inline_doc = inline_comment_from_keyword_gap(parent_children, keyword, block_idx);
						if inline_doc != () {
							prefix_comment_doc = inline_doc;
							force_one_line_comment = true;
						}
					}
					let prev_idx = block_idx - 1;
					while prev_idx >= 0 {
						let k = parent_children[prev_idx].kind_id();
						if k != kinds::line_comment && k != kinds::block_comment {
							break;
						}
						if prev_idx == 0 {
							prev_idx = -1;
							break;
						}
						prev_idx -= 1;
					}
					if prev_idx >= 0 {
						let header_end = end(byte_range(parent_children[prev_idx]));
						if header_end < block_start {
							let gap = slice(range(header_end, block_start));
							let inline_comment_doc = comment_helpers::inline_comment_doc_from_gap(gap);
							if inline_comment_doc == () {
								inline_comment_doc = comment_helpers::inline_comment_doc_between("java", header_end, start(block_range));
							}
							if inline_comment_doc != () {
								prefix_comment_doc = inline_comment_doc;
								force_one_line_comment = true;
							}
						}
					}
				}
				break;
			}
			header_parent = header_parent.parent();
		}
	}
	if prefix_comment_doc == () {
		let parent = node.parent();
		if parent != () && parent.kind_id() == kinds::statement {
			let parent_children = children(parent);
			let block_idx = -1;
			let i = 0;
			while i < parent_children.len() {
				let r = byte_range(parent_children[i]);
				if start(r) == block_start && end(r) == end(block_range) {
					block_idx = i;
					break;
				}
				i += 1;
			}
			if block_idx > 0 {
				let prev_idx = block_idx - 1;
				while prev_idx >= 0 {
					let k = parent_children[prev_idx].kind_id();
					if k != kinds::line_comment && k != kinds::block_comment {
						break;
					}
					if prev_idx == 0 {
						prev_idx = -1;
						break;
					}
					prev_idx -= 1;
				}
				if prev_idx >= 0 {
					let header_end = end(byte_range(parent_children[prev_idx]));
					if header_end < start(block_range) {
						let gap = slice(range(header_end, start(block_range)));
						let inline_comment_doc = comment_helpers::inline_comment_doc_from_gap(gap);
						if inline_comment_doc == () {
							inline_comment_doc = comment_helpers::inline_comment_doc_between("java", header_end, start(block_range));
						}
						if inline_comment_doc != () {
							prefix_comment_doc = inline_comment_doc;
							force_one_line_comment = true;
						}
						else if pk == kinds::catch_clause {
							let alt_doc = comment_helpers::inline_comment_doc_between(
								"java",
								start(byte_range(header_parent)),
								block_start
							);
							if alt_doc != () {
								prefix_comment_doc = alt_doc;
								force_one_line_comment = true;
							}
							else {
								let prefix_gap = slice(range(start(byte_range(header_parent)), block_start));
								let alt_inline = comment_helpers::inline_comment_doc_from_gap(prefix_gap);
								if alt_inline != () {
									prefix_comment_doc = alt_inline;
									force_one_line_comment = true;
								}
								else if block_start > 0 {
									let prev_line = line_at(block_start - 1);
									let prev_text = line_text(prev_line);
									let line_idx = prev_text.index_of("//");
									if line_idx >= 0 {
										let raw = prev_text.sub_string(line_idx + 2, prev_text.len() - line_idx - 2).trim();
										let comment_doc = if raw.is_empty() {
											doc_text("//")
										}
										else {
											doc_text("// " + raw)
										};
										prefix_comment_doc = comment_doc;
										force_one_line_comment = true;
									}
								}
							}
						}
					}
				}
			}
		}
	}
	let brace_idx = -1;
	let first_content_idx = -1;
	let prefix_inline_idx = -1;
	let scan = 0;
	while scan < children.len {
		let k = children.kind(scan);
		if k == k_lbrace && brace_idx < 0 {
			brace_idx = scan;
		}
		if k != k_lbrace && k != k_rbrace && first_content_idx < 0 {
			first_content_idx = scan;
		}
		scan += 1;
	}
	if prefix_comment_doc == () && brace_idx >= 0 {
		let scan = brace_idx - 1;
		while scan >= 0 {
			let k = children.kind(scan);
			if k == k_line_comment || k == k_block_comment {
				let gap = slice(range(end(children.range(scan)), start(children.range(brace_idx))));
				if gap.trim()
					.is_empty() {
					prefix_comment_doc = doc_for_child(children, scan);
					force_one_line_comment = true;
					prefix_inline_idx = scan;
				}
				break;
			}
			if k != k_lbrace && k != k_rbrace {
				break;
			}
			scan -= 1;
		}
	}
	let inline_comment_idx = -1;
	if brace_idx >= 0 && first_content_idx >= 0 {
		let fk = children.kind(first_content_idx);
		if fk == k_line_comment || fk == k_block_comment {
			let gap = slice(range(end(children.range(brace_idx)), start(children.range(first_content_idx))));
			if gap.index_of("\n") < 0 && gap.index_of("\r") < 0 {
				inline_comment_idx = first_content_idx;
			}
		}
	}
	if inline_comment_idx >= 0 && prefix_comment_doc == () {
		prefix_comment_doc = doc_for_child(children, inline_comment_idx);
		force_one_line_comment = true;
		prefix_inline_idx = inline_comment_idx;
	}
	if prefix_comment_doc == () {
		let line_info = line_at(block_start);
		let line_end = end_offset(line_info);
		if line_end > block_start {
			let inline_doc = comment_helpers::inline_comment_doc_between("java", block_start, line_end);
			if inline_doc != () {
				prefix_comment_doc = inline_doc;
				force_one_line_comment = true;
			}
		}
	}
	let parts = [];
	let leading_blank_line = false;
	let i = 0;
	let prev_range = ();
	while i < children.len {
		let k = children.kind(i);
		if k != k_lbrace && k != k_rbrace {
			if i == inline_comment_idx || i == prefix_inline_idx {
				i += 1;
				continue;
			}
			if k == k_line_comment && prev_range != () {
				let gap = slice(range(end(prev_range), start(children.range(i))));
				if gap.index_of("\n") < 0 && gap.index_of("\r") < 0 {
					parts.push(doc_text(" "));
					parts.push(doc_for_child(children, i));
					prev_range = children.range(i);
					i += 1;
					continue;
				}
			}
			if parts.len() > 0 {
				if prev_range != () {
					let gap = slice(range(end(prev_range), start(children.range(i))));
					if gap.index_of("\n\n\n") >= 0 || gap.index_of("\r\n\r\n\r\n") >= 0 {
						parts.push(doc_text("\n\n"));
					}
					else if gap.index_of("\n\n") >= 0 || gap.index_of("\r\n\r\n") >= 0 {
						parts.push(doc_text("\n"));
					}
				}
				parts.push(doc_hardline());
			}
			else if prev_range == () && brace_idx >= 0 && i == first_content_idx {
				let gap = slice(range(end(children.range(brace_idx)), start(children.range(i))));
				if gap.index_of("\n\n") >= 0 || gap.index_of("\r\n\r\n") >= 0 {
					leading_blank_line = true;
				}
			}
			parts.push(doc_for_child(children, i));
			prev_range = children.range(i);
		}
		i += 1;
	}
	let indent_size = configuration::values["tab_width"];
	let extra_lambda_indent = false;
	let p = node.parent();
	let steps = 0;
	while p != () && steps < 5 {
		if p.kind_id() == kinds::lambda_expression {
			let inv = p.parent();
			while inv != () && inv.kind_id() != kinds::method_invocation {
				inv = inv.parent();
			}
			if inv != () && children(inv).len() > 0 {
				let recv_kind = children(inv)
				[0].kind_id();
				let recv_is_invocation = recv_kind == kinds::method_invocation;
				let recv_is_identifier = recv_kind == kinds::identifier || recv_kind == kinds::scoped_identifier;
				let inv_start = start(byte_range(inv));
				let line_info = line_at(inv_start);
				let line_start = start_offset(line_info);
				let prefix = if inv_start > line_start {
					slice(range(line_start, inv_start))
				}
				else {
					()
				};
				let line_start_invocation = prefix == () || prefix.trim().is_empty();
				let inv_parent = inv.parent();
				let inv_parent_is_invocation = inv_parent != () && inv_parent.kind_id() == kinds::method_invocation;
				if !recv_is_invocation && recv_is_identifier && line_start_invocation && inv_parent_is_invocation {
					indent_size = indent_size + configuration::values["tab_width"];
					extra_lambda_indent = true;
				}
			}
			break;
		}
		p = p.parent();
		steps += 1;
	}
	let closing = if extra_lambda_indent {
		let indent_style = configuration::values["indent_style"];
		let tab_width = configuration::values["tab_width"];
		let indent_str = if indent_style == "spaces" {
			whitespace::repeat_str(" ", tab_width)
		}
		else {
			"\t"
		};
		doc_text(indent_str + "}")
	}
	else {
		doc_text("}")
	};
	if prefix_comment_doc != () {
		if force_one_line_comment {
			if parts.len() == 0 {
				return doc_concat_list(
					[
						doc_text("{"),
						doc_text(" "),
						prefix_comment_doc,
						doc_hardline(),
						closing
					]
				);
			}
			let inner = doc_concat_list(parts);
			return doc_concat_list(
				[
					doc_text("{"),
					doc_text(" "),
					prefix_comment_doc,
					doc_indent(indent_size, doc_concat_list([doc_hardline(), inner])),
					doc_hardline(),
					closing
				]
			);
		}
		if parts.len() == 0 {
			return doc_concat_list(
				[
					doc_text("{"),
					doc_text(" "),
					prefix_comment_doc,
					doc_hardline(),
					closing
				]
			);
		}
		let inner = doc_concat_list(parts);
		return doc_concat_list(
			[
				doc_text("{"),
				doc_text(" "),
				prefix_comment_doc,
				doc_indent(indent_size, doc_concat_list([doc_hardline(), inner])),
				doc_hardline(),
				closing
			]
		);
	}
	if inline_comment_idx >= 0 {
		let comment_doc = doc_for_child(children, inline_comment_idx);
		if parts.len() == 0 {
			return doc_concat_list(
				[
					doc_text("{"),
					doc_text(" "),
					comment_doc,
					doc_hardline(),
					closing
				]
			);
		}
		let inner = doc_concat_list(parts);
		return doc_concat_list(
			[
				doc_text("{"),
				doc_text(" "),
				comment_doc,
				doc_indent(indent_size, doc_concat_list([doc_hardline(), inner])),
				doc_hardline(),
				closing
			]
		);
	}
	if parts.len() == 0 {
		return doc_concat_list(
			[
				doc_text("{"),
				doc_hardline(),
				closing
			]
		);
	}
	let inner = doc_concat_list(parts);
	if leading_blank_line {
		return doc_concat_list(
			[
				doc_text("{"),
				doc_hardline(),
				doc_indent(indent_size, doc_concat_list([doc_hardline(), inner])),
				doc_hardline(),
				closing
			]
		);
	}
	doc_concat_list([
		doc_text("{"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), inner])),
		doc_hardline(),
		closing
	])
}

fn doc_method_like(node, children, body_capture) {
	let k_formal_params = kinds::formal_parameters;
	let k_block = kinds::block;
	let body_idx = -1;
	let params_idx = -1;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_block {
			body_idx = i;
			break;
		}
		if k == k_formal_params {
			params_idx = i;
		}
		i += 1;
	}
	if body_idx < 0 {
		return doc_text(text(node));
	}
	if params_idx < 0 {
		let header = header_with_generic_text(node, start(children.range(body_idx))).trim();
		let body_doc = doc_for_child(children, body_idx);
		return doc_concat_list(
			[
				doc_text(header),
				doc_text(" "),
				body_doc
			]
		);
	}
	let header_prefix = header_with_generic_text(node, start(children.range(params_idx))).trim();
	let max_width = configuration::values["max_width"];
	let tab_width = configuration::values["tab_width"];
	let node_children = node.children();
	let params_node = if params_idx >= 0 && params_idx < node_children.len() {
		node_children[params_idx]
	}
	else {
		()
	};
	let params_children = if params_node == () {
		[]
	}
	else {
		children(params_node)
	};
	let params_doc = if header_prefix.index_of("\n") >= 0 || header_prefix.index_of("\r") >= 0 {
		doc_formal_parameters_with_indent(params_node, params_children, tab_width * 2)
	}
	else {
		doc_for_child(children, params_idx)
	};
	let header_suffix = slice(range(end(children.range(params_idx)), start(children.range(body_idx))))
		.trim();
	let body_doc = doc_for_child(children, body_idx);
	let header_docs = [];
	if header_prefix.index_of("@") >= 0 {
		let modifiers_node = ();
		let mi = 0;
		while mi < node_children.len() {
			let child = node_children[mi];
			if child != () && child.kind_id() == kinds::modifiers {
				modifiers_node = child;
				break;
			}
			mi += 1;
		}
		if modifiers_node != () {
			let mod_children = children(modifiers_node);
			let annotation_docs = [];
			let modifier_words = [];
			let i = 0;
			while i < mod_children.len() {
				let child = mod_children[i];
				if child != () {
					let k = child.kind_id();
					if k == kinds::annotation || k == kinds::marker_annotation {
						let doc = doc_for_node(child);
						if doc != () {
							annotation_docs.push(doc);
						}
						else {
							let r = byte_range(child);
							annotation_docs.push(doc_range(start(r), end(r)));
						}
					}
					else {
						let text = text(child).trim();
						if !text.is_empty() {
							modifier_words.push(text);
						}
					}
				}
				i += 1;
			}
			if annotation_docs.len() > 0 {
				let rest_text = slice(range(end(byte_range(modifiers_node)), start(children.range(params_idx)))).trim();
				let modifier_text = "";
				let mi = 0;
				while mi < modifier_words.len() {
					if mi > 0 {
						modifier_text += " ";
					}
					modifier_text += modifier_words[mi];
					mi += 1;
				}
				let header_line = if modifier_text.is_empty() {
					rest_text
				}
				else if rest_text.is_empty() {
					modifier_text
				}
				else {
					modifier_text + " " + rest_text
				};
				let j = 0;
				while j < annotation_docs.len() {
					if j > 0 {
						header_docs.push(doc_hardline());
					}
					header_docs.push(annotation_docs[j]);
					j += 1;
				}
				if !header_line.is_empty() {
					header_docs.push(doc_hardline());
					header_docs.push(doc_text(header_line));
				}
				let header_parts = [doc_concat_list(header_docs), params_doc];
				if !header_suffix.is_empty() {
					header_parts.push(doc_text(" "));
					header_parts.push(doc_text(header_suffix));
				}
				return doc_concat_list(
					[
						doc_concat_list(header_parts),
						doc_text(" "),
						body_doc
					]
				);
			}
		}
	}
	if header_docs.len() > 0 {
		let header_parts = [doc_concat_list(header_docs), params_doc];
		if !header_suffix.is_empty() {
			header_parts.push(doc_text(" "));
			header_parts.push(doc_text(header_suffix));
		}
		return doc_concat_list(
			[
				doc_concat_list(header_parts),
				doc_text(" "),
				body_doc
			]
		);
	}
	if header_prefix.index_of("\n") >= 0 || header_prefix.index_of("\r") >= 0 {
		let raw_lines = header_prefix.split("\n");
		let lines = [];
		let li = 0;
		while li < raw_lines.len() {
			let line = raw_lines[li];
			let trimmed = whitespace::strip_leading_ws(line);
			let trimmed = if trimmed.ends_with("\r") {
				trimmed.sub_string(0, trimmed.len() - 1)
			}
			else {
				trimmed
			};
			if trimmed.starts_with("=") || trimmed.starts_with(",") {
				if lines.len() > 0 {
					lines[lines.len() - 1] = lines[lines.len() - 1] + " " + trimmed;
					li += 1;
					continue;
				}
			}
			lines.push(line);
			li += 1;
		}
		let i = 0;
		while i < lines.len() {
			let line = lines[i];
			if line.ends_with("\r") {
				line = line.sub_string(0, line.len() - 1);
			}
			let cleaned = whitespace::strip_leading_ws(line);
			let line_doc = {
				let trimmed = cleaned.trim();
				let annotation_doc = ();
				if trimmed.starts_with("@") && trimmed.len() > max_width {
					let open_idx = trimmed.index_of("(");
					let close_idx = last_index_of(trimmed, ")");
					if open_idx >= 0 && close_idx > open_idx {
						let inner = trimmed.sub_string(open_idx + 1, close_idx - open_idx - 1);
						if inner.index_of(",") >= 0 {
							let parts = inner.split(", ");
							if parts.len() > 1 {
								let prefix = trimmed.sub_string(0, open_idx + 1);
								let rest_docs = [];
								let j = 1;
								while j < parts.len() {
									let part = parts[j];
									let text = if j == parts.len() - 1 {
										part + ")"
									}
									else {
										part + ","
									};
									rest_docs.push(doc_text(text));
									if j < parts.len() - 1 {
										rest_docs.push(doc_hardline());
									}
									j += 1;
								}
								annotation_doc = doc_concat_list(
									[
										doc_text(prefix + parts[0] + ","),
										doc_indent(tab_width, doc_concat_list([doc_hardline(), doc_concat_list(rest_docs)]))
									]
								);
							}
						}
					}
				}
				if annotation_doc != () {
					annotation_doc
				}
				else {
					doc_text(trimmed)
				}
			};
			let split_idx = -1;
			let trimmed_line = cleaned.trim();
			if trimmed_line.starts_with("@") {
				let close_idx = last_index_of(trimmed_line, ")");
				if close_idx >= 0 {
					let rest = trimmed_line.sub_string(close_idx + 1, trimmed_line.len() - close_idx - 1).trim();
					if !rest.is_empty() {
						let rest_lower = rest;
						if rest_lower.starts_with("public ") || rest_lower.starts_with("protected ") || rest_lower.starts_with("private ") || rest_lower.starts_with("static ") || rest_lower.starts_with("final ") || rest_lower.starts_with("abstract ") {
							split_idx = close_idx + 1;
						}
					}
				}
				else {
					let space_idx = trimmed_line.index_of(" ");
					if space_idx > 0 {
						split_idx = space_idx;
					}
				}
			}
			if split_idx > 0 {
				let anno_text = trimmed_line.sub_string(0, split_idx).trim();
				let rest_text = trimmed_line.sub_string(split_idx + 1, trimmed_line.len() - split_idx - 1).trim();
				let anno_doc = doc_text(anno_text);
				if i > 0 {
					header_docs.push(doc_hardline());
				}
				header_docs.push(anno_doc);
				if !rest_text.is_empty() {
					header_docs.push(doc_hardline());
					header_docs.push(doc_text(rest_text));
				}
			}
			else {
				if i > 0 {
					header_docs.push(doc_hardline());
				}
				header_docs.push(line_doc);
			}
			i += 1;
		}
	}
	else {
		let trimmed_line = header_prefix.trim();
		if trimmed_line.starts_with("@") {
			let split_idx = -1;
			let close_idx = last_index_of(trimmed_line, ")");
			if close_idx >= 0 {
				let rest = trimmed_line.sub_string(close_idx + 1, trimmed_line.len() - close_idx - 1).trim();
				if !rest.is_empty() {
					let rest_lower = rest;
					if rest_lower.starts_with("public ") || rest_lower.starts_with("protected ") || rest_lower.starts_with("private ") || rest_lower.starts_with("static ") || rest_lower.starts_with("final ") || rest_lower.starts_with("abstract ") {
						split_idx = close_idx + 1;
					}
				}
			}
			else {
				let space_idx = trimmed_line.index_of(" ");
				if space_idx > 0 {
					split_idx = space_idx;
				}
			}
			if split_idx > 0 {
				let anno_text = trimmed_line.sub_string(0, split_idx).trim();
				let rest_text = trimmed_line.sub_string(split_idx + 1, trimmed_line.len() - split_idx - 1).trim();
				header_docs.push(doc_text(anno_text));
				if !rest_text.is_empty() {
					header_docs.push(doc_hardline());
					header_docs.push(doc_text(rest_text));
				}
			}
			else {
				header_docs.push(doc_text(header_prefix));
			}
		}
		else {
			header_docs.push(doc_text(header_prefix));
		}
	}
	let header_parts = [doc_concat_list(header_docs), params_doc];
	if !header_suffix.is_empty() {
		header_parts.push(doc_text(" "));
		header_parts.push(doc_text(header_suffix));
	}
	doc_concat_list([
		doc_concat_list(header_parts),
		doc_text(" "),
		body_doc
	])
}

fn doc_class_like(node, children) {
	let k_class_body = kinds::class_body;
	let body_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_class_body {
			body_idx = i;
			break;
		}
		i += 1;
	}
	if body_idx < 0 {
		return doc_text(text(node));
	}
	let header = header_with_generic_text(node, start(children.range(body_idx))).trim();
	let body_doc = doc_for_child(children, body_idx);
	doc_concat_list([
		doc_text(header),
		doc_text(" "),
		body_doc
	])
}

fn doc_enum_declaration(node, children) {
	let k_enum_body = kinds::enum_body;
	let k_enum_const = kinds::enum_constant;
	let body_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_enum_body {
			body_idx = i;
			break;
		}
		i += 1;
	}
	if body_idx < 0 {
		return doc_text(text(node));
	}
	let header = header_with_generic_text(node, start(children.range(body_idx))).trim();
	let node_children = node.children();
	if node_children == () || body_idx < 0 || body_idx >= node_children.len() {
		return doc_text(text(node));
	}
	let body_node = node_children[body_idx];
	let body_children = children(body_node);
	if body_children == () {
		return doc_text(text(node));
	}
	let has_body_decls = false;
	i = 0;
	while i < body_children.len() {
		if body_children[i].kind_id() == kinds::semi {
			has_body_decls = true;
			break;
		}
		i += 1;
	}
	if has_body_decls {
		return doc_text(text(node));
	}
	let constants = [];
	let constants_texts = [];
	let body_range = byte_range(body_node);
	let matches = query("java", "(enum_constant) @c", body_range);
	for m in matches {
		let c = m.captures()
		["c"];
		if c == () {
			continue;
		}
		constants.push(byte_range(c));
	}
	if constants.len() == 0 {
		return doc_text(text(node));
	}
	let j = 0;
	while j < constants.len() {
		let constant_text = slice(constants[j]).trim();
		if !constant_text.is_empty() {
			if j < constants.len() - 1 {
				constants_texts.push(constant_text + ",");
			}
			else {
				constants_texts.push(constant_text);
			}
		}
		j += 1;
	}
	let indent_style = configuration::values["indent_style"];
	let tab_width = configuration::values["tab_width"];
	let indent_str = if indent_style == "spaces" {
		whitespace::repeat_str(" ", tab_width)
	}
	else {
		"\t"
	};
	let body_parts = [doc_text("{"), doc_hardline()];
	let j = 0;
	while j < constants_texts.len() {
		let text = constants_texts[j];
		if j > 0 {
			body_parts.push(doc_hardline());
		}
		body_parts.push(doc_text(indent_str + text));
		j += 1;
	}
	body_parts.push(doc_hardline());
	body_parts.push(doc_text("}"));
	let body_doc = doc_concat_list(body_parts);
	doc_concat_list([
		doc_text(header),
		doc_text(" "),
		body_doc
	])
}

fn doc_class_body(node, children) {
	let k_lbrace = kinds::lbrace;
	let k_rbrace = kinds::rbrace;
	let k_line_comment = kinds::line_comment;
	let k_block_comment = kinds::block_comment;
	let k_field = kinds::field_declaration;
	let k_method = kinds::method_declaration;
	let k_ctor = kinds::constructor_declaration;
	let k_compact_ctor = kinds::compact_constructor_declaration;
	let k_class = kinds::class_declaration;
	let k_interface = kinds::interface_declaration;
	let k_enum = kinds::enum_declaration;
	let k_record = kinds::record_declaration;
	let k_anno = kinds::annotation_type_declaration;
	let k_static_init = kinds::static_initializer;
	let k_instance_init = kinds::instance_initializer;
	let parts = [];
	let last_member_idx = -1;
	let scan = 0;
	while scan < children.len {
		let k = children.kind(scan);
		if k != k_lbrace && k != k_rbrace && k != k_line_comment && k != k_block_comment {
			last_member_idx = scan;
		}
		scan += 1;
	}
	let prev_group = 0;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == k_lbrace || k == k_rbrace {
			i += 1;
			continue;
		}
		let group = group_for_kind(
			k,
			k_field,
			k_method,
			k_ctor,
			k_compact_ctor,
			k_class,
			k_interface,
			k_enum,
			k_record,
			k_anno,
			k_static_init,
			k_instance_init
		);
		if (k == k_line_comment || k == k_block_comment) {
			let next_info = next_member_info(children, i + 1, k_lbrace, k_rbrace, k_line_comment, k_block_comment);
			let comment_start = next_info[0];
			let member_idx = next_info[1];
			if comment_start >= 0 && member_idx >= 0 && comment_start == i {
				let member_k = children.kind(member_idx);
				let next_group = group_for_kind(
					member_k,
					k_field,
					k_method,
					k_ctor,
					k_compact_ctor,
					k_class,
					k_interface,
					k_enum,
					k_record,
					k_anno,
					k_static_init,
					k_instance_init
				);
				if prev_group != 0 && next_group != 0 && prev_group != next_group {
					parts.push(doc_hardline());
				}
				let j = comment_start;
				while j < member_idx {
					parts.push(doc_for_child(children, j));
					j += 1;
				}
				parts.push(doc_for_child(children, member_idx));
				if next_group != 0 {
					prev_group = next_group;
				}
				if member_idx < last_member_idx {
					parts.push(doc_hardline());
				}
				i = member_idx + 1;
				continue;
			}
		}
		let child_doc = children.doc(i);
		if child_doc == () {
			let member_text = slice(children.range(i)).trim();
			if !member_text.is_empty() {
				parts.push(doc_text(member_text));
			}
		}
		else {
			parts.push(child_doc);
		}
		if group != 0 {
			prev_group = group;
		}
		if i < last_member_idx {
			let next_info = next_member_info(children, i + 1, k_lbrace, k_rbrace, k_line_comment, k_block_comment);
			let next_idx = next_info[1];
			if next_idx >= 0 && next_idx <= last_member_idx {
				let next_k = children.kind(next_idx);
				let next_group = group_for_kind(
					next_k,
					k_field,
					k_method,
					k_ctor,
					k_compact_ctor,
					k_class,
					k_interface,
					k_enum,
					k_record,
					k_anno,
					k_static_init,
					k_instance_init
				);
				let add_blank = (group != 0 && next_group != 0 && group != next_group) || (group == 2 && next_group == 2) || (group == 3 && next_group == 3);
				if add_blank {
					parts.push(doc_text("\n"));
				}
				parts.push(doc_hardline());
			}
		}
		i += 1;
	}
	let indent_size = configuration::values["tab_width"];
	if parts.len() == 0 {
		return doc_concat_list(
			[
				doc_text("{"),
				doc_hardline(),
				doc_text("}")
			]
		);
	}
	let inner = doc_concat_list(parts);
	doc_concat_list([
		doc_text("{"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), inner])),
		doc_hardline(),
		doc_text("}")
	])
}

fn build_doc(node, children) {
	let k = node.kind_id();
	if k == kinds::program {
		return doc_program(node, children);
	}
	if k == kinds::enum_body {
		return doc_enum_body(node, children);
	}
	if k == kinds::line_comment {
		return comments::doc_line_comment(node);
	}
	if k == kinds::block_comment {
		return comments::doc_block_comment(node);
	}
	if k == kinds::text_block {
		return doc_text_block(node);
	}
	if k == kinds::string_literal {
		return doc_string_literal(node);
	}
	if k == kinds::block {
		return doc_block(node, children);
	}
	if k == kinds::if_statement {
		return if_else::doc_if_statement(node, children);
	}
	if k == kinds::method_declaration || k == kinds::constructor_declaration || k == kinds::compact_constructor_declaration {
		return doc_method_like(node, children, "body");
	}
	if k == kinds::class_declaration || k == kinds::interface_declaration || k == kinds::record_declaration || k == kinds::annotation_type_declaration {
		return doc_class_like(node, children);
	}
	if k == kinds::enum_declaration {
		return doc_enum_declaration(node, children);
	}
	if k == kinds::class_body {
		return doc_class_body(node, children);
	}
	if k == kinds::switch_statement || k == kinds::switch_expression {
		return switch_fmt::doc_switch_statement(node, children);
	}
	if k == kinds::switch_block {
		return switch_fmt::doc_switch_block(node, children);
	}
	if k == kinds::switch_block_statement_group {
		return switch_fmt::doc_switch_group(node, children);
	}
	if k == kinds::try_statement {
		return try_catch::doc_try_statement(node, children);
	}
	if k == kinds::try_with_resources_statement {
		return try_catch::doc_try_with_resources(node, children);
	}
	if k == kinds::catch_clause {
		return try_catch::doc_catch_clause(node, children);
	}
	if k == kinds::finally_clause {
		return try_catch::doc_finally_clause(node, children);
	}
	if k == kinds::binary_expression || k == kinds::assignment_expression {
		return doc_operator_expression(node, children);
	}
	if k == kinds::method_invocation {
		return doc_method_invocation(node, children);
	}
	if k == kinds::lambda_expression {
		return doc_lambda_expression(node, children);
	}
	if k == kinds::argument_list {
		return doc_argument_list(node, children);
	}
	if k == kinds::element_value_pair {
		return doc_element_value_pair(node, children);
	}
	if k == kinds::annotation {
		return doc_annotation(node, children);
	}
	if k == kinds::object_creation_expression {
		return doc_object_creation_expression(node, children);
	}
	if k == kinds::formal_parameters {
		return doc_formal_parameters(node, children);
	}
	if k == kinds::formal_parameter || k == kinds::spread_parameter {
		return doc_formal_parameter(node, children);
	}
	if k == kinds::parenthesized_expression {
		return doc_parenthesized_expression(node, children);
	}
	if k == kinds::cast_expression {
		return doc_cast_expression(node, children);
	}
	if k == kinds::expression_statement {
		return doc_expression_statement(children);
	}
	if k == kinds::return_statement {
		return doc_return_statement(children);
	}
	if k == kinds::throw_statement {
		return doc_throw_statement(children);
	}
	if k == kinds::variable_declarator {
		return doc_variable_declarator(children);
	}
	if k == kinds::local_variable_declaration {
		return doc_local_variable_declaration(node, children);
	}
	if k == kinds::variable_declaration || k == kinds::field_declaration {
		return doc_field_or_variable_declaration(node, children);
	}
	if k == kinds::ternary_expression || k == kinds::conditional_expression {
		return doc_ternary_expression(node, children);
	}
	if k == kinds::for_statement {
		return loop_sync::doc_for_statement(node, children);
	}
	if k == kinds::enhanced_for_statement {
		return loop_sync::doc_enhanced_for_statement(node, children);
	}
	if k == kinds::while_statement {
		return loop_sync::doc_while_statement(node, children);
	}
	if k == kinds::do_statement {
		return loop_sync::doc_do_statement(node, children);
	}
	if k == kinds::synchronized_statement {
		return loop_sync::doc_synchronized_statement(node, children);
	}
	doc_text(text(node))
}
let start_total = now_ms();
let start_docs = now_ms();
doc_reset();
let queries = [
	"(program) @n",
	"(enum_body) @n",
	"(line_comment) @n",
	"(block_comment) @n",
	"(string_literal) @n",
	"(block) @n",
	"(parenthesized_expression) @n",
	"(cast_expression) @n",
	"(if_statement) @n",
	"(method_declaration) @n",
	"(constructor_declaration) @n",
	"(class_declaration) @n",
	"(interface_declaration) @n",
	"(enum_declaration) @n",
	"(record_declaration) @n",
	"(annotation_type_declaration) @n",
	"(class_body) @n",
	"(switch_expression) @n",
	"(switch_block) @n",
	"(switch_block_statement_group) @n",
	"(try_statement) @n",
	"(try_with_resources_statement) @n",
	"(catch_clause) @n",
	"(finally_clause) @n",
	"(binary_expression) @n",
	"(assignment_expression) @n",
	"(method_invocation) @n",
	"(lambda_expression) @n",
	"(argument_list) @n",
	"(element_value_pair) @n",
	"(annotation) @n",
	"(formal_parameter) @n",
	"(spread_parameter) @n",
	"(expression_statement) @n",
	"(variable_declarator) @n",
	"(for_statement) @n",
	"(enhanced_for_statement) @n",
	"(while_statement) @n",
	"(do_statement) @n",
	"(synchronized_statement) @n",
	"(switch_label) @n",
	"(return_statement) @n",
	"(throw_statement) @n",
	"(ternary_expression) @n",
	"(local_variable_declaration) @n",
	"(field_declaration) @n",
	"(object_creation_expression) @n",
	"(formal_parameters) @n"
];
let root_doc = walk(
	"java",
	queries,
	|node, children| {
		build_doc(node, children)
	}
);
let end_docs = now_ms();
log("doc build: " + (end_docs - start_docs) + "ms");
let start_render = now_ms();
let width = configuration::values["max_width"];
let indent_style = configuration::values["indent_style"];
let tab_width = configuration::values["tab_width"];
let output = doc_render_with_indent(root_doc, width, indent_style, tab_width);
let lines = output.split("\n");
let i = 0;
let base_tabs = -1;
let empty = "";
while i < lines.len() {
	let line = lines[i];
	if line.trim()
		.is_empty() {
		lines[i] = empty;
	}
	else {
		let tabs = 0;
		while tabs < line.len() {
			let ch = line.sub_string(tabs, 1);
			if ch == "\t" {
				tabs += 1;
			}
			else {
				break;
			}
		}
		let trimmed = line.sub_string(tabs, line.len() - tabs);
		if trimmed.starts_with(".") || trimmed.starts_with("//") {
			if base_tabs >= 0 && tabs > base_tabs + 1 {
				let new_tabs = base_tabs + 1;
				lines[i] = whitespace::repeat_str("\t", new_tabs) + trimmed;
				tabs = new_tabs;
			}
		}
		else {
			base_tabs = tabs;
		}
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
let end_render = now_ms();
log("doc render: " + (end_render - start_render) + "ms");
let start_apply = now_ms();
set_output(output);
let end_apply = now_ms();
log("apply output: " + (end_apply - start_apply) + "ms");
let end_total = now_ms();
log("total: " + (end_total - start_total) + "ms");

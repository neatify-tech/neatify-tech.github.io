// Doc-first formatter entrypoint for SQL.
import "sql/kinds.rhai" as kinds;
import "sql/configuration.rhai" as configuration;
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

fn doc_text_lines(text) {
	let normalized = normalize_ops(text);
	if normalized.index_of("\n") < 0 {
		return doc_text(normalized.trim());
	}
	let lines = normalized.split("\n");
	let parts = [];
	let i = 0;
	while i < lines.len() {
		let line = normalize_ops(lines[i].trim());
		if i > 0 {
			parts.push(doc_hardline());
		}
		parts.push(doc_text(line));
		i += 1;
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

fn lower(text) {
	text.to_lower()
}

fn normalize_ops(text) {
	let out = "";
	let i = 0;
	while i < text.len() {
		let ch = text.sub_string(i, 1);
		let next = if i + 1 < text.len() {
			text.sub_string(i + 1, 1)
		}
		else {
			""
		};
		let two = ch + next;
		if two == ">=" || two == "<=" || two == "<>" || two == "!=" {
			out += " " + two + " ";
			i += 2;
			continue;
		}
		if ch == "=" || ch == ">" || ch == "<" {
			out += " " + ch + " ";
			i += 1;
			continue;
		}
		out += ch;
		i += 1;
	}
	let parts = out.split(" ");
	let cleaned = [];
	let j = 0;
	while j < parts.len() {
		let part = parts[j];
		if part != "" {
			cleaned.push(part);
		}
		j += 1;
	}
	let result = "";
	let k = 0;
	while k < cleaned.len() {
		if k > 0 {
			result += " ";
		}
		result += cleaned[k];
		k += 1;
	}
	result
}

fn doc_where_in_subquery(raw, base_start) {
	let lower_raw = lower(raw);
	let where_idx = lower_raw.index_of("where");
	if where_idx < 0 {
		return ();
	}
	let after_where = raw.sub_string(where_idx + 5, raw.len() - (where_idx + 5)).trim();
	let lower_after = lower(after_where);
	if lower_after.index_of("select") < 0 {
		return ();
	}
	let patterns = [" in ", " in(", " in\t", " in\n"];
	let in_idx_rel = -1;
	let p = 0;
	while p < patterns.len() {
		let idx = lower_after.index_of(patterns[p]);
		if idx >= 0 && (in_idx_rel < 0 || idx < in_idx_rel) {
			in_idx_rel = idx;
		}
		p += 1;
	}
	if in_idx_rel < 0 {
		return ();
	}
	let in_idx = where_idx + 5 + in_idx_rel;
	let left = raw.sub_string(where_idx + 5, in_idx - (where_idx + 5)).trim();
	let open_idx = -1;
	let i = in_idx;
	while i < raw.len() {
		let ch = raw.sub_string(i, 1);
		if ch == "(" {
			open_idx = i;
			break;
		}
		i += 1;
	}
	if open_idx < 0 {
		return ();
	}
	let depth = 1;
	let j = open_idx + 1;
	let close_idx = -1;
	while j < raw.len() {
		let ch = raw.sub_string(j, 1);
		if ch == "(" {
			depth += 1;
		}
		else if ch == ")" {
			depth -= 1;
			if depth == 0 {
				close_idx = j;
				break;
			}
		}
		j += 1;
	}
	if close_idx <= open_idx {
		return ();
	}
	let abs_start = base_start + open_idx + 1;
	let abs_end = base_start + close_idx;
	let sub_doc = format_fragment_doc("sql", range(abs_start, abs_end));
	if sub_doc == () {
		let inner_raw = raw.sub_string(open_idx + 1, close_idx - (open_idx + 1)).trim();
		if inner_raw != "" {
			sub_doc = doc_text(inner_raw);
		}
	}
	if sub_doc == () {
		return ();
	}
	let indent_size = configuration::values["tab_width"];
	doc_concat_list([
		doc_text("where " + left + " in ("),
		doc_indent(indent_size * 2, doc_concat_list([doc_hardline(), sub_doc])),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_text(")")]))
	])
}

fn extract_where_raw(raw) {
	let lower_raw = lower(raw);
	let where_idx = lower_raw.index_of(" where ");
	if where_idx < 0 {
		return "";
	}
	let start_idx = where_idx + 1;
	let rest = raw.sub_string(start_idx, raw.len() - start_idx);
	let lower_rest = lower(rest);
	let tags = [" group by ", " having ", " order by ", " limit "];
	let end_idx = rest.len();
	let i = 0;
	while i < tags.len() {
		let idx = lower_rest.index_of(tags[i]);
		if idx >= 0 && idx < end_idx {
			end_idx = idx;
		}
		i += 1;
	}
	let clause = rest.sub_string(0, end_idx).trim();
	if clause.ends_with(";") {
		clause = clause.sub_string(0, clause.len() - 1).trim();
	}
	if lower(clause).index_of(" in (") >= 0 && clause.index_of(")") < 0 {
		clause = clause + ")";
	}
	clause
}

fn doc_identifier(node) {
	let r = byte_range(node);
	doc_range(start(r), end(r))
}

fn doc_binary_expression(node, children) {
	let left = ();
	let right = ();
	let op = "";
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if left == () {
			left = doc_for_child(children, i);
		}
		else if k == kinds::eq || k == kinds::gte || k == kinds::gt || k == kinds::lt || k == kinds::lte || k == kinds::neq || k == kinds::not_eq || k == kinds::binary_operator {
			let r = children.range(i);
			op = slice(r).trim();
		}
		else if right == () {
			right = doc_for_child(children, i);
		}
		i += 1;
	}
	if left == () || right == () {
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	if op == "" {
		op = "=";
	}
	doc_concat_list([left, doc_text(" "), doc_text(op), doc_text(" "), right])
}

fn doc_in_expression(node, children) {
	let left = ();
	let tuple = ();
	let subquery = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if left == () {
			left = doc_for_child(children, i);
		}
		else if k == kinds::tuple {
			tuple = doc_for_child(children, i);
		}
		else if k == kinds::select_statement || k == kinds::select_subexpression {
			subquery = doc_for_child(children, i);
		}
		i += 1;
	}
	if left == () || tuple == () {
		if left != () && subquery != () {
			if subquery != () && tuple == () {
				return doc_concat_list([left, doc_text(" in "), subquery]);
			}
			let indent_size = configuration::values["tab_width"];
			return doc_concat_list(
				[
					left,
					doc_text(" in ("),
					doc_indent(indent_size * 2, doc_concat_list([doc_hardline(), subquery])),
					doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_text(")")]))
				]
			);
		}
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	doc_concat_list([left, doc_text(" in "), tuple])
}

fn doc_tuple(node, children) {
	let items = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::string || k == kinds::number || k == kinds::identifier || k == kinds::dotted_name || k == kinds::argument_reference || k == kinds::named_parameter || k == kinds::literal_parameter || k == kinds::positional_parameter || k == kinds::select_statement {
			items.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if items.len() == 0 {
		return doc_text("()")
	}
	let parts = [];
	i = 0;
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
	let inner_indent = indent_size * 2;
	doc_concat_list([
		doc_text("("),
		doc_indent(inner_indent, doc_concat_list([doc_hardline(), doc_concat_list(parts)])),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_text(")")]))
	])
}

fn doc_is_expression(node, children) {
	let left = ();
	let has_not = false;
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if left == () {
			left = doc_for_child(children, i);
		}
		else if k == kinds::NOT {
			has_not = true;
		}
		i += 1;
	}
	if left == () {
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	let tail = if has_not {
		" is not null"
	}
	else {
		" is null"
	};
	doc_concat_list([left, doc_text(tail)])
}

fn doc_boolean_expression(node, children) {
	let parts = [];
	let ops = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::AND || k == kinds::OR {
			let r = children.range(i);
			ops.push(lower(slice(r).trim()));
		}
		else {
			parts.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if parts.len() == 0 {
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	let head = parts[0];
	if ops.len() == 0 {
		return head;
	}
	let tail = [];
	i = 1;
	while i < parts.len() {
		let op = if i - 1 < ops.len() {
			ops[i - 1]
		}
		else {
			"and"
		};
		let segment = doc_concat_list([doc_text(op + " "), parts[i]]);
		if tail.len() > 0 {
			tail.push(doc_hardline());
		}
		tail.push(segment);
		i += 1;
	}
	let indent_size = configuration::values["tab_width"];
	doc_concat_list([head, doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(tail)]))])
}

fn doc_select_clause_body(node, children) {
	let items = [];
	let item_start = -1;
	let item_end = -1;
	let case_idx = -1;
	let saw_comma = false;
	let case_ranges = [];
	let select_ranges = [];
	let i = 0;
	while i < children.len {
		let r = children.range(i);
		if children.kind(i) == kinds::conditional_expression && case_idx < 0 {
			case_idx = i;
		}
		if children.kind(i) == kinds::conditional_expression {
			case_ranges.push([start(r), end(r), i]);
		}
		if children.kind(i) == kinds::select_subexpression {
			select_ranges.push([start(r), end(r), i]);
		}
		if item_start < 0 {
			item_start = start(r);
		}
		if children.kind(i) == kinds::comma {
			saw_comma = true;
			let item_range = range(item_start, start(r));
			let doc = ();
			let j = 0;
			while j < select_ranges.len() {
				let entry = select_ranges[j];
				let s_start = entry[0];
				let s_end = entry[1];
				if s_start >= item_start && s_end <= start(r) {
					let select_doc = doc_for_child(children, entry[2]);
					let tail = slice(range(s_end, start(r))).trim();
					if tail != "" {
						doc = doc_concat_list([select_doc, doc_text(" " + normalize_ops(tail))]);
					}
					else {
						doc = select_doc;
					}
					break;
				}
				j += 1;
			}
			if doc == () {
				let j = 0;
				while j < case_ranges.len() {
					let entry = case_ranges[j];
					let c_start = entry[0];
					let c_end = entry[1];
					if c_start >= item_start && c_end <= start(r) {
						let case_doc = doc_for_child(children, entry[2]);
						let tail = slice(range(c_end, start(r))).trim();
						if tail != "" {
							doc = doc_concat_list([case_doc, doc_text(" " + tail)]);
						}
						else {
							doc = case_doc;
						}
						break;
					}
					j += 1;
				}
			}
			if doc == () {
				let text = slice(item_range).trim();
				if text != "" {
					doc = doc_text_lines(text);
				}
			}
			if doc != () {
				items.push(doc);
			}
			item_start = -1;
			item_end = -1;
		}
		else {
			item_end = end(r);
		}
		i += 1;
	}
	if item_start >= 0 && item_end >= 0 {
		let doc = ();
		let j = 0;
		while j < select_ranges.len() {
			let entry = select_ranges[j];
			let s_start = entry[0];
			let s_end = entry[1];
			if s_start >= item_start && s_end <= item_end {
				let select_doc = doc_for_child(children, entry[2]);
				let tail = slice(range(s_end, item_end)).trim();
				if tail != "" {
					doc = doc_concat_list([select_doc, doc_text(" " + normalize_ops(tail))]);
				}
				else {
					doc = select_doc;
				}
				break;
			}
			j += 1;
		}
		if doc == () {
			let j = 0;
			while j < case_ranges.len() {
				let entry = case_ranges[j];
				let c_start = entry[0];
				let c_end = entry[1];
				if c_start >= item_start && c_end <= item_end {
					let case_doc = doc_for_child(children, entry[2]);
					let tail = slice(range(c_end, item_end)).trim();
					if tail != "" {
						doc = doc_concat_list([case_doc, doc_text(" " + tail)]);
					}
					else {
						doc = case_doc;
					}
					break;
				}
				j += 1;
			}
		}
		if doc == () {
			let text = slice(range(item_start, item_end)).trim();
			if text != "" {
				doc = doc_text_lines(text);
			}
		}
		if doc != () {
			items.push(doc);
		}
	}
	if !saw_comma && case_idx >= 0 {
		let case_doc = doc_for_child(children, case_idx);
		let case_range = children.range(case_idx);
		let tail = slice(range(end(case_range), end(byte_range(node)))).trim();
		if tail != "" {
			return doc_concat_list([case_doc, doc_text(" " + tail)]);
		}
		return case_doc;
	}
	if items.len() == 0 {
		let r = byte_range(node);
		let raw = slice(r).trim();
		if raw != "" {
			items.push(doc_text_lines(raw));
		}
	}
	if items.len() == 0 {
		return doc_text("");
	}
	let parts = [];
	i = 0;
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
	doc_concat_list(parts)
}

fn doc_select_list(node, children) {
	let body_doc = ();
	let i = 0;
	while i < children.len {
		if children.kind(i) == kinds::select_clause_body {
			body_doc = doc_for_child(children, i);
			break;
		}
		i += 1;
	}
	if body_doc == () {
		let items = [];
		let current = [];
		i = 0;
		while i < children.len {
			let k = children.kind(i);
			if k == kinds::SELECT {
				i += 1;
				continue;
			}
			if k == kinds::comma {
				items.push(doc_concat_list(current));
				current = [];
			}
			else {
				current.push(doc_for_child(children, i));
			}
			i += 1;
		}
		if current.len() > 0 {
			items.push(doc_concat_list(current));
		}
		if items.len() > 0 {
			let parts = [];
			i = 0;
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
			body_doc = doc_concat_list(parts);
		}
	}
	if body_doc == () {
		return doc_text("select");
	}
	let indent_size = configuration::values["tab_width"];
	doc_concat_list([
		doc_text("select"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), body_doc]))
	])
}

fn doc_from_clause(node, children) {
	let k_join = kinds::join_clause;
	let join_idx = -1;
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_join {
			join_idx = i;
			break;
		}
		i += 1;
	}
	if join_idx >= 0 {
		let join_doc = doc_for_child(children, join_idx);
		return doc_concat_list([doc_text("from "), join_doc]);
	}
	let r = byte_range(node);
	let raw = trim(slice(r));
	let tail = raw.sub_string(4, raw.len() - 4).trim();
	doc_text("from " + tail)
}

fn doc_join_clause(node, children) {
	let left_parts = [];
	let right_parts = [];
	let join_type = "";
	let on_doc = ();
	let state = "left";
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::join_condition {
			on_doc = doc_for_child(children, i);
			break;
		}
		if k == kinds::join_type {
			let r = children.range(i);
			join_type = lower(slice(r).trim());
			state = "join";
			i += 1;
			continue;
		}
		if k == kinds::JOIN {
			state = "right";
			i += 1;
			continue;
		}
		let d = doc_for_child(children, i);
		if state == "left" {
			if left_parts.len() > 0 {
				left_parts.push(doc_text(" "));
			}
			left_parts.push(d);
		}
		else if state == "right" {
			if right_parts.len() > 0 {
				right_parts.push(doc_text(" "));
			}
			right_parts.push(d);
		}
		i += 1;
	}
	let left_doc = doc_concat_list(left_parts);
	let right_doc = doc_concat_list(right_parts);
	let join_prefix = if join_type == "" {
		"join"
	}
	else {
		join_type + " join"
	};
	let indent_size = configuration::values["tab_width"];
	let parts = [left_doc, doc_hardline(), doc_text(join_prefix + " "), right_doc];
	if on_doc != () {
		parts.push(doc_indent(indent_size, doc_concat_list([doc_hardline(), on_doc])));
	}
	doc_concat_list(parts)
}

fn doc_join_condition(node, children) {
	let expr_doc = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k != kinds::ON {
			expr_doc = doc_for_child(children, i);
		}
		i += 1;
	}
	if expr_doc == () {
		return doc_text("on");
	}
	doc_concat_list([doc_text("on "), expr_doc])
}

fn doc_order_by_clause(children) {
	let k_order = kinds::order_expression;
	let items = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_order {
			items.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if items.len() == 0 {
		let r = children.range(0);
		return doc_range(start(r), end(r));
	}
	if items.len() == 1 {
		return doc_concat_list([doc_text("order by "), items[0]]);
	}
	let parts = [];
	i = 0;
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
		doc_text("order by"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)]))
	])
}

fn doc_order_expression(node, children) {
	let expr_doc = ();
	let direction = "";
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::ASC || k == kinds::DESC {
			let r = children.range(i);
			direction = lower(slice(r).trim());
		}
		else if expr_doc == () {
			expr_doc = doc_for_child(children, i);
		}
		i += 1;
	}
	if expr_doc == () {
		return doc_text("");
	}
	if direction == "" {
		return expr_doc;
	}
	doc_concat_list([expr_doc, doc_text(" "), doc_text(direction)])
}

fn doc_group_by_clause(node, children) {
	let k_group = kinds::group_expression;
	let items = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_group {
			items.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if items.len() == 0 {
		let r = children.range(0);
		return doc_range(start(r), end(r));
	}
	if items.len() == 1 {
		let base = doc_concat_list([doc_text("group by "), items[0]]);
		let r = byte_range(node);
		let raw = slice(r);
		let lower_raw = lower(raw);
		let tag = " having ";
		let idx = lower_raw.index_of(tag);
		if idx >= 0 {
			let start_idx = idx + tag.len();
			let having_part = raw.sub_string(start_idx, raw.len() - start_idx).trim();
			if having_part != "" {
				return doc_concat_list([base, doc_hardline(), doc_text("having " + normalize_ops(having_part))]);
			}
		}
		return base;
	}
	let parts = [];
	i = 0;
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
	let base = doc_concat_list(
		[
			doc_text("group by"),
			doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)]))
		]
	);
	let r = byte_range(node);
	let raw = slice(r);
	let lower_raw = lower(raw);
	let tag = " having ";
	let idx = lower_raw.index_of(tag);
	if idx >= 0 {
		let start_idx = idx + tag.len();
		let having_part = raw.sub_string(start_idx, raw.len() - start_idx).trim();
		if having_part != "" {
			return doc_concat_list([base, doc_hardline(), doc_text("having " + normalize_ops(having_part))]);
		}
	}
	base
}

fn doc_having_clause(node, children) {
	let expr_doc = ();
	let expr_start = -1;
	let comment_doc = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::comment && comment_doc == () {
			comment_doc = doc_for_child(children, i);
		}
		if k == kinds::boolean_expression || k == kinds::binary_expression || k == kinds::in_expression || k == kinds::is_expression || k == kinds::conditional_expression {
			let r = children.range(i);
			let s = start(r);
			if expr_start < 0 || s < expr_start {
				expr_doc = doc_for_child(children, i);
				expr_start = s;
			}
		}
		i += 1;
	}
	if expr_doc == () {
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	if comment_doc != () {
		return doc_concat_list([doc_text("having "), comment_doc, doc_text(" "), expr_doc]);
	}
	doc_concat_list([doc_text("having "), expr_doc])
}

fn doc_limit_clause(children) {
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::number {
			let d = doc_for_child(children, i);
			return doc_concat_list([doc_text("limit "), d]);
		}
		i += 1;
	}
	let r = children.range(0);
	doc_range(start(r), end(r))
}

fn doc_with_clause(children) {
	let k_cte = kinds::cte;
	let ctes = [];
	let i = 0;
	while i < children.len {
		if children.kind(i) == k_cte {
			ctes.push(doc_for_child(children, i));
		}
		i += 1;
	}
	if ctes.len() == 0 {
		return doc_text("");
	}
	let parts = [];
	parts.push(doc_text("with "));
	parts.push(ctes[0]);
	let i = 1;
	while i < ctes.len() {
		parts.push(doc_text(","));
		parts.push(doc_hardline());
		parts.push(ctes[i]);
		i += 1;
	}
	doc_concat_list(parts)
}

fn doc_cte(node, children) {
	let name_doc = ();
	let select_doc = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::identifier && name_doc == () {
			name_doc = doc_for_child(children, i);
		}
		else if k == kinds::select_statement {
			select_doc = doc_for_child(children, i);
		}
		i += 1;
	}
	if name_doc == () || select_doc == () {
		let r = children.range(0);
		return doc_range(start(r), end(r));
	}
	let indent_size = configuration::values["tab_width"];
	doc_concat_list([
		name_doc,
		doc_text(" as ("),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), select_doc])),
		doc_hardline(),
		doc_text(")")
	])
}

fn doc_select_statement(node, children) {
	let stmt_children = children;
	let select_doc = ();
	let from_doc = ();
	let where_doc = ();
	let where_span = -1;
	let select_start = -1;
	let select_end = -1;
	let from_start = -1;
	let from_end = -1;
	let having_doc = ();
	let order_doc = ();
	let limit_doc = ();
	let with_doc = ();
	let group_doc = ();
	let has_semicolon = false;
	let i = 0;
	while i < stmt_children.len {
		let k = stmt_children.kind(i);
		if k == kinds::select_clause {
			let r = stmt_children.range(i);
			let s = start(r);
			if select_start < 0 || s > select_start {
				select_doc = doc_for_child(stmt_children, i);
				select_start = s;
				select_end = end(r);
			}
		}
		else if k == kinds::from_clause {
			let r = stmt_children.range(i);
			let s = start(r);
			if select_start >= 0 && s > select_start && (from_start < 0 || s > from_start) {
				from_doc = doc_for_child(stmt_children, i);
				from_start = s;
				from_end = end(r);
			}
		}
		else if k == kinds::where_clause {
			let r = stmt_children.range(i);
			let start_pos = start(r);
			let valid = true;
			if from_end >= 0 {
				valid = start_pos > from_end;
			}
			else if select_end >= 0 {
				valid = start_pos > select_end;
			}
			if !valid {
				i += 1;
				continue;
			}
			let raw_where = slice(r);
			let lower_where = lower(raw_where);
			let has_subquery = lower_where.index_of(" in ") >= 0 && lower_where.index_of("select") >= 0;
			let span = end(r) - start(r);
			if has_subquery {
				where_doc = doc_for_child(stmt_children, i);
				where_span = span;
			}
			else if where_span < 0 || span > where_span {
				where_doc = doc_for_child(stmt_children, i);
				where_span = span;
			}
		}
		else if k == kinds::having_clause && having_doc == () {
			having_doc = doc_for_child(stmt_children, i);
		}
		else if k == kinds::order_by_clause && order_doc == () {
			order_doc = doc_for_child(stmt_children, i);
		}
		else if k == kinds::limit_clause && limit_doc == () {
			limit_doc = doc_for_child(stmt_children, i);
		}
		else if k == kinds::with_clause && with_doc == () {
			with_doc = doc_for_child(stmt_children, i);
		}
		else if k == kinds::group_by_clause && group_doc == () {
			group_doc = doc_for_child(stmt_children, i);
		}
		else if k == kinds::semi {
			has_semicolon = true;
		}
		i += 1;
	}
	if !has_semicolon {
		let r = byte_range(node);
		let raw = slice(r).trim();
		if raw.len() > 0 {
			let last = raw.sub_string(raw.len() - 1, 1);
			if last == ";" {
				has_semicolon = true;
			}
		}
	}
	let r = byte_range(node);
	let raw = slice(r);
	if where_doc == () {
		let in_subquery = doc_where_in_subquery(raw, start(r));
		if in_subquery != () {
			where_doc = in_subquery;
		}
		let where_raw = extract_where_raw(raw);
		if where_raw != "" {
			let lower_where = lower(where_raw);
			if lower_where.index_of(" in ") >= 0 && lower_where.index_of("select") >= 0 {
				where_doc = doc_text(where_raw);
			}
		}
	}
	let parts = [];
	if with_doc != () {
		parts.push(with_doc);
		parts.push(doc_hardline());
	}
	if select_doc != () {
		parts.push(select_doc);
	}
	if from_doc != () {
		parts.push(doc_hardline());
		parts.push(from_doc);
	}
	if where_doc != () {
		parts.push(doc_hardline());
		parts.push(where_doc);
	}
	if group_doc != () {
		parts.push(doc_hardline());
		parts.push(group_doc);
	}
	if having_doc != () {
		parts.push(doc_hardline());
		parts.push(having_doc);
	}
	if order_doc != () {
		parts.push(doc_hardline());
		parts.push(order_doc);
	}
	if limit_doc != () {
		parts.push(doc_hardline());
		parts.push(limit_doc);
	}
	if has_semicolon {
		parts.push(doc_text(";"));
	}
	doc_concat_list(parts)
}

fn doc_where_clause(node, children) {
	let r = byte_range(node);
	let raw = slice(r);
	let lower_raw = lower(raw);
	let in_idx = lower_raw.index_of(" in ");
	if in_idx >= 0 && lower_raw.index_of("select") >= 0 {
		let left = raw.sub_string(0, in_idx).trim();
		let lower_left = lower(left);
		if lower_left.starts_with("where ") {
			left = left.sub_string(6, left.len() - 6).trim();
		}
		let open_idx = -1;
		let i = in_idx;
		while i < raw.len() {
			let ch = raw.sub_string(i, 1);
			if ch == "(" {
				open_idx = i;
				break;
			}
			i += 1;
		}
		if open_idx >= 0 {
			let depth = 1;
			let j = open_idx + 1;
			let close_idx = -1;
			while j < raw.len() {
				let ch = raw.sub_string(j, 1);
				if ch == "(" {
					depth += 1;
				}
				else if ch == ")" {
					depth -= 1;
					if depth == 0 {
						close_idx = j;
						break;
					}
				}
				j += 1;
			}
			if close_idx > open_idx {
				let abs_start = start(r) + open_idx + 1;
				let abs_end = start(r) + close_idx;
				let sub_doc = format_fragment_doc("sql", range(abs_start, abs_end));
				if sub_doc != () {
					let indent_size = configuration::values["tab_width"];
					return doc_concat_list(
						[
							doc_text("where " + left + " in ("),
							doc_indent(indent_size * 2, doc_concat_list([doc_hardline(), sub_doc])),
							doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_text(")")]))
						]
					);
				}
			}
		}
	}
	let expr_doc = ();
	let expr_start = -1;
	let comment_doc = ();
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::comment && comment_doc == () {
			comment_doc = doc_for_child(children, i);
		}
		if k == kinds::boolean_expression || k == kinds::binary_expression || k == kinds::in_expression || k == kinds::is_expression {
			let r = children.range(i);
			let s = start(r);
			if expr_start < 0 || s < expr_start {
				expr_doc = doc_for_child(children, i);
				expr_start = s;
			}
		}
		i += 1;
	}
	if expr_doc == () {
		let r = children.range(0);
		return doc_range(start(r), end(r));
	}
	if comment_doc != () {
		return doc_concat_list([doc_text("where "), comment_doc, doc_text(" "), expr_doc]);
	}
	doc_concat_list([doc_text("where "), expr_doc])
}

fn doc_case_expression(node, children) {
	let markers = [];
	let i = 0;
	while i < children.len {
		let k = children.kind(i);
		if k == kinds::WHEN || k == kinds::THEN || k == kinds::ELSE || k == kinds::END {
			let r = children.range(i);
			markers.push([k, start(r), end(r)]);
		}
		i += 1;
	}
	if markers.len() == 0 {
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	let end_r = byte_range(node);
	let end_pos = end(end_r);
	let lines = [];
	let idx = 0;
	while idx < markers.len() {
		let entry = markers[idx];
		let k = entry[0];
		let start_pos = entry[1];
		let end_pos_marker = entry[2];
		if k == kinds::WHEN {
			let then_idx = idx + 1;
			if then_idx >= markers.len() {
				break;
			}
			let then_entry = markers[then_idx];
			let then_kind = then_entry[0];
			if then_kind != kinds::THEN {
				idx += 1;
				continue;
			}
			let cond_text = normalize_ops(slice(range(end_pos_marker, then_entry[1])).trim());
			let next_idx = then_idx + 1;
			let next_pos = if next_idx < markers.len() {
				markers[next_idx]
				[1]
			}
			else {
				end_pos
			};
			let result_text = slice(range(then_entry[2], next_pos)).trim();
			lines.push(doc_text("when " + cond_text + " then " + result_text));
			idx = then_idx + 1;
			continue;
		}
		if k == kinds::ELSE {
			let next_idx = idx + 1;
			let next_pos = if next_idx < markers.len() {
				markers[next_idx]
				[1]
			}
			else {
				end_pos
			};
			let else_text = slice(range(end_pos_marker, next_pos)).trim();
			lines.push(doc_text("else " + else_text));
			idx += 1;
			continue;
		}
		if k == kinds::END {
			idx += 1;
			continue;
		}
		idx += 1;
	}
	if lines.len() == 0 {
		let r = byte_range(node);
		return doc_range(start(r), end(r));
	}
	let parts = [];
	let i = 0;
	while i < lines.len() {
		if i > 0 {
			parts.push(doc_hardline());
		}
		parts.push(lines[i]);
		i += 1;
	}
	let indent_size = configuration::values["tab_width"];
	doc_concat_list([
		doc_text("case"),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)])),
		doc_hardline(),
		doc_text("end")
	])
}

fn build_doc(node, children) {
	let k = node.kind_id();
	if k == kinds::source_file {
		let i = 0;
		let docs = [];
		while i < children.len {
			let child_kind = children.kind(i);
			if child_kind == kinds::select_statement {
				docs.push(doc_for_child(children, i));
			}
			i += 1;
		}
		return doc_concat_list(docs);
	}
	if k == kinds::select_statement {
		return doc_select_statement(node, children);
	}
	if k == kinds::from_clause {
		return doc_from_clause(node, children);
	}
	if k == kinds::where_clause {
		return doc_where_clause(node, children);
	}
	if k == kinds::having_clause {
		return doc_having_clause(node, children);
	}
	if k == kinds::order_by_clause {
		return doc_order_by_clause(children);
	}
	if k == kinds::limit_clause {
		return doc_limit_clause(children);
	}
	if k == kinds::with_clause {
		return doc_with_clause(children);
	}
	if k == kinds::cte {
		return doc_cte(node, children);
	}
	if k == kinds::group_by_clause {
		return doc_group_by_clause(node, children);
	}
	if k == kinds::join_clause {
		return doc_join_clause(node, children);
	}
	if k == kinds::join_condition {
		return doc_join_condition(node, children);
	}
	if k == kinds::tuple {
		return doc_tuple(node, children);
	}
	if k == kinds::order_expression {
		return doc_order_expression(node, children);
	}
	if k == kinds::select_clause {
		return doc_select_list(node, children);
	}
	if k == kinds::select_clause_body {
		return doc_select_clause_body(node, children);
	}
	if k == kinds::select_subexpression {
		let select_doc = ();
		let i = 0;
		while i < children.len {
			if children.kind(i) == kinds::select_statement {
				select_doc = doc_for_child(children, i);
				break;
			}
			i += 1;
		}
		if select_doc == () {
			let r = byte_range(node);
			return doc_range(start(r), end(r));
		}
		let indent_size = configuration::values["tab_width"];
		return doc_concat_list(
			[
				doc_text("("),
				doc_indent(indent_size, doc_concat_list([doc_hardline(), select_doc])),
				doc_hardline(),
				doc_text(")")
			]
		);
	}
	if k == kinds::boolean_expression {
		return doc_boolean_expression(node, children);
	}
	if k == kinds::binary_expression {
		return doc_binary_expression(node, children);
	}
	if k == kinds::in_expression {
		return doc_in_expression(node, children);
	}
	if k == kinds::is_expression {
		return doc_is_expression(node, children);
	}
	if k == kinds::conditional_expression {
		return doc_case_expression(node, children);
	}
	let r = byte_range(node);
	doc_range(start(r), end(r))
}
doc_reset();
let queries = [
	"(source_file) @n",
	"(select_statement) @n",
	"(select_clause) @n",
	"(select_clause_body) @n",
	"(select_subexpression) @n",
	"(from_clause) @n",
	"(where_clause) @n",
	"(having_clause) @n",
	"(order_by_clause) @n",
	"(limit_clause) @n",
	"(with_clause) @n",
	"(cte) @n",
	"(group_by_clause) @n",
	"(join_clause) @n",
	"(join_condition) @n",
	"(order_expression) @n",
	"(tuple) @n",
	"(boolean_expression) @n",
	"(binary_expression) @n",
	"(in_expression) @n",
	"(is_expression) @n",
	"(conditional_expression) @n"
];
let root_doc = walk(
	"sql",
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
let source_text = slice(range(0, source_len()));
let source_trim = source_text.trim();
if source_trim.len() > 0 {
	let source_last = source_trim.sub_string(source_trim.len() - 1, 1);
	if source_last == ";" {
		let output_trim = output.trim();
		if output_trim.len() == 0 {
			output = output + ";";
		}
		else {
			let output_last = output_trim.sub_string(output_trim.len() - 1, 1);
			if output_last != ";" {
				output = output + ";";
			}
		}
	}
}
let output = output + "\n";
set_output(output);

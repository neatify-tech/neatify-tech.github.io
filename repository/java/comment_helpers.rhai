// Shared helpers for inline comments between headers and blocks.
import "shared/comment_helpers.rhai" as shared_helpers;
import "java/comments.rhai" as comments;

fn inline_comment_doc_from_gap(gap) {
	shared_helpers::inline_comment_doc_from_gap(gap, "//", "/*", "*/")
}

fn inline_comment_doc_between(language, header_end, block_start) {
	shared_helpers::inline_comment_doc_between(language, header_end, block_start, "line_comment", "block_comment", "//", "/*", "*/");
}

fn node_for_range_kind(language, parent_node, target_range, kind_name) {
	shared_helpers::node_for_range_kind(language, parent_node, target_range, kind_name)
}

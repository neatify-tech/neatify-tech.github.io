// Comment formatting helpers.
import "shared/comments.rhai" as shared_comments;
fn strip_incidental_ws_block_comment(text) {
	shared_comments::strip_incidental_ws_block_comment(text)
}

fn doc_line_comment(node) {
	shared_comments::doc_line_comment(node, "//")
}

fn doc_block_comment(node) {
	shared_comments::doc_block_comment(node, "/*", "*/")
}
// Exports are implicit via module import.

if k == "comment_line_doc" {
	return comments::doc_line_comment(node, "//");
}
if k == "comment_block_doc" {
	return comments::doc_block_comment(node, "/*", "*/");
}

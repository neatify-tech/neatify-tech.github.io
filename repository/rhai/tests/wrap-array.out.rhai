return doc_concat_list(
	[
		doc_text("("),
		doc_indent(indent_size, doc_concat_list([doc_hardline(), doc_concat_list(parts)])),
		doc_hardline(),
		doc_text(")")
	]
);
return doc_concat_list(
	[
		doc_text("("),
		doc_indent(
			indent_size,
			doc_concat_list(
				[
					doc_hardline(),
					doc_concat_list(parts),
					doc_text("over here"),
					doc_text("and there"),
					doc_text("and this here of course!")
				]
			)
		),
		doc_hardline(),
		doc_text(")")
	]
);

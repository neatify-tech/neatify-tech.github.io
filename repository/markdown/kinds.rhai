const map = kind_ids_map(
	"markdown",
	[
		"document",
		"paragraph",
		"atx_heading",
		"setext_heading",
		"list",
		"list_item",
		"block_quote",
		"fenced_code_block",
		"code_fence_content",
		"info_string",
		"language",
		"link_reference_definition",
		"thematic_break"
	],
	[
		true,
		true,
		true,
		true,
		true,
		true,
		true,
		true,
		true,
		true,
		true,
		true,
		true
	]
);
export map as map;
export const document = kind_id("markdown", "document", true);
export const section = kind_id("markdown", "section", true);
export const paragraph = kind_id("markdown", "paragraph", true);
export const atx_heading = kind_id("markdown", "atx_heading", true);
export const setext_heading = kind_id("markdown", "setext_heading", true);
export const list = kind_id("markdown", "list", true);
export const list_item = kind_id("markdown", "list_item", true);
export const block_quote = kind_id("markdown", "block_quote", true);
export const fenced_code_block = kind_id("markdown", "fenced_code_block", true);
export const code_fence_content = kind_id("markdown", "code_fence_content", true);
export const info_string = kind_id("markdown", "info_string", true);
export const language = kind_id("markdown", "language", true);
export const link_reference_definition = kind_id("markdown", "link_reference_definition", true);
export const thematic_break = kind_id("markdown", "thematic_break", true);

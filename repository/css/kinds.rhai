const map = kind_ids_map(
	"css",
	[
		"stylesheet",
		"rule_set",
		"selectors",
		"block",
		"declaration",
		"property_name",
		"at_rule",
		"media_statement",
		"supports_statement",
		"scope_statement",
		"keyframes_statement",
		"keyframe_block_list",
		"keyframe_block",
		"import_statement",
		"charset_statement",
		"namespace_statement",
		"postcss_statement"
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
		true,
		true,
		true,
		true,
		true
	]
);
export map as map;
export const stylesheet = kind_id("css", "stylesheet", true);
export const rule_set = kind_id("css", "rule_set", true);
export const selectors = kind_id("css", "selectors", true);
export const block = kind_id("css", "block", true);
export const declaration = kind_id("css", "declaration", true);
export const property_name = kind_id("css", "property_name", true);
export const at_rule = kind_id("css", "at_rule", true);
export const media_statement = kind_id("css", "media_statement", true);
export const supports_statement = kind_id("css", "supports_statement", true);
export const scope_statement = kind_id("css", "scope_statement", true);
export const keyframes_statement = kind_id("css", "keyframes_statement", true);
export const keyframe_block_list = kind_id("css", "keyframe_block_list", true);
export const keyframe_block = kind_id("css", "keyframe_block", true);
export const import_statement = kind_id("css", "import_statement", true);
export const charset_statement = kind_id("css", "charset_statement", true);
export const namespace_statement = kind_id("css", "namespace_statement", true);
export const postcss_statement = kind_id("css", "postcss_statement", true);

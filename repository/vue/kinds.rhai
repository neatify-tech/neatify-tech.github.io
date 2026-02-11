const map = kind_ids_map(
	"vue",
	[
		"component",
		"element",
		"template_element",
		"script_element",
		"style_element",
		"start_tag",
		"end_tag",
		"self_closing_tag",
		"tag_name",
		"attribute",
		"attribute_name",
		"attribute_value",
		"quoted_attribute_value",
		"text",
		"raw_text",
		"comment",
		"interpolation",
		"erroneous_end_tag",
		"erroneous_end_tag_name",
		"_implicit_end_tag",
		"directive_attribute",
		"directive_argument",
		"directive_dynamic_argument",
		"directive_modifiers",
		"directive_modifier"
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
export const component = kind_id("vue", "component", true);
export const element = kind_id("vue", "element", true);
export const template_element = kind_id("vue", "template_element", true);
export const script_element = kind_id("vue", "script_element", true);
export const style_element = kind_id("vue", "style_element", true);
export const start_tag = kind_id("vue", "start_tag", true);
export const end_tag = kind_id("vue", "end_tag", true);
export const self_closing_tag = kind_id("vue", "self_closing_tag", true);
export const tag_name = kind_id("vue", "tag_name", true);
export const attribute = kind_id("vue", "attribute", true);
export const attribute_name = kind_id("vue", "attribute_name", true);
export const attribute_value = kind_id("vue", "attribute_value", true);
export const quoted_attribute_value = kind_id("vue", "quoted_attribute_value", true);
export const text = kind_id("vue", "text", true);
export const raw_text = kind_id("vue", "raw_text", true);
export const comment = kind_id("vue", "comment", true);
export const interpolation = kind_id("vue", "interpolation", true);
export const erroneous_end_tag = kind_id("vue", "erroneous_end_tag", true);
export const erroneous_end_tag_name = kind_id("vue", "erroneous_end_tag_name", true);
export const _implicit_end_tag = kind_id("vue", "_implicit_end_tag", true);
export const directive_attribute = kind_id("vue", "directive_attribute", true);
export const directive_argument = kind_id("vue", "directive_argument", true);
export const directive_dynamic_argument = kind_id("vue", "directive_dynamic_argument", true);
export const directive_modifiers = kind_id("vue", "directive_modifiers", true);
export const directive_modifier = kind_id("vue", "directive_modifier", true);

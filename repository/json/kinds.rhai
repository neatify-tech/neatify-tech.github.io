const map = kind_ids_map(
	"json",
	[
		"document",
		"object",
		"pair",
		"array",
		"string",
		"number",
		"true",
		"false",
		"null",
		"_value"
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
		false
	]
);
export map as map;
export const document = kind_id("json", "document", true);
export const object = kind_id("json", "object", true);
export const pair = kind_id("json", "pair", true);
export const array = kind_id("json", "array", true);
export const string = kind_id("json", "string", true);
export const number = kind_id("json", "number", true);
export const lit_true = kind_id("json", "true", true);
export const lit_false = kind_id("json", "false", true);
export const lit_null = kind_id("json", "null", true);
export const value = kind_id("json", "_value", false);

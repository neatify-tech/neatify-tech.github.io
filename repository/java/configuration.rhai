// Centralized resolved settings for Java formatter.
const VALUES = #{
	"max_width": setting("max_width", 100),
	"tab_width": setting("tab_width", 4),
	"preserve_arg_newlines": setting("preserve_arg_newlines", false),
	"indent_style": setting("indent_style", "tabs"),
	"wrap_str": setting("wrap_str", 1),
	"profile": setting("profile", false),
	"switch_break_align": setting("switch_break_align", true),
};
export VALUES as values;

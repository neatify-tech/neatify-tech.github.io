const KIND_PAIRS = [
	["Rhai", true],
	["Item", true],
	["Doc", true],
	["Stmt", true],
	["Expr", true],
	["ExprNoDecl", true],
	["ExprChain", true],
	["ExprChainBase", true],
	["ChainSegment", true],
	["ExprBlock", true],
	["ExprIf", true],
	["ExprFor", true],
	["ExprWhile", true],
	["ExprLoop", true],
	["ExprDo", true],
	["ExprSwitch", true],
	["SwitchArmList", true],
	["SwitchArm", true],
	["SwitchArmCondition", true],
	["ExprReturn", true],
	["ExprBreak", true],
	["ExprContinue", true],
	["ExprThrow", true],
	["ExprTry", true],
	["ExprFn", true],
	["ExprImport", true],
	["ExprExportIdent", true],
	["ExprDeclareVar", true],
	["ExprCall", true],
	["ExprDotAccess", true],
	["ExprBinary", true],
	["ExprUnary", true],
	["binop", true],
	["ExprParen", true],
	["ExprArray", true],
	["ExprObject", true],
	["ObjectField", true],
	["ExprIndex", true],
	["ExprClosure", true],
	["ClosureParamList", true],
	["ArgList", true],
	["ParamList", true],
	["Param", true],
	["Path", true],
	["ExprPath", true],
	["ExprIdent", true],
	["ExprLit", true],
	["Lit", true],
	["LitUnit", true],
	["ident", true],
	["lit_str", true],
	["lit_int", true],
	["lit_float", true],
	["lit_bool", true],
	["comment_line_doc", true],
	["comment_block_doc", true],
	["DefModuleInline", true],
	["DefStmt", true],
	["Def", true],
	["DefItem", true],
	["DefConst", true],
	["DefLet", true],
	["DefFn", true],
	["Type", true],
	["TypeIdent", true],
	["TypeLit", true],
	["TypeTuple", true],
	["TypeArray", true],
	["TypeObject", true],
	["TypeObjectField", true],
	["TypeUnion", true],
	["TypeUnknown", true],
	["TypeList", true],
	["TypeGenerics", true],
	["TypedParamList", true],
	["TypedParam", true],
	["module", false],
	["{", false],
	["}", false],
	["(", false],
	[")", false],
	["[", false],
	["]", false],
	["#", false],
	["#{", false],
	[",", false],
	[";", false],
	[":", false],
	["::", false],
	[".", false],
	["?.", false],
	["=", false],
	["->", false],
	["=>", false],
	["+", false],
	["-", false],
	["*", false],
	["**", false],
	["/", false],
	["%", false],
	["==", false],
	["!=", false],
	["<", false],
	[">", false],
	["<=", false],
	[">=", false],
	["&&", false],
	["||", false],
	["!", false],
	["&", false],
	["|", false],
	["^", false],
	["<<", false],
	[">>", false],
	["+=", false],
	["-=", false],
	["*=", false],
	["/=", false],
	["%=", false],
	["<<=", false],
	[">>=", false],
	["&=", false],
	["|=", false],
	["^=", false],
	["??", false],
	["..", false],
	["..=", false],
	["if", false],
	["else", false],
	["for", false],
	["in", false],
	["while", false],
	["loop", false],
	["do", false],
	["until", false],
	["switch", false],
	["return", false],
	["break", false],
	["continue", false],
	["throw", false],
	["try", false],
	["catch", false],
	["fn", false],
	["private", false],
	["let", false],
	["const", false],
	["export", false],
	["import", false],
	["as", false]
];
fn build_kind_map(pairs) {
	let out = #{};
	let i = 0;
	while i < pairs.len() {
		let entry = pairs[i];
		out[entry[0]] = kind_id("rhai", entry[0], entry[1]);
		i += 1;
	}
	out
}
let kinds = build_kind_map(KIND_PAIRS);
export kinds as map;
export const Rhai = kind_id("rhai", "Rhai", true);
export const Item = kind_id("rhai", "Item", true);
export const Doc = kind_id("rhai", "Doc", true);
export const Stmt = kind_id("rhai", "Stmt", true);
export const Expr = kind_id("rhai", "Expr", true);
export const ExprNoDecl = kind_id("rhai", "ExprNoDecl", true);
export const ExprChain = kind_id("rhai", "ExprChain", true);
export const ExprChainBase = kind_id("rhai", "ExprChainBase", true);
export const ChainSegment = kind_id("rhai", "ChainSegment", true);
export const ExprBlock = kind_id("rhai", "ExprBlock", true);
export const ExprIf = kind_id("rhai", "ExprIf", true);
export const ExprFor = kind_id("rhai", "ExprFor", true);
export const ExprWhile = kind_id("rhai", "ExprWhile", true);
export const ExprLoop = kind_id("rhai", "ExprLoop", true);
export const ExprDo = kind_id("rhai", "ExprDo", true);
export const ExprSwitch = kind_id("rhai", "ExprSwitch", true);
export const SwitchArmList = kind_id("rhai", "SwitchArmList", true);
export const SwitchArm = kind_id("rhai", "SwitchArm", true);
export const SwitchArmCondition = kind_id("rhai", "SwitchArmCondition", true);
export const ExprReturn = kind_id("rhai", "ExprReturn", true);
export const ExprBreak = kind_id("rhai", "ExprBreak", true);
export const ExprContinue = kind_id("rhai", "ExprContinue", true);
export const ExprThrow = kind_id("rhai", "ExprThrow", true);
export const ExprTry = kind_id("rhai", "ExprTry", true);
export const ExprFn = kind_id("rhai", "ExprFn", true);
export const ExprImport = kind_id("rhai", "ExprImport", true);
export const ExprExportIdent = kind_id("rhai", "ExprExportIdent", true);
export const ExprDeclareVar = kind_id("rhai", "ExprDeclareVar", true);
export const ExprCall = kind_id("rhai", "ExprCall", true);
export const ExprDotAccess = kind_id("rhai", "ExprDotAccess", true);
export const ExprBinary = kind_id("rhai", "ExprBinary", true);
export const ExprUnary = kind_id("rhai", "ExprUnary", true);
export const binop = kind_id("rhai", "binop", true);
export const ExprParen = kind_id("rhai", "ExprParen", true);
export const ExprArray = kind_id("rhai", "ExprArray", true);
export const ExprObject = kind_id("rhai", "ExprObject", true);
export const ObjectField = kind_id("rhai", "ObjectField", true);
export const ExprIndex = kind_id("rhai", "ExprIndex", true);
export const ExprClosure = kind_id("rhai", "ExprClosure", true);
export const ClosureParamList = kind_id("rhai", "ClosureParamList", true);
export const ArgList = kind_id("rhai", "ArgList", true);
export const ParamList = kind_id("rhai", "ParamList", true);
export const Param = kind_id("rhai", "Param", true);
export const Path = kind_id("rhai", "Path", true);
export const ExprPath = kind_id("rhai", "ExprPath", true);
export const ExprIdent = kind_id("rhai", "ExprIdent", true);
export const ExprLit = kind_id("rhai", "ExprLit", true);
export const Lit = kind_id("rhai", "Lit", true);
export const LitUnit = kind_id("rhai", "LitUnit", true);
export const ident = kind_id("rhai", "ident", true);
export const lit_str = kind_id("rhai", "lit_str", true);
export const lit_int = kind_id("rhai", "lit_int", true);
export const lit_float = kind_id("rhai", "lit_float", true);
export const lit_bool = kind_id("rhai", "lit_bool", true);
export const comment_line_doc = kind_id("rhai", "comment_line_doc", true);
export const comment_block_doc = kind_id("rhai", "comment_block_doc", true);
export const DefModuleInline = kind_id("rhai", "DefModuleInline", true);
export const DefStmt = kind_id("rhai", "DefStmt", true);
export const Def = kind_id("rhai", "Def", true);
export const DefItem = kind_id("rhai", "DefItem", true);
export const DefConst = kind_id("rhai", "DefConst", true);
export const DefLet = kind_id("rhai", "DefLet", true);
export const DefFn = kind_id("rhai", "DefFn", true);
export const Type = kind_id("rhai", "Type", true);
export const TypeIdent = kind_id("rhai", "TypeIdent", true);
export const TypeLit = kind_id("rhai", "TypeLit", true);
export const TypeTuple = kind_id("rhai", "TypeTuple", true);
export const TypeArray = kind_id("rhai", "TypeArray", true);
export const TypeObject = kind_id("rhai", "TypeObject", true);
export const TypeObjectField = kind_id("rhai", "TypeObjectField", true);
export const TypeUnion = kind_id("rhai", "TypeUnion", true);
export const TypeUnknown = kind_id("rhai", "TypeUnknown", true);
export const TypeList = kind_id("rhai", "TypeList", true);
export const TypeGenerics = kind_id("rhai", "TypeGenerics", true);
export const TypedParamList = kind_id("rhai", "TypedParamList", true);
export const TypedParam = kind_id("rhai", "TypedParam", true);
export const kw_module = kind_id("rhai", "module", false);
export const lbrace = kind_id("rhai", "{", false);
export const rbrace = kind_id("rhai", "}", false);
export const lparen = kind_id("rhai", "(", false);
export const rparen = kind_id("rhai", ")", false);
export const lbracket = kind_id("rhai", "[", false);
export const rbracket = kind_id("rhai", "]", false);
export const hash = kind_id("rhai", "#", false);
export const hash_lbrace = kind_id("rhai", "#{", false);
export const comma = kind_id("rhai", ",", false);
export const semi = kind_id("rhai", ";", false);
export const colon = kind_id("rhai", ":", false);
export const colon_colon = kind_id("rhai", "::", false);
export const dot = kind_id("rhai", ".", false);
export const qdot = kind_id("rhai", "?.", false);
export const assign = kind_id("rhai", "=", false);
export const arrow = kind_id("rhai", "->", false);
export const fat_arrow = kind_id("rhai", "=>", false);
export const plus = kind_id("rhai", "+", false);
export const minus = kind_id("rhai", "-", false);
export const star = kind_id("rhai", "*", false);
export const pow = kind_id("rhai", "**", false);
export const slash = kind_id("rhai", "/", false);
export const percent = kind_id("rhai", "%", false);
export const eq_eq = kind_id("rhai", "==", false);
export const not_eq = kind_id("rhai", "!=", false);
export const lt = kind_id("rhai", "<", false);
export const gt = kind_id("rhai", ">", false);
export const lt_eq = kind_id("rhai", "<=", false);
export const gt_eq = kind_id("rhai", ">=", false);
export const and_and = kind_id("rhai", "&&", false);
export const or_or = kind_id("rhai", "||", false);
export const bang = kind_id("rhai", "!", false);
export const amp = kind_id("rhai", "&", false);
export const pipe = kind_id("rhai", "|", false);
export const caret = kind_id("rhai", "^", false);
export const shl = kind_id("rhai", "<<", false);
export const shr = kind_id("rhai", ">>", false);
export const plus_assign = kind_id("rhai", "+=", false);
export const minus_assign = kind_id("rhai", "-=", false);
export const star_assign = kind_id("rhai", "*=", false);
export const slash_assign = kind_id("rhai", "/=", false);
export const percent_assign = kind_id("rhai", "%=", false);
export const shl_assign = kind_id("rhai", "<<=", false);
export const shr_assign = kind_id("rhai", ">>=", false);
export const and_assign = kind_id("rhai", "&=", false);
export const or_assign = kind_id("rhai", "|=", false);
export const xor_assign = kind_id("rhai", "^=", false);
export const null_coalesce = kind_id("rhai", "??", false);
export const range = kind_id("rhai", "..", false);
export const range_eq = kind_id("rhai", "..=", false);
export const kw_if = kind_id("rhai", "if", false);
export const kw_else = kind_id("rhai", "else", false);
export const kw_for = kind_id("rhai", "for", false);
export const kw_in = kind_id("rhai", "in", false);
export const kw_while = kind_id("rhai", "while", false);
export const kw_loop = kind_id("rhai", "loop", false);
export const kw_do = kind_id("rhai", "do", false);
export const kw_until = kind_id("rhai", "until", false);
export const kw_switch = kind_id("rhai", "switch", false);
export const kw_return = kind_id("rhai", "return", false);
export const kw_break = kind_id("rhai", "break", false);
export const kw_continue = kind_id("rhai", "continue", false);
export const kw_throw = kind_id("rhai", "throw", false);
export const kw_try = kind_id("rhai", "try", false);
export const kw_catch = kind_id("rhai", "catch", false);
export const kw_fn = kind_id("rhai", "fn", false);
export const kw_private = kind_id("rhai", "private", false);
export const kw_let = kind_id("rhai", "let", false);
export const kw_const = kind_id("rhai", "const", false);
export const kw_export = kind_id("rhai", "export", false);
export const kw_import = kind_id("rhai", "import", false);
export const kw_as = kind_id("rhai", "as", false);
export const expression_statement = kind_id("rhai", "expression_statement", false);
export const DefModule = kind_id("rhai", "DefModule", false);

const map = kind_ids_map(
	"sql",
	[
		"source_file",
		"select_statement",
		"select_clause",
		"select_clause_body",
		"select_subexpression",
		"from_clause",
		"where_clause",
		"having_clause",
		"order_by_clause",
		"limit_clause",
		"with_clause",
		"cte",
		"group_by_clause",
		"group_expression",
		"join_clause",
		"join_type",
		"join_condition",
		"boolean_expression",
		"binary_expression",
		"binary_operator",
		"in_expression",
		"tuple",
		"is_expression",
		"order_expression",
		"conditional_expression",
		"identifier",
		"dotted_name",
		"argument_reference",
		"named_parameter",
		"literal_parameter",
		"positional_parameter",
		"alias",
		"function_call",
		"string",
		"number",
		"comment",
		"NULL",
		"TRUE",
		"FALSE",
		"ASC",
		"DESC",
		"AND",
		"OR",
		"IN",
		"IS",
		"NOT",
		"ON",
		"JOIN",
		"LEFT",
		"RIGHT",
		"FULL",
		"INNER",
		"OUTER",
		"AS",
		"DISTINCT",
		"CASE",
		"WHEN",
		"THEN",
		"ELSE",
		"END",
		"GROUP_BY",
		"ORDER_BY",
		"LIMIT",
		"WHERE",
		"HAVING",
		"FROM",
		"SELECT",
		"WITH",
		";",
		",",
		"=",
		">=",
		">",
		"<=",
		"<",
		"<>",
		"!="
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
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false,
		false
	]
);
export map as map;
export const source_file = kind_id("sql", "source_file", true);
export const select_statement = kind_id("sql", "select_statement", true);
export const select_clause = kind_id("sql", "select_clause", true);
export const select_clause_body = kind_id("sql", "select_clause_body", true);
export const select_subexpression = kind_id("sql", "select_subexpression", true);
export const from_clause = kind_id("sql", "from_clause", true);
export const where_clause = kind_id("sql", "where_clause", true);
export const having_clause = kind_id("sql", "having_clause", true);
export const order_by_clause = kind_id("sql", "order_by_clause", true);
export const limit_clause = kind_id("sql", "limit_clause", true);
export const with_clause = kind_id("sql", "with_clause", true);
export const cte = kind_id("sql", "cte", true);
export const group_by_clause = kind_id("sql", "group_by_clause", true);
export const group_expression = kind_id("sql", "group_expression", true);
export const join_clause = kind_id("sql", "join_clause", true);
export const join_type = kind_id("sql", "join_type", true);
export const join_condition = kind_id("sql", "join_condition", true);
export const boolean_expression = kind_id("sql", "boolean_expression", true);
export const binary_expression = kind_id("sql", "binary_expression", true);
export const binary_operator = kind_id("sql", "binary_operator", true);
export const in_expression = kind_id("sql", "in_expression", true);
export const tuple = kind_id("sql", "tuple", true);
export const is_expression = kind_id("sql", "is_expression", true);
export const order_expression = kind_id("sql", "order_expression", true);
export const conditional_expression = kind_id("sql", "conditional_expression", true);
export const identifier = kind_id("sql", "identifier", true);
export const dotted_name = kind_id("sql", "dotted_name", true);
export const argument_reference = kind_id("sql", "argument_reference", true);
export const named_parameter = kind_id("sql", "named_parameter", true);
export const literal_parameter = kind_id("sql", "literal_parameter", true);
export const positional_parameter = kind_id("sql", "positional_parameter", true);
export const alias = kind_id("sql", "alias", true);
export const function_call = kind_id("sql", "function_call", true);
export const string = kind_id("sql", "string", true);
export const number = kind_id("sql", "number", true);
export const comment = kind_id("sql", "comment", true);
export const NULL = kind_id("sql", "NULL", false);
export const TRUE = kind_id("sql", "TRUE", false);
export const FALSE = kind_id("sql", "FALSE", false);
export const ASC = kind_id("sql", "ASC", false);
export const DESC = kind_id("sql", "DESC", false);
export const AND = kind_id("sql", "AND", false);
export const OR = kind_id("sql", "OR", false);
export const IN = kind_id("sql", "IN", false);
export const IS = kind_id("sql", "IS", false);
export const NOT = kind_id("sql", "NOT", false);
export const ON = kind_id("sql", "ON", false);
export const JOIN = kind_id("sql", "JOIN", false);
export const LEFT = kind_id("sql", "LEFT", false);
export const RIGHT = kind_id("sql", "RIGHT", false);
export const FULL = kind_id("sql", "FULL", false);
export const INNER = kind_id("sql", "INNER", false);
export const OUTER = kind_id("sql", "OUTER", false);
export const AS = kind_id("sql", "AS", false);
export const DISTINCT = kind_id("sql", "DISTINCT", false);
export const CASE = kind_id("sql", "CASE", false);
export const WHEN = kind_id("sql", "WHEN", false);
export const THEN = kind_id("sql", "THEN", false);
export const ELSE = kind_id("sql", "ELSE", false);
export const END = kind_id("sql", "END", false);
export const GROUP_BY = kind_id("sql", "GROUP_BY", false);
export const ORDER_BY = kind_id("sql", "ORDER_BY", false);
export const LIMIT = kind_id("sql", "LIMIT", false);
export const WHERE = kind_id("sql", "WHERE", false);
export const HAVING = kind_id("sql", "HAVING", false);
export const FROM = kind_id("sql", "FROM", false);
export const SELECT = kind_id("sql", "SELECT", false);
export const WITH = kind_id("sql", "WITH", false);
export const semi = kind_id("sql", ";", false);
export const comma = kind_id("sql", ",", false);
export const eq = kind_id("sql", "=", false);
export const gte = kind_id("sql", ">=", false);
export const gt = kind_id("sql", ">", false);
export const lte = kind_id("sql", "<=", false);
export const lt = kind_id("sql", "<", false);
export const neq = kind_id("sql", "<>", false);
export const not_eq = kind_id("sql", "!=", false);

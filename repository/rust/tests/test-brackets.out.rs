let is_stop = has_stop && stop_kinds.unwrap_or(&[])
	.iter()
	.any(|k| *k == kind_id);
let is_continue_allowed = !has_continue || continue_kinds.unwrap_or(&[])
	.iter()
	.any(|k| *k == kind_id);

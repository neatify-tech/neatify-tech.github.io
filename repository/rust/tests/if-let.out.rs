fn pick(opt: Option<i32>) -> i32 {
	if let Some(v) = opt {
		v
	}
	else {
		0
	}
}

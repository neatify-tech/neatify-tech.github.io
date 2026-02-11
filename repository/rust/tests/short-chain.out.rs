fn short(items: Vec<i32>) -> Vec<i32> {
	items.iter()
		.map(|x| x + 1)
		.collect()
}

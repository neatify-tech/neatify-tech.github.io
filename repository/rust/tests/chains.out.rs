fn build(items: Vec<i32>) -> Vec<i32> {
	items.into_iter()
		.map(|x| x + 1)
		.filter(|x| x % 2 == 0)
		.enumerate()
		.map(|(idx, v)| v + idx as i32)
		.take(100)
		.collect()
}

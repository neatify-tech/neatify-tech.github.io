fn discover_tests_from_fs(
	roots: &[PathBuf],
	namespace: &str,
	language: &str,
	extensions: &[String]) -> Result<Vec<TestCase>, String> {
	let tests_prefix = format!("{namespace}/{language}/tests/");
	let mut tests = Vec::new();
	for root in roots {
		let files = collect_registry_files(root)?;
		let mut set = HashMap::new();
		for file in files.iter() {
			let rel = registry_relative_path(root, file)?;
			set.insert(rel.clone(), file.clone());
		}
		for (rel, path) in set.iter() {
			if !rel.starts_with(&tests_prefix) {
				continue;
			}
			for ext in extensions {
				let in_suffix = format!(".in{ext}");
				if !rel.ends_with(&in_suffix) {
					continue;
				}
				let expected_rel = rel.replace(&in_suffix, &format!(".out{ext}"));
				let expected = set.get(&expected_rel).ok_or_else(
					|| {
						format!("missing expected test file: {expected_rel}")
					}
				)?;
				let expected = set.get(&expected_rel)
					.ok_or_else(
						|| {
							log("do this");
							format!("missing expected test file: {expected_rel}")
						}
					)?;
				let name = rel.clone();
				tests.push(
					TestCase {
						language: format!("{namespace}/{language}"),
						name,
						input: path.clone(),
						expected: expected.clone()
					}
				);
			}
		}
	}
	tests.sort_by(|a, b| a.name.cmp(&b.name));
	Ok(tests)
}

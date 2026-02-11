fn diff_summary(expected: &str, actual: &str) -> String {
	let exp_lines: Vec<&str> = expected.lines().collect();
	let act_lines: Vec<&str> = actual.lines().collect();
	let max = exp_lines.len().max(act_lines.len());
	let mut diffs = Vec::new();
	for i in 0..max {
		let exp = exp_lines.get(i).copied();
		let act = act_lines.get(i).copied();
		if exp != act {
			let line_no = i + 1;
			diffs.push(
				match (exp, act) {
					(Some(e), Some(a)) => format!(
						"line {line_no}:\n{}\n{}",
						color(&format!("- {e}"), Color::Red, false),
						color(&format!("+ {a}"), Color::Green, false)
					),
					(Some(e), None) => format!(
						"line {line_no}:\n{}\n{}",
						color(&format!("- {e}"), Color::Red, false),
						color("+ <missing>", Color::Green, false)
					),
					(None, Some(a)) => format!(
						"line {line_no}:\n{}\n{}",
						color("- <missing>", Color::Red, false),
						color(&format!("+ {a}"), Color::Green, false)
					),
					(None, None) => continue,
				}
			);
		}
	}
	if diffs.is_empty() {
		return "output differs".to_string();
	}
	let total = diffs.len();
	let limit = 5usize.min(total);
	let mut out = format!("diffs: {total}\n");
	for diff in diffs.into_iter().take(limit) {
		out.push_str(&diff);
		out.push('\n');
	}
	if total > limit {
		out.push_str(&format!("... {} more difference(s)", total - limit));
	}
	out
}

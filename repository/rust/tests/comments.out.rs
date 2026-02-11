fn comments() {
	// start
	let x = 1;
	// note
	/* block
	comment */
	let y = 2; // end
	x + y
	/// Override local cache root
}

struct Cli {
	/// Override local cache root
	#[arg(long = "local", value_name = "PATH")]
	local_root: Option<String>,
}

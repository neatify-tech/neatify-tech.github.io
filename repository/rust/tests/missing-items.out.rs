extern crate alloc;

mod inner {
	pub const X: i32 = 1;
	pub static mut Y: usize = 0;
}

const ANSWER: i32 = 42;

static mut COUNT: usize = 0;

type Alias = Result<i32, i32>;

union U {
	a: u32,
	b: f32,
}

extern "C" {
	fn printf(fmt: *const i8, ...);
}

macro_rules! m {
	($e:expr) => {
		$e
	};
}

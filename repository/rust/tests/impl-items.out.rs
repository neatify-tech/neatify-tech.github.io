impl Foo {
	fn new() -> Self {
		Self {}
	}
	fn with<T: Send>(t: T) -> Self
	where T: Send {
		Self {}
	}
}

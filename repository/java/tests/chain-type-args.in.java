class ChainTypeArgs {
	public void run() {
		Foo.<Bar>baz().qux();
	}

	static class Foo {
		static <T> Foo baz() {
			return new Foo();
		}

		Foo qux() {
			return this;
		}
	}

	static class Bar {
	}
}

use crate::foo::*;

enum State {
	On,
	Off,
}

trait Greeter {
	fn hi(&self) -> String;
}

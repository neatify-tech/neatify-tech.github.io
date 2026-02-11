class ChainError {
	void run() {
		obj.get()
			.next(,   ???)
			.andThenDoSomethingLonger()
			.andThenDoAnotherThing()
			.andThenDoOneMoreThing()
			.finalize();
	}
}

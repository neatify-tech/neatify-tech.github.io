public class Sample {
	public void run() {
		if (true) { // if c
			call();
		}
		else if (false) { // else if c
		}
		else { // else c
		}
		for (int i = 0; i < 1; i++) { // for c
			call();
		}
		while (true) { // while c
			call();
		}
		synchronized (this) { // sync c
			call();
		}
		try { // try c
		}
		catch (Exception e) { // catch c
		}
		finally { // finally c
		}
		switch (1) { // switch c
			default:
				call();
		}
		for (Object o : objects) { // foreach c
		}
	}

	public static void call() {
	}
}

public class Sample {
	public void run() throws Exception {
		try {
			call();
		}
		catch (Exception ex) {
			call();
		}
		try (java.io.ByteArrayInputStream in1 = new java.io.ByteArrayInputStream(new byte[0]);
				java.io.ByteArrayInputStream in2 = new java.io.ByteArrayInputStream(new byte[0])) {
			call();
		}
		catch (java.io.IOException ex) {
			call();
		}
	}
}

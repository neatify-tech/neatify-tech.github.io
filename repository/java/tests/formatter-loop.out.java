class FormatterLoop {
	private String append(String content, Boolean ensureNewline) {
		String read = "";
		return write(
			"path",
			(read == null ? "" : read + (ensureNewline != null
					&& ensureNewline
					&& !read.endsWith("\n")
					&& !read.isEmpty()
				? "\n"
				: "")) + content
		);
	}

	private String prepend(String content) {
		String read = "";
		return write("path", content + (read == null ? "" : "\n" + read));
	}

	private String write(String path, String content) {
		return path + content;
	}
}

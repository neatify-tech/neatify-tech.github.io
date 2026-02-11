import java.util.List;

public class EmbeddedChains {
	public void run(Service svc, List<String> list) {
		svc.getClient().register(new Callback(){@Override public void onDone(String v){System.out.println(v);}}, x -> { return x.trim();}).close();
		list.stream().filter(s -> {s = s.trim(); return !s.isEmpty();}).map(s -> s.toUpperCase()).forEach(s -> System.out.println(s));
		Foo foo = new Foo(){@Override public String toString(){ return "x";}};
		Builder.builder().withA(1).withB( new Bar(){@Override public int size(){return 1;}}).build();
		boolean ok = list != null && list.stream().anyMatch(s -> s != null && s.startsWith("x"));
		Runnable r = () -> { new Thread(() -> System.out.println("hi")).start(); };
	}
}

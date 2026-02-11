import java.lang.annotation.ElementType;
import java.lang.annotation.Target;
import java.util.List;
import java.util.Map;

class GenericsSpacing <  T ,U> {
	private Map<  T,    U> map;
	private List<@Anno("x, y") String /* c1 */> annotated;
	private Map<
		/* k */ String,
		@Anno("a>b") List</* inner */ Integer>
	> multiline;
	private Map< List< String >, List< List< String > >  > deep;

	public List<  Map<  T , U > > build(Map<  T ,U> input) {
		return List.< Map< T ,U> >of(input);
	}
}

@Target(ElementType.TYPE_USE)
@interface Anno {
	String value();
}

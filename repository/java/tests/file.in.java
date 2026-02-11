public class File {
    public static void call(int... values) {
        System.out.println(values.length);
    }

    public static void callStrings(String... values) {
        System.out.println(values.length);
    }

/**
 * Main entry point.
 *
 *  - Uses the formatter demo data.
 *    Indented line with extra spaces.
 */
    public static void main(String[] args){
        int a=0;
    int b=1;
        int c=2;
        int d=3;
        int e=4;
        int f=5;
        int g=6;
        int h=7;
        int i=8;
        int j=9;
        int k=10;
        int l=11;
		Runnable m=s -> {System.out.println("test");};
		Runnable n=() -> {System.out.println("test");};
Runnable o =s->System.out.println("test");
        String s = args.length > 0 ? args[0] : "this string is a bit long";
        String t = args.length > 1 ? args[1] : "this string is not too long";
        String u = args.length > 2 ? args[2] : "but this string is more";
        String v = args.length > 3 ? args[3] : "than this string?";
	if    (false) System.out.println("not true!");

        if(true)
        {
            call(a,b,c);
			} else if ("this string is a bit long" == "this string is not too long" && "but this string is more" == "than this string?") {System.out.println("yes!");
        } else {
            call( a ,b );
        }
        while(s.equals("this string is a bit long") && t.equals("this string is not too long") && u.equals("but this string is more") && v.equals("than this string?"))			{
			call(a,b);
		}
		switch(a){
		case 0: return true;
		case 1: System.out.println("true");
		break;
		default:
			System.out.println("else");
		}
	//comment here?
        try{
            call(a,b,c,d,e,f,g,h,i,j,k,l);//sticky comment
        } catch(Exception ex){
            call(a,b);
        }
        try(java.io.ByteArrayInputStream in1 = new java.io.ByteArrayInputStream(new byte[0]); java.io.ByteArrayInputStream in2 = new java.io.ByteArrayInputStream(new byte[0]); java.io.ByteArrayInputStream in3 = 	new java.io.ByteArrayInputStream(new byte[0])) {
            call(a,b);
        } catch (  java.io.IOException ex) {            call(a,b);
        }
     String textBlock = """
         line one
           line two (indented)
             line three (indented enough for a tab)
         line four
            """;
		List.of().stream().filter(s -> { s.doIt(); return false;}).map(s -> s.mapThisToSomethingElse()).map(s -> s.andThenToThis()).map(s -> s.andThisToo()).map(s -> s.dontForgetThis()).toList();
		stream.filter(s -> { s.doIt(); return false;}).map(s -> s.simple()).toList();
        System.out.println(textBlock);
        // comment: call( a , b ) should stay inside comment
        call(a, b); // trailing comment
        callStrings("alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel", "india", "juliet", "kilo", "lima", "mike", "november", "oscar");
        call(a,b);
	/*
	multiline comment call (a,,  b)
	  more content here
	    with extra indent
	*/
        call(a, b, c, d, e, f, g, h, i, j, k, l, a, b, c, d, e, f, g, h, i, j, k, l);
        call(a, b, c, d, e, f, g, h, i, j, k,  l);


a.doThis().thenThis().andThis();
				b.doThis().thenThis().thenCallStrings("alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel", "india", "juliet", "kilo", "lima", "mike").andThis();
    }
}
class TernarySample {
public void run(boolean a, boolean b, boolean c, boolean d, boolean e) {
int x=a?0:1;
String ok=a && b ? "ok" : "no";
String longValue=a && b && c && d && e && a && b ? "long-yes" : "long-no";
int nested=a ? (b ? 1:2) : (c ? 3:4);
String call=a ? someMethod("a", "b", "c", "d") : otherCall();
String wrapped=a && b && c && d && e ? reallyLongMethodNameWithManyCharactersAndParts() : "short";
}
private String someMethod(String paramOne, String paramTwo, String paramThree, String paramFour){
return paramOne + paramTwo + paramThree + paramFour;
}
private String otherCall(){return "other";}
private String reallyLongMethodNameWithManyCharactersAndParts(){return "long";}
}

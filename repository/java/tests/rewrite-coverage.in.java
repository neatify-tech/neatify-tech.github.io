public class Sample {
public void run(int a) throws Exception{
int x=1;
call (a);//sticky comment
if(true) call(); else call();
for(int i = 0; i < 3; i++){call();}
while(a < 3){call();}
synchronized(this){call();}
if(true){call();}call();
try(java.io.ByteArrayInputStream in=new java.io.ByteArrayInputStream(new byte[0])){call();}catch(Exception ex){call();}
int value=switch(a){default -> 1;};
}
public static void call(int ... values){}
}

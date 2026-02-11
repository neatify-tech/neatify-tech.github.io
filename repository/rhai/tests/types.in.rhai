let config:{path:string,retries:i64,flags:[bool]}=#{path:"x",retries:3,flags:[true,false]};
fn handle(item:(i64,{tag:string,meta:{id:i64,ok:bool}}))->(i64,bool);

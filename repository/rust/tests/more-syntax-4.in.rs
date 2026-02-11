use crate :: foo :: { bar :: { A ,  B } , baz ::  C };
enum   Mode{ Fast , // speed
Slow ,Custom }
trait   Worker{fn run<T>(&self,job:T)->Result<(),()> where  T:Send{Ok(())}}

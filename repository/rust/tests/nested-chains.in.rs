fn nested(items:Vec<i32>)->Vec<i32>{
wrap(items.into_iter().map(|x|{x+1}).filter(|x|x%2==0).enumerate().map(|(idx,v)|{v+idx}).collect()).trim().to_string().into_bytes().into_iter().take(10).collect()
}

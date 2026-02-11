fn closure_inline_ref(items: Vec<i32>) -> Vec<&mut i32> {
 items.iter_mut().map( |x | & mut    x)
.collect()
}

fn closure_params() {
    let f = |(a, b): (i32, i32), x: Option<(i32, i32)>| a + b + x.unwrap().0;
}

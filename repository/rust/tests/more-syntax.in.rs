use crate::foo::{Bar, Baz};

struct Point {
x: i32,
    y: i32,
}

impl Point {
    fn new(x: i32, y: i32) -> Self {
        Self { x, y }
    }
}

fn demo(items: Vec<i32>) -> i32 {
    for i in items {        if i > 1 {       return i;        }    }
    match 1 {
        1 => 2,
        _ => 3,
    }
}

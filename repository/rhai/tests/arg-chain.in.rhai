let out = sink(make().with(arg().trim().to_int()).and_then(ready()).and_then(cache()).build()).finish();

enum Msg {
    Ping,
    Pong(u8),
    Data { id: u32, value: i64 },
}

trait Service {
    fn ping(&self) -> Result<(), ()> {
        Ok(())
    }
    fn notify(&self, msg: Msg);
}

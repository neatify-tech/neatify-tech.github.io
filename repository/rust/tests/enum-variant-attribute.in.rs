#[derive(Debug)]
pub enum Status {
    #[serde(rename="ok")]
    Ok,
    #[serde(rename = "error")]
    Error,
}

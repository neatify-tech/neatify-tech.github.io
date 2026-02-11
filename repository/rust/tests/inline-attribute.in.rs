#[derive(Clone, Debug, Deserialize)]
pub struct LanguageSpec {
    pub name: String,
    pub version:                String,
    pub formatter: String,
    #[serde(rename = "fragment-marker")]
    pub fragment_marker: Option <   String>,
    pub extensions: Vec<String>,
    pub    treesitter:    TreesitterSpec,
}

import "rhai/kinds.rhai" as kinds;
import "rhai/configuration.rhai" as configuration;
import "shared/whitespace.rhai" as whitespace;
import "shared/comments.rhai" as comments;

fn doc_concat_list(docs) {
    if docs.len() == 0 {
        return doc_text("");
    }
    if docs.len() == 1 {
        return docs[0];
    }
    doc_concat(docs)
}

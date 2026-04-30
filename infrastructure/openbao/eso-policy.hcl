# ESO can read and list secrets under secret/
path "secret/data/*" {
capabilities = ["read", "list"]
}
path "secret/metadata/*" {
capabilities = ["read", "list"]
}
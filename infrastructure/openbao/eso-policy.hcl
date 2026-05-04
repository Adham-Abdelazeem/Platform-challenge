path "secret/data/*" {
  capabilities = ["read", "list", "create", "update"]
}
path "secret/metadata/*" {
  capabilities = ["read", "list", "create", "update", "delete"]
}
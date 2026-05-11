path "secret/data/*" {
  capabilities = ["read", "list", "create", "update"]
}
path "secret/metadata/*" {
  capabilities = ["read", "list", "create", "update", "delete"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "secret/data/app/k8s-generated" {
  capabilities = ["create", "update", "read", "delete"]
}
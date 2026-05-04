# Platform Challenge — Runbook

---

## 1. Create the Cluster

```bash
k3d cluster create platform-challenge \
  --agents 3 \
  --k3s-arg "--disable=traefik@server:0" \
  --port "443:443@loadbalancer" \ 
  --port "80:80@loadbalancer"
```

!! Choose different port numbers if you are using 80 , 443 already
---

## 2. Install Core Infrastructure

```bash
# Apply namespaces
kubectl apply -f infrastructure/namespaces/namespaces.yaml

# Install Argo CD - this is only one-time installaton
helm repo add argo https://argoproj.github.io/argo-helm && helm repo update
helm install argocd argo/argo-cd \
  --namespace argocd \
  --values bootstrap/argocd-values.yaml

# Bootstrap root application (App of Apps design)
kubectl apply -f bootstrap/root-application.yaml
```

---

## 3. Access the Argo CD Dashboard

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open: **<https://localhost:8080>**

- **User:** `admin`
- **Password:**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

!!password could be changed later
---

## 4. Initialize OpenBao *(once per cluster lifetime)*

Wait until OpenBao pods are running (status will show `0/1` until unsealed).

```bash
kubectl exec -n openbao openbao-0 -- bao operator init \
  -key-shares=5 -key-threshold=3 -format=json > openbao-init.json
```

> ⚠️ **Never commit `openbao-init.json` to Git.** Store it securely offline. otherwise it will crash the pipline

---

## 5. Unseal OpenBao

```bash
kubectl exec -n openbao <pod-name> -- bao operator unseal <key-1>
kubectl exec -n openbao <pod-name> -- bao operator unseal <key-2>
kubectl exec -n openbao <pod-name> -- bao operator unseal <key-3>
```

> !! run it for eachpod
> !! using the same key is not a problem
> ⚠️ OpenBao must be re-unsealed after every cluster restart.

---

## 6. Verify Everything is Working

| Component | Command |
|---|---|
| Argo CD apps | `kubectl get applications -n argocd` |
| OpenBao status | `kubectl exec -n openbao openbao-0 -- bao status` |
| ESO secrets | `kubectl get externalsecrets -A` |
| Postgres replication | `kubectl exec -n postgres postgres-ha-1 -- psql -U postgres -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"` |

**Expected for Postgres:** 2 rows with `state = streaming`.

**Test end-to-end secret injection:**

```bash
APP_POD=$(kubectl get pods -n app -l app=demo-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n app $APP_POD -- env | grep DB_PASSWORD
```

**Expected:** `DB_PASSWORD=supersecret123`

---

**Hope everything would work fine**

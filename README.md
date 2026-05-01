# IKIM Challenge - Production-Grade OpenBao Platform


A Kubernetes platform applying OpenBao for secrets management, GitOps deployment via Argo CD(which is used for K8s), and high-availability (HA) PostgreSQL as the vault backend.

---

## What This Project Builds

A self-healing infrastructure where applications automatically receive their secrets — and every change to the system is tracked, auditable, and recoverable.

| Component | Role | Analogy |
|---|---|---|
| Kubernetes | THe Cluster which runs and schedules all the services | The city |
| Argo CD | Deploys everything from Git , and watch for any updates | The city inspector |
| OpenBao | Encrypted secrets vault | The bank vault |
| PostgreSQL HA | Physical storage for the vault | The steel room |
| External Secrets Operator | Delivers secrets to apps (Translator) | The armored courier |
| cert-manager | Issues and renews TLS certificates | The locksmith |

---

## Architecture

```
Developer → Git Repository → Argo CD (watches Git)
                                  ↓
                     [ Kubernetes Cluster ]
                     ┌─────────────────────────────┐
                     │  Load Balancer (entry point) │
                     │           ↓                  │
                     │       Argo CD                │
                     │           ↓                  │
                     │  cert-manager  |  OpenBao ←→ PostgreSQL HA  │
                     │                       ↓      │
                     │         External Secrets Op. │
                     │                       ↓      │
                     │         App Pod 1 | 2 | 3    │
                     │                              │
                     │  Worker Node 0 | 1 | 2       │
                     └─────────────────────────────┘
```

---

## Build Progress

---

### Phase -1 — Environment Setup
**Date:** 2026-04-25

Set up the local development environment on Ubuntu (VM on Windows).

**What was done:**
- Updated Ubuntu, installed base tools (`curl`, `git`, `jq`, `gnupg`)
- Installed Docker and added user to docker group
- Installed `kubectl`, `helm`, `k3d`, `k9s`, Argo CD CLI
- Configured Git identity and GitLab Personal Access Token

---

### Phase 0 — Repository and Folder Structure
**Date:** 2026-04-26

Created the Git repository and established the folder layout before writing a single config file.

**What was done:**
- Created `platform-challenge` repository on GitLab
- Set up folder structure:
  ```
  platform-challenge/
  ├── bootstrap/        # one-time manual installs (Argo CD)

  ```

---

### Phase 1 — Kubernetes Cluster
**Date:** 2026-04-26

Created a multi-node local Kubernetes cluster using k3d.

**What was done:**
- Created cluster with 1 control-plane node + 3 worker nodes
  ```bash
  k3d cluster create platform-challenge \
    --agents 3 \
    --k3s-arg "--disable=traefik@server:0" \ <- this is disabled here as we would like to manage ingress on ourselves for full control.
    --port "443:443@loadbalancer" \
    --port "80:80@loadbalancer"
  ```
- Verified all 4 nodes in `Ready` state
- Created all namespaces: `argocd`, `openbao`, `postgres`, `external-secrets`, `cert-manager`, `app` (which will be used later in this project)


---

### Phase 2 — Argo CD Bootstrap
**Date:** 2026-04-26

Installed Argo CD.

**What was done:**
- Added Argo CD Helm repo, installed with 2 server replicas and Redis HA enabled (for cache to be on , to prevent fetching the data every time)
- Retrieved and changed the initial admin password, deleted the initial secret from Argo web UI
- Connected Argo CD to this GitHub repository from Argo web UI as well
- Committed all Argo CD values to `bootstrap/`

---

### Phase 3 — cert-manager (TLS Infrastructure)
**Date:** 2026-04-27

Installed cert-manager which is the component that issues and auto-renews TLS certificates inside the cluster. 

**Files created:**
- `apps/cert-manager.yaml`, the Argo CD Application manifest (tells Argo CD to manage cert-manager)
- `infrastructure/cert-manager/release.yaml`, the Helm release definition
- `infrastructure/cert-manager/cluster-issuer.yaml`, the self-signed certificate authority
- `bootstrap/root-application.yaml`,the root App of Apps (deployed here, activates all `apps/`)- which was applied manually 

**What was done:**
- Created the Argo CD root Application manifest (App of Apps pattern) — one root app that discovers and manages all other apps
- Created `values.yaml` with `installCRDs: true` and `replicaCount: 2`
- Created a Helm release manifest for Argo CD to deploy cert-manager from the external chart
- Created a `ClusterIssuer` using `selfSigned`, which acts as the internal certificate authority for all cluster components
- Pushed everything; Argo CD picked it up and deployed cert-manager automatically

---


### Phase 4 — PostgreSQL HA (CloudNativePG)
**Date:** 2026-04-29

Deployed a highly available PostgreSQL cluster using the CloudNativePG (CNPG) operator.

This would be OpenBao's storage backend where all secrets should be there.

**Files created:**
- `infrastructure/postgres/cluster.yaml`,  the actual database cluster (3 instances, storage, backup, bootstrap)
- `apps/cluster-application.yaml`, which is the application which refers to the actual cluster inside infrastructr/postgres/cluster.yaml
- `apps/cnpg-operator-application.yaml`, which is Argo CD Application for the CNPG operator (cluster-wide controller)
- `infrastructure/postgres/credentials-secret.yaml`, refers to the temp openBao secret which is applyied manually 


**What was done:**
- Deployed the CNPG operator first which it teaches Kubernetes what a `Cluster` resource means via CRDs
- Created a 3-instance PostgreSQL cluster: 1 primary + 2 replicas, with automatic failover
- Configured persistent storage using k3d's built-in `local-path` storage class
- Set up a bootstrap database named `openbao` owned by user `openbao`
- Created `openbao-db-credentials` secret manually — bootstrapping requirement before CNPG can create the cluster


---


### Phase 5 — OpenBao (Secrets Vault)
**Date:** 2026-04-30

Deployed OpenBao with PostgreSQL as its storage backend, initialized the vault, unsealed all three instances, and configured the KV secrets engine.

**Files created:**
- `apps/openbao.yaml`, which is an Argo CD Application installing OpenBao from the official Helm chart with inline values

**What was done:**
- Deployed OpenBao in HA mode (3 replicas) from `https://openbao.github.io/openbao-helm`
- Generated 5 unseal keys with a threshold of 3, stored securely outside the repo
- Unsealed all 3 pods individually (each pod requires 3 of the 5 keys independently)
- Enabled the KV v2 secrets engine at path `secret/`
- Stored a test secret at `secret/myapp/config`
- Created `eso-policy` granting read access to `secret/data/*` and `secret/metadata/*`
- Created a long-lived ESO token (768h) with that policy attached


---

### Phase 6 — External Secrets Operator
**Date:** 2026-04-30

Installed ESO and configured it to pull secrets from OpenBao and automatically create Kubernetes Secrets in application namespaces.

**Files created:**
- `apps/eso.yaml`, which isArgo CD Application installing ESO from `https://charts.external-secrets.io`
- `apps/eso-infra.yaml`, which is Argo CD Application deploying the ClusterSecretStore from GitLab
- `infrastructure/eso/secret-store.yaml`which is ClusterSecretStore connecting ESO to OpenBao

**What was done:**
- Installed ESO with `installCRDs: true` and `ServerSideApply: true`
- Created a `ClusterSecretStore` pointing to OpenBao at `http://openbao.openbao.svc.cluster.local:8200`
- Used `http` not `https` as TLS is disabled in the local k3d setup
- Stored the ESO token as a Kubernetes Secret in the `external-secrets` namespace


---

### Phase 7 — Secret Pipeline Verified End_to_End
**Date:** 2026-04-30

Proved the full pipeline works: a secret written to OpenBao automatically appears as a Kubernetes Secret accessible to applications.

**Files created:**
- `workloads/external-secret.yaml` as ExternalSecret pulling `myapp/config` from OpenBao into a Kubernetes Secret named `myapp-secret` in the `app` namespace
- `apps/workloads.yaml`which is an Argo CD Application deploying the workloads folder

**Verification:**
```bash
kubectl get externalsecret myapp-secret -n app
# NAME           STATUS         READY
# myapp-secret   SecretSynced   True

kubectl get secret myapp-secret -n app \
  -o jsonpath="{.data.db_password}" | base64 -d
# myappsecretpassword
```
![Logo](C:\Users\adham\Pictures\Screenshots\Screenshot 2026-05-01 210819.png)

**Full data flow confirmed:**
```
OpenBao (secret stored)
  → ESO authenticates via scoped token + policy
    → ESO reads secret over HTTP
      → Kubernetes Secret created in app namespace
        → Application reads it as environment variable
```

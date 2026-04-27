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
- `infrastructure/cert-manager/values.yaml`, the Helm config
- `infrastructure/cert-manager/release.yaml`, the Helm release definition
- `infrastructure/cert-manager/cluster-issuer.yaml`, the self-signed certificate authority
- `bootstrap/root-application.yaml`,the root App of Apps (deployed here, activates all `apps/`)

**What was done:**
- Created the Argo CD root Application manifest (App of Apps pattern) — one root app that discovers and manages all other apps
- Created `values.yaml` with `installCRDs: true` and `replicaCount: 2`
- Created a Helm release manifest for Argo CD to deploy cert-manager from the external chart
- Created a `ClusterIssuer` using `selfSigned`, which acts as the internal certificate authority for all cluster components
- Pushed everything; Argo CD picked it up and deployed cert-manager automatically

---




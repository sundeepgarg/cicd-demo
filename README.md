# CI/CD Demo — GitHub Actions + ACR + AKS

End-to-end CI/CD pipeline: code push → automated tests → Docker build → Azure deployment.

## Pipeline Flow

```
git push
    │
    ▼
GitHub Actions
    │
    ├─ Job 1: test ──────────────── pytest (every branch)
    │         │
    │         ▼ (pass)
    ├─ Job 2: build ─────────────── docker build → push to ACR (every branch)
    │         │
    │         ▼ (pass + main branch only)
    └─ Job 3: deploy ────────────── kubectl rolling update → AKS
                                    └─ smoke test: curl /health ✅
```

## Azure Infrastructure (Terraform)

```
rg-cicd-demo  (Resource Group)
  ├── cicddemoacr<suffix>  (Azure Container Registry — Basic)
  │     └── cicd-demo:sha-abc1234    ← Docker image built by CI
  │
  └── aks-cicd-demo  (AKS — 1 node, Standard_B2s)
        └── cicd-demo Deployment (2 pods)
              └── Azure LoadBalancer → public IP → internet
```

## Project Structure

```
cicd-demo/
├── app/
│   ├── app.py              Flask app  (GET /, GET /health)
│   ├── test_app.py         pytest tests
│   └── requirements.txt
├── k8s/
│   ├── deployment.yaml     2 replicas, liveness + readiness probes
│   └── service.yaml        LoadBalancer — Azure assigns public IP
├── infra/
│   ├── main.tf             AKS + ACR + role assignment
│   ├── variables.tf
│   └── outputs.tf
├── Dockerfile
├── SETUP.md                ← Start here for first-time setup
└── .github/
    └── workflows/
        ├── ci.yml              Full pipeline (test → build → deploy)
        └── cd-minikube.yml     Local testing variant (Minikube)
```

## Quick Start

See [SETUP.md](SETUP.md) for the full one-time setup.

```powershell
# 1. Provision Azure infra
cd infra
terraform init && terraform apply

# 2. Add 5 secrets to GitHub repo (see SETUP.md)

# 3. Push code → pipeline runs automatically
git push origin main
```

## GitHub Secrets Required

| Secret | Description |
|---|---|
| `AZURE_CREDENTIALS` | Service principal JSON (`az ad sp create-for-rbac --sdk-auth`) |
| `ACR_LOGIN_SERVER` | ACR hostname (e.g. `cicddemoacr123.azurecr.io`) |
| `ACR_USERNAME` | ACR admin username |
| `ACR_PASSWORD` | ACR admin password |
| `AKS_CLUSTER_NAME` | `aks-cicd-demo` |
| `AKS_RESOURCE_GROUP` | `rg-cicd-demo` |

## What Each Pipeline Step Does

| Step | Tool used | Purpose |
|---|---|---|
| `actions/checkout@v4` | GitHub Actions | Downloads code into runner |
| `setup-python` | GitHub Actions | Installs Python 3.11 |
| `pytest app/ -v` | pytest | Runs unit tests — fails fast before Docker build |
| `docker/login-action` | Docker | Authenticates to ACR |
| `docker/build-push-action` | Docker BuildKit | Builds image, pushes `:sha-<7-char>` and `:latest` |
| `azure/login@v2` | Azure CLI | Logs in using service principal from AZURE_CREDENTIALS |
| `azure/aks-set-context@v3` | Azure CLI | Downloads kubeconfig — enables `kubectl` in the runner |
| `sed` + `kubectl apply` | kubectl | Replaces image tag in YAML, applies to cluster |
| `kubectl rollout status` | kubectl | Waits for rolling update — fails job if pods crash |
| `curl /health` | curl | Hits live app — confirms deploy worked |

## Run Locally

```bash
# App
pip install -r app/requirements.txt
python app/app.py
curl http://localhost:5000/health

# Tests
pytest app/ -v

# Docker
docker build -t cicd-demo .
docker run -p 5000:5000 cicd-demo

# Kubectl (after az aks get-credentials)
kubectl get pods
kubectl get svc cicd-demo
```

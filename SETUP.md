# Setup Guide — One Time Steps

Run these once. After this, every `git push` to main runs the full pipeline automatically.

---

## Prerequisites

Install these on your laptop if not already present:

```powershell
# Azure CLI
winget install Microsoft.AzureCLI

# Terraform
winget install Hashicorp.Terraform

# kubectl
winget install Kubernetes.kubectl
```

---

## Step 1 — Log in to Azure

```powershell
az login
az account show   # confirm correct subscription
```

---

## Step 2 — Create Azure infrastructure with Terraform

```powershell
cd D:\git_repos\cicd-demo\infra

terraform init
terraform plan    # review what will be created
terraform apply   # type 'yes' when prompted
```

**What gets created:**
- Resource group: `rg-cicd-demo`
- ACR: `cicddemoacr<suffix>.azurecr.io`
- AKS: `aks-cicd-demo` (1 node, Standard_B2s)
- Role assignment: AKS can pull from ACR without imagePullSecret

**After apply, note the outputs:**
```powershell
terraform output                              # shows ACR login server, AKS name etc.
terraform output -raw acr_admin_password      # shows ACR password (sensitive)
```

---

## Step 3 — Create Azure service principal for GitHub Actions

GitHub Actions needs credentials to log in to Azure and deploy to AKS.

```powershell
# Get your subscription ID
$SUBSCRIPTION_ID = az account show --query id -o tsv

# Create service principal with Contributor access to the resource group
az ad sp create-for-rbac `
  --name "cicd-demo-github-actions" `
  --role contributor `
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-cicd-demo" `
  --sdk-auth
```

This outputs a JSON block like:
```json
{
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "...",
  "tenantId": "...",
  ...
}
```

**Copy the entire JSON** — you need it in the next step.

---

## Step 4 — Add GitHub Secrets

Go to: **GitHub repo → Settings → Secrets and variables → Actions → New repository secret**

Add these 5 secrets:

| Secret name | Where to get the value |
|---|---|
| `AZURE_CREDENTIALS` | The full JSON from Step 3 |
| `ACR_LOGIN_SERVER` | `terraform output acr_login_server` (e.g. `cicddemoacr123.azurecr.io`) |
| `ACR_USERNAME` | `terraform output acr_admin_username` |
| `ACR_PASSWORD` | `terraform output -raw acr_admin_password` |
| `AKS_CLUSTER_NAME` | `terraform output aks_cluster_name` (= `aks-cicd-demo`) |
| `AKS_RESOURCE_GROUP` | `terraform output resource_group_name` (= `rg-cicd-demo`) |

---

## Step 5 — Create GitHub repo and push

```powershell
cd D:\git_repos\cicd-demo

# If not already initialised
git init
git add .
git commit -m "initial commit: Flask app + CI/CD pipeline"
git branch -M main

# Create repo on github.com then:
git remote add origin https://github.com/YOUR_USERNAME/cicd-demo.git
git push -u origin main
```

The push triggers the pipeline immediately.

---

## Step 6 — Watch the pipeline run

1. Go to **github.com/YOUR_USERNAME/cicd-demo → Actions**
2. You'll see "CI/CD Pipeline" running
3. Click it to see the 3 jobs: Test → Build → Deploy
4. After Deploy completes, click the environment URL shown to open the live app

---

## Step 7 — Configure kubectl on your laptop (optional)

To run `kubectl` commands against your AKS cluster locally:

```powershell
az aks get-credentials --resource-group rg-cicd-demo --name aks-cicd-demo
kubectl get pods
kubectl get svc cicd-demo   # shows public IP
```

---

## Cost control — stop the cluster when not using it

AKS charges for the VMs even when idle. Stop/start the cluster to save cost:

```powershell
# Stop cluster (stops billing for VMs, free while stopped)
az aks stop --name aks-cicd-demo --resource-group rg-cicd-demo

# Start cluster again
az aks start --name aks-cicd-demo --resource-group rg-cicd-demo
```

**Estimated cost:** ~₹2,500/month if running 24/7. Stop when not using → ~₹300/month.

---

## Tear down everything

```powershell
cd D:\git_repos\cicd-demo\infra
terraform destroy   # deletes AKS + ACR + resource group
```

---

## Troubleshooting

**Pipeline fails at "Log in to ACR" step**
→ Check ACR_LOGIN_SERVER, ACR_USERNAME, ACR_PASSWORD secrets are set correctly

**Pipeline fails at "Get AKS credentials"**
→ Check AZURE_CREDENTIALS is the full JSON (not just clientId)
→ Check service principal has Contributor role on the resource group

**Smoke test fails — no IP yet**
→ First deploy: LoadBalancer IP takes 2–3 minutes. Re-run the deploy job manually.

**Pods in CrashLoopBackOff**
→ Run: `kubectl logs -l app=cicd-demo` to see app error

# Setup Guide — Azure Container Apps

Run these steps once. After this, every `git push` to main deploys automatically.

---

## What gets created

```
Azure
└── rg-cicd-demo  (Resource Group)
    └── cicd-demo-env  (Container Apps Environment — managed hosting layer)
        └── cicd-demo  (Container App — your running app)
              └── public HTTPS URL: https://cicd-demo.<hash>.eastus.azurecontainerapps.io
```

No AKS. No ACR. No Kubernetes to manage.
Image comes from GHCR (free, already set up in ci.yml).

---

## Prerequisites

```powershell
# Install Azure CLI if not already installed
winget install Microsoft.AzureCLI

# Log in
az login
```

---

## Step 1 — Make the GHCR package public

After your first `git push`, GitHub Actions will build and push the Docker image to GHCR.
By default the package is private — Azure Container Apps can't pull it.

Make it public:
1. Go to: **github.com/sundeepgarg → Packages → cicd-demo**
2. Click **Package settings** (bottom right)
3. Scroll to **Danger Zone → Change visibility → Public**

> Do this after the first CI run pushes the image. The build job will succeed even if you haven't done this yet — you only need it before the deploy job runs.

---

## Step 2 — Create Azure infrastructure (one time, ~3 minutes)

```powershell
# Create resource group
az group create --name rg-cicd-demo --location eastus

# Create Container Apps Environment
# This is the managed hosting layer — handles networking, scaling, certificates
az containerapp env create `
  --name cicd-demo-env `
  --resource-group rg-cicd-demo `
  --location eastus

# Create the initial Container App
# Points to :latest image — pipeline will update it with :sha-<commit> on each deploy
az containerapp create `
  --name cicd-demo `
  --resource-group rg-cicd-demo `
  --environment cicd-demo-env `
  --image ghcr.io/sundeepgarg/cicd-demo:latest `
  --target-port 5000 `
  --ingress external `
  --min-replicas 0 `
  --max-replicas 3

# Get the public URL (note this down)
az containerapp show `
  --name cicd-demo `
  --resource-group rg-cicd-demo `
  --query "properties.configuration.ingress.fqdn" `
  --output tsv
```

Open the URL in your browser — you should see the app running.

---

## Step 3 — Create service principal for GitHub Actions

GitHub Actions needs permission to update the Container App on each deploy.

```powershell
$SUB = az account show --query id -o tsv

az ad sp create-for-rbac `
  --name "cicd-demo-github-actions" `
  --role contributor `
  --scopes "/subscriptions/$SUB/resourceGroups/rg-cicd-demo" `
  --sdk-auth
```

Copy the entire JSON output — looks like:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  ...
}
```

---

## Step 4 — Add GitHub Secret (only 1 needed)

Go to: **github.com/sundeepgarg/cicd-demo → Settings → Secrets and variables → Actions → New repository secret**

| Secret name | Value |
|---|---|
| `AZURE_CREDENTIALS` | The full JSON from Step 3 |

That's it. Only 1 secret — compare to AKS which needed 6.

---

## Step 5 — Push code and watch the pipeline

```powershell
cd D:\git_repos\cicd-demo
git add .
git commit -m "add Container Apps deploy"
git push origin main
```

Go to: **github.com/sundeepgarg/cicd-demo → Actions**

You will see 3 jobs run in sequence:
```
1 · Unit Tests          ~1 min
2 · Build & Push        ~2 min
3 · Deploy to ACA       ~1 min
                        ──────
Total                   ~4 min
```

At the end of Job 3, click the environment URL to open your live app.

---

## How to test the full loop

Make a code change and push — watch it deploy automatically:

```python
# app/app.py — change the message
@app.route("/")
def hello():
    return jsonify({"message": "Hello — version 2!", "version": APP_VERSION})
```

```powershell
git add app/app.py
git commit -m "update hello message"
git push origin main
```

Watch Actions → 4 minutes later the live URL shows the new message.

---

## Cost

- **Container Apps Environment:** Free for the first environment per subscription
- **Container App:** Free tier — 180,000 vCPU-seconds + 360,000 GB-seconds per month
- **min-replicas 0:** scales to zero when no requests → zero cost when idle

Effectively free for a learning project.

---

## Tear down

```powershell
az group delete --name rg-cicd-demo --yes
```

Deletes everything including the Container App and Environment.

---

## Troubleshooting

**Job 3 fails: "containerapp not found"**
→ The initial `az containerapp create` in Step 2 hasn't been run yet.

**Job 3 fails: "unauthorized" pulling image**
→ GHCR package is still private. Follow Step 1.

**Smoke test fails with connection refused**
→ Container is still starting. Increase `sleep 15` to `sleep 30` in ci.yml.

**App returns 502**
→ Flask is crashing. Check logs:
```powershell
az containerapp logs show --name cicd-demo --resource-group rg-cicd-demo --tail 50
```

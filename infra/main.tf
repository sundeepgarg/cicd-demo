terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

# Short random suffix so ACR name is globally unique
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# ── Resource Group ──────────────────────────────────────────────────────────
resource "azurerm_resource_group" "cicd" {
  name     = var.resource_group_name
  location = var.location
}

# ── Azure Container Registry ────────────────────────────────────────────────
resource "azurerm_container_registry" "acr" {
  name                = "cicddemoacr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.cicd.name
  location            = azurerm_resource_group.cicd.location
  sku                 = "Basic"
  admin_enabled       = true   # enables username/password for GitHub Actions login
}

# ── AKS Cluster ─────────────────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-cicd-demo"
  resource_group_name = azurerm_resource_group.cicd.name
  location            = azurerm_resource_group.cicd.location
  dns_prefix          = "cicd-demo"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"   # 2 vCPU, 4 GB RAM — cheapest that runs 2 pods
  }

  # SystemAssigned identity — AKS manages its own service principal
  identity {
    type = "SystemAssigned"
  }
}

# ── Attach ACR to AKS ───────────────────────────────────────────────────────
# Grants AKS kubelet identity the AcrPull role on ACR
# This means pods can pull images from ACR without imagePullSecret
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

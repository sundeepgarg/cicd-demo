output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "ACR login server — add as GitHub secret ACR_LOGIN_SERVER"
}

output "acr_admin_username" {
  value       = azurerm_container_registry.acr.admin_username
  description = "ACR admin username — add as GitHub secret ACR_USERNAME"
}

output "acr_admin_password" {
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
  description = "Run: terraform output -raw acr_admin_password — add as GitHub secret ACR_PASSWORD"
}

output "aks_cluster_name" {
  value       = azurerm_kubernetes_cluster.aks.name
  description = "AKS cluster name — add as GitHub secret AKS_CLUSTER_NAME"
}

output "resource_group_name" {
  value       = azurerm_resource_group.cicd.name
  description = "Resource group name — add as GitHub secret AKS_RESOURCE_GROUP"
}

output "get_credentials_command" {
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.cicd.name} --name ${azurerm_kubernetes_cluster.aks.name}"
  description = "Run this to configure kubectl on your local machine"
}

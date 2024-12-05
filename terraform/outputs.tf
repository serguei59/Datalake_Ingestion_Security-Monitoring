output "client_secret" {
  value     = azuread_service_principal_password.sp_password.value
  sensitive = true
}
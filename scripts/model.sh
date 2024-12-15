#!/bin/bash

set -e

# === Variables ===
RESOURCE_GROUP="rg-preliminary-setup"
LOCATION="francecentral"
KEYVAULT_NAME="terraformAccessKeyVault"
SP_NAME="keyvault-access-sps"
LOG_FILE="setup_preliminary_environment.log"

# === Logging ===
exec > >(tee -i "$LOG_FILE") 2>&1

echo "🔧 Starting Preliminary Setup..."

# === Azure CLI Login Check ===
if ! az account show &>/dev/null; then
    echo "❌ You are not logged into Azure CLI. Run 'az login' and try again."
    exit 1
fi
echo "✅ Azure CLI login verified."

# === Create Resource Group ===
echo "📦 Creating Resource Group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
echo "✅ Resource Group created: $RESOURCE_GROUP"

# === Check and Handle Deleted Key Vault ===
echo "🔍 Checking for existing deleted Key Vault..."
DELETED_KV=$(az keyvault list-deleted --query "[?name=='$KEYVAULT_NAME']" -o tsv)

if [ -n "$DELETED_KV" ]; then
    echo "⚠️ Key Vault '$KEYVAULT_NAME' exists in deleted state. Attempting to purge..."
    az keyvault purge --name "$KEYVAULT_NAME" || {
        echo "❌ Failed to purge Key Vault."
        exit 1
    }
    echo "✅ Key Vault purged successfully."
fi

# === Create Key Vault ===
echo "🔒 Creating Key Vault..."
az keyvault create \
    --name "$KEYVAULT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" || {
    echo "❌ Failed to create Key Vault $KEYVAULT_NAME."
    exit 1
}
echo "✅ Key Vault created successfully."

# === Create Service Principal ===
echo "🛠 Creating Service Principal without role assignment..."
SP_OUTPUT=$(az ad sp create-for-rbac --name "$SP_NAME" --skip-assignment --query "{appId: appId, password: password}" -o json)
SP_CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')
SP_CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.password')
echo "✅ Service Principal created: $SP_NAME"

# === Assign Contributor Role to Key Vault ===
echo "🔑 Assigning Contributor role to Key Vault..."
az role assignment create \
    --assignee "$SP_CLIENT_ID" \
    --role "Contributor" \
    --scope "$(az keyvault show --name "$KEYVAULT_NAME" --query id -o tsv)" || {
    echo "❌ Failed to assign Contributor role to Key Vault."
    exit 1
}
echo "✅ Role Contributor assigned to Service Principal for Key Vault."

# === Set Access Policies for Secrets ===
echo "🔑 Setting Access Policy for Key Vault Secrets..."
az keyvault set-policy \
    --name "$KEYVAULT_NAME" \
    --spn "$SP_CLIENT_ID" \
    --secret-permissions get list || {
    echo "❌ Failed to set Access Policy."
    exit 1
}
echo "✅ Access Policy set for Key Vault Secrets."

# === Store Secrets in Key Vault ===
echo "🔒 Storing sensitive values in Key Vault..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "SP-ClientSecret" --value "$SP_CLIENT_SECRET"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "SubscriptionId" --value "$SUBSCRIPTION_ID"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "TenantId" --value "$TENANT_ID"

unset SP_CLIENT_SECRET
echo "✅ Sensitive variables cleared from memory."

# === Enable Monitoring and Alerts ===
echo "📊 Enabling Monitoring for Key Vault..."
WORKSPACE_ID=$(az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "law-preliminary-setup" \
    --location "$LOCATION" \
    --query id -o tsv)

az monitor diagnostic-settings create \
    --name "KeyVaultLogs" \
    --resource "$(az keyvault show --name "$KEYVAULT_NAME" --query id -o tsv)" \
    --workspace "$WORKSPACE_ID" \
    --logs '[{"category": "AuditEvent","enabled": true}]'
echo "✅ Monitoring enabled for Key Vault."

# Set Alert rules for Key Vault
echo "🚨 Setting Alert Rules for Key Vault..."
if az monitor metrics alert create \
    --name "KeyVaultAccessAlert" \
    --resource-group "$RESOURCE_GROUP" \
    --scopes "$(az keyvault show --name "$KEYVAULT_NAME" --query id -o tsv)" \
    --condition "total > 0 where Category=='AuditEvent'" \
    --description "Alert on Key Vault access" \
    --action-group "<ACTION_GROUP_NAME>"; then
    echo "✅ Alerts configured for Key Vault access."
else
    echo "Failed to configure alerts for Key Vault access."
    exit 1
fi

# === Link Key Vault Diagnostics to Log Analytics Workspace ===
echo "Linking Key Vault diagnostics to Log Analytics Workspace..."
if az monitor diagnostic-settings create \
    --name "KeyVaultLogsToLogAnalytics" \
    --resource "$(az keyvault show --name "$KEYVAULT_NAME" --query id -o tsv)" \
    --workspace "$(az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" --name "$LOG_ANALYTICS_WORKSPACE_NAME" --query id -o tsv)" \
    --logs '[{"category": "AuditEvent","enabled": true}]'; then
    echo "✅ Key Vault diagnostics linked to Log Analytics Workspace."
else
    echo "Failed to link Key Vault diagnostics to Log Analytics Workspace."
    exit 1
fi


echo "🎉 Preliminary setup completed successfully!"

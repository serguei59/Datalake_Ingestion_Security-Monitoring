#!/bin/bash

#------------------------------------------
# Variables and prerequisite
#------------------------------------------
#chemin vers .env
#$0 : représente le chemin du script actuellement exécuté
#dirname "$0" : permet d'obtenir le répertoire où se trouve le script.
ENV_FILE="$(dirname "$0")/../.env"

# Load existing environnment variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo ".env not found, please create one filled with required variables"
    exit 1
fi

# enable logging
LOG_FILE="(dirname "$0")/../setup_environment.log"
exec > >(tee -i $"$LOG_FILE")

# Verify Azure CLI Login
if ! az account show &>/dev/null; then
    echo "You're not logged into Azure Cli.Please run 'az login' and try again"
    exit 1
fi
echo "Azure CLI login verified"

# Check if GitHub CLI is installed
if ! command -v gh &>/dev/null; then
    echo "GitHub CLI is not installed or not in Path."
    echo "Please install it, GitHub CLI: https://cli.github.com/"
    exit 1
fi
echo "GitHub CLI is installed"

#------------------------------------------
# Create Resource Groups
#------------------------------------------
echo "Creating Resource Group: $RESOURCE_GROUP_SECURITY"
if az group create --name "$RESOURCE_GROUP_SECURITY" --location "$LOCATION"; then
    echo "Resource Group $RESOURCE_GROUP_SECURITY created successfully."
else
    echo "Failed to create Resource group $RESOURCE_GROUP_SECURITY."
    exit 1
fi

echo "Creating Resource Group: $RESOURCE_GROUP_TERRAFORM"
if az group create --name "$RESOURCE_GROUP_TERRAFORM" --location "$LOCATION"; then
    echo "Resource Group $RESOURCE_GROUP_TERRAFORM created successfully."
else
    echo "Failed to create Resource group $RESOURCE_GROUP_TERRAFORM."
    exit 1
fi

#------------------------------------------
# Create Key Vault
#------------------------------------------
# Check and handle Deleted Key Vault
echo "Checking for existing deleted Key Vault..."
DELETED_KEYVAULT=$(az keyvault list-deleted --query "[?name=='$KEYVAULT_NAME']" -o tsv)

if [ -n "$DELETED_KEYVAULT" ]; then
    echo "Key Vault $KEYVAULT_NAME exists in deleted state. Attempting to purge..."
    if az keyvault purge --name "$KEYVAULT_NAME"; then
        echo "Key Vault $KEYVAULT_NAME purged successfully."
    else
        echo "Failed to purge Key Vault $KEYVAULT_NAME."
        exit 1
    fi
fi
# Create Key Vault
echo "Creating Key Vault : $KEYVAULT_NAME"
if az keyvault create --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP_SECURITY" --location "$LOCATION" \
    --enable-rbac-authorization false; then
    echo "Key Vault $KEYVAULT_NAME created successfully."
else
    echo "Failed to create Key Vault $KEYVAULT_NAME."
    exit 1
fi

#---------------------------------------------
# Create Storage Account for Terraform Backend
#---------------------------------------------
echo "Creating Storage Account: $STORAGE_ACCOUNT_NAME..."
if az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_TERRAFORM" \
    --location "$LOCATION" \
    --sku Standard_LRS; then
    echo "Storage Account $STORAGE_ACCOUNT_NAME created successfully."
else
    echo "Failed to create Storage Account $STORAGE_ACCOUNT_NAME."
    exit 1
fi

# Create Container for Terraform state
echo "Creating container: $CONTAINER_NAME..."
if az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --auth-mode login; then
    echo "Container $CONTAINER_NAME created successfully."
else
    echo "Failed to create Container $CONTAINER_NAME."
    exit 1
fi

#----------------------------------------------------------------------------
# Create Service Principal SP_KV_NAME for Key Vault Secrets access
#----------------------------------------------------------------------------
# Delete any existing Service Principal
APP_ID=$(az ad sp list --display-name "$SP_KV_NAME" --query "[0].appId" -o tsv)

if [ -n "$APP_ID" ]; then
    echo "Deleting existing Service Principal: $SP_KV_NAME..."
    if az ad sp delete --id "$APP_ID"; then
        echo "Service Principal $SP_KV_NAME deleted successfully."
    else
        echo "Failed to delete Service Principal $SP_KV_NAME."
        exit 1
    fi
fi


# Create Service Principal
echo "Creating Service Principal: $SP_KV_NAME..."
SP_OUTPUT=$(az ad sp create-for-rbac \
    --name "$SP_KV_NAME"  \
    --skip-assignment \
    --query "{appId: appId, password: password}" -o json)
    
# Validate SP_OUTPUT
if [[ -z "$SP_OUTPUT" ]]; then
    echo "Failed to create Service Principal."
    exit 1
fi

# Extract  ClientId and ClientSecret using jq
SP_CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')
SP_CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.password')

if [[ -z "$SP_CLIENT_ID" || -z "$SP_CLIENT_SECRET" ]]; then
    echo "Failed to extract ClientId and ClientSecret from Service Principal creation output"
    exit 1
fi

echo "Service Principal created: $SP_KV_NAME"

# Customize Service Principal: Add Contributor role and Reduce Key Vault's scope
echo "Adding Contributor role and Reducing Service Principal's scope to the specific Key Vault."
az role assignment create \
    --assignee "$SP_CLIENT_ID" \
    --role "Contributor" \
    --scope "$(az keyvault show --name "$KEYVAULT_NAME" --query id -o tsv)" || {
    echo "Failed to reduce scope."
    exit 1
}
echo " Contributor role added and Scope reduced to Key Vault successfully"

#------------------------------
# Add Access Policy for Secrets
#------------------------------

#
echo "Setting Key Vault Access Policy for Service Principal..."
az keyvault set-policy  \
    --name "$KEYVAULT_NAME" \
    --spn "$SP_CLIENT_ID" \
    --secret-permissions get list || {
    echo "Failed to add Access Policy."
    exit 1
}
echo "Access Policy set successfully"

#-------------
#Configuration
#-------------

# Store SubscriptionId & TenantId in Key Vault
echo "Storing secrets in Key Vault..."
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
TENANT_ID=$(az account show --query "tenantId" -o tsv)

echo "Storing SubScriptionId in Key Vault..."
if az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "SubscriptionId" --value "$SUBSCRIPTION_ID"; then
    echo "Secret 'SubscriptionID' stored successfully."
else
    echo "Failed to store 'SubscriptionId."
    exit 1
fi

echo "Storing TenantId in Key Vault..."
if az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "TenantId" --value "$TENANT_ID"; then
    echo "Secret 'TenantId' stored successfully."
else
    echo "Failed to store 'TenantId'."
    exit 1
fi

# Store SP ClientSecret in Key Vault
echo "Storing Service Principal ClientSecret in Key Vault..."
if az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "SP-ClientSecret" --value "$SP_CLIENT_SECRET"; then
    echo "Secret 'SP-ClientSecret' stored successfully."
else
    echo "Failed to store 'SP-ClientSecret'."
    exit 1
fi

# Add Service Principal ID to GitHub Secrets
echo "Adding Service Principal ClientId to GitHub Secrets..."
if /usr/bin/gh secret set ARM_CLIENT_ID --repo "$GITHUB_REPO" -b "$SP_CLIENT_ID"; then
    echo " Added 'SP-ClientId successfully to GitHub Secrets."
else
    echo "Failed to add 'SP-ClientId'."
    exit 1
fi

#----------------------------------------------------------------------------
# Clean Up Sensitive Variables
#----------------------------------------------------------------------------
unset SP_CLIENT_SECRET
echo "Sensitive variables cleared from memory"

#----------------------------------------------------------------------------
# Monitoring & Alerts
#----------------------------------------------------------------------------
echo "📊 Enabling Monitoring for Key Vault..."

# define supported API version
API_VERSION="2024-08-01"

# Check if diagnostic settings already exist
EXISTING_DIAGNOSTIC_SETTINGS=$(az monitor diagnostic-settings list\
    --resource "$(az keyvault show --name "$KEYVAULT_NAME" --query id -o tsv)" \
    --query "[?name=='KeyVaultLogsAnalytics'].name" -o tsv
    )
if [ -n  "$EXISTING_DIAGNOSTIC_SETTINGS" ]; then
    echo "Diagnostic settings already exist for Key Vault. Skipping creation."
else
    echo "Creating Log Analytrics workspace and Diagnostics Settings."

    # Create Log Analytics Workspace if it doesn't exists
    echo "Creating Log Analytics Workspace..."
    WORKSPACE_ID=$(az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP_SECURITY" \
    --workspace-name "$LOG_ANALYTICS_SECURITY_WORKSPACE_NAME" \
    --location "$LOCATION" \
    --query id -o tsv)
    
    if [ -z "$WORKSPACE_ID" ]; then
        echo "Failed to create Log Analytics Workspace."
        exit 1
    fi
    echo "Log Analytics Workspace created successfully."

    # === Link Key Vault Diagnostics to Log Analytics Workspace ===
    echo "Linking Key Vault diagnostics to Log Analytics Workspace..."
    if az monitor diagnostic-settings create \
        --name "KeyVaultLogsToLogAnalytics" \
        --resource "$(az keyvault show --name "$KEYVAULT_NAME" --query id -o tsv)" \
        --workspace "$(az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP_SECURITY" --name "$LOG_ANALYTICS_SECURITY_WORKSPACE_NAME" --query id -o tsv)" \
        --logs '[{"category": "AuditEvent","enabled": true}]'; then
        echo "✅ Key Vault diagnostics linked to Log Analytics Workspace."
    else
        echo "Failed to link Key Vault diagnostics to Log Analytics Workspace."
        exit 1
    fi
fi

# Set Alert rules for Key Vault

## Check if Action Group exists
echo "Checking if Action Group exists..."
EXISTING_ACTION_GROUP=$(az monitor action-group show \
    --resource-group "$RESOURCE_GROUP_SECURITY" \
    --name "KeyVaultAlertGroup" \
    --query id -o tsv 2>/dev/null)

if [ -z "$EXISTING_ACTION_GROUP" ]; then
    echo "Creating Action Group for Key vault Alerts..."
    if az monitor action-group create \
        --name "KeyVaultAlertGroup" \
        --resource-group "$RESOURCE_GROUP_SECURITY" \
        --short-name "KVAlertGroup"; then
        echo "Action Group created successfully."

        # Add email receiver to the action group
        echo "Adding email receiver to Action Group..."
        if az monitor action-group update \
        --name "KeyVaultAlertGroup" \
        --resource-group "$RESOURCE_GROUP_SECURITY" \
        --add-action email "EmailReceiver" "sergebuasa@gmail.com"; then
            echo "Email receiver added successfully."
        else
            echo "Failed to add email receiver to Action Group"
            exit 1
        fi
    else
        echo "Failed to create Action Group."
        exit 1
    fi
else
    echo "Action Group already exists. Skipping creation"
fi

## Retrieve Action Group Id
KVGROUP_ID=$(az monitor action-group show \
    --resource-group "$RESOURCE_GROUP_SECURITY" \
    --name "KeyVaultAlertGroup" \
    --query id -o tsv)

echo "Action Group Id: $KVGROUP_ID"

if [ -z "$KVGROUP_ID" ]; then
    echo "Failed to retrieve Action Group Id."
    exit 1
else
    echo "Action Group Id retrieved successfully."
fi

## Setting Alert Rules
echo "🚨 Setting Alert Rules for Key Vault..."
if az monitor metrics alert create \
    --name "KeyVaultAccessAlert" \
    --resource-group "$RESOURCE_GROUP_SECURITY" \
    --scopes "$(az keyvault show --name "$KEYVAULT_NAME" --query id -o tsv)" \
    --condition "total ServiceApiHit > 50" \
    --description "Alert trigerred on Key Vault access" \
    --evaluation-frequency "PT5M" \
    --window-size "PT5M" \
    --severity 2 \
    --action "$KVGROUP_ID" \
    --debug; then
    echo "✅ Alerts configured for Key Vault access."
else
    echo "Failed to configure alerts for Key Vault."
    exit 1
fi

echo "Preliminary setup completed succesfully"

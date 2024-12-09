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

#------------------------------------------
# Create Resource Groups
#------------------------------------------
echo "Creating Resource Group: $RESOURCE_GROUP_SECURITY"
az group create --name "$RESOURCE_GROUP_SECURITY" --location "$LOCATION"
if [ $? -eq 0 ]; then
    echo "Resource Group $RESOURCE_GROUP_SECURITY created successfully."
else
    echo "Failed to create Resource group $RESOURCE_GROUP_SECURITY."
    exit 1
fi

echo "Creating Resource Group: $RESOURCE_GROUP_TERRAFORM"
az group create --name "$RESOURCE_GROUP_TERRAFORM" --location "$LOCATION"
if [ $? -eq 0 ]; then
    echo "Resource Group $RESOURCE_GROUP_TERRAFORM created successfully."
else
    echo "Failed to create Resource group $RESOURCE_GROUP_TERRAFORM."
    exit 1
fi

#------------------------------------------
# Create Key Vault
#------------------------------------------
echo "Creating Key Vault : $KEYVAULT_NAME"
az keyvault create --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP_SECURITY" --location "$LOCATION"
if [ $? -eq 0 ]; then
    echo "Key Vault $KEYVAULT_NAME created successfully."
else
    echo "Failed to create Key Vault $KEYVAULT_NAME."
    exit 1
fi

#---------------------------------------------
# Create Storage Account for Terraform Backend
#---------------------------------------------
echo "Creating Storage Account: $STORAGE_ACCOUNT_NAME..."
az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_TERRAFORM" \
    --location "$LOCATION" \
    --sku Standard_LRS
if [ $? -eq 0 ]; then
echo "Storage Account $STORAGE_ACCOUNT_NAME created successfully."
else
    echo "Failed to create Storage Account $STORAGE_ACCOUNT_NAME."
    exit 1
fi

# Create Container for Terraform state
echo "Creating container: $CONTAINER_NAME..."
az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --auth-mode login    
if [ $? -eq 0 ]; then
echo "Container $CONTAINER_NAME created successfully."
else
    echo "Failed to create Container $CONTAINER_NAME."
    exit 1
fi

#----------------------------------------------------------------------------
# Create Service Principal SP_KV_NAME for Key Vault Secrets access
#----------------------------------------------------------------------------
# Supprime any existing Service Principal
APP_ID=$(az ad sp list --display-name "$SP_KV_NAME" --query "[0].appId" -o tsv)

if [ -n "$APP_ID" ]; then
    echo "Deleting existing Service Principal: $SP_KV_NAME..."
    az ad sp delete --id "$APP_ID"
    if [ $? -eq 0 ]; then
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
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "SubscriptionId" --value "$SUBSCRIPTION_ID"
if [ $? -eq 0 ]; then
    echo "Secret 'SubscriptionID' stored successfully."
else
    echo "Failed to store 'SubscriptionId."
    exit 1
fi

echo "Storing TenantId in Key Vault..."
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "TenantId" --value "$TENANT_ID"
if [ $? -eq 0 ]; then
    echo "Secret 'TenantId' stored successfully."
else
    echo "Failed to store 'TenantId'."
    exit 1
fi

# Store SP ClientSecret in Key Vault
echo "Storing Service Principal ClientSecret in Key Vault..."
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "SP-ClientSecret" --value "$SP_CLIENT_SECRET"
if [ $? -eq 0 ]; then
    echo "Secret 'SP-ClientSecret' stored successfully."
else
    echo "Failed to store 'SP-ClientSecret'."
    exit 1
fi

# Check if GitHub CLI is installed
if ! command -v gh &>/dev/null; then
    echo "GitHub CLI is not installed or not in Path. Please install and configure it"
    exit 1
fi

# Add Service Principal ID to GitHub Secrets
echo "Adding Service Principal ClientId to GitHub Secrets..."
/usr/bin/gh secret set ARM_CLIENT_ID --repo "$GITHUB_REPO" -b "$SP_CLIENT_ID"
if [ $? -eq 0 ]; then
    echo "Secret 'SP-ClientId' # Reassign role Key Vault Secrets User
 successfully to GitHub Secrets."
else
    echo "Failed to add 'SP-ClientId'."
    exit 1
fi


#----------------------------------------------------------------------------
# Monitoring & Alerts
#----------------------------------------------------------------------------

#----------------------------------------------------------------------------
# Clean Up Sensitive Variables
#----------------------------------------------------------------------------
unset SP_CLIENT_SECRET
echo "Sensitive variables cleared from memory"

echo "Preliminary setup completed succesfully"
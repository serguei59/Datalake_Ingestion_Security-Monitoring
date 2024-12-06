#!/bin/bash

#------------------------------------------
# Variables and qprerequisite
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

# Store secrets in Key Vault
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
echo "TENANT_ID is : $TENANT_ID"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "TenantId" --value "$TENANT_ID"
if [ $? -eq 0 ]; then
    echo "Secret 'TenantId' stored successfully."
else
    echo "Failed to store 'TenantId'."
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
    --account-name "$STORAGE_ACCOUNT_NAME"    
if [ $? -eq 0 ]; then
echo "Container $CONTAINER_NAME created successfully."
else
    echo "Failed to create Container $CONTAINER_NAME."
    exit 1
fi



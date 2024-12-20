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

# Variables(inutile cf importation de toutes celles du .env)
KEYVAULT_NAME="$KEYVAULT_NAME"
SP_NAME="$SP_KV_NAME"
GITHUB_REPO="$GITHUB_REPO"

# Generate new ClientSecret for KV Service Principal
echo "Generating new ClientSecret for KeyVault's access Service Principal..."
SP_CLIENT_SECRET_REGENERATED=$(az ad sp credentials reset \
    --name "$SP_KV_NAME" \
    --query "password" -o tsv)

if [ -z "$SP_CLIENT_SECRET_REGENERATED" ]; then
    echo "Failed to generate new secret."
    exit 1
fi
echo "New secret generated."

# Update KV Service Principal's secrets in Azure Key Vault
echo "Storing updated secrets in Azure Key Vault "
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name




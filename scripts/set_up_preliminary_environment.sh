#!/bin/bash

#------------------------------------------
# Load Environment Variables
#------------------------------------------
#chemin vers .env
#$0 : représente le chemin du script actuellement exécuté
#dirname "$0" : permet d'obtenir le répertoire où se trouve le script.
ENV_FILE="$(dirname "$0")/../.env"
#load existing environnment variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo ".env not found, please create one filled with required variables"
    exit 1
fi

#------------------------------------------
# Verify Azure Login
#------------------------------------------
if ! az account show &>/dev/null; then
    echo "You're not logged into Azure Cli.Please run 'az login' and try again"
    exit 1
fi
echo "Azure CLI login verified"

#------------------------------------------
# Create Resource Groups
#------------------------------------------

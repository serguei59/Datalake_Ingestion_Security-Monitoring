
# Preliminary Setup

## Overview
This document outlines the steps required to initialize the project environment securely and efficiently. The focus is on setting up Azure resources, securing sensitive credentials, and preparing for Terraform integration and CI/CD workflows.

---

## Objectives
- **Resource Management**: Create and organize Azure resources, including Resource Groups and Key Vaults.
- **Security**: Store sensitive credentials securely in Azure Key Vault.
- **Service Principal (SP)**: Set up a secure SP with scoped permissions.
- **Monitoring**: Implement diagnostic settings and alerting for Key Vault access.
- **Automation**: Prepare the environment for seamless Terraform integration and GitHub workflows.

---

## Steps and Implementation

### 1. **Create Resource Groups**
Two resource groups were created to organize Azure resources logically:

#### **a. RG_SBUASA**
- **Command:**
  ```bash
  az group create --name RG_SBUASA --location francecentral
  ```
- **Purpose:** Hosts general resources required for the preliminary setup, including the Key Vault and the Storage Account for Terraform's backend.

#### **b. RG_Security_SBUASA**
- **Command:**
  ```bash
  az group create --name RG_Security_SBUASA --location francecentral
  ```
- **Purpose:** Dedicated to security-related resources, ensuring a clear separation of concerns. This group contains sensitive components like monitoring and diagnostic tools.

---

### 2. **Handle Key Vault (Soft Delete)**
- **Problem**: Key Vaults in deleted state cause conflicts when attempting to recreate them.
- **Solution**:
  - Purge existing deleted Key Vault:
    ```bash
    az keyvault purge --name <KEYVAULT_NAME>
    ```
  - Create a new Key Vault:
    ```bash
    az keyvault create --name <KEYVAULT_NAME> --resource-group RG_SBUASA --location francecentral
    ```

#### Key Learnings:
- Soft Delete is enabled by default and cannot be disabled.
- Automating purges ensures smooth setup.

---

### 3. **Set Up Service Principal (SP)**
- **Problem**: Assigning roles like `Key Vault Secrets User` was restricted due to permissions.
- **Solution**:
  - Create SP without role assignment:
    ```bash
    az ad sp create-for-rbac --name <SP_NAME> --skip-assignment
    ```
  - Assign the `Contributor` role scoped to the Key Vault:
    ```bash
    az role assignment create \
        --assignee <SP_CLIENT_ID> \
        --role "Contributor" \
        --scope "$(az keyvault show --name <KEYVAULT_NAME> --query id -o tsv)"
    ```

---

### 4. **Store Sensitive Credentials**
- **Stored Values**:
  - **Tenant ID**
  - **Subscription ID**
  - **SP Client Secret**
- **Command**:
  ```bash
  az keyvault secret set --vault-name <KEYVAULT_NAME> --name <SECRET_NAME> --value <SECRET_VALUE>
  ```
- **Purpose**: Secure storage of sensitive values for Terraform and automation workflows.

---

### 5. **Enable Monitoring**
- **Diagnostic Settings**:
  ```bash
  az monitor diagnostic-settings create \
      --name "KeyVaultLogs" \
      --resource "$(az keyvault show --name <KEYVAULT_NAME> --query id -o tsv)" \
      --logs '[{"category": "AuditEvent","enabled": true}]'
  ```
- **Alerts**:
  ```bash
  az monitor metrics alert create \
      --name "KeyVaultAccessAlert" \
      --resource-group RG_Security_SBUASA \
      --scopes "$(az keyvault show --name <KEYVAULT_NAME> --query id -o tsv)" \
      --condition "total > 0 where Category=='AuditEvent'" \
      --description "Alert on Key Vault access"
  ```

---

## Key Decisions Made

### 1. Using Access Policies Over RBAC
- **Why?** RBAC simplifies secret access management for Terraform and CI/CD workflows.
- **Impact:** Better compatibility with modern automation tools.

### 2. Scoped Permissions
- Service Principal permissions were restricted to the Key Vault to reduce overprivileged access.

### 3. Soft Delete Handling
- Automating the purge process ensures no conflicts during setup.

---

## Lessons Learned
1. **Soft Delete in Key Vault**: Plan for soft delete behavior in automation scripts.
2. **RBAC Simplicity**: Using RBAC over access policies reduces configuration complexity.
3. **Error Handling**: Build resilience by automating recovery from common errors.

---

## Next Steps
- **Backend Terraform Setup**: Use the created Storage Account for Terraform state management.
- **CI/CD Integration**: Configure GitHub workflows to streamline deployments and resource management.
- **Enhanced Monitoring**: Expand logging and analytics with Log Analytics for deeper insights.

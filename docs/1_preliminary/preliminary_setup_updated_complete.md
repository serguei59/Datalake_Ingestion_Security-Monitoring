
# Preliminary Setup

## Overview
This document outlines the steps required to initialize the project environment securely and efficiently. The focus is on setting up Azure resources, securing sensitive credentials, implementing monitoring, and preparing for Terraform integration and CI/CD workflows.

---

## Objectives
- **Resource Management**: Create and organize Azure resources, including Resource Groups and Key Vaults.
- **Security**: Store sensitive credentials securely in Azure Key Vault.
- **Service Principal (SP)**: Set up a secure SP with scoped permissions.
- **Monitoring**: Implement diagnostic settings, alerting for Key Vault access, and advanced monitoring tools.
- **Automation**: Prepare the environment for seamless Terraform integration and GitHub workflows.

---

## Why this Approach?
1. **RBAC vs Access Policies**: Access Policies were chosen due to the unavailability of precise RBAC roles. They provide specific control over secret access.
2. **Soft Delete Management**: Automating purges ensures smooth Key Vault recreation.
3. **Scoped Permissions**: Access for the Service Principal was limited to the Key Vault to minimize exposure.

---

## Technical Choices and Justifications
- **Access Policies**: Enabled fine-grained permissions for accessing Key Vault secrets.
- **Soft Delete Handling**: Automated purges to prevent manual intervention.
- **Monitoring Tools**: Integrated Azure Monitor and Log Analytics for resource access tracking.

---

## Prerequisites
1. **Azure CLI Installed**: Ensure the latest version is available.
2. **Subscription Access**: Permissions to create resources, assign roles, and configure monitoring.
3. **jq Installed**: Required for JSON parsing.
4. **Log Analytics Workspace**: For advanced monitoring and analysis.

---

## Step-by-Step Instructions

### **1. Download the Bash Script**
- Download the setup script:
  ```bash
  wget https://github.com/your-repo/path-to-script/setup_preliminary_environment.sh
  chmod +x setup_preliminary_environment.sh
  ```

---

### **2. Run the Script**
- Execute the script:
  ```bash
  ./setup_preliminary_environment.sh
  ```

---

### **3. Create Storage Account and Container for Terraform Backend**
- Create a Storage Account:
  ```bash
  az storage account create       --name <STORAGE_ACCOUNT_NAME>       --resource-group RG_SBUASA       --location francecentral       --sku Standard_LRS       --kind StorageV2
  ```
- Create a container within the Storage Account:
  ```bash
  az storage container create       --account-name <STORAGE_ACCOUNT_NAME>       --name <CONTAINER_NAME>
  ```

---

### **4. Store Sensitive Credentials**
- Sensitive credentials securely stored in Azure Key Vault:
  - **Tenant ID**
  - **Subscription ID**
  - **Service Principal Client Secret**
- **Commands**:
  ```bash
  az keyvault secret set --vault-name <KEYVAULT_NAME> --name TenantId --value <TENANT_ID>
  az keyvault secret set --vault-name <KEYVAULT_NAME> --name SubscriptionId --value <SUBSCRIPTION_ID>
  az keyvault secret set --vault-name <KEYVAULT_NAME> --name SP-ClientSecret --value <CLIENT_SECRET>
  ```

---

### **5. Add Service Principal Client ID to GitHub Secrets**
- Add the Service Principal Client ID to GitHub Secrets for use in workflows:
  ```bash
  gh secret set SP_CLIENT_ID --body <CLIENT_ID>
  ```

---

### **6. Enable Monitoring**

#### Diagnostic Settings
- Configure diagnostic settings to capture access logs for the Key Vault:
  ```bash
  az monitor diagnostic-settings create       --name "KeyVaultLogs"       --resource "$(az keyvault show --name <KEYVAULT_NAME> --query id -o tsv)"       --logs '[{"category": "AuditEvent","enabled": true}]'
  ```

#### Alerts
- Set up alerts for unauthorized access attempts:
  ```bash
  az monitor metrics alert create       --name "KeyVaultAccessAlert"       --resource-group RG_Security_SBUASA       --scopes "$(az keyvault show --name <KEYVAULT_NAME> --query id -o tsv)"       --condition "total > 0 where Category=='AuditEvent'"       --description "Alert on Key Vault access"
  ```

---

### **7. Advanced Monitoring Tools**

#### Log Analytics
- Link the Key Vault diagnostics to a Log Analytics Workspace:
  ```bash
  az monitor diagnostic-settings create       --name "KeyVaultLogsToLogAnalytics"       --resource "$(az keyvault show --name <KEYVAULT_NAME> --query id -o tsv)"       --workspace "$(az monitor log-analytics workspace show --resource-group RG_Security_SBUASA --name <WORKSPACE_NAME> --query id -o tsv)"       --logs '[{"category": "AuditEvent","enabled": true}]'
  ```

#### Monitoring Dashboard
- Create an Azure Monitor Dashboard for visual insights into Key Vault access and resource health:
  1. Go to the **Azure Portal**.
  2. Navigate to **Azure Monitor > Dashboards**.
  3. Add custom tiles to display metrics and logs from Key Vault and related resources.

---

## Lessons Learned
1. **RBAC Integration**: Transition to RBAC when specific roles become available.
2. **Soft Delete Handling**: Automating purges eliminates manual intervention for Key Vault recreation.
3. **Comprehensive Monitoring**: Using Azure Monitor and Log Analytics ensures visibility into resource access and potential security issues.

---

## Next Steps
1. **Backend Terraform Setup**: Use the created Storage Account for Terraform state management.
2. **CI/CD Integration**: Configure GitHub Actions for seamless deployments.
3. **Enhanced Monitoring**: Expand monitoring capabilities with Log Analytics queries and alert rules.

---

## Useful Links
- **Azure Key Vault Documentation**: [Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/)
- **Azure Monitor Documentation**: [Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/)
- **Log Analytics Workspace**: [Log Analytics](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-workspace-overview)

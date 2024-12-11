
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

## Why this Approach?
1. **RBAC vs Access Policies**: Due to role limitations, Access Policies were chosen for the Key Vault to define exact permissions (`get` and `list`) required by the Service Principal.
2. **Soft Delete Management**: Automating purges ensures no conflicts with recreating Key Vaults.
3. **Scoped Permissions**: Even with the Contributor role, access was limited to the specific Key Vault to enhance security.

---

## Technical Choices and Justifications
- **Access Policies**: Opted over RBAC due to unavailability of roles like `Key Vault Secrets User`. Allows fine-grained control over secret access.
- **Soft Delete Automation**: Ensures seamless recreation of Key Vaults in scripts.
- **Service Principal Scope Reduction**: Reducing the scope of the SP minimizes risk while maintaining functionality.

---

## Prerequisites
1. **Azure CLI Installed**: Ensure you have the latest version of Azure CLI.
2. **Subscription Access**: Sufficient permissions to create resources and assign roles.
3. **jq Installed**: Required for JSON parsing in the script.

---

## Step-by-Step Instructions

### **1. Download the Bash Script**
- Download the setup script from the project repository:
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

### **3. Monitor the Execution**
- Verify the following outputs during execution:
  - Resource Groups created: `RG_SBUASA` and `RG_Security_SBUASA`.
  - Key Vault created and secrets stored successfully.
  - Service Principal created with reduced scope.
  - Access policies set for the Key Vault.

---

## Useful Links
- **Azure Key Vault Documentation**:
  [Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/)
- **Azure CLI Commands Reference**:
  [Azure CLI Reference](https://learn.microsoft.com/en-us/cli/azure/)
- **RBAC vs Access Policies**:
  [Key Vault Access Management](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide)
- **Terraform State Management**:
  [Terraform Backend](https://developer.hashicorp.com/terraform/docs/state/remote)

---

## Lessons Learned
1. **RBAC Integration**: While Access Policies provided a workaround, RBAC remains the preferred approach for modern workflows.
2. **Soft Delete Handling**: Automating purges ensures that deleted Key Vaults do not block script execution.
3. **Least Privilege Principle**: Scoped permissions reduce risks, even when broader roles like Contributor are required initially.

---

## Next Steps
1. **Backend Terraform Setup**: Use the created Storage Account for Terraform state management.
2. **CI/CD Integration**: Configure GitHub Actions for seamless automation.
3. **Advanced Monitoring**: Expand monitoring with Log Analytics for comprehensive resource tracking.

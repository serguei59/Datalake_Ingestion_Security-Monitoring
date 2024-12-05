# Preliminary Step: Secure Configuration for Terraform with Azure Key Vault

## **Introduction**

This preliminary step sets up a secure environment to allow Terraform to access sensitive information (like Subscription ID and Tenant ID) while ensuring isolation and proper secret management.

### **Objectives**
1. Create an **Azure Key Vault** to secure sensitive information.
2. Configure a **secondary Service Principal (SP2)** with limited permissions to access the Key Vault.
3. Set up a **Storage Account** for the Terraform backend.
4. Add necessary secrets to **GitHub Secrets** for CI/CD workflows.

### **Why this Approach?**

- **Enhanced Security**: Secrets are stored securely in Azure Key Vault and not exposed in code or logs.
- **Role Isolation**: The secondary Service Principal has limited access to the Key Vault, reducing the impact of potential compromise.
- **CI/CD Integration**: Secrets are injected into GitHub Secrets, enabling Terraform workflows to run autonomously.

---

## **Technical Choices and Justifications**

### **1. Azure Key Vault**
- Used to store sensitive information like `SubscriptionId` and `TenantId`.
- Benefits:
  - **Encryption at rest and in transit**.
  - **Access logging** through Azure Monitor.
  - **Automatic key rotation** (optional).

### **2. Secondary Service Principal (SP2)**
- Role: **Key Vault Secrets User**.
- Limited access to read secrets in the Key Vault.

### **3. Terraform Backend (Azure Storage Account)**
- Centralizes and secures Terraform state to avoid conflicts during CI/CD workflow execution.
- Stores the state in a dedicated container within an isolated Storage Account.

---

## **Prerequisites**

1. **Azure CLI** installed and configured.
   - [Azure CLI Documentation](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **GitHub CLI** installed to manage GitHub Secrets.
   - [GitHub CLI Documentation](https://cli.github.com/)
3. An Azure account with the following permissions:
   - Create Azure resources (Key Vault, resource groups, etc.).
   - Manage Azure identities (Service Principals).
4. A GitHub repository set up for the project.

---

## **Step-by-Step Instructions**

### **1. Download the Bash Script**

A Bash script is provided to automate the setup process. Download it from the GitHub repository:

https://github.com/serguei59/Datalake_Ingestion_Security-Monitoring/blob/main/src/set_up_preliminary_environment.sh

### **2. Run the Script**

#### **Make the script executable**
```bash
chmod +x setup_preliminary_environment.sh
```
#### **Execute the script**
```bash
./setup_preliminary_environment.sh
```
### **3. What the Script does**

The script retrieves the following

####  **Subscription ID**
####  **Tenant ID**
####  **Create Resource Groups**
3 resource_groups are created:
RG_Security,
RG_Terraform,
RG_Projet
#### **Set up Azure Key Vault**
Creation and store secrets in Key Vault
#### **Configure Terraform Back end**
Create a Storage Account and a Container for the State
#### **Create or Regenerate the Secondary Service Principal (SP2)**
Create SP2 if not exists, regenerate credentials 
#### **Add secrets to GitHub**
----
### **Post-Execution Checks**

#### **1. Azure Key Vault**
Verify the Subscription_Id and TenantId are stored:
```bash
az keyvault secret list --vault-name secureKeyVault
```
#### **2. Service Principal (SP2)**
Verify SP2 exists:
```bash
az ad sp list --dipslay-name keyvault-access-sp
```
#### **3. GithHub Secrets**
##### **Steps to Verify GitHub Secrets**

1. **Navigate to the Secrets Management Page**
   - Open your GitHub repository.
   - Go to **Settings > Secrets and Variables > Actions**.

##### [Navigate to Secrets](https://docs.github.com/assets/images/help/repository/secrets.png)

2. **Ensure the Following Secrets are Present:**

   | Secret Name         | Description                                      |
   |---------------------|--------------------------------------------------|
   | `SP2_CLIENT_ID`     | The client ID of the secondary Service Principal.|
   | `SP2_CLIENT_SECRET` | The client secret of the secondary Service Principal.|
   | `TENANT_ID`         | The tenant ID of your Azure account.             |
   | `KEYVAULT_NAME`     | The name of the Azure Key Vault.                 |

---

##### **Example**

Here’s an example of what the secrets should look like in your repository:

- **SP2_CLIENT_ID**: `12345678-90ab-cdef-1234-567890abcdef`
- **SP2_CLIENT_SECRET**: `abcdefghijklmnopqrstuvwxyz1234567890`
- **TENANT_ID**: `12345678-90ab-cdef-1234-567890abcdef`
- **KEYVAULT_NAME**: `mysecurekeyvault`

---

#### **Common Issues and Troubleshooting**

##### **1. Secrets Not Found**
   - If a secret is missing, ensure that the preliminary setup script was executed successfully:
```bash
   ./setup_preliminary_environment.sh
```

##### **2. Incorrect Secret Values**
   - You can update secrets manually using the **GitHub CLI**:
 ```bash
 gh secret set SP2_CLIENT_ID --repo <username/repository> -b "<correct_value>"
 ```

---

## **Useful Links**

- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Azure CLI Documentation](https://learn.microsoft.com/en-us/cli/azure/)
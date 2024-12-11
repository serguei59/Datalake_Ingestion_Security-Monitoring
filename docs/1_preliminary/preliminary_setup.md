Preliminary Setup

Overview This document outlines the steps required to initialize the
project environment securely and efficiently. The focus is on setting up
Azure resources, securing sensitive credentials, and preparing for
Terraform integration and CI/CD workflows.

Objective To establish a secure and automated setup for managing Azure
resources, including: - Creating Resource Groups - Configuring Azure Key
Vault for secure storage of sensitive data. - Setting Up a Service
Principal (SP) with appropriate roles. - Defining Key Vault Access
Policies or RBAC permissions. - Implementing Monitoring and Alerts for
resource access and security.

Steps and Challenges

1\. Resource Group Creation - Command: az group create \--name
\<RESOURCE_GROUP\> \--location \<LOCATION\> - Outcome: Successfully
created RG_SBUASA in the francecentral region. - Note: Resource groups
are the foundation for organizing Azure resources.

2\. Azure Key Vault Setup - Initial Issue: Soft Delete conflict when
recreating a Key Vault with the same name. - Solution:  - Purge the
deleted Key Vault: az keyvault purge \--name \<KEYVAULT_NAME\>  - Create
the Key Vault: az keyvault create \--name \<KEYVAULT_NAME\>
\--resource-group \<RESOURCE_GROUP\> \--location \<LOCATION\>

Key Learnings: - Soft Delete cannot be disabled and must be managed
proactively. - Avoid reusing Key Vault names unless absolutely
necessary.

3\. Service Principal (SP) Creation - Initial Issue: Unable to assign
roles like Key Vault Secrets User due to lack of permissions. -
Solution:  - Use the \--skip-assignment flag to create the SP without
roles: az ad sp create-for-rbac \--name \<SP_NAME\> \--skip-assignment
 - Assign the Contributor role to the SP for the Key Vault scope: az
role assignment create \\ \--assignee \<SP_CLIENT_ID\> \\ \--role
\"Contributor\" \\ \--scope \<KEYVAULT_ID\>

4\. Storing Credentials in Azure Key Vault - Stored Secrets:  - Tenant
ID  - Subscription ID  - SP Client Secret - Command: az keyvault secret
set \--vault-name \<KEYVAULT_NAME\> \--name \<SECRET_NAME\> \--value
\<SECRET_VALUE\>

5\. Monitoring and Alerts Setup - Diagnostic Settings: az monitor
diagnostic-settings create \\ \--name \"KeyVaultLogs\" \\ \--resource
\<KEYVAULT_ID\> \\ \--logs \'\[{\"category\":
\"AuditEvent\",\"enabled\": true}\]\' - Alert Rules: az monitor metrics
alert create \\ \--name \"KeyVaultAccessAlert\" \\ \--resource-group
\<RESOURCE_GROUP\> \\ \--scopes \<KEYVAULT_ID\> \\ \--condition \"total
\> 0 where Category==\'AuditEvent\'\" \\ \--description \"Alert on Key
Vault access\"

Key Decisions Made

1\. Using RBAC Over Access Policies - Why? RBAC provides better
integration with Terraform and CI/CD workflows. - Impact: Simplifies
secret access management across the project lifecycle.

2\. Soft Delete Handling - Purging was automated to ensure a smooth
setup without manual intervention.

3\. Scoped SP Permissions - The SP\'s role was limited to Contributor on
the Key Vault to minimize overprivileged access.

What's Next? - Backend Terraform Setup:  - Use the created Storage
Account for managing Terraform state. - CI/CD Integration:  - Configure
GitHub Actions for automated workflows using the SP credentials. -
Expand Monitoring:  - Add Log Analytics for advanced alerting and data
analysis.

Lessons Learned 1. Soft Delete in Key Vault: It's critical to account
for this behavior in automation scripts. 2. SP Permissions: Always aim
for the least privilege principle, even when starting with broader
roles. 3. Error Handling: Automating recovery from common errors
improves resilience.

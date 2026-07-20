# gr_resfrac-azure-assignment

## Executive Summary

This project demonstrates a production-oriented Azure DevOps solution built on Microsoft Azure using Infrastructure as Code (Terraform), Azure DevOps multi-stage CI/CD pipelines, secure identity and secret management, monitoring, and operational best practices.

The solution provisions Azure infrastructure, deploys a secure Node.js REST API and a Python Azure Function, integrates Azure SQL Database, Azure Storage, Azure Key Vault, Microsoft Entra ID, Application Insights, Azure Monitor, and Log Analytics into a cloud-native platform.

The primary objective of this assignment is not only to deploy Azure resources, but also to demonstrate engineering judgment, security best practices, operational troubleshooting, monitoring strategy, and production readiness.

---

## Table of Contents

1. Repository Structure
2. Technology Stack
3. Setup & Deployment
4. Architecture Decisions
5. Security Considerations
6. Monitoring Approach
7. Assumptions & Tradeoffs
8. Future Improvements

## 1. Repository Structure

```text
.
├── api/                      # Node.js REST API
├── function/                 # Python Azure Function
├── infra/                    # Terraform Infrastructure
├── azure_pipelines/          # Azure DevOps YAML pipelines
├── architecture/             # Architecture diagrams
├── AI_Usage/                 # AI transcript & disclosure
├── assets/                   # Interface screenshots
├── README.md
└── .gitignore
```

## 2. Technology Stack
| Component              | Technology               | Purpose                     |
| ---------------------- | ------------------------ | --------------------------- |
| Cloud Platform         | Microsoft Azure          | Cloud Infrastructure        |
| Infrastructure as Code | Terraform                | Infrastructure provisioning |
| API                    | Node.js, Express         | Secure REST API             |
| Compute                | Azure Functions (Python) | Blob processing             |
| Database               | Azure SQL Database       | Application data            |
| Storage                | Azure Blob Storage       | File processing             |
| Identity               | Microsoft Entra ID       | OAuth2/JWT Authentication   |
| Secrets                | Azure Key Vault          | Secure secret management    |
| Monitoring             | Application Insights     | Telemetry                   |
| Logging                | Log Analytics            | Centralized log analysis    |
| Alerting               | Azure Monitor            | Health & operational alerts |
| CI/CD                  | Azure DevOps             | Build & Deployment          |

## 3. Setup & Deployment

### Prerequisites

Before deploying the solution, ensure the following prerequisites are available:

- Azure Subscription with Contributor permissions
- Azure CLI
- Terraform v1.14.2 or later
- Azure DevOps Project
- Azure DevOps Service Connection (Workload Identity Federation)
- Remote Storage Account for Terraform State
- Node.js 20
- Python 3.11
- Azure Functions Core Tools

---

### Infrastructure Deployment

Initialize Terraform using the appropriate backend configuration.

```bash
cd infra

terraform init

terraform plan -var-file="dev.tfvars"

terraform apply -auto-approve

terraform plan -destroy -var-file="dev.tfvars"   # dry run — verified clean for teardown resources.
```

Terraform provisions:

Resource Group
Virtual Network
Storage Account
Azure SQL Database
Key Vault
Application Insights
Log Analytics Workspace
Azure Monitor Alerts
App Service
Function App
Managed Identities
RBAC Role Assignments

### Application Deployment

 Deploy the Node.js API

```bash
cd api
npm ci

tar -a -c -f deploy.zip *

az webapp deploy --name <app-name> --resource-group <resource-group> --src-path deploy.zip --type zip
```
Deploy the Azure Function
```bash
cd function
tar -a -c -f deploy.zip *
az functionapp deployment source config-zip --name <function-name> --resource-group <resource-group> --src deploy.zip
```
### Verification
```
/health endpoint: https://app-resfracassign-prod.azurewebsites.net/health

/protected endpoint: http://app-resfracassign-dev.azurewebsites.net/protected

```
Expected
{
  "status": "ok"
}

Protected endpoints should return 401 Unauthorized when no valid JWT token is supplied.

## 4. Architecture Decisions

This solution was designed to prioritize maintainability, automation, scalability, and operational simplicity while remaining aligned with Azure best practices and the scope of the assignment.

### Infrastructure as Code

Terraform was selected over imperative scripting because it provides:

- Declarative infrastructure management
- Version-controlled infrastructure changes
- Repeatable deployments across environments
- State-based drift detection
- Easier collaboration and change tracking

---

### CI/CD Strategy

Azure DevOps YAML pipelines were selected to automate infrastructure provisioning and application deployments.

The pipeline separates infrastructure deployment from application deployment, enabling:

- Repeatable deployments
- Environment consistency
- Manual approval gates for Production
- Reduced deployment errors

---

### Authentication Architecture

Microsoft Entra ID was selected as the identity provider because it integrates natively with Azure services and supports OAuth2/JWT authentication.

This approach provides centralized identity management while avoiding custom authentication implementations.

---

### Secret Management Strategy

Azure Key Vault was chosen as the centralized location for storing application secrets and configuration values.

Separating secrets from application code improves maintainability and allows secret rotation without requiring code changes.

---

### Monitoring Architecture

Application Insights, Log Analytics, Dashboards and Azure Monitor were selected to provide centralized monitoring, logging, telemetry, and alerting.

This enables faster troubleshooting and improves operational visibility across both infrastructure and applications.

## 5. Security Considerations

Security was incorporated throughout the solution by protecting identities, secrets, network access, deployment pipelines, and application resources.

### Identity & Access Management

- Microsoft Entra ID is used for authentication.
- OAuth2/JWT tokens secure protected API endpoints.
- Azure RBAC enforces least-privilege access to Azure resources.

---

### Managed Identities

System-assigned Managed Identities are used wherever possible to eliminate hardcoded credentials.

Benefits include:

- Automatic credential rotation
- No embedded secrets
- Reduced credential management
- Secure authentication between Azure services

---

### Secret Protection

The SQL administrator password is stored in Azure Key Vault as the `sql-admin-password` secret. The password is passed securely to Terraform through a secret Azure DevOps variable and is never committed to source control.

The Node.js API uses `DefaultAzureCredential` and `SecretClient` to authenticate with Key Vault and retrieve the secret at runtime. 

---

### Network Security

Network access is restricted by implementing:

- Private Endpoint for Azure SQL Database
- Private Endpoint for Azure Key Vault

These controls reduce the attack surface by preventing direct public access to sensitive resources.

---

### Secure CI/CD

The Azure DevOps pipeline follows secure deployment practices by:

- Using Workload Identity Federation instead of client secrets
- Storing sensitive pipeline values in Variable Groups
- Preventing secrets from being committed to source control
- Requiring manual approvals before Production deployment

---

### Data Protection

- Azure-managed encryption protects data at rest.
- Azure SQL Database and Azure Storage use platform-managed encryption by default.

---

### Security Summary

The solution follows Azure security best practices by implementing:

- Microsoft Entra ID authentication
- Azure RBAC
- Managed Identities
- Azure Key Vault
- Private Endpoints
- Secure CI/CD authentication
- Encryption in transit and at rest
---

### Networking Design

Private Endpoints were implemented for Azure SQL Database and Azure Key Vault to reduce public exposure of sensitive resources.

The Azure Function App remains on the Consumption (Y1) plan because it provides a cost-effective serverless deployment model for this assignment, although this plan does not support VNet Integration.

## 6. Monitoring Approach

Monitoring and observability were implemented to provide operational visibility across infrastructure and applications. The solution uses Azure-native monitoring services to collect telemetry, detect failures, generate alerts, and assist with troubleshooting.

### Monitoring Components

| Service | Purpose |
|---------|---------|
| Application Insights | Application telemetry, request tracking, dependency monitoring, exceptions, and performance metrics |
| Azure Monitor | Health monitoring, metric-based alerts, and resource availability |
| Log Analytics Workspace | Centralized log collection, querying, and troubleshooting |
| Azure Activity Logs | Tracks resource-level operations and configuration changes |

---

## Monitoring and Alerting

### Health / Availability Alert

An Azure Monitor alert is configured for the Azure App Service to detect availability issues by monitoring HTTP errors. If the threshold is exceeded, an email notification is sent through an Azure Monitor Action Group.

---

### Application Failure Alert

An Azure Monitor alert is configured using Application Insights to detect application exceptions. This helps identify runtime failures in the REST API or Azure Function and notifies administrators for immediate investigation.

---

### Infrastructure Alert

An Azure Monitor alert monitors Azure SQL Database CPU utilization. When CPU usage exceeds the configured threshold, an email notification is triggered to help prevent performance degradation.

---
### Dashboard:
An Azure dashboard was created to provide a centralized operational view of the solution.

The dashboard includes visualizations for:

- Application exceptions
- Failed API requests
- API response time
- Azure Function execution count
- Azure SQL utilization
---
### Issue Investigation

When an alert is triggered:

1. Review the Azure Monitor alert details.
2. Analyze Application Insights telemetry for exceptions and failed requests.
3. Check Log Analytics logs to identify the root cause.
4. Verify the application status using the Azure Monitoring Dashboard.

---

### Rollback / Recovery

If a deployment introduces issues:

1. Redeploy the last successful release using the Azure DevOps CI/CD pipeline.
2. Verify application health through Azure Monitor and Application Insights.
3. Confirm normal application operation before resuming deployments.

## 7. Assumptions & Tradeoffs

| Decision | Reason |
|----------|--------|
| **Terraform used instead of Azure CLI/PowerShell** | Terraform was selected because it provides declarative Infrastructure as Code, version control, repeatable deployments, and drift detection, making infrastructure management more reliable. |
| **Central US deployment** | The original target region (East US) had App Service quota limitations in the Azure for Students subscription. Central US was selected as an alternative where resources were available. |
| **Azure Function on Consumption Plan (Y1)** | The Consumption plan was chosen for cost efficiency. As a result, VNet Integration is not supported, so the Function App retains public network access. |
| **Private Endpoints implemented for SQL and Key Vault** | Private networking was prioritized for the most sensitive resources while balancing platform limitations and assignment scope. |
| **Separate Terraform state files** | Development and Production use separate state files to reduce the risk of accidental cross-environment deployments. |
| **Environment-based deployment** | Prod was provisioned but not fully configured — a live subscription quota constraint (B1/F1 SKU limits) forced an unplanned region migration that consumed the remaining time-box. Added to future enhancements: fully automating multi-environment (QA, PVT, Pre-Prod) deployment. |

## 8. Future Improvements
Given additional time and a production-scale environment, the following enhancements would be implemented.

### End-to-End File Processing Monitoring

Implement end-to-end tracking for files entering and leaving the blob-processing workflow.

The enhancement would:

- Record an upload event when a file enters the `uploads` container.
- Record processing start, completion, and failure events from the Azure Function.
- Correlate events using the blob filename or a generated correlation ID.
- Detect files that remain in the `uploads` container beyond an expected processing threshold.
- Create an Azure Monitor scheduled-query alert for unprocessed or stuck files.
- Display received, processed, failed, and pending file counts on an operational dashboard.

This requires enabling Storage Account Diagnostic Settings and sending blob operation logs to Log Analytics.

### Scalability and Performance

Improve the solution's ability to handle increased API traffic and higher file-processing volume.

Potential enhancements include:

- Scale the App Service Plan vertically by increasing the pricing tier when additional CPU and memory are required.
- Configure horizontal autoscaling for the API based on request volume, CPU utilization, response time, or queue depth.
- Upgrade the Azure Function from the Consumption plan to Elastic Premium to support improved performance, reduced cold starts, VNet Integration, and more predictable scaling.
- Introduce Azure Front Door or Application Gateway for global routing, load balancing, Web Application Firewall protection, and improved availability.
- Add caching where appropriate to reduce repeated database calls.
- Review Azure SQL compute sizing and enable scaling based on workload demand.
- Perform load and performance testing as part of the CI/CD process before Production releases.

### Networking and Security

- Extend Private Endpoint and VNet Integration configuration to the Production environment.
- Introduce a self-hosted Azure DevOps agent inside the VNet.
- Disable Key Vault public network access after a private CI/CD and administrative access path is available.
- Enable Microsoft Defender for Cloud and Azure Policy for governance and compliance.

### Reliability and Disaster Recovery

- Enable geo-redundant storage where required.
- Configure Azure SQL backup and geo-replication strategies.
- Define and validate Recovery Time Objective and Recovery Point Objective requirements.
- Automate backup restoration and disaster recovery testing.
- Add infrastructure drift-detection checks and scheduled Terraform plans.

### Testing and Deployment

- Add automated integration tests for API, SQL, Key Vault, and Function workflows.
- Fully automate multi-environment deployment (Dev, QA, PVT, Pre-Prod, Prod) through the CI/CD pipeline with environment-specific approval gates, extending the current Dev-only automated path.
- Add performance and load tests for increased traffic scenarios.
- Introduce deployment slots for safer API releases.
- Implement automated rollback based on failed smoke tests or health checks.
  
## Conclusion

This assignment demonstrates the design and implementation of a secure, cloud-native Azure platform using Infrastructure as Code, Azure DevOps CI/CD, managed identities, RBAC, Azure Monitor, and operational best practices.

The solution emphasizes automation, security, monitoring, and maintainability while documenting engineering trade-offs and production considerations encountered during implementation.

Although built within the scope of a technical assignment, the overall design follows production-oriented engineering principles and can be extended further for enterprise-scale deployments.

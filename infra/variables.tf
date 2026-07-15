variable "project_name" {
  description = "Short name used as a prefix for all resources"
  type        = string
  default     = "resfracassign"
}

variable "environment" {
  description = "Deployment environment (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "sql_admin_username" {
  description = "Admin username for Azure SQL Server"
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  description = "Admin password for Azure SQL Server"
  type        = string
  sensitive   = true
}

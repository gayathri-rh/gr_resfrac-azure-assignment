resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = "East US"
}

resource "azurerm_storage_account" "sa" {
  name                     = lower(replace("sa${var.project_name}${var.environment}", "-", ""))
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
}

resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "processed" {
  name                  = "processed"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_key_vault_secret" "sql_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_mssql_server" "sql" {
  name                         = "sql-${var.project_name}-${var.environment}-1"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = "Central US"
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "sqldb" {
  name                        = "sqldb-${var.project_name}-${var.environment}"
  server_id                   = azurerm_mssql_server.sql.id
  sku_name                    = "GP_S_Gen5_1"
  min_capacity                = 0.5
  auto_pause_delay_in_minutes = 60
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "allow_my_ip" {
  name             = "AllowLocalDevIP"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "98.220.50.92"
  end_ip_address   = "98.220.50.92"
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "appi" {
  name                = "ap-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
}

resource "azurerm_service_plan" "asp" {
  name                = "asp-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = "Central US"
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "api" {
  name                = "app-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = "Central US"
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    application_stack {
      node_version = "20-lts"
    }
    app_command_line = "node server.js"
    vnet_route_all_enabled = true
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.appi.connection_string
    "KEY_VAULT_URI"                          = azurerm_key_vault.kv.vault_uri
    "SQL_SERVER"                             = azurerm_mssql_server.sql.fully_qualified_domain_name
    "SQL_DATABASE"                           = azurerm_mssql_database.sqldb.name
    "SQL_USER"                               = var.sql_admin_username
    "SCM_DO_BUILD_DURING_DEPLOYMENT"         = "false"
    "WEBSITE_RUN_FROM_PACKAGE"               = "1"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_service_plan" "func_asp" {
  name                = "asp-func-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = "Central US"
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "func" {
  name                = "func-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = "Central US"
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  service_plan_id            = azurerm_service_plan.func_asp.id

  site_config {
    application_stack {
      python_version = "3.11"
    }
   
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"               = "python"
    "APPLICATIONINSIGHTS_CONNECTION_STRING"  = azurerm_application_insights.appi.connection_string
    "KEY_VAULT_URI"                          = azurerm_key_vault.kv.vault_uri
    "UPLOADS_CONTAINER"                      = azurerm_storage_container.uploads.name
    "PROCESSED_CONTAINER"                    = azurerm_storage_container.processed.name
     "BlobStorageConnectionString"           = azurerm_storage_account.sa.primary_connection_string
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault" "kv" {
  name                       = "kv-${var.project_name}-${var.environment}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization  = true
  public_network_access_enabled = false
}

resource "azurerm_role_assignment" "api_kv_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.api.identity[0].principal_id
}

resource "azurerm_role_assignment" "func_kv_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.func.identity[0].principal_id
}

resource "azurerm_role_assignment" "pipeline_kv_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = "3b390e44-1076-430c-9e88-ec7d88c6330f"
}

resource "azurerm_role_assignment" "user_kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = "5167feb5-68ca-4bfc-a9da-ceaccb3e5de6"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project_name}-${var.environment}"
  address_space       = ["10.10.0.0/16"]
  location            = "Central US"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "appservice_subnet" {
  name                 = "snet-appservice-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]

  delegation {
    name = "appservice-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "privateendpoint_subnet" {
  name                 = "snet-privateendpoint-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_private_dns_zone" "kv_dns" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_dns_link" {
  name                  = "kv-dns-link-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.kv_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "pe-kv-${var.project_name}-${var.environment}"
  location            = "Central US"
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.privateendpoint_subnet.id

  private_service_connection {
    name                           = "kv-privateserviceconnection"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv_dns.id]
  }
}
resource "azurerm_app_service_virtual_network_swift_connection" "api_vnet_integration" {
  app_service_id = azurerm_linux_web_app.api.id
  subnet_id      = azurerm_subnet.appservice_subnet.id
}


resource "azurerm_private_dns_zone" "sql_dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_dns_link" {
  name                  = "sql-dns-link-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_endpoint" "sql_pe" {
  name                = "pe-sql-${var.project_name}-${var.environment}"
  location            = "Central US"
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.privateendpoint_subnet.id

  private_service_connection {
    name                           = "sql-privateserviceconnection"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql_dns.id]
  }
}

resource "azurerm_private_dns_zone" "storage_dns" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_dns_link" {
  name                  = "storage-dns-link-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_endpoint" "storage_pe" {
  name                = "pe-storage-${var.project_name}-${var.environment}"
  location            = "Central US"
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.privateendpoint_subnet.id

  private_service_connection {
    name                           = "storage-privateserviceconnection"
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_dns.id]
  }
}
targetScope = 'resourceGroup'

@description('Azure region.')
param location string

@description('Tags applied to Azure SQL audit resources.')
param tags object

@description('Azure SQL logical server name.')
param serverName string

@description('Azure SQL database name.')
param databaseName string = 'pricing_mlops_audit'

@description('Microsoft Entra administrator display/login name.')
param entraAdministratorLogin string

@description('Microsoft Entra administrator object id.')
param entraAdministratorObjectId string

@description('Serverless SQL database SKU name.')
param skuName string = 'GP_S_Gen5_1'

@description('Serverless SQL database tier.')
param skuTier string = 'GeneralPurpose'

@description('Serverless SQL database family.')
param skuFamily string = 'Gen5'

@description('Serverless SQL database vCore capacity.')
param skuCapacity int = 1

@description('Serverless database minimum capacity.')
param minCapacity int = 1

@description('Auto-pause delay in minutes. Use -1 to disable auto-pause.')
param autoPauseDelay int = 60

@description('Allow Azure platform services to reach SQL. Required for staging MVP without private endpoints.')
param allowAzureServices bool = true

resource server 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: serverName
  location: location
  tags: tags
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      login: entraAdministratorLogin
      sid: entraAdministratorObjectId
      tenantId: tenant().tenantId
      azureADOnlyAuthentication: true
      principalType: 'User'
    }
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource database 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: server
  name: databaseName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
    family: skuFamily
    capacity: skuCapacity
  }
  properties: {
    autoPauseDelay: autoPauseDelay
    minCapacity: minCapacity
    maxSizeBytes: 34359738368
    zoneRedundant: false
  }
}

resource allowAzureServicesFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = if (allowAzureServices) {
  parent: server
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output serverName string = server.name
output databaseName string = database.name
output fullyQualifiedDomainName string = server.properties.fullyQualifiedDomainName

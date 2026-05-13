targetScope = 'resourceGroup'

@description('Azure region.')
param location string

@description('Tags applied to observability resources.')
param tags object

@description('Log Analytics workspace name.')
param logAnalyticsName string

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

output logAnalyticsWorkspaceName string = logAnalytics.name

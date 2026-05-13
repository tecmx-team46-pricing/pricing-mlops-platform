targetScope = 'resourceGroup'

@description('Azure region.')
param location string

@description('Tags applied to shared services.')
param tags object

@description('Key Vault name.')
@minLength(3)
@maxLength(24)
param keyVaultName string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    publicNetworkAccess: 'Enabled'
    softDeleteRetentionInDays: 7
  }
}

output keyVaultName string = keyVault.name

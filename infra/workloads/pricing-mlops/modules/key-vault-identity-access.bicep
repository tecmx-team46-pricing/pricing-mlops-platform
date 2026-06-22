@description('Key Vault name.')
param keyVaultName string

@description('Principal id receiving minimum read access to the Key Vault resource.')
param principalId string

var readerRoleDefinitionId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var keyVaultSecretsOfficerRoleDefinitionId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource keyVaultReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, readerRoleDefinitionId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

resource keyVaultSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, keyVaultSecretsOfficerRoleDefinitionId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsOfficerRoleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output keyVaultReaderRoleAssignmentId string = keyVaultReader.id
output keyVaultSecretsOfficerRoleAssignmentId string = keyVaultSecretsOfficer.id

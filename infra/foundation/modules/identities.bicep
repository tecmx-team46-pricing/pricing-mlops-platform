targetScope = 'resourceGroup'

@description('Azure region.')
param location string

@description('Tags applied to identity resources.')
param tags object

@description('Existing shared Key Vault name.')
param keyVaultName string

@description('One user-assigned managed identity for GitHub Actions OIDC.')
param githubActionsIdentityName string

@description('GitHub repository in org/repo format. Empty value skips federated credential creation.')
param githubRepository string = ''

@description('GitHub environment used by deployments.')
param githubEnvironment string

@description('Create the GitHub Actions identity and federated credential.')
param enableGithubActionsIdentity bool = !empty(githubRepository)

@description('Optional user-assigned managed identity for the functional model repo GitHub Actions OIDC.')
param modelGithubActionsIdentityName string = ''

@description('Functional model GitHub repository in org/repo format. Empty value skips model federated credential creation.')
param modelGithubRepository string = ''

@description('GitHub environment used by the functional model repo.')
param modelGithubEnvironment string = githubEnvironment

@description('Create the functional model repo GitHub Actions identity and federated credential.')
param enableModelGithubActionsIdentity bool = !empty(modelGithubRepository)

var keyVaultSecretsUserRoleDefinitionId = '4633458b-17de-408a-b874-0445c86b69e6'
var githubActionsSubject = 'repo:${githubRepository}:environment:${githubEnvironment}'
var shouldCreateFederatedCredential = enableGithubActionsIdentity && !empty(githubRepository)
var modelGithubActionsSubject = 'repo:${modelGithubRepository}:environment:${modelGithubEnvironment}'
var shouldCreateModelFederatedCredential = enableModelGithubActionsIdentity && !empty(modelGithubRepository) && !empty(modelGithubActionsIdentityName)

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource githubActionsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (enableGithubActionsIdentity) {
  name: githubActionsIdentityName
  location: location
  tags: tags
}

resource githubActionsCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = if (shouldCreateFederatedCredential) {
  parent: githubActionsIdentity
  name: 'github-${githubEnvironment}'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: githubActionsSubject
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

resource githubKeyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableGithubActionsIdentity) {
  scope: keyVault
  name: guid(keyVault.id, githubActionsIdentityName, keyVaultSecretsUserRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleDefinitionId)
    principalId: githubActionsIdentity!.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource modelGithubActionsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (enableModelGithubActionsIdentity && !empty(modelGithubActionsIdentityName)) {
  name: modelGithubActionsIdentityName
  location: location
  tags: union(tags, {
    repo_role: 'model'
  })
}

resource modelGithubActionsCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = if (shouldCreateModelFederatedCredential) {
  parent: modelGithubActionsIdentity
  name: 'github-model-${modelGithubEnvironment}'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: modelGithubActionsSubject
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

output githubActionsClientId string = enableGithubActionsIdentity ? githubActionsIdentity!.properties.clientId : ''
output githubActionsPrincipalId string = enableGithubActionsIdentity ? githubActionsIdentity!.properties.principalId : ''
output githubActionsSubject string = shouldCreateFederatedCredential ? githubActionsSubject : ''
output modelGithubActionsClientId string = shouldCreateModelFederatedCredential ? modelGithubActionsIdentity!.properties.clientId : ''
output modelGithubActionsPrincipalId string = shouldCreateModelFederatedCredential ? modelGithubActionsIdentity!.properties.principalId : ''
output modelGithubActionsSubject string = shouldCreateModelFederatedCredential ? modelGithubActionsSubject : ''

targetScope = 'subscription'

@description('Azure region.')
param location string

@description('Shared platform Resource Group name.')
param sharedResourceGroupName string

@description('Workload Resource Group name.')
param workloadResourceGroupName string

@description('Tags for the shared platform Resource Group.')
param sharedTags object

@description('Tags for the workload Resource Group.')
param workloadTags object

resource sharedRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: sharedResourceGroupName
  location: location
  tags: sharedTags
}

resource workloadRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: workloadResourceGroupName
  location: location
  tags: workloadTags
}

output sharedResourceGroupName string = sharedRg.name
output workloadResourceGroupName string = workloadRg.name

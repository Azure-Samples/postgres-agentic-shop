metadata description = 'Creates an Azure Container Registry.'
param name string
param location string = resourceGroup().location
param tags object = {}

@description('Indicates whether admin user is enabled')
param adminUserEnabled bool = true

@description('Indicates whether anonymous pull is enabled')
param anonymousPullEnabled bool = false

@description('Azure ad authentication as arm policy settings')
param azureADAuthenticationAsArmPolicy object = {
  status: 'enabled'
}

@description('Indicates whether data endpoint is enabled')
param dataEndpointEnabled bool = false

@description('Encryption settings')
param encryption object = {
  status: 'disabled'
}

@description('Export policy settings')
param exportPolicy object = {
  status: 'enabled'
}

@description('Metadata search settings')
param metadataSearch string = 'Disabled'

@description('Options for bypassing network rules')
param networkRuleBypassOptions string = 'AzureServices'

@description('Public network access setting')
param publicNetworkAccess string = 'Enabled'

@description('Quarantine policy settings')
param quarantinePolicy object = {
  status: 'disabled'
}

@description('Retention policy settings')
param retentionPolicy object = {
  days: 7
  status: 'disabled'
}

@description('Scope maps setting')
param scopeMaps array = []

@description('SKU settings')
param sku object = {
  name: 'Basic'
}

@description('Soft delete policy settings')
param softDeletePolicy object = {
  retentionDays: 7
  status: 'disabled'
}

@description('Trust policy settings')
param trustPolicy object = {
  type: 'Notary'
  status: 'disabled'
}

@description('Zone redundancy setting')
param zoneRedundancy string = 'Disabled'

@description('Optional override for the resource group. If empty, uses the module\'s resource group.')
param targetResourceGroupName string = '' // Add parameter for receiving

// define a scope when built
var targetScope = empty(targetResourceGroupName)
  ? resourceGroup()
  : resourceGroup(targetResourceGroupName)

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2024-11-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: sku
  properties: {
    adminUserEnabled: adminUserEnabled
    anonymousPullEnabled: anonymousPullEnabled
    dataEndpointEnabled: dataEndpointEnabled
    encryption: encryption
    metadataSearch: metadataSearch
    networkRuleBypassOptions: networkRuleBypassOptions
    policies:{
      quarantinePolicy: quarantinePolicy
      trustPolicy: trustPolicy
      retentionPolicy: retentionPolicy
      exportPolicy: exportPolicy
      azureADAuthenticationAsArmPolicy: azureADAuthenticationAsArmPolicy
      softDeletePolicy: softDeletePolicy
    }
    publicNetworkAccess: publicNetworkAccess
    zoneRedundancy: zoneRedundancy
  }

  resource scopeMap 'scopeMaps' = [for scopeMap in scopeMaps: {
    name: scopeMap.name
    properties: scopeMap.properties
  }]
}

output id string = containerRegistry.id
output loginServer string = containerRegistry.properties.loginServer
output name string = containerRegistry.name

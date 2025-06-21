metadata description = 'Creates an Azure Container Registry and an Azure Container Apps environment.'
param name string
param location string = resourceGroup().location
param tags object = {}

param containerAppsEnvironmentName string
param containerRegistryName string
param containerRegistryResourceGroupName string = ''
param containerRegistryAdminUserEnabled bool = false

module containerAppsEnvironment 'container-apps-environment.bicep' = {
  name: '${name}-container-apps-environment'
  scope: resourceGroup()
  params: {
    name: containerAppsEnvironmentName
    location: location
    tags: tags
  }
}

// ACR: for local RG
module containerRegistryLocal 'container-registry.bicep' = if (empty(containerRegistryResourceGroupName)) {
  name: 'acr-local'
  scope: resourceGroup()
  params: {
    name                : containerRegistryName
    location            : location
    adminUserEnabled    : containerRegistryAdminUserEnabled
    tags                : tags
  }
}

// ACR: for cross RG
module containerRegistryCrossRG 'container-registry.bicep' = if (!empty(containerRegistryResourceGroupName)) {
  name: 'acr-cross'
  scope: resourceGroup(containerRegistryResourceGroupName)
  params: {
    name             : containerRegistryName
    location         : location
    adminUserEnabled : containerRegistryAdminUserEnabled
    tags             : tags
  }
}

output defaultDomain string = containerAppsEnvironment.outputs.defaultDomain
output environmentName string = containerAppsEnvironment.outputs.name
output environmentId string = containerAppsEnvironment.outputs.id

// switch output
var loginServerOut = empty(containerRegistryResourceGroupName)
  ? containerRegistryLocal.outputs.loginServer
  : containerRegistryCrossRG.outputs.loginServer
output registryLoginServer string = loginServerOut

var loginServerName = empty(containerRegistryResourceGroupName)
  ? containerRegistryLocal.outputs.name
  : containerRegistryCrossRG.outputs.name
output registryName string = loginServerName

var loginServerId = empty(containerRegistryResourceGroupName)
  ? containerRegistryLocal.outputs.id
  : containerRegistryCrossRG.outputs.id
output registryid string = loginServerId

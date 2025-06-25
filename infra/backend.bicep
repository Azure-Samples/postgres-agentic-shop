metadata description = 'Creates Backend Azure Container App.'
param name string
param location string = resourceGroup().location
param tags object = {}

param containerAppsEnvironmentName string
param containerRegistryName string
param exists bool
param identityName string
param serviceName string = 'backend'
param environmentVariables array = []
@secure()
param secrets object

resource webIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

module backendapp 'core/host/container-app.bicep' = {
  name: '${serviceName}-container-app-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityName: webIdentity.name
    exists: exists
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    registries: [
      {
        server: '${containerRegistryName}.azurecr.io'
        identity: webIdentity.id
  }]
    env: union(
      environmentVariables,
      [
        {
          name: 'APP_IDENTITY_ID'
          value: webIdentity.properties.clientId
        }
        {
          name: 'APP_IDENTITY_NAME'
          value: webIdentity.name
        }
      ]
    )
    secrets: secrets
    targetPort: 80
  }
}

output SERVICE_WEB_IDENTITY_PRINCIPAL_ID string = webIdentity.properties.principalId
output SERVICE_WEB_IDENTITY_NAME string = webIdentity.name
output SERVICE_WEB_NAME string = backendapp.outputs.name
output SERVICE_WEB_URI string = backendapp.outputs.uri
output SERVICE_WEB_IMAGE_NAME string = backendapp.outputs.imageName

output uri string = backendapp.outputs.uri

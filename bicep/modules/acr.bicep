param AcrRole string
param AksIdentity string

// ACR ARM Template: https://docs.microsoft.com/en-us/azure/templates/microsoft.containerregistry/registries?tabs=json#QuarantinePolicy
resource acr 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = {
  name: 'crgarprv3acr'
  location: resourceGroup().location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true // disable username/password auth
  }
}

// Role Assignments ARM Template: https://docs.microsoft.com/en-us/azure/templates/microsoft.authorization/2020-04-01-preview/roleassignments?tabs=json#RoleAssignmentProperties
// ACR Permissions: https://docs.microsoft.com/en-us/azure/container-registry/container-registry-roles
resource aksAcrPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id)
  scope: acr
  properties: {
    principalId: AksIdentity
    roleDefinitionId: AcrRole
  }
}

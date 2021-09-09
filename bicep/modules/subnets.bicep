param routeTableId string
param vnetName string

var aksSubnetInfo = {
  name: 'aks-nodes-subnet'
  properties: {
    addressPrefix: '10.2.4.0/24'
  }
}

var privateEndpointsSubnetInfo = {
  name: 'aks-prvendpt-subnet'
  properties: {
    addressPrefix: '10.2.5.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var jumpboxSubnetInfo = {
  name: 'aks-jumpbox-subnet'
  properties: {
    addressPrefix: '10.2.6.0/24'
  }
}

var allSubnets = [
  privateEndpointsSubnetInfo
  aksSubnetInfo
  jumpboxSubnetInfo
]

resource existingVNET 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: vnetName
}

@batchSize(1)
resource Subnets 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = [for (sn, index) in allSubnets: {
  name: sn.name
  parent: existingVNET
  properties: union(sn.properties, {
    routeTable: {
      id: routeTableId
    }
  })
}]

output vnetId string = existingVNET.id
output aksSubnetId string = '${existingVNET.id}/subnets/${aksSubnetInfo.name}'

param EnvironmentName string
param K8sVersion string
param AdminGroupObjectIDs array = []
param RouteTableId string
param VnetName string


module SubnetsModule 'modules/subnets.bicep' = {
  name: 'SubnetsDeployment'

  params: {
    routeTableId: RouteTableId
    vnetName: VnetName
  }
}

module LogAnalyticsModule 'modules/loganalytics.bicep' = {
  name: 'LogAnalyticsDeployment'

  params: {
    EnvironmentName: EnvironmentName
  }
}

module AksModule 'modules/aks.bicep' = {
  name: 'AksClusterDeployment'
  
  dependsOn: [
    SubnetsModule
    LogAnalyticsModule
  ]

  params: {
    ClusterName: '${EnvironmentName}-aks'
    SubnetId: SubnetsModule.outputs.aksSubnetId
    logAnalyticsWorkspaceID: LogAnalyticsModule.outputs.logAnalyticsWorkspaceID
    AdminGroupObjectIDs: AdminGroupObjectIDs
    K8sVersion: K8sVersion
  }
}


module antoher 'modules/another.bicep' = {
  name: 'asd'

  params: {
    input: '9'
  }

}

resource Subnets 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = [for sn in antoher.outputs.myoutput: {
  
}]

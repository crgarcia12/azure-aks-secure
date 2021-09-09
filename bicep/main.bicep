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

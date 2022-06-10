param ClusterName string
param SubnetId string
param logAnalyticsWorkspaceID string
param AdminGroupObjectIDs array
param K8sVersion string

param userNodePools array = [
  {
    name: 'usernp01'
    count: 1
    vmSize: 'Standard_D4s_v3'
    osDiskSizeGB: 100
    osDiskType: 'Ephemeral'
    vnetSubnetID: SubnetId
    maxPods: 10
    maxCount: 1
    minCount: 1
    enableAutoScaling: true
    mode: 'User'
    orchestratorVersion: K8sVersion
    maxSurge: null
    tags: {}
    nodeLabels: {}
    taints: []
  }
]

param aksSettings object = {
  kubernetesVersion: null
  identity: 'SystemAssigned'
  networkPlugin: 'azure'
  networkPolicy: 'calico'
  serviceCidr: '172.16.0.0/22' // Must be cidr not in use any where else across the Network (Azure or Peered/On-Prem).  Can safely be used in multiple clusters - presuming this range is not broadcast/advertised in route tables.
  dnsServiceIP: '172.16.0.10' // Ip Address for K8s DNS
  dockerBridgeCidr: '172.16.4.1/22' // Used for the default docker0 bridge network that is required when using Docker as the Container Runtime.  Not used by AKS or Docker and is only cluster-routable.  Cluster IP based addresses are allocated from this range.  Can be safely reused in multiple clusters.
  loadBalancerSku: 'standard'
  sku_tier: 'Free'				
  enableRBAC: true 
  aadProfileManaged: true

  outboundType: 'userDefinedRouting'
  enablePrivateCluster: true
}

param defaultNodePool object = {
  name: 'systempool01'
  count: 3
  vmSize: 'Standard_D2s_v3'
  osDiskSizeGB: 50
  osDiskType: 'Ephemeral'
  vnetSubnetID: SubnetId
  osType: 'Linux'
  maxCount: 1
  minCount: 1
  enableAutoScaling: true
  type: 'VirtualMachineScaleSets'
  mode: 'System' // setting this to system type for just k8s system services
  orchestratorVersion: null
  nodeTaints: [
    'CriticalAddonsOnly=true:NoSchedule' // adding to ensure that only k8s system services run on these nodes
  ]
}

// https://docs.microsoft.com/en-us/azure/templates/microsoft.containerservice/managedclusters?tabs=json#ManagedClusterAgentPoolProfile
resource aks 'Microsoft.ContainerService/managedClusters@2021-02-01' = {
  name: ClusterName
  location: resourceGroup().location
  identity: {
    type: aksSettings.identity
  }
  sku: {
    name: 'Basic'
    tier: aksSettings.sku_tier
  }
  properties: {
    kubernetesVersion: aksSettings.kubernetesVersion
    dnsPrefix: ClusterName    
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceID
        }
      }
    }
    
    enableRBAC: aksSettings.enableRBAC

    enablePodSecurityPolicy: false // setting to false since PSPs will be deprecated in favour of Gatekeeper/OPA

    networkProfile: {
      networkPlugin: aksSettings.networkPlugin 
      networkPolicy: aksSettings.networkPolicy 
      serviceCidr: aksSettings.serviceCidr  // Must be cidr not in use any where else across the Network (Azure or Peered/On-Prem).  Can safely be used in multiple clusters - presuming this range is not broadcast/advertised in route tables.
      dnsServiceIP: aksSettings.dnsServiceIP // Ip Address for K8s DNS
      dockerBridgeCidr: aksSettings.dockerBridgeCidr  // Used for the default docker0 bridge network that is required when using Docker as the Container Runtime.  Not used by AKS or Docker and is only cluster-routable.  Cluster IP based addresses are allocated from this range.  Can be safely reused in multiple clusters.
      outboundType: aksSettings.outboundType 
      loadBalancerSku: aksSettings.loadBalancerSku 
      // networkMode: 'transparent' // defaults to transparent
      // podCidr: '' // used when networkPlugin is set to kubenet
      // loadBalancerProfile: {} // Profile for when outboundType: 'loadBalancer' - can config multiple pip etc. for cluster LB
    }

    aadProfile: {
      managed: aksSettings.aadProfileManaged
      enableAzureRBAC: true // Cross-Tenant Azure RBAC doesn't work - must be same tenant as the cluster subscription
      adminGroupObjectIDs: AdminGroupObjectIDs
    }

    autoUpgradeProfile: {}

    apiServerAccessProfile: {
      enablePrivateCluster: false // we're not deploying a private cluster in this webinar
      // privateDNSZone: 'some.customdomain.com' // allows you to BYO DNS
      // authorizedIPRanges: [] // we are not whitelisting IP ranges to communicate with the API server
    }
    
    agentPoolProfiles: [
      defaultNodePool
    ]
  }
}

resource aksNodepool 'Microsoft.ContainerService/managedClusters/agentPools@2021-02-01' = [ for nodepool in userNodePools: {
  name: '${aks.name}/${nodepool.name}'
  properties: {
    count: nodepool.count
    vmSize: nodepool.vmSize
    osDiskSizeGB: nodepool.osDiskSizeGB
    osDiskType: nodepool.osDiskType
    vnetSubnetID: SubnetId
    maxPods: nodepool.maxPods
    osType: 'Linux'
    maxCount: nodepool.maxCount
    minCount: nodepool.minCount
    enableAutoScaling: nodepool.enableAutoScaling
    type: 'VirtualMachineScaleSets'
    mode: nodepool.mode
    orchestratorVersion: nodepool.orchestratorVersion
    upgradeSettings: {
      maxSurge: nodepool.maxSurge
    }
    tags: nodepool.tags
    nodeLabels: nodepool.nodeLabels
    nodeTaints: nodepool.taints
  }
}]

output AksIdentity string = aks.identity.principalId

param cluster_name string = ''
param spoke_virtual_network_subnet_id string = ''
param log_analytics_workspace_id string = ''
param location string = ''
param kubernetesVersion string = '1.21.1'
param cluster_rg_msi_id string = ''
param api_server_dns_resource_id string = ''
param resource_tags object = {
  kubernetesVersion: '1.21.1'
  dns: 'byodns'
}

resource cluster_name_resource 'Microsoft.ContainerService/managedClusters@2020-12-01' = {
  name: cluster_name
  location: location
  tags: resource_tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${cluster_rg_msi_id}': {}
    }
  }
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: 'crgarclusterdnsprefix'
    fqdnSubdomain: 'crgarfqdn'
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: api_server_dns_resource_id
    }
    aadProfile: {
      managed: true
      adminGroupObjectIDs: [
        '8dda9002-1249-48ad-8620-4ee582b98f6b'
      ]
    }
    enableRBAC: true
    enablePodSecurityPolicy: false
    networkProfile: {
      networkPlugin: 'kubenet'
      loadBalancerSku: 'standard'
      outboundType: 'userDefinedRouting'
      networkPolicy: 'calico'
    }
    agentPoolProfiles: [
      {
        name: 'default'
        count: 2
        maxCount: 4
        minCount: 1
        vmSize: 'Standard_DS2_v2'
        osDiskSizeGB: 30
        vnetSubnetID: spoke_virtual_network_subnet_id
        maxPods: 30
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        enableAutoScaling: true
        orchestratorVersion: kubernetesVersion
        enableNodePublicIP: false
        mode: 'System'
        osType: 'Linux'
      }
    ]
    addonProfiles: {
      kubeDashboard: {
        enabled: false
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: log_analytics_workspace_id
        }
      }
      azurepolicy: {
        config: {
          version: 'v2'
        }
        enabled: true
        identity: null
      }
    }
  }
}

resource cluster_name_Microsoft_Insights_diagnostics 'Microsoft.ContainerService/managedClusters/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${cluster_name}/Microsoft.Insights/diagnostics'
  properties: {
    workspaceId: log_analytics_workspace_id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'kube-apiserver'
        enabled: true
      }
      {
        category: 'kube-audit'
        enabled: true
      }
      {
        category: 'kube-audit-admin'
        enabled: true
      }
      {
        category: 'kube-controller-manager'
        enabled: true
      }
      {
        category: 'kube-scheduler'
        enabled: true
      }
      {
        category: 'cluster-autoscaler'
        enabled: true
      }
      {
        category: 'guard'
        enabled: true
      }
    ]
  }
  dependsOn: [
    cluster_name_resource
  ]
}
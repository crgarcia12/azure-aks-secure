// https://docs.microsoft.com/en-us/azure/templates/microsoft.operationalinsights/2020-03-01-preview/workspaces?tabs=json
param EnvironmentName string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: '${EnvironmentName}-loganalytics'
  tags: {}
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: 30
    }
    // publicNetworkAccessForIngestion: 'false'
    // publicNetworkAccessForQuery: 'false'
  }
}
output logAnalyticsWorkspaceID string = logAnalyticsWorkspace.id

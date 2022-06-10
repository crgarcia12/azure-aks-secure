function Add-AzureIpRestrictionRule
{
    [CmdletBinding()]
    Param
    (
        # Name of the resource group that contains the App Service.
        [Parameter()]
        $ResourceGroupName = "crgar-domaintest",

        # Name of your Web or API App.
        [Parameter()]
        $AppServiceName ="crgar-domaintest-app",

        # rule to add.
        [Parameter(Mandatory=$true, Position=2)]
        [PSCustomObject]$rule 
    )

    $ApiVersions = Get-AzResourceProvider -ProviderNamespace Microsoft.Web | 
        Select-Object -ExpandProperty ResourceTypes |
        Where-Object ResourceTypeName -eq 'sites' |
        Select-Object -ExpandProperty ApiVersions

    $LatestApiVersion = $ApiVersions[0]

    $WebAppConfig = Get-AzResource -ResourceType 'Microsoft.Web/sites/config' -ResourceName $AppServiceName -ResourceGroupName $ResourceGroupName -ApiVersion $LatestApiVersion

    $WebAppConfig.Properties.ipSecurityRestrictions =  $WebAppConfig.Properties.ipSecurityRestrictions + @($rule) | 
        Group-Object name | 
        ForEach-Object { $_.Group | Select-Object -Last 1 }

    Set-AzResource -ResourceId $WebAppConfig.ResourceId -Properties $WebAppConfig.Properties -ApiVersion $LatestApiVersion -Force    
}


$rule = [PSCustomObject]@{
  ipAddress = "40.40.40.40/32"
  action = "Allow"  
  priority = 123 
  name = '{0}_{1}' -f $env:computername, $env:USERNAME 
  description = "Automatically added ip restriction"
}

Add-AzureIpRestrictionRule -rule $rule


return 


$ResourceGroupName = "crgar-aks-prv4-spoke-rg"

az deployment group create `
  --name aksdeployment1 `
  --resource-group $ResourceGroupName `
  --template-file main.bicep `
  --parameters '@parameters.json' `
  --mode Incremental




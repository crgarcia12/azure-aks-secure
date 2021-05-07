function New-CompliantAksCluster {
    [CmdletBinding()]
    Param(
        $EnvironmentName,
        $Location
    )

    Write-Verbose "Deploying AKS in RG '$Properties.ResourceGroupName'."
    $Properties = Get-CompliantAksProperties -EnvironmentName $EnvironmentName -Location $Location
    New-AzResourceGroupDeployment -ResourceGroupName $Properties.ResourceGroupName -TemplateFile ./arm/aks-kubenet.json -TemplateParameterFile $Properties.TemplateParameterFilePath
    Write-Verbose "Done deploying AKS."

    return $Properties
}

function New-CompliantAksContainerRegistry
{
    $networkName = $(az network vnet list `
        --resource-group $Properties.ResourceGroupName `
        --query '[].{Name: name}' --output tsv)
  
    $subnetName = $(az network vnet list `
        --resource-group $Properties.ResourceGroupName `
        --query '[].{Subnet: subnets[0].name}' --output tsv)

    az acr create --name 'crgar-dns-es-spoke-acr'`
              --resource-group 'crgar-dns-es-spoke' `
              --sku Premium `
              --admin-enabled false `
              --location `
              --public-network-enabled false `
              --zone-redundancy Disabled `
                --allow-trusted-services true

            #     [--default-action {Allow, Deny}]
            #   [--identity]
            #   [--key-encryption-key]

            #   [--workspace]
            #   [, Enabled}]
}
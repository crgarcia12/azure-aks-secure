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
    Write-Verbose "Connecting ACR to AKS..."
    az aks update -n $Properties.ClusterName -g $Properties.ResourceGroupName --attach-acr $Properties.ContainerRegistryId
    Write-Verbose "Done connecting ACR to AKS"

    return $Properties
}

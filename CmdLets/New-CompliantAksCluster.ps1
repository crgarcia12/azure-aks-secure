function New-CompliantAksCluster {
    [CmdletBinding()]
    Param(
        $EnvironmentName,
        $Location
    )

    $Properties = Get-CompliantAksProperties -EnvironmentName $EnvironmentName -Location $Location

    Write-Verbose "Deploying AKS in RG '$Properties.SpokeResourceGroupName'."
    New-AzResourceGroupDeployment `
        -ResourceGroupName $Properties.SpokeResourceGroupName `
        -TemplateFile ./arm/aks-kubenet.json `
        -TemplateParameterFile $Properties.TemplateParameterFilePath
    Write-Verbose "Done deploying AKS."

    Write-Verbose "Connecting ACR to AKS..."
    az aks update -n $Properties.ClusterName -g $Properties.SpokeResourceGroupName --attach-acr $Properties.ContainerRegistryId
    Write-Verbose "Done connecting ACR to AKS"

    return $Properties
}

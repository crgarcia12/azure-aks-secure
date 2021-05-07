function New-CompliantAksCluster {
    [CmdletBinding()]
    Param(
        $EnvironmentName,
        $Location
    )

    Write-Verbose "Deploying AKS in RG '$Properties.ResourceGroupName'."
    $Properties = Get-CompliantAksProperties -EnvironmentName $EnvironmentName -Location $Location
    New-AzResourceGroupDeployment -ResourceGroupName $Properties.ResourceGroupName -TemplateFile ./arm/aks.json -TemplateParameterFile $Properties.TemplateParameterFilePath
    Write-Verbose "Done deploying AKS."

    return $Properties
}

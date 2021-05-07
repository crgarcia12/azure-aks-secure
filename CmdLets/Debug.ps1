# You can press F5 in here, and it will break on breakpoints
Import-Module ./CmdLets/CompliantAks.psm1 -Verbose -Force

$EnvironmentName = "crgar-aks-27"
$Location = 'westeurope'

New-CompliantAksLandingZone -EnvironmentName $EnvironmentName -Location $Location
#New-CompliantAksCluster -EnvironmentName $EnvironmentName -Location $Location\



$Properties = Get-CompliantAksProperties -EnvironmentName $EnvironmentName -Location $Location

New-AzResourceGroupDeployment -ResourceGroupName "crgar-aks-21-cluster-rg" -TemplateFile aks-kubenet.json


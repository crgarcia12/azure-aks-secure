# You can press F5 in here, and it will break on breakpoints
Import-Module ./CmdLets/CompliantAks.psm1 -Verbose -Force

$EnvironmentName = "crgar-aks-73"
$Location = 'westeurope'

$Properties = New-CompliantAksLandingZone -EnvironmentName $EnvironmentName -Location $Location
New-CompliantAksCluster -EnvironmentName $EnvironmentName -Location $Location
# $Properties = Get-CompliantAksProperties -EnvironmentName $EnvironmentName -Location $Location


# You can press F5 in here, and it will break on breakpoints
Import-Module ./CmdLets/CompliantAks.psm1 -Verbose -Force

$EnvironmentName = "crgar-aks-81"
$Location = 'switzerlandnorth'

$Properties = New-CompliantAksLandingZone -EnvironmentName $EnvironmentName -Location $Location
New-CompliantAksCluster -EnvironmentName $EnvironmentName -Location $Location
# $Properties = Get-CompliantAksProperties -EnvironmentName $EnvironmentName -Location $Location



# $clusterMsiId = "/subscriptions/930c11b0-5e6d-458f-b9e3-f3dda0734110/resourcegroups/crgar-aks-byomsi-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/crgar-aks-byomsi-clustermsi"
# $rg = "crgar-aks-byomsi-rg"
# $subnetId = "/subscriptions/930c11b0-5e6d-458f-b9e3-f3dda0734110/resourceGroups/crgar-aks-byomsi-rg/providers/Microsoft.Network/virtualNetworks/crgar-aks-byomsi-vnet/subnets/aks"
# $identityId = "/subscriptions/930c11b0-5e6d-458f-b9e3-f3dda0734110/resourceGroups/crgar-aks-byomsi-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/crgar-aks-byomsi-clustermsi"

# az aks create `
#     --resource-group "crgar-aks-byomsi-rg" `
#     --name crgar-aks-byomsi-aks `
#     --network-plugin azure `
#     --vnet-subnet-id $subnetId `
#     --docker-bridge-address 172.17.0.1/16 `
#     --dns-service-ip 10.2.0.10 `
#     --service-cidr 10.2.0.0/24 `
#     --enable-managed-identity `
#     --assign-identity $identityId
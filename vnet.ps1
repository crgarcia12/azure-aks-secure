Connect-AzAccount
Get-AzSubscription 
Select-AzSubscription -Subscription "crgar-Internal-subscription"
$rgHub = "crgar-aks-81-hub-rg"
$rgSpoke = "crgar-aks-81-spoke-rg"
 
$vNetHub = Get-AzVirtualNetwork -Name "crgar-aks-81-hub-vnet" `
                               -ResourceGroupName $rgHub
$vNetSpoke = Get-AzVirtualNetwork -Name "crgar-aks-81-spoke-vnet" `
                               -ResourceGroupName $rgSpoke

Get-AzVirtualNetworkPeering -VirtualNetworkName $vNetSpoke.Name -ResourceGroupName $rgSpoke
Get-AzVirtualNetworkPeering -VirtualNetworkName $vNetHub.Name -ResourceGroupName $rgHub


$vNetSpoke.AddressSpace.AddressPrefixes.Add("10.50.0.0/16")
$vNetSpoke | Set-AzVirtualNetwork

Get-AzVirtualNetworkPeering -VirtualNetworkName $vNetSpoke.Name -ResourceGroupName $rgSpoke `
    | Format-Table Name, peeringState, PeeringSyncLevel

 
Get-AzVirtualNetworkPeering -VirtualNetworkName $vNetHub.Name -ResourceGroupName $rgHub `
    | Format-Table Name, peeringState, PeeringSyncLevel

Sync-AzVirtualNetworkPeering -Name "hub-spoke" -VirtualNetworkName $vNetHub.Name -ResourceGroupName $rgHub
Sync-AzVirtualNetworkPeering -Name "spoke-hub" -VirtualNetworkName $vNetSpoke.Name -ResourceGroupName $rgSpoke

az aks update -g crgar-aks-81-spoke-rg -n crgar-aks-81-cluster
az aks nodepool add --cluster-name crgar-aks-81-cluster `
                    --name pool2 `
                    --resource-group crgar-aks-81-spoke-rg `
                    --mode User `
                    --node-count 1 `
                    --vnet-subnet-id "/subscriptions/930c11b0-5e6d-458f-b9e3-f3dda0734110/resourceGroups/crgar-aks-81-spoke-rg/providers/Microsoft.Network/virtualNetworks/crgar-aks-81-spoke-vnet/subnets/aks-nodes2-subnet"

az aks get-credentials -g crgar-aks-81-spoke-rg -n crgar-aks-81-cluster --admin

$cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
    -Subject "CN=P2SRootCert" -KeyExportPolicy Exportable `
    -HashAlgorithm sha256 -KeyLength 2048 `
    -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign

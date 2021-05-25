
function New-CompliantAksLandingZoneRouteTable {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )
    $Properties = $PropertiesRef.Value
    
    Write-Verbose "Creating UDR & Routing Table for Azure Firewall"
    #az network route-table create -g $ResourceGroup --name $FwRouteTableName
    $Properties.RouteTable = New-AzRouteTable `
        -ResourceGroupName $Properties.SpokeResourceGroupName `
        -Name $Properties.RouteTableName `
        -Location $Properties.Location

    $outnull = az network route-table route create `
        -g $Properties.SpokeResourceGroupName `
        --name "firewallroute" `
        --route-table-name $Properties.RouteTableName `
        --address-prefix 0.0.0.0/0 `
        --next-hop-type VirtualAppliance `
        --next-hop-ip-address $Properties.Firewall.IpConfigurations.PrivateIpAddress `
        --subscription $Properties.SubscriptionId

    Write-Verbose "Associating AKS Subnet to Azure Firewall"
    $outnull = az network vnet subnet update `
        -g $Properties.SpokeResourceGroupName `
        --vnet-name $Properties.SpokeVNetName `
        --name $Properties.SpokeSubnets.Nodes.Name `
        --route-table $properties.RouteTableName
    
}
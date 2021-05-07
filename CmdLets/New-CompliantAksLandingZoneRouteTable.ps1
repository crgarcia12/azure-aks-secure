
function New-CompliantAksLandingZoneRouteTable {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )
    $Properties = $PropertiesRef.Value
    
    Write-Verbose "Creating UDR & Routing Table for Azure Firewall"
    #az network route-table create -g $ResourceGroup --name $FwRouteTableName
    $Properties.RouteTable = New-AzRouteTable `
        -ResourceGroupName $Properties.ResourceGroupName `
        -Name $Properties.RouteTableName `
        -Location $Properties.Location

    az network route-table route create -g $Properties.ResourceGroupName --name "firewallroute" --route-table-name $Properties.RouteTableName --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $Properties.Firewall.IpConfigurations.PrivateIpAddress --subscription $Properties.SubscriptionId

    Write-Verbose "Associating AKS Subnet to Azure Firewall"
    az network vnet subnet update -g $Properties.ResourceGroupName --vnet-name $Properties.VnetName --name $Properties.Subnets["Nodes"].Name --route-table $properties.RouteTableName
    
}
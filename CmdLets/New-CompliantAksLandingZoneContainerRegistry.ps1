function New-CompliantAksLandingZoneContainerRegistry {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )
    $Properties = $PropertiesRef.Value

    Write-Verbose "Creating Container Registry '$($Properties.ContainerRegistryName)'"
    $registry = New-AzContainerRegistry `
            -ResourceGroupName $Properties.ResourceGroupName `
            -Name $Properties.ContainerRegistryName `
            -Sku Premium `
            -Location $Properties.Location `
            -EnableAdminUser `
    
    $Properties.ContainerRegistryId = $registry.Id

    # Disable itnernet access
    az acr update --name $Properties.ContainerRegistryName  --public-network-enabled false  

    # Private endpoint does not support policies (ex: NSG) so we need to disable it
    $prvEndpointSubnet = $Properties.SpokeVnet.Subnets | ? Name -eq $Properties.SpokeSubnets.PrivateEndpoint.Name
    $prvEndpointSubnet.PrivateEndpointNetworkPolicies = "Disabled"
    $Properties.SpokeVnet = $Properties.SpokeVnet | Set-AzVirtualNetwork 

    # Create the endpoint and the connection to the registry
    $acrPrivateLinkConnection = New-AzPrivateLinkServiceConnection `
        -Name 'ACRPrivateLink' `
        -PrivateLinkServiceId $Properties.ContainerRegistryId `
        -GroupId 'registry'

    $prvEndpointSubnet = $Properties.SpokeVnet.Subnets | ? Name -eq $Properties.SpokeSubnets.PrivateEndpoint.Name
    $arcPrivateEndpoint = New-AzPrivateEndpoint `
        -Name "AcrPrivateEndpoint" `
        -ResourceGroupName $Properties.ResourceGroupName `
        -Location $Properties.Location `
        -Subnet $prvEndpointSubnet `
        -PrivateLinkServiceConnection $acrPrivateLinkConnection

    # Update the DNS

    New-AzPrivateDnsZone `
        -ResourceGroupName $Properties.ResourceGroupName `
        -Name "privatelink.azurecr.io" | Out-Null

    New-AzPrivateDnsVirtualNetworkLink `
        -ResourceGroupName $Properties.ResourceGroupName `
        -ZoneName "privatelink.azurecr.io" `
        -Name 'AcrDnsLink' `
        -VirtualNetwork $Properties.HubVnet `
        -EnableRegistration:$false | Out-Null

    $endpointPrivateIpAddress = $arcPrivateEndpoint.CustomDnsConfigs[1].IpAddresses[0]
    $Records = New-AzPrivateDnsRecordConfig -IPv4Address $endpointPrivateIpAddress
    New-AzPrivateDnsRecordSet `
        -Name $Properties.ContainerRegistryName `
        -ZoneName "privatelink.azurecr.io" `
        -ResourceGroupName $Properties.ResourceGroupName `
        -Ttl 1 `
        -RecordType A `
        -PrivateDnsRecord $Records | Out-Null
    
    $dataEndpointPrivateIpAddress = $arcPrivateEndpoint.CustomDnsConfigs[0].IpAddresses[0]
    $Records = New-AzPrivateDnsRecordConfig -IPv4Address $dataEndpointPrivateIpAddress
    New-AzPrivateDnsRecordSet `
        -Name "$($Properties.ContainerRegistryName).$($Properties.Location).data" `
        -ZoneName "privatelink.azurecr.io" `
        -ResourceGroupName $Properties.ResourceGroupName `
        -Ttl 1 `
        -RecordType A `
        -PrivateDnsRecord $Records | Out-Null
}
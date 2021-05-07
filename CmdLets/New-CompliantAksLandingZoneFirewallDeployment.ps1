function New-CompliantAksLandingZoneFirewallDeployment {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )
    $Properties = $PropertiesRef.Value

    Write-Verbose "Creating Public IP for Azure Firewall"
    $Properties.FirewallPublicIp = New-AzPublicIpAddress -ResourceGroupName $Properties.ResourceGroupName -Name $Properties.FirewallPublicIpName -Location $Properties.Location -Sku "Standard" -AllocationMethod Static

    Write-Verbose "Creating Azure Firewall"
    $Properties.Firewall = New-AzFirewall `
        -Name $Properties.FirewallName `
        -ResourceGroupName $Properties.ResourceGroupName `
        -Location $Properties.Location `
        -VirtualNetwork  $Properties.Vnet `
        -PublicIpAddress $Properties.FirewallPublicIp
    
    # This will enable the firewall to have FQDN rules

    # We neecd to have DNS enabled
    $Properties.Firewall.DNSEnableProxy = $true 

    Write-Verbose "Validate Azure Firewall IP Address Values"
    Write-Verbose "Public Ip: $($Properties.FirewallPublicIp.IpAddress)"
    Write-Verbose "Private Ip: $($Properties.Firewall.IpConfigurations.PrivateIpAddress)"

    Write-Verbose "Adding Network FW Rules for egress traffic"

    # FQDN Tags for FW Application Rules:
    # az network firewall application-rule create -g $RG -f $FWNAME --collection-name 'aksfwar' -n 'fqdn' --source-addresses '*' --protocols 'http=80' 'https=443' --fqdn-tags "AzureKubernetesService" --action allow --priority 100

    $priority = 1000
    $NetworkTimeProtocolRule = New-AzFirewallNetworkRule -Name 'NetworkTimeProtocol' `
        -SourceAddress '*' `
        -DestinationFqdn 'ntp.ubuntu.com' `
        -DestinationPort '123' `
        -Protocol UDP

    $MandatoryExternalCollection = New-AzFirewallNetworkRuleCollection -Name 'Mandatory-Externals' -Priority $($priority+=100;$priority) -Rule $NetworkTimeProtocolRule -ActionType "Allow"
    $Properties.Firewall.NetworkRuleCollections = $MandatoryExternalCollection

    $MicrosoftFQDNRule = New-AzFirewallApplicationRule -Name 'MicrosoftFQDN' `
        -SourceAddress '*' `
        -Protocol HTTPS `
        -TargetFqdn @(
            # "*.hcp.$($Properties.Location).azmk8s.io"
            'mcr.microsoft.com'
            '*.cdn.mscr.io'
            '*.data.mcr.microsoft.com'
            'management.azure.com'
            'login.microsoftonline.com'
            'packages.microsoft.com'
            'acs-mirror.azureedge.net'
        )
    $MandatoryMicrosoftCollection = New-AzFirewallApplicationRuleCollection -Name 'Mandatory-Microsoft' -Priority $($priority+=100;$priority) -Rule $MicrosoftFQDNRule -ActionType "Allow"

    $UbuntuUpdatesRule = New-AzFirewallApplicationRule -Name  'UbuntuUpdates' `
        -SourceAddress '*' `
        -Protocol HTTP `
        -TargetFqdn @(
                'security.ubuntu.com'
                'azure.archive.ubuntu.com'
                'changelogs.ubuntu.com'
        )
    $OptionalExternalCollection = New-AzFirewallApplicationRuleCollection -Name 'Optional-External' -Priority $($priority+=100;$priority) -Rule $UbuntuUpdatesRule -ActionType "Allow"
    

    $MonitoringRule = New-AzFirewallApplicationRule -Name 'Monitoring' `
        -SourceAddress '*' `
        -Protocol HTTPS `
        -TargetFqdn @(
            'dc.services.visualstudio.com'
            '*.ods.opinsights.azure.com'
            '*.oms.opinsights.azure.com'
            '*.microsoftonline.com'
            '*.monitoring.azure.com'
        )

    $PoliciesRule = New-AzFirewallApplicationRule -Name 'Policies' `
        -SourceAddress '*' `
        -Protocol HTTPS `
        -TargetFqdn @( 
            'gov-prod-policy-data.trafficmanager.net'
            'raw.githubusercontent.com'
            'dc.services.visualstudio.com'
        )
    $OptionalMsCollection = New-AzFirewallApplicationRuleCollection -Name 'Optional-Microsoft' -Priority $($priority+=100;$priority) -Rule $PoliciesRule, $MonitoringRule -ActionType "Allow"
    
    $Properties.Firewall.ApplicationRuleCollections = $MandatoryMicrosoftCollection, $OptionalExternalCollection, $OptionalMsCollection
    Set-AzFirewall -AzureFirewall $Properties.Firewall

    Write-Verbose "Done creating and configuring Firewall"
    
    Write-Verbose "Setting Firewall as DNS in the VNet"
    $Properties.Vnet.DhcpOptions.DnsServers += $Properties.Firewall.IpConfigurations.PrivateIpAddress
    Set-AzVirtualNetwork -VirtualNetwork $Properties.Vnet

    Write-Verbose "Done setting Firewall as DNS in the VNet"


}

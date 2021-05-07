function Select-CompliantAksAccount {
    [CmdletBinding()]
    Param(
        [string] $SubscriptionId
    )
    Write-Verbose "Selecting subscription" -Verbose

    Select-AzSubscription -SubscriptionId $SubscriptionId
    az account set --subscription $SubscriptionId
}

function New-CompliantAksFullDeployment {
    [CmdletBinding()]
    Param(
        [string] $EnvironmentName,
        [string] $Location,
        [switch] $RemoveOnly
    )
    Write-Verbose "Starting full deployment $EnvironmentName in $Location" -Verbose

    $properties = Get-CompliantAksProperties -EnvironmentName $EnvironmentName -Location $Location
    $group = Get-AzResourceGroup -Name $properties.ResourceGroupName -ErrorAction SilentlyContinue
    if($group)
    {
        Write-Verbose "Group $($properties.ResourceGroupName) exist. killing it!"
        Remove-AzResourceGroup -Name $properties.ResourceGroupName -Force
    }

    if($RemoveOnly)
    {
        return
    }

    $Properties = New-CompliantAksLandingZone -EnvironmentName $EnvironmentName -Location $Location
    $Properties = New-CompliantAksCluster -EnvironmentName $EnvironmentName -Location $Location
    
    Write-Verbose "Done with full deployment $EnvironmentName"
    $Properties
}

function Get-CompliantAksProperties
{
    [CmdletBinding()]
    Param(
        [string] $EnvironmentName,
        [string] $Location
    )

    # if ($EnvironmentName.Length -gt 12) {
    #     Write-Error "Environment Name '$EnvironmentName' is too long. It should be shorter than 13 - jumpbox vm name too long" -ErrorAction Stop
    # }
    
    Write-Verbose "Creating parameters for environment: '$EnvironmentName'"
    # Define resource names based on EnvironmentName
    $Properties = @{
        EnvironmentName = $EnvironmentName
        SubscriptionId = "930c11b0-5e6d-458f-b9e3-f3dda0734110"
        Location = $Location
        ResourceGroupName = "$EnvironmentName-rg"
        ClusterName = "$EnvironmentName-cluster"
        ContainerRegistryName = "$($EnvironmentName)acr" -replace "-", ""
        LogAnalyticsWorkspaceName = "$EnvironmentName-loganalytics"
        FirewallName = "$EnvironmentName-fw"
        FirewallPublicIpName = "$EnvironmentName-fw-publicip"
        RouteTableName = "$EnvironmentName-routetable"
        VnetName = "$EnvironmentName-vnet"
        Subnets = @{
            Firewall = @{
                Name = "AzureFirewallSubnet"
                AddressPrefix = "10.1.1.0/24"
                Subnet = "<PlaceHolder>"
            } 
            AppGateway= @{
                Name = "aks-gw-subnet"
                AddressPrefix = "10.1.2.0/24"
                Subnet = "<PlaceHolder>"
            }  
            Services = @{
                Name = "aks-svc-subnet"
                AddressPrefix = "10.1.3.0/24"
                Subnet = "<PlaceHolder>"
            }
            Nodes = @{
                Name = "aks-nodes-subnet"
                AddressPrefix = "10.1.4.0/24"
                SubnetId = "<PlaceHolder>"
            }
            PrivateEndpoint = @{
                Name = "aks-prvendpt-subnet"
                AddressPrefix = "10.1.5.0/24"
                Subnet = "<PlaceHolder>"
            }
            JumpBox = @{
                Name = "aks-jumpbox-subnet"
                AddressPrefix = "10.1.6.0/24"
                Subnet = "<PlaceHolder>"
            }
        }
        TemplateParameterFilePath = "./arm/environments/aks-params-$EnvironmentName.json"
        WindowsJumpBoxVmName = "$($EnvironmentName)win"
        LinuxJumpBoxVmName = "$($EnvironmentName)lin"
        Vnet = "<PlaceHolder>"
        Firewall = "<PlaceHolder>"
        FirewallIp = "<PlaceHolder>"
        FirewallPublicIp = "<PlaceHolder>"
        RouteTable = "<PlaceHolder>"
        ContainerRegistryId = "<PlaceHolder>"
    }

    $Properties.Vnet = Get-AzVirtualNetwork -Name $Properties.VnetName -ResourceGroupName $Properties.ResourceGroupName 

    $Properties
}

function New-CompliantAksLandingZone {
    [CmdletBinding()]
    Param(
        [string] $EnvironmentName,
        [string] $Location
    )
    $VerbosePreference = "Continue"

    $Properties = Get-CompliantAksProperties -EnvironmentName $EnvironmentName -Location $Location
    New-CompliantAksLandingZoneVnet -Properties ([ref]$Properties)
    New-CompliantAksLandingZoneLogAnalytics -Properties ([ref]$Properties)
    New-CompliantAksLandingZoneFirewallDeployment -Properties ([ref]$Properties)
    New-CompliantAksLandingZoneRouteTable -Properties ([ref]$Properties)
    Add-CompliantAksJumpBox -Properties ([ref]$Properties)
    New-CompliantAksParametersTemplateFile -Properties $Properties

}

function New-CompliantAksLandingZoneVnet {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )

    $Properties = $PropertiesRef.Value
    New-AzResourceGroup -Name $Properties.ResourceGroupName -Location $Properties.Location -Force

    Write-Verbose "Creating VNet and subnet: ' $($Properties.VnetName)'"
        New-AzVirtualNetwork `
            -Name $Properties.VnetName `
            -ResourceGroupName $Properties.ResourceGroupName `
            -Location $Location `
            -AddressPrefix 10.1.0.0/16 -Force | Out-Null
        $Properties.Vnet = Get-AzVirtualNetwork -Name $Properties.VnetName -ResourceGroupName $Properties.ResourceGroupName
        foreach($subnet in $Properties.Subnets.Values) {
            Write-Verbose "Creating Subnet $($subnet.Id)"
            Add-AzVirtualNetworkSubnetConfig `
                -VirtualNetwork $Properties.Vnet `
                -Name $subnet.Name `
                -AddressPrefix $subnet.AddressPrefix | Out-Null
        }
        $Properties.Vnet | Set-AzVirtualNetwork | Out-Null
    Write-Verbose "Done creating VNet and subnet."

    Write-Verbose "Getting Node Pool Subnet Id"
    $Properties.Subnets["Nodes"].SubnetId = ""
    while($Properties.Subnets["Nodes"].SubnetId -eq "")
    {
        $attempt++
        Start-Sleep -s 1
        $Properties.Vnet = Get-AzVirtualNetwork -Name $Properties.VnetName -ResourceGroupName $Properties.ResourceGroupName
        $Properties.Subnets["Nodes"].SubnetId = ($Properties.Vnet.Subnets | ? Name -eq $Properties.Subnets["Nodes"].Name).Id 
        Write-Verbose "Subnet Id: '$($Properties.Subnets[`"Nodes`"].SubnetId)'"
    }
    Write-Verbose "Done getting Subnet Id '$($Properties.Subnets[`"Nodes`"].SubnetId)'"
}

function New-CompliantAksLandingZoneLogAnalytics {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )
    $Properties = $PropertiesRef.Value

    Write-Verbose "Creating log analytics workspace: '$($Properties.LogAnalyticsWorkspaceName)'"
        New-AzOperationalInsightsWorkspace -Location $Properties.Location -Name $Properties.LogAnalyticsWorkspaceName -Sku Standard -ResourceGroupName $Properties.ResourceGroupName -Force
        $Properties.LogAnalyticsWorkspaceId = (get-AzOperationalInsightsWorkspace -Name $Properties.LogAnalyticsWorkspaceName -ResourceGroupName $Properties.ResourceGroupName).ResourceId
    Write-Verbose "Done creating log analytics workspace. Id: '$($Properties.LogAnalyticsWorkspaceId)'"
}

function New-CompliantAksLandingZoneRegistry {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )
    $Properties = $PropertiesRef.Value

    Write-Verbose "Creating Container Registry '$($Properties.LogAnalyticsWorkspaceName)'"
    $registry = New-AzContainerRegistry `
            -ResourceGroupName $Properties.ResourceGroupName `
            -Name $Properties.ContainerRegistryName `
            -Sku Premium `
            -Location $Properties.Location `
    $Properties.ContainerRegistryId = $registry.Id


    #$Properties.ContainerRegistryId = (Get-AzContainerRegistry -Name $Properties.ContainerRegistryName -ResourceGroupName $Properties.ResourceGroupName).Id

    New-AzPrivateDnsZone `
        -ResourceGroupName $Properties.ResourceGroupName `
        -Name "privatelink.azurecr.io" `

    New-AzPrivateDnsVirtualNetworkLink `
        -ResourceGroupName $Properties.ResourceGroupName `
        -ZoneName "privatelink.azurecr.io" `
        -Name 'AcrDnsLink' `
        -VirtualNetwork $Properties.Vnet `
        -EnableRegistration:$false

    $prvEndpointSubnet = $Properties.Vnet.Subnets["PrivateEndpoint"] | ? Name -eq "aks-prvendpt-subnet"

    # Private endpoint does not support policies (ex: NSG) so we need to disable it
    $prvEndpointSubnet.PrivateEndpointNetworkPolicies = "Disabled"
    $Properties.Vnet | Set-AzVirtualNetwork 

    # Create the endpoint and the connection to the registry
    $acrPrivateLinkConnection = New-AzPrivateLinkServiceConnection `
        -Name 'ACRPrivateLink' `
        -PrivateLinkServiceId $Properties.ContainerRegistryId `
        -GroupId 'registry'

    $arcPrivateEndpoint = New-AzPrivateEndpoint `
        -Name "AcrPrivateEndpoint" `
        -ResourceGroupName $Properties.ResourceGroupName `
        -Location $Properties.Location `
        -Subnet $prvEndpointSubnet `
        -PrivateLinkServiceConnection $acrPrivateLinkConnection

    # Update the DNS
    
    $endpointPrivateIpAddress = $arcPrivateEndpoint.CustomDnsConfigs[1].IpAddresses[0]
    $Records = New-AzPrivateDnsRecordConfig -IPv4Address $endpointPrivateIpAddress
    New-AzPrivateDnsRecordSet `
        -Name $Properties.ContainerRegistryName `
        -ZoneName "privatelink.azurecr.io" `
        -ResourceGroupName $Properties.ResourceGroupName `
        -Ttl 1 `
        -RecordType A `
        -PrivateDnsRecord $Records
    
    $dataEndpointPrivateIpAddress = $arcPrivateEndpoint.CustomDnsConfigs[0].IpAddresses[0]
    $Records = New-AzPrivateDnsRecordConfig -IPv4Address $dataEndpointPrivateIpAddress
    New-AzPrivateDnsRecordSet `
        -Name "$($Properties.ContainerRegistryName).$($Properties.Location).data" `
        -ZoneName "privatelink.azurecr.io" `
        -ResourceGroupName $Properties.ResourceGroupName `
        -Ttl 1 `
        -RecordType A `
        -PrivateDnsRecord $Records
}


function New-CompliantAksParametersTemplateFile {
    [CmdletBinding()]
    Param(
        $Properties
    )

    $params = Get-Content "./arm/aks-params-template.json"
    $params = $params -Replace "<Location>", $Properties.Location
    $params = $params -Replace "<ClusterName>", $Properties.ClusterName
    $params = $params -Replace "<SubnetId>", $Properties.Subnets["Nodes"].SubnetId
    $params = $params -Replace "<WorkspaceId>", $Properties.LogAnalyticsWorkspaceId
    $params = $params -Replace "<ServiceCidr>", $Properties.Subnets["Services"].AddressPrefix
    $params > $Properties.TemplateParameterFilePath   
}

function New-CompliantAksConnection {
    [CmdletBinding()]
    Param(
        [string] $EnvironmentName,
        [string] $Location
    )
    # Do this in a JumpBox VM 
    # Install Az Cli
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    sudo apt-get update
    sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg
    curl -sL https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
    AZ_REPO=$(lsb_release -cs)
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
    sudo tee /etc/apt/sources.list.d/azure-cli.list
    sudo apt-get update
    sudo apt-get install azure-cli

    # Install AKS Preview
    az extension add --name aks-preview
    az extension update --name aks-preview

    # Log in to azure, and get the credentials jumping out AAD (--admin)
    az login 
    az account set --subscription 930c11b0-5e6d-458f-b9e3-f3dda0734110
    sudo az aks install-cli
    kubectl get pods
    "az aks get-credentials --resource-group $($Properties.ResourceGroupName) --name $($Properties.ClusterName) --admin"
    kubectl apply -f rbac_users.yml
    "kubectl config delete-cluster $($Properties.ClusterName)"
    az aks get-credentials --resource-group crgar-secureaks-env10-rg --name crgar-secureaks-env10-cluster    

    # Validating policies
    kubectl get pods -n gatekeeper-system
    kubectl get psp
}

function Add-CompliantAksPermissions {
    [CmdletBinding()]
    Param(
        [string] $EnvironmentName,
        [string] $Location
    )

    $Properties = Get-CompliantAksProperties -EnvironmentName $EnvironmentName -Location $Location
    az aks get-credentials --resource-group $props.ResourceGroupName --name $props.ClusterName
    kubectl get pods
}

function Add-CompliantAksJumpBox {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )
    $Properties = $PropertiesRef.Value
    
    Write-Verbose "Creating Windows JumpBox VM..."
    $credentials = New-Object -TypeName PSCredential -ArgumentList "adminuser", $(ConvertTo-SecureString "P@ssword123123" -AsPlainText)
    $imageURN = "microsoftwindowsdesktop:office-365:20h2-evd-o365pp:latest"
    New-AzVm -ResourceGroupName $Properties.ResourceGroupName `
        -Location $Properties.Location `
        -Name $Properties.JumpBoxVmName `
        -Credential $credentials `
        -PublicIpAddressName "$($Properties.JumpBoxVmName)-ip" `
        -OpenPorts "3389" `
        -VirtualNetworkName $Properties.VnetName `
        -SubnetName $Properties.Subnets.JumpBox.Name `
        -Image $imageURN

    Write-Verbose "Creating Linux JumpBox VM..."
    $imageURN = "canonical:0001-com-ubuntu-server-groovy:20_10:latest"
    $linuxJumpBoxVm = New-AzVm -ResourceGroupName $Properties.ResourceGroupName `
        -Location $Properties.Location `
        -Name $Properties.LinuxJumpBoxVmName `
        -Credential $credentials `
        -PublicIpAddressName "$($Properties.LinuxJumpBoxVmName)-ip" `
        -OpenPorts "22" `
        -VirtualNetworkName $Properties.VnetName `
        -SubnetName $Properties.Subnets.JumpBox.Name `
        -Image $imageURN

    Write-Verbose "Done creating JumpBox VMs..."

    $ipAddress = Get-AzPublicIpAddress -Name "$($Properties.LinuxJumpBoxVmName)-ip" | Select IpAddress
    # TODO, SSH into the VM and set up everything, including VPN or somthing
}

Get-ChildItem "$PSScriptRoot/*-CompliantAks*.ps1" | ForEach-Object {. $_}
Export-ModuleMember *-CompliantAks*

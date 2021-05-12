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
        WindowsJumpBoxVmName = "$($EnvironmentName)win".Substring(0, 14)
        LinuxJumpBoxVmName = "$($EnvironmentName)lin"
        Vnet = "<PlaceHolder>"
        Firewall = "<PlaceHolder>"
        FirewallIp = "<PlaceHolder>"
        FirewallPublicIp = "<PlaceHolder>"
        RouteTable = "<PlaceHolder>"
        ContainerRegistryId = "<PlaceHolder>"
        ApiServerDnsResourceId = "<PlaceHolder>"
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

    try 
    {            
        New-AzResourceGroup -Name $Properties.ResourceGroupName -Location $Properties.Location -Force
        New-CompliantAksManagedServiceIdentity -Properties ([ref]$Properties)
        New-CompliantAksLandingZoneVnet -Properties ([ref]$Properties)
        New-CompliantAksLandingZoneContainerRegistry -Properties ([ref]$Properties)
        New-CompliantAksLandingZoneLogAnalytics -Properties ([ref]$Properties)
        New-CompliantAksLandingZoneFirewallDeployment -Properties ([ref]$Properties)
        New-CompliantAksLandingZoneRouteTable -Properties ([ref]$Properties)
        New-CompliantAksJumpBox -Properties ([ref]$Properties)
        New-ComplianceAksApiServerDns -Properties ([ref]$Properties)
        # We try that setting permissions is as late as possible, since we need AAD to update
        # the global cache from the changes in New-CompliantAksManagedServiceIdentity
        New-CompliantAksManagedServiceIdentityPermissions -Properties ([ref]$Properties)

        New-CompliantAksParametersTemplateFile -Properties $Properties

    }
    finally
    {
        $Properties
    }   

}

function New-ComplianceAksApiServerDns {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )

    $Properties = $PropertiesRef.Value

    $dnsZone = New-AzPrivateDnsZone `
        -ResourceGroupName $Properties.ResourceGroupName `
        -Name "privatelink.$($Properties.Location).azmk8s.io"

    $Properties.ApiServerDnsResourceId = $dnsZone.ResourceId
}

function New-CompliantAksLandingZoneVnet {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )

    $Properties = $PropertiesRef.Value
    
    Write-Verbose "Creating VNet and subnet: ' $($Properties.VnetName)'"

    $subnets = @()
    foreach($subnet in $Properties.Subnets.Values) {
        Write-Verbose "Creating Subnet $($subnet.Id)"
        $subnets += New-AzVirtualNetworkSubnetConfig `
            -Name $subnet.Name `
            -AddressPrefix $subnet.AddressPrefix
    }

    $Properties.Vnet = New-AzVirtualNetwork `
        -Name $Properties.VnetName `
        -ResourceGroupName $Properties.ResourceGroupName `
        -Location $Location `
        -AddressPrefix 10.1.0.0/16 `
        -Subnet $subnets `
        -Force

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
    $params = $params -Replace "<ClusterRgMsiId>", $Properties.ClusterRgMsiId
    $params = $params -Replace "<ApiServerDnsResourceId>", $Properties.ApiServerDnsResourceId

    # Make sure there is a directory where to put the params
    $Properties.TemplateParameterFilePath | Split-Path | % { New-Item -ItemType Directory -Path $_ -ErrorAction SilentlyContinue}
    $params > $Properties.TemplateParameterFilePath 
}

function New-CompliantAksManagedServiceIdentityPermissions {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )
    $Properties = $PropertiesRef.Value

    $retry = 3
    while($retry -gt 0)
    {
        try 
        {
            Write-Verbose "Trying to assign MSI to RG..."
            $ra = New-AzRoleAssignment -ObjectId $Properties.MsiPrincipalId -RoleDefinitionName "Contributor" -Scope "/subscriptions/$($Properties.SubscriptionId)/resourceGroups/$($Properties.ResourceGroupName)" -ErrorAction Stop
            $retry = 0
            Write-Verbose "Done trying to assign MSI to RG..."
        }
        catch
        {
            Write-Verbose "Failed to assign MSI to RG. Retries: $retry"
            Write-Error $_ -ErrorAction Continue
            $retry--
            Start-Sleep -Seconds 10
        }
    }

}

function New-CompliantAksManagedServiceIdentity {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )
    $Properties = $PropertiesRef.Value
    $msi = New-AzUserAssignedIdentity -ResourceGroupName $Properties.ResourceGroupName -Name "$($Properties.EnvironmentName)-msi"

    $Properties.ClusterRgMsiId = $msi.Id
    $Properties.MsiPrincipalId = $msi.PrincipalId
}

function New-CompliantAksJumpBox {
    [CmdletBinding()]
    Param(
        [ref]$PropertiesRef
    )
    $Properties = $PropertiesRef.Value

    $credentials = New-Object -TypeName PSCredential -ArgumentList "adminuser", $(ConvertTo-SecureString "P@ssword123123" -AsPlainText)
    
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

    # Write-Verbose "Creating Windows JumpBox VM..."
    # $imageURN = "microsoftwindowsdesktop:office-365:20h2-evd-o365pp:latest"
    # New-AzVm -ResourceGroupName $Properties.ResourceGroupName `
    #     -Location $Properties.Location `
    #     -Name $Properties.WindowsJumpBoxVmName `
    #     -Credential $credentials `
    #     -PublicIpAddressName "$($Properties.WindowsJumpBoxVmName)-ip" `
    #     -OpenPorts "3389" `
    #     -VirtualNetworkName $Properties.VnetName `
    #     -SubnetName $Properties.Subnets.JumpBox.Name `
    #     -Image $imageURN
    
    #     Invoke-AzVMRunCommand -ResourceGroupName $Properties.ResourceGroupName -Name $Properties.WindowsJumpBoxVmName -CommandId 'RunPowerShellScript' -ScriptPath .\CmdLets\New-CompliantAksWinJumpboxConfig.ps1 #-Parameter @{"arg1" = "var1";"arg2" = "var2"}
    
    Write-Verbose "Done creating JumpBox VMs..."

    # $ipAddress = Get-AzPublicIpAddress -Name "$($Properties.LinuxJumpBoxVmName)-ip" | Select IpAddress
    # TODO, SSH into the VM and set up everything, including VPN or somthing
}

Get-ChildItem "$PSScriptRoot/*-CompliantAks*.ps1" | ForEach-Object {. $_}
Export-ModuleMember *-CompliantAks*

function New-CompliantAksWinJumpboxConfig {
    [CmdletBinding()]
    Param(

    )

    # install Az cli
    try {
        Write-Verbose "Start installing Az CLI"
        Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
        Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
        rm .\AzureCLI.msi
        Write-Verbose "Done installing Az CLI"
    }
    catch
    {
        Write-Verbose "Error installing Az CLI"
        Write-Verbose $_
    }

    # install vscode
    try {
        Write-Verbose "Start installing VSCode"
        Install-Script -Name Install-VSCode -Force
        Write-Verbose "Done installing VSCode"
    }
    catch
    {
        Write-Verbose "Error installing Az CLI"
        Write-Verbose $_
    }

}
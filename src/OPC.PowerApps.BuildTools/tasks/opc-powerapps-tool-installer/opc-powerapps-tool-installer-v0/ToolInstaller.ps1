[CmdletBinding()]
param()


function Install-PowerShellModule {
    [CmdletBinding()]
    param(
        [string][ValidateNotNullOrEmpty()]$RootPath,
        [string][ValidateNotNullOrEmpty()]$ModuleName,
        [string][ValidateNotNullOrEmpty()]$ModuleVersion
    )

    Write-Host "Installing PS module $ModuleName - $ModuleVersion ..."
    $savedModulePath = [IO.Path]::Combine($RootPath, $ModuleName, $ModuleVersion)
    $fixedModulePath = Join-Path $savedModulePath $ModuleName

    if (!(Test-Path -Path $fixedModulePath)) {
        Get-PackageSource -ProviderName "PowerShellGet" | ForEach-Object {
            $packageSource = $_.Name

            $moduleArguments = @{
                Name = $ModuleName
                RequiredVersion = $ModuleVersion
                Source = $packageSource
            }
    
            if ($packageSource -ne "PSGallery") {
                $serviceConnection = Get-ServiceConnection -serviceConnectionRef $packageSource
                $PSCredential = Get-PSCredentialFromServiceConnection -serviceConnection $serviceConnection
                $moduleArguments.Credential = $PSCredential
            }
            
            $softwareIdentities = (Find-Package @moduleArguments -Verbose 2> $null)
            if ($softwareIdentities.Length -gt 0) {
                Save-Package @moduleArguments -Path $RootPath -Force -Verbose

                Write-Verbose "Moving module into $fixedModulePath ..."
                $moduleItems = Get-ChildItem -Path $savedModulePath
                New-Item $fixedModulePath -ItemType Directory -Force | Out-Null
                $moduleItems | Move-Item -Destination $fixedModulePath -Force

                Set-VstsTaskVariable OPC_PowerAppsTools_$($ModuleName.Replace('.','_')) $savedModulePath

                break
            }
        }        
    } else {
        Write-Verbose "Found module already installed, nothing to do."
    }    
}

function Set-PowershellSource {
    [CmdletBinding()]
    param(
        [string][ValidateNotNullOrEmpty()]$RepositoryName,
        [string][ValidateNotNullOrEmpty()]$RepositoryUrl,
        [PSCredential]$Credential
    )
    
    Register-PackageSource -Name $RepositoryName -Location $RepositoryUrl -ProviderName "PowerShellGet" -Force -Trusted -Verbose -Credential $Credential   
}

function Confirm-PackageProvider {
    [CmdletBinding()]
    param(
        [string][ValidateNotNullOrEmpty()]$ProviderName
    )

    Find-PackageProvider -Name $ProviderName | Install-PackageProvider -Force -Scope CurrentUser
}

Trace-VstsEnteringInvocation $MyInvocation
try {
    $sharedFunctionsLocation = Join-Path -Path $PSScriptRoot "PowerApps-SharedFunctions.psm1"
    Import-Module $sharedFunctionsLocation

	$xrmOnlineManagementApiVersion = Get-VSTSInput -Name "XrmOnlineManagementApiVersion" -Require
    $powerappsAdministrationVersion = Get-VSTSInput -Name "PowerAppsAdministrationVersion" -Require
    $powerappsVersion = Get-VSTSInput -Name "PowerAppsVersion" -Require
    $xrmToolingCrmConnectorVersion = Get-VSTSInput -Name "XrmToolingCrmConnectorVersion" -Require
    $dataMigationVersion = Get-VSTSInput -Name "DataMigrationVersion" -Require
    $powershellServiceConnections = Get-VSTSInput -Name "powershellServiceConnections"

    $toolsSubFolder = "_tools"
    if (Test-Path Env:VSTS_TOOLS_PATH) {
        $toolsPath = $Env:VSTS_TOOLS_PATH
    }
    elseif (Test-Path Env:PIPELINE_WORKSPACE) {
        $toolsPath = Join-Path $Env:PIPELINE_WORKSPACE $toolsSubFolder
    }
    elseif (Test-Path Env:AGENT_WORKFOLDER ) {
        $toolsPath = Join-Path $Env:AGENT_WORKFOLDER $toolsSubFolder
    }
    else {
        $toolsPath = Join-Path (Get-Location) $toolsSubFolder
    }

    $powerAppsToolsPath = "$toolsPath\PA.BuildTools"
    New-Item $powerAppsToolsPath -ItemType Directory -Force | Out-Null
    Write-Verbose "tools folder: $powerAppsToolsPath"

    Confirm-PackageProvider -ProviderName "PowerShellGet"

    if ($powershellServiceConnections) {
        $powershellServiceConnections.Split(",") | ForEach-Object {
            $serviceConnectionRef = $_
            $serviceConnection = Get-ServiceConnection -serviceConnectionRef $serviceConnectionRef
            $PSCredential = Get-PSCredentialFromServiceConnection -serviceConnection $serviceConnection

            Set-PowershellSource -RepositoryName $serviceConnectionRef -RepositoryUrl $serviceConnection.Url -Credential $PSCredential
        }
    }    

    Install-PowerShellModule -RootPath $powerAppsToolsPath -ModuleName "Microsoft.Xrm.OnlineManagementAPI" -ModuleVersion $xrmOnlineManagementApiVersion
    Install-PowerShellModule -RootPath $powerAppsToolsPath -ModuleName "Microsoft.PowerApps.Administration.PowerShell" -ModuleVersion $powerappsAdministrationVersion
    Install-PowerShellModule -RootPath $powerAppsToolsPath -ModuleName "Microsoft.PowerApps.PowerShell" -ModuleVersion $powerappsVersion
    Install-PowerShellModule -RootPath $powerAppsToolsPath -ModuleName "Microsoft.Xrm.Tooling.CrmConnector.PowerShell" -ModuleVersion $xrmToolingCrmConnectorVersion
    Install-PowerShellModule -RootPath $powerAppsToolsPath -ModuleName "OPC.PowerApps.DataMigration" -ModuleVersion $dataMigationVersion
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}

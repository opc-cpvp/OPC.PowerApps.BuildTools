[CmdletBinding()]
param()

function Invoke-ExportEnvironmentSchema {
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true)][string]$EnvironmentUrl,
        [parameter (Mandatory = $true)][PSCredential]$PSCredential,
        [parameter (Mandatory = $true)][string]$SchemaOutputPath,
        [parameter (Mandatory = $true)][string]$SchemaFileName,
        [parameter (Mandatory = $false)][string]$ConfigurationPath
    )

    begin {    
        #Setup parameter hash table
        $Parameters = . Get-ParameterValue
    }

    process {     
        $output = Get-EnvironmentSchema -EnvironmentURL $EnvironmentURL -Credentials $PSCredential -Verbose @Parameters
    }

    end {
        return $output        
    }
}

Trace-VstsEnteringInvocation $MyInvocation
try {
    # Load shared functions and other dependencies
    $sharedFunctionsLocation = Join-Path -Path $PSScriptRoot "PowerApps-SharedFunctions.psm1"
    $getParameterValueLocation = Join-Path -Path $PSScriptRoot "Get-ParameterValue.ps1"
    Import-Module $sharedFunctionsLocation, $getParameterValueLocation

    Import-PowerAppsToolsPowerShellModule -ModuleName "OPC.PowerApps.DataMigration"

	# Get input parameters and credentials
    $serviceConnectionRef = Get-VSTSInput -Name "PowerAppsAdminCredentials" -Require
    $serviceConnection = Get-ServiceConnection -serviceConnectionRef $serviceConnectionRef
    $PSCredential = Get-PSCredentialFromServiceConnection -serviceConnection $serviceConnection

    $environmentUrl = Get-VSTSInput -Name "EnvironmentUrl" -Require
    $configurationPath = Get-VstsInput -Name "ConfigurationPath"
    $schemaOutputPath = Get-VstsInput -Name "SchemaOutputPath" -Require
    $schemaFileName = Get-VstsInput -Name "SchemaFileName" -Require

    #TFS Build Parameters
    $sourcesDirectory = $env:BUILD_SOURCESDIRECTORY
    $defaultDirectory = $env:SYSTEM_DEFAULTWORKINGDIRECTORY

    if ($configurationPath -eq $sourcesDirectory -or $configurationPath -eq $defaultDirectory)
    {
        $configurationPath = $null
    }

    Invoke-ExportEnvironmentSchema -EnvironmentUrl $environmentUrl -PSCredential $PSCredential `
        -ConfigurationPath $configurationPath -SchemaOutputPath $schemaOutputPath `
        -SchemaFileName $schemaFileName
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}

[CmdletBinding()]
param()

function Invoke-ExportEnvironmentData {
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true)][string]$EnvironmentUrl,
        [parameter (Mandatory = $true)][PSCredential]$PSCredential,
        [parameter (Mandatory = $true)][string]$SchemaPath,
        [parameter (Mandatory = $true)][string]$DataOutputPath,
        [parameter (Mandatory = $true)][string]$DataFileName
    )

    begin {    
        #Setup parameter hash table
        $Parameters = . Get-ParameterValue
    }

    process {     
        $output = Get-EnvironmentData -EnvironmentURL $EnvironmentURL -Credentials $PSCredential -Verbose @Parameters
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
    $schemaPath = Get-VstsInput -Name "SchemaPath" -Require
    $dataOutputPath = Get-VstsInput -Name "DataOutputPath" -Require
    $dataFileName = Get-VstsInput -Name "DataFileName" -Require

    Invoke-ExportEnvironmentData -EnvironmentUrl $environmentUrl -PSCredential $PSCredential `
        -SchemaPath $schemaPath -DataOutputPath $dataOutputPath `
        -DataFileName $dataFileName
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}

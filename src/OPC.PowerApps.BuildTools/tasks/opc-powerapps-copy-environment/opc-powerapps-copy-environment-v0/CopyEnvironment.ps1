[CmdletBinding()]
param()

function New-CopyRequestInfo {
    [CmdletBinding()]
    param (
        # New-CrmInstanceCopyRequestInfo
        [parameter (Mandatory = $true)][string]$FriendlyName,
        [parameter (Mandatory = $true)][Guid]$TargetInstanceId,
        [parameter (Mandatory = $true)][ValidateSet("FullCopy", "MinimalCopy")]$CopyType,
        [parameter (Mandatory = $false)][Guid]$SecurityGroupId
    )

    begin {
        #Setup parameter hash table
        $Parameters = . Get-ParameterValue
    }

    process {
        $newCopyRequestInfo = New-CrmInstanceCopyRequestInfo -Verbose @Parameters
    }

    end {
        Remove-Module Get-ParameterValue
        return $newCopyRequestInfo
    }
}

function Copy-Instance {
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true)][string]$EnvironmentURL,
        [parameter (Mandatory = $true)][PSCredential]$PSCredential,
        [parameter (Mandatory = $true)][PSObject]$CopyRequestInfo
    )

    begin {
        # Get Organization Information
        $organizationInfo = Get-OrgInfo -PSCredential $PSCredential -EnvironmentUrl $EnvironmentURL
    }

    process {
        #Create the new copy Job
        $copyOperation = Copy-CrmInstance -SourceInstanceIdToCopy $organizationInfo.OrganizationID -CopyInstanceRequestDetails $copyRequestInfo -ApiUrl $organizationInfo.ServiceURL -Credential $PSCredential -Verbose

        # Wait for operation to complete
        Write-Host "Waiting for copy operation to complete..."
        Wait-CrmOperation -ServiceUrl $organizationInfo.ServiceURL -PSCredential $PSCredential -OperationId $copyOperation.OperationId
    }

    end {
        return "Copy status is $($copyOperation.status). Copy Complete."
    }
}


Trace-VstsEnteringInvocation $MyInvocation
try {
    # Load shared functions and other dependencies
    $sharedFunctionsLocation = Join-Path -Path $PSScriptRoot "PowerApps-SharedFunctions.psm1"
    $getParameterValueLocation = Join-Path -Path $PSScriptRoot "Get-ParameterValue.ps1"
    Import-Module $sharedFunctionsLocation, $getParameterValueLocation
    Import-PowerAppsToolsPowerShellModule -ModuleName "Microsoft.Xrm.Tooling.CrmConnector.PowerShell"
    Import-PowerAppsToolsPowerShellModule -ModuleName "Microsoft.Xrm.OnlineManagementAPI"

    # Get input parameters and credentials
    $sourceServiceConnectionRef = Get-VSTSInput -Name "PowerAppsSourceEnvironment" -Require
    $sourceServiceConnection = Get-ServiceConnection -serviceConnectionRef $sourceServiceConnectionRef
    $PSCredential = Get-PSCredentialFromServiceConnection -serviceConnection $sourceServiceConnection
    $targetEnvironmentUrl = Get-VSTSInput -Name "TargetEnvironmentUrl" -Require

    $copyType = Get-VSTSInput -Name "CopyType" -Require
    $friendlyName = Get-VSTSInput -Name "FriendlyName"

    # Get org info of target environment
    $targetOrganizationInfo = Get-OrgInfo -PSCredential $PSCredential -EnvironmentUrl $targetEnvironmentUrl
    if ([String]::IsNullOrEmpty($friendlyName)) {
        $friendlyName = $targetOrganizationInfo.FriendlyName
    }

    $copyRequestInfo = New-CopyRequestInfo -FriendlyName $friendlyName -TargetInstanceId $targetOrganizationInfo.OrganizationID -CopyType $copyType

    Copy-Instance -EnvironmentURL $sourceServiceConnection.url -PSCredential $PSCredential -CopyRequestInfo $copyRequestInfo

} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}

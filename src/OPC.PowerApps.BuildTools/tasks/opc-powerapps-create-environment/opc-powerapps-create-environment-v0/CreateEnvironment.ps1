[CmdletBinding()]
param()

function New-Environment {
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true)][string]$DisplayName,
        [parameter (Mandatory = $true)][string]$LocationName,
        [parameter (Mandatory = $true)][string]$EnvironmentSku,
        [parameter (Mandatory = $true)][string]$CurrencyName,
        [parameter (Mandatory = $true)][string]$LanguageName,
        [parameter (Mandatory = $true)][string]$DomainName,
        [parameter (Mandatory = $false)][string[]]$Templates,
        [parameter (Mandatory = $false)][string]$SecurityGroupId,
        [parameter (Mandatory = $false)][boolean]$WaitUntilFinished,
        [parameter (Mandatory = $false)][string]$ApiVersion
    )

    begin { }

    process {
        #Create Instance job
        Write-Host "Starting create environment operation for $DomainName..."
        New-AdminPowerAppEnvironment -DisplayName $DisplayName -LocationName $LocationName -EnvironmentSku $EnvironmentSku -ProvisionDatabase -CurrencyName $CurrencyName -LanguageName $LanguageName -DomainName $DomainName -Templates $Templates -WaitUntilFinished $WaitUntilFinished -Verbose
    }

    end {
        Remove-Module Get-ParameterValue
    }
}

function Add-OPCPowerAppsAccount {
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true)][PSCredential]$PSCredential
    )

    begin { }

    process {
        #Add PowerApps Account
        Write-Host "Adding PowerApps account."
        Add-PowerAppsAccount -Username $PSCredential.UserName -Password $PSCredential.Password -Verbose
    }

    end { }
}

function Get-NewEnvironmentUrl {
    [CmdletBinding()]
    param ()

    begin {
        $locationURLTable = @{
            "North America"   = ".crm.dynamics.com"
            "North America 2" = ".crm9.dynamics.com"
            "EMEA"            = ".crm4.dynamics.com"
            "APAC"            = ".crm5.dynamics.com"
            "Oceania"         = ".crm6.dynamics.com"
            "JPN"             = ".crm7.dynamics.com"
            "South America"   = ".crm2.dynamics.com"
            "IND"             = ".crm8.dynamics.com"
            "Canada"          = ".crm3.dynamics.com"
            "UK"              = ".crm11.dynamics.com"
        }
    }

    process {
        $LatestEnvironment = Get-AdminPowerAppEnvironment | Sort-Object -Property CreatedTime | Select-Object -Last 1

        $Regex = [Regex]::new("\(([^)]+)\)")
        $Match = $Regex.Matches($LatestEnvironment.DisplayName)
        $DomainName = $Match.value
        $CleanedDomainName = $DomainName.Substring(1, $DomainName.Length - 2)
        $LocationURL = $locationURLTable.item($LatestEnvironment.Location)

        $EnvironmentUrl = "https://$($CleanedDomainName)$($LocationURL)"
        return $EnvironmentUrl
    }

    end { }
}

Trace-VstsEnteringInvocation $MyInvocation
try {
    # Load shared functions and other dependencies
    $sharedFunctionsLocation = Join-Path -Path $PSScriptRoot "PowerApps-SharedFunctions.psm1"
    $getParameterValueLocation = Join-Path -Path $PSScriptRoot "Get-ParameterValue.ps1"
    Import-Module $sharedFunctionsLocation, $getParameterValueLocation
    Import-PowerAppsToolsPowerShellModule -ModuleName "Microsoft.PowerApps.Administration.PowerShell"
    Import-PowerAppsToolsPowerShellModule -ModuleName "Microsoft.PowerApps.PowerShell"
    Import-PowerAppsToolsPowerShellModule -ModuleName "Microsoft.Xrm.Tooling.CrmConnector.PowerShell"

    # Get input parameters and credentials
    $serviceConnectionRef = Get-VSTSInput -Name "PowerAppsAdminCredentials" -Require
    $serviceConnection = Get-ServiceConnection -serviceConnectionRef $serviceConnectionRef
    $PSCredential = Get-PSCredentialFromServiceConnection -serviceConnection $serviceConnection

    $displayName = Get-VSTSInput -Name "DisplayName" -Require
    $locationName = Get-VSTSInput -Name "LocationName" -Require
    $environmentSku = Get-VSTSInput -Name "EnvironmentSku" -Require
    $sales = Get-VstsInput -Name "sales" -AsBool
    $customerService = Get-VstsInput -Name "customerService" -AsBool
    $fieldService = Get-VstsInput -Name "fieldService" -AsBool
    $projectServiceAutomation = Get-VstsInput -Name "projectServiceAutomation" -AsBool
    $sampleApp = Get-VstsInput -Name "sampleApp" -AsBool
    $developerEdition = Get-VstsInput -Name "developerEdition" -AsBool
    $currencyName = Get-VSTSInput -Name "CurrencyName" -Require
    $languageName = Get-VSTSInput -Name "LanguageName" -Require
    $domainName = Get-VSTSInput -Name "DomainName" -Require
    $waitUntilFinished = $true

    $templates = [string[]] @()
    if ($sales) { $templates += "D365_Sales" }
    if ($customerService) { $templates += "D365_CustomerService" }
    if ($fieldService) { $templates += "D365_FieldService" }
    if ($projectServiceAutomation) { $templates += "D365_ProjectServiceAutomation" }
    if ($sampleApp) { $templates += "D365_CDSSampleApp" }
    if ($developerEdition) { $templates += "D365_DeveloperEdition" }

    Add-OPCPowerAppsAccount -PSCredential $PSCredential
    New-Environment -DisplayName $displayName -LocationName $locationName -EnvironmentSku $environmentSku -CurrencyName $currencyName -LanguageName $languageName -DomainName $domainName -Templates $templates -WaitUntilFinished $waitUntilFinished
    $newEnvironmentUrl = Get-NewEnvironmentUrl

    Write-Host "New Environment URL: $newEnvironmentUrl"

    # Get Organization Information. We wait one minute to make sure the environment is created and visible in the list of organizations
    $OrganizationInfo = Wait-EnvironmentAvailability -PSCredential $PSCredential -EnvironmentUrl $newEnvironmentUrl

    # Output variable for use in downstream tasks in the same job
    Write-VstsSetVariable -Name "NewEnvironmentUrl" -Value $newEnvironmentUrl
    Write-VstsSetVariable -Name "NewOrganizationId" -Value $OrganizationInfo.OrganizationID

    # Set Release variables if they exist.
    Set-ReleaseVariable -VariableName "NewEnvironmentUrl" -VariableValue $newEnvironmentUrl
    Set-ReleaseVariable -VariableName "NewOrganizationId" -VariableValue $OrganizationInfo.OrganizationID
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}

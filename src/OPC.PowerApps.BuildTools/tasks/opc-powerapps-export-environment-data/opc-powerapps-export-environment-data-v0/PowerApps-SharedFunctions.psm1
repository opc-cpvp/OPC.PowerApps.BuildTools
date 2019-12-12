

function Get-ServiceConnection {
    [CmdletBinding()]
    param([string][ValidateNotNullOrEmpty()]$serviceConnectionRef)

    begin {
    }

    process {
        $serviceConnection = Get-VstsEndpoint -Name $serviceConnectionRef -Require
    }

    end {
        return $serviceConnection
    }
}

function Get-PSCredentialFromServiceConnection {
    [CmdletBinding()]
    param([object][ValidateNotNullOrEmpty()]$serviceConnection)

    begin {
        $user = $serviceConnection.Auth.Parameters.UserName
        $password = $serviceConnection.Auth.Parameters.Password
    }

    process {
        $PSCredential = New-Object System.Management.Automation.PSCredential ($user, (ConvertTo-SecureString $password -AsPlainText -Force))
    }

    end {
        return $PSCredential
    }
}

function Get-ServicePrincipalInfoFromServiceConnection {
    [CmdletBinding()]
    param([object][ValidateNotNullOrEmpty()]$serviceConnection)

    begin {
        $servicePrincipalId = $serviceConnection.Auth.Parameters.servicePrincipalId
        $servicePrincipalKey = $serviceConnection.Auth.Parameters.servicePrincipalKey
        $tenantId = $serviceConnection.Auth.Parameters.tenantId
    }

    process {
        $servicePrincipalSecret = ConvertTo-SecureString $servicePrincipalKey -AsPlainText -Force

        $servicePrincipalInfo = [PSCustomObject]@{
            ServicePrincipalId      = $servicePrincipalId
            ServicePrincipalSecret  = $servicePrincipalSecret
            TenantId                = $tenantId
        }
    }

    end {
        return $servicePrincipalInfo
    }
}

function Get-BoolFromTaskInput {
    [CmdletBinding()]
    param(
        [string][ValidateNotNullOrEmpty()]$StringInput,
        [bool]$FallbackValue = $false
    )

    begin {
        $parsedBool = $null
    }

    process {
        if ([bool]::TryParse($stringInput, [ref]$parsedBool)) {
        }
        else {
            $parsedBool = $DefaultValue
        }
    }

    end {
        return $parsedBool
    }
}

function Get-DomainNameFromUrl {
    [CmdletBinding()]
    param([string][ValidateNotNullOrEmpty()]$Url)

    begin {
        $uri = [System.Uri]$Url
    }

    process {
        $domainName = $uri.Host.Split('.')[0]
    }

    end {
        return $domainName
    }
}

function Import-PowerAppsToolsPowerShellModule {
    [CmdletBinding()]
    param([string][ValidateNotNullOrEmpty()]$ModuleName)

    begin {
        $taskVariable = "OPC_PowerAppsTools_$($ModuleName.Replace('.','_'))"
    }

    process {
        $newModulePath = Get-VstsTaskVariable -Name $taskVariable
        Write-Verbose "Importing PowerAppsTools PowerShell Module: $($ModuleName) from: $newModulePath"
        if ($env:PSModulePath.IndexOf($newModulePath, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            Write-Verbose("Adding $newModulePath to PSModulePath")
            $env:PSModulePath += ";$newModulePath"
            Write-Verbose "PSModPath: $env:PSModulePath"
        }

        Import-Module (Join-Path -Path $newModulePath $ModuleName)
    }

    end {}
}

function Get-InstalledNuGetPackageRootPath {
    [CmdletBinding()]
    param([string][ValidateNotNullOrEmpty()]$PackageName)

    begin {
        $packageRootPathEnvVariable = "Env:\OPC_PowerAppsTools_$($PackageName.Replace('.','_'))"
    }

    process {
        Write-Verbose "Attempting to get env variable: $packageRootPathEnvVariable)"
        $nugetPackageRootPath = Get-Item $packageRootPathEnvVariable
        Write-Verbose "NuGet Package Root Path: $($nugetPackageRootPath.Value)"
    }

    end {
        return $nugetPackageRootPath.Value
    }
}

function Get-OrgInfo {
    # Depends on Microsoft.Xrm.Tooling.CrmConnector.PowerShell
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)] $EnvironmentUrl,
        [parameter(Mandatory = $true)][ValidateNotNull()][PSCredential] $PSCredential
    )

    begin {
		$waitForOrg = $true
        $waitTimer = [Diagnostics.Stopwatch]::StartNew()
        $SecondsDelay = 15
        $SecondsTimeout = 300
	}

    process {
		while($waitForOrg)
        {
			## Get-CrmOrganizations will not currently function under Azure DevOps agents on the first attempt
			## Once an agent and service account have attempted a connection once and failed, all further calls will not run into the same error
			## The temporary workaround in place is to use a try/catch to handle the one time failure until the root cause is fixed (Bug #60)
			try {
				$allCrmOrgInfo = Get-CrmOrganizations -ServerUrl $EnvironmentUrl -Credential $PSCredential -WarningAction SilentlyContinue
			}
			catch {
				$allCrmOrgInfo = Get-CrmOrganizations -ServerUrl $EnvironmentUrl -Credential $PSCredential
			}

			# Get org info for the matched environment
            $crmOrgInfo = $allCrmOrgInfo | Where-Object {([System.Uri]$_.WebApplicationUrl).AbsoluteUri -eq ([System.Uri]$EnvironmentUrl).AbsoluteUri}
            if(!([string]::IsNullOrWhiteSpace($crmOrgInfo)))
            {
                $waitForOrg = $false;
            }

            if ($waitTimer.Elapsed.TotalSeconds -gt $SecondsTimeout) {
                $waitForOrg = $false
                Write-Warning "Waiting for organization ($EnvironmentUrl) availability failed to complete within the timeout window."
            }
            else {
                Start-Sleep -Seconds $SecondsDelay
            }
        }

		write-host "New Organization Info
		OrganizationID: $($crmOrgInfo.OrganizationId)
		DiscoveryServerShortname: $($crmOrgInfo.DiscoveryServerShortname)
		DiscoverySeverName: $($crmOrgInfo.DiscoverySeverName)
		FriendlyName: $($crmOrgInfo.FriendlyName)
		UniqueName: $($crmOrgInfo.UniqueName)
		Version: $($crmOrgInfo.Version)
		OrganizationURL: $($crmOrgInfo.OrganizationURL)
		OrganizationRestURL: $($crmOrgInfo.OrganizationRestURL)
		OrganizationWebAPIURL: $($crmOrgInfo.OrganizationWebAPIURL)
		AdminWebApiUrl: $($crmOrgInfo.AdminWebApiUrl)"

        # There is a typo in the powershell cmdlet for Get-CrmOrganizations.  The property "DiscoveryServerName" is misspelled with "DiscoverySeverName"
        $organizationInfo = [PSCustomObject]@{
            OrganizationID        = $crmOrgInfo.OrganizationId
            DiscoveryShortName    = $crmOrgInfo.DiscoveryServerShortname
            DiscoveryServerName   = $crmOrgInfo.DiscoverySeverName
            FriendlyName          = $crmOrgInfo.FriendlyName
            UniqueName            = $crmOrgInfo.UniqueName
            Version               = $crmOrgInfo.Version
            OrganizationURL       = $crmOrgInfo.OrganizationURL
            OrganizationRestURL   = $crmOrgInfo.OrganizationRestURL
            OrganizationWebAPIURL = $crmOrgInfo.OrganizationWebAPIURL
            ServiceURL            = $crmOrgInfo.AdminWebApiUrl
        }
    }

    end {
        return $organizationInfo
    }
}

function Wait-CrmOperation {
    # Depends on Microsoft.Xrm.OnlineManagementAPI
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()] $ServiceUrl,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][PSCredential] $PSCredential,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()] $OperationId,
        [parameter(Mandatory = $false)] $SecondsDelay = 15,
        [parameter(Mandatory = $false)] $SecondsTimeout = 600
    )

    begin {
        $failedOperationStates = "FailedToCreate","Failed","Cancelled","Aborted","Deleted"
        $waitForOperation = $true
        $operationTimer = [Diagnostics.Stopwatch]::StartNew()
        $percentChunk = $SecondsDelay / $SecondsTimeout * 100
        $percentTotal = 0
    }

    process {
        while ($waitForOperation) {
            $currentOperation = Get-CrmOperationStatus -Id $OperationId -ApiUrl $ServiceUrl -Credential $PSCredential

            if ($failedOperationStates.Contains($currentOperation.status)) {
                $waitForOperation = $false
                Write-Error "Operation ID $OperationId failed to complete successfully."
                Write-Error $currentOperation.Errors
            }
            if ($currentOperation.status -eq "Succeeded") {
                $waitForOperation = $false
            }
            if ($operationTimer.Elapsed.TotalSeconds -gt $SecondsTimeout) {
                $waitForOperation = $false
                Write-Warning "Operation ID ($OperationId) failed to complete within the timeout window."
            }
            else {
                [int]$percentTotal = [Math]::min(($percentTotal + $percentChunk), 99)
                Write-VstsSetProgress -Percent $percentTotal
                Start-Sleep -Seconds $SecondsDelay
            }
        }
    }

    end {
        return $currentOperation
    }
}

function Wait-EnvironmentAvailability {
    # Depends on Microsoft.Xrm.OnlineManagementAPI
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()] $EnvironmentUrl,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][PSCredential] $PSCredential,
        [parameter(Mandatory = $false)] $SecondsDelay = 15,
        [parameter(Mandatory = $false)] $SecondsTimeout = 600
    )

    begin {
        $waitForReadiness = $true
        $waitTimer = [Diagnostics.Stopwatch]::StartNew()
        $percentChunk = $SecondsDelay / $SecondsTimeout * 100
        $percentTotal = 0
    }

    process {
        while ($waitForReadiness) {
            try {
                $organizationInfo = Get-OrgInfo -EnvironmentUrl $EnvironmentUrl -PSCredential $PSCredential
                $waitForReadiness = $false
            }
            catch {
                if ($waitTimer.Elapsed.TotalSeconds -gt $SecondsTimeout) {
                    $waitForReadiness = $false
                    Write-Warning "Waiting for environment ($EnvironmentUrl) availability failed to complete within the timeout window."
                }
                else {
                    [int]$percentTotal = [Math]::min(($percentTotal + $percentChunk), 99)
                    Write-VstsSetProgress -Percent $percentTotal
                    Start-Sleep -Seconds $SecondsDelay
                }
            }
        }
    }

    end {
        return $organizationInfo
    }
}

function Invoke-SolutionPackager {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)][ValidateSet("Extract", "Pack")] $action,
        [parameter(Mandatory = $true)] $zipFile,
        [parameter(Mandatory = $true)] $folder,
        [parameter(Mandatory = $true)][ValidateSet("Unmanaged", "Managed", "Both")] $packagetype,
        [parameter(Mandatory = $false)][ValidateSet("Yes", "No")] $allowDelete,
        [parameter(Mandatory = $false)][ValidateSet("Yes", "No")] $allowWrite,
        [parameter(Mandatory = $false)][bool] $clobber,
        [parameter(Mandatory = $false)][ValidateSet("Off", "Error", "Warning", "Info", "Verbose")] $errorLevel,
        [parameter(Mandatory = $false)] $map,
        [parameter(Mandatory = $false)] $log
    )

    begin {
        $solutionPackagerNugetPackage = "Microsoft.CrmSdk.CoreTools"

        $nugetPackageRootPath = Get-InstalledNuGetPackageRootPath -PackageName $solutionPackagerNugetPackage

        $solutionPackagerFilePath = Get-ChildItem $nugetPackageRootPath -Recurse -Filter "SolutionPackager.exe"

        if ($solutionPackagerFilePath) {
            $solutionPackagerLocation = $solutionPackagerFilePath.FullName
            Write-Verbose "SolutionPackager.exe found: $solutionPackagerLocation"
            #Create custom object with requred parameters.
            $packParms = $PSBoundParameters
        }
        else {
            Write-Error "Could not locate SolutionPackager.exe in path: $nugetPackageRootPath"
        }
    }

    process {
        ForEach ($property in $packParms.GetEnumerator()) {
            if ($property.key -eq "clobber") {
                $solutionPackagerArgList += ("/" + $property.key + " ")
            }
            else {
                $solutionPackagerArgList += ("/" + $property.key + ":" + $property.value + " ")
            }
        }
        $Process = Invoke-VstsTool $solutionPackagerLocation -Arguments $solutionPackagerArgList
    }

    end {
        return $Process
    }
}

function Set-ReleaseVariable {
	[CmdletBinding()]
    param (
		[Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $VariableName,
		[Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $VariableValue
    )

    begin {}

    process {
		$baseUri =  "$env:SYSTEM_TEAMFOUNDATIONSERVERURI$env:SYSTEM_TEAMPROJECTID"
		$releaseId = "$env:RELEASE_RELEASEID"
		$header = @{Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"}

		$url = "$baseUri/_apis/release/releases/$($releaseId)?api-version=5.1"

		$release = Invoke-RestMethod -Uri $url -Headers $header

		if ($release.variables.($VariableName)){
			# Update an existing variable
			Write-Host "Setting variable value..."
			$release.variables.($VariableName).value = $VariableValue;
			Write-Host "Completed setting variable value."

			# Update the modified object
			$release2 = $release | ConvertTo-Json -Depth 100
			$release2 = [Text.Encoding]::UTF8.GetBytes($release2)

			$updatedef = Invoke-RestMethod -Uri $url -Method Put -Headers $header -ContentType "application/json" -Body $release2 -Verbose -Debug
			Write-host "The value of Release Variable $VariableName is updated to $VariableValue"
		}
		else {
			Write-host "The Release Variable $VariableName was not updated because it does not exist."
		}
    }

    end {}
}
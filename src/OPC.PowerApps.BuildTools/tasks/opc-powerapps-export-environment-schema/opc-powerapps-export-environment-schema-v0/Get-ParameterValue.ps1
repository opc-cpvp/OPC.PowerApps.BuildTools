function Get-ParameterValue {
    [CmdletBinding()]
    param(
        # The $MyInvocation for the caller -- DO NOT pass this (dot-source Get-ParameterValues instead)
        $Invocation = $MyInvocation,
        # The $PSBoundParameters for the caller -- DO NOT pass this (dot-source Get-ParameterValues instead)
        $BoundParameters = $PSBoundParameters
    )
    begin {

        $ParameterValues = @{ }

    }

    process {

        foreach ($parameter in $Invocation.MyCommand.Parameters.GetEnumerator()) {
            try {
                $key = $parameter.Key
                
                if ($null -ne ($value = Get-Variable -Name $key -ValueOnly -ErrorAction Ignore )) {
                    if ($value -ne ($null -as $parameter.Value.ParameterType)) {
                        $ParameterValues[$key] = $value
                    }
                }
                

                if ($BoundParameters.ContainsKey($key)) {
                    $ParameterValues[$key] = $BoundParameters[$key]
                }
                
                if (($key -eq "PSCredential") -or ($key -eq "EnvironmentURL")) {
                    $ParameterValues.Remove($key)
                }
            }
            
            finally { }
        }
    }
    end {

        return $ParameterValues
    }
}
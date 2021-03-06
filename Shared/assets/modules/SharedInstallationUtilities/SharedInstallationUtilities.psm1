
Function Replace-String {
    param(
        [Parameter(Mandatory = $true)]
        [string]$source,
        [Parameter(Mandatory = $true)]
        [string]$search,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$replace

    )

    Write-Verbose -Message $PSCmdlet.MyInvocation.MyCommand
    
    Write-Verbose "Searching for: $search in string: $source to replace with $replace"

    $result = $null
    $result = $source -replace $search, $replace
    

    Write-Verbose "Result: $result"
    return $result
}

Function Get-SitecoreModuleDetails {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$assets,
        [Parameter(Mandatory = $true)]
        [string]$moduleId
    )
    Write-Verbose -Message $PSCmdlet.MyInvocation.MyCommand
    Write-Verbose "Getting module: $moduleId"
    
    $assets = ConvertTo-Json -InputObject $assets | ConvertFrom-Json

    $result = $null
    $result = $assets.modules | Where-Object { $_.id -eq $moduleId}

    Write-Verbose "Result: $($result.Name)"
    return $result
}

Function Get-ObjectProperty {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$module,
        [Parameter(Mandatory = $true)]
        [string]$field
    )
    Write-Verbose -Message $PSCmdlet.MyInvocation.MyCommand
    
    Write-Verbose "Getting property $field in  module"

    $result = $null
    $result = $module.$field

    Write-Verbose "Result: $result"
    return $result
}
Function Add-DatabaseUser {
    param(
        [Parameter(Mandatory)]
        [string] $SqlServer,
        [Parameter(Mandatory)]
        [string] $SqlAdminUser,
        [Parameter(Mandatory)]
        [string] $SqlAdminPassword,
        [Parameter(Mandatory)]
        [string] $Username,
        [Parameter(Mandatory)]
        [string] $UserPassword,
        [Parameter(Mandatory)]
        [string] $DatabasePrefix,
        [Parameter(Mandatory)]
        [string] $DatabaseSuffix,
        [Parameter(Mandatory)]
        [bool] $IsCoreUser
    )
   
    #Write-Host ("Adding {0} to {1}_{2} with password {3}" -f $UserName, $DatabasePrefix, $DatabaseSuffix, $UserPassword   ) 
    $sqlVariables = "DatabasePrefix = $DatabasePrefix", "DatabaseSuffix = $DatabaseSuffix", "UserName = $UserName", "Password = $UserPassword"
    $sqlFile = ""
    if ($IsCoreUser ) {
        $sqlFile = Join-Path (Resolve-Path "..\..") "\database\addcoredatabaseuser.sql"
    }
    else {
        $sqlFile = Join-Path (Resolve-Path "..\..") "\database\adddatabaseuser.sql"
    }
    #Write-Host "Sql File: $sqlFile"
    Invoke-Sqlcmd -Variable $sqlVariables -Username $SqlAdminUser -Password $SqlAdminPassword -ServerInstance $SqlServer -InputFile $sqlFile 
  
}

Function Kill-DatabaseConnections {
    param(
        [Parameter(Mandatory)]
        [string] $SqlServer,
        [Parameter(Mandatory)]
        [string] $SqlAdminUser,
        [Parameter(Mandatory)]
        [string] $SqlAdminPassword,
        [Parameter(Mandatory)]
        [string] $DatabasePrefix,
        [Parameter(Mandatory)]
        [string] $DatabaseSuffix
    )
   
    #Write-Host ("Adding {0} to {1}_{2} with password {3}" -f $UserName, $DatabasePrefix, $DatabaseSuffix, $UserPassword   ) 
    $sqlVariables = "DatabasePrefix = $DatabasePrefix", "DatabaseSuffix = $DatabaseSuffix"
    $sqlFile = Join-Path (Resolve-Path "..\..") "\database\killdatabaseconnections.sql"
   
    #Write-Host "Sql File: $sqlFile"
    Invoke-Sqlcmd -Variable $sqlVariables -Username $SqlAdminUser -Password $SqlAdminPassword -ServerInstance $SqlServer -InputFile $sqlFile 
  
}

Function Start-SitecoreSite {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [ValidateSet('get', 'post')]
        [string]$Action = 'get',
        [string]$ContentType,
        [hashtable]$Parameters,
        [int]$ExpectedStatusCode = 200,
        [int]$TimeoutSec = 60
    )

    Function CheckResponseStatus {
        param(
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Response,
            [Parameter(Mandatory = $true)]
            [int]$ExpectedResponseStatus
        )

        if ($Response.StatusCode -eq $ExpectedResponseStatus) {
            return $true
        }

        return $false
    }

    try {
        Write-Verbose "$Action request to $Uri"

        if ($PSCmdlet.ShouldProcess($Uri, "HTTP request")) {
            for ($i = 0; $i -lt 3; $i++) {
                $response = Invoke-WebRequest -Method $Action -Uri $Uri -ContentType $ContentType -Body $Parameters -UseBasicParsing -TimeoutSec $TimeoutSec
                Write-Verbose "Response code was '$($response.StatusCode)'"
                if(CheckResponseStatus -Response $response -ExpectedResponseStatus $ExpectedStatusCode){
                    return
                }
                Start-Sleep -Seconds 20
                
            }
            if (!(CheckResponseStatus -Response $response -ExpectedResponseStatus $ExpectedStatusCode)) {
                throw "HTTP request $Uri expected Response code $ExpectedStatusCode but returned $($response.StatusCode)"
            }
        }
    }
    catch [System.Net.WebException] {

        if ($null -eq $_.Exception.Response) {
            Write-Error $_
            return
        }

        Write-Verbose "Response code was '$($response.StatusCode)'"

        $responseStatusIsExpected = CheckResponseStatus -Response $_.Exception.Response -ExpectedResponseStatus $ExpectedStatusCode

        if (-not($responseStatusIsExpected)) {
            Write-Error -Message "HTTP request $Uri expected Response code $ExpectedStatusCode but returned $([int]$_.Exception.Response.StatusCode)"
        }
    }
    catch {
        Write-Error $_
    }
}
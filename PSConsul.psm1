#
Set-StrictMode -Version 2


function Add-Watcher
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Name of watcher / service
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$Name,

        # Consul key to watch
        [string]$Key,
        
        [string]$Script,

        [string]$Token = $env:CONSUL_TOKEN
    )


        $servicename = "consulwatch-$name"
        $powershell = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
        $consul = "C:\ProgramData\chocolatey\lib\consul\tools\consul.exe"
        $param = "watch -type keyprefix -prefix $Key -token $Token $Script"
        if (Get-Service $servicename)
        {
            Stop-Service $servicename
            #nssm.exe remove $servicename confirm
        }
        else
        {
            nssm.exe install $servicename $consul
        }
#        nssm.exe set $servicename ObjectName "NT Authority\NetworkService"
        nssm.exe set $servicename AppParameters $param
        nssm.exe set $servicename DependOnService "consul"
        nssm.exe set $servicename Start SERVICE_AUTO_START
#        nssm.exe set $servicename AppExit Default Restart
        nssm.exe set $servicename AppEnvironmentExtra CONSUL_TOKEN=$Token
        nssm.exe set $servicename AppStdout C:\scripts\$servicename-stdout.log
        nssm.exe set $servicename AppStderr C:\scripts\$servicename-stderr.log
        nssm.exe set $servicename AppStdoutCreationDisposition 4
        nssm.exe set $servicename AppStderrCreationDisposition 4
        nssm.exe set $servicename AppRotateFiles 1
        nssm.exe set $servicename AppRotateOnline 1
        nssm.exe set $servicename AppRotateSeconds 86400
        nssm.exe set $servicename AppRotateBytes 1048576    
        Start-Service $servicename
    
}


<#
.Synopsis
   Get Consul keys
.DESCRIPTION
   Returns array of Consul keys
.EXAMPLE
   Get-ConsulKeys -Path /test/folder/key1 -Server http://22.33.44.55:8500
#>
function Get-ConsulKeys
{
    [CmdletBinding()]
#    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=0)]
		[AllowEmptyString()]
        [string]$Path = '/',

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=1)]
        [string]$Server = 'http://localhost:8500',

        [Parameter()]
        [AllowEmptyString()]
        [string]$Token = $env:CONSUL_TOKEN
    )

        if ($env:Consul)  { $Server=$env:Consul }
        if ($Path[0] -ne '/') { $Path = '/' + $Path }
        $URI = $Server + '/v1/kv' + $Path + '?recurse'
        if ($Token)  { $URI += "&token=$token" }
        try {
            $data = Invoke-RestMethod -Uri $Uri 
			$data | Sort-Object Key | ForEach-Object {
				$_ | select Key, @{Name="Value"; Expression = {[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String( $_.Value ))}}
			}
        }
        catch {
            Write-Error $_
       }

}


<#
.Synopsis
   Get info of registered node
.DESCRIPTION
   Get info of registered node
.EXAMPLE
   $env:Consul = 'http://22.33.44.55:8500' #defaults to localhost
   Get-ConsulNode node1
.EXAMPLE
   $x = Get-ConsulNode WEB01
   $x.Services.psobject.Properties.value

   Get tag info
#>
function Get-ConsulNode
{
    [CmdletBinding()]
    Param
    (

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$false, Position=0)]
        [string]$Node,
                
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=1)]
        [string]$Server = 'http://localhost:8500'
    )

        if ($env:Consul)  { 
            $Server=$env:Consul 
        }
        $URI = $Server + '/v1/catalog/node/' + $Node

        try {
            $data = Invoke-RestMethod -Uri $Uri
            if ($data -eq 'null') { throw } 
            return $data

        }
        catch {
            $e = new-object System.Management.Automation.ErrorRecord "Node `"$Node`" not found", "Y", ([System.Management.Automation.ErrorCategory]::NotSpecified), "Z"
            $PSCmdlet.WriteError( $e )
       }

}


<#
.Synopsis
   Get list of registered nodes
.DESCRIPTION
   Get list of registered nodes
.EXAMPLE
   $env:Consul = 'http://22.33.44.55:8500' #defaults to localhost
   Get-ConsulNodes
   
   Returns all Nodes
.EXAMPLE
   (Get-ConsulNodes).Where({$_.Node -like 'node1'}).Address

   Returns address of specified node
#>
function Get-ConsulNodes
{
    [CmdletBinding()]
    Param
    (

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=0)]
        [string]$Server = 'http://localhost:8500'
    )

        if ($env:Consul)  { 
            $Server=$env:Consul 
        }
        $URI = $Server + '/v1/catalog/nodes'

        try {
            $data = Invoke-RestMethod -Uri $Uri
            return $data

        }
        catch {
            $e = new-object System.Management.Automation.ErrorRecord "$Server error: request unsuccessful", "", ([System.Management.Automation.ErrorCategory]::NotSpecified), ""
            $PSCmdlet.WriteError( $e )
       }

}


<#
.Synopsis
   Get details of registered service
.DESCRIPTION
   Get details of registered service
.EXAMPLE
   Get-ConsulService -Service service -Server http://server:8500
.EXAMPLE
   if ($s = Get-ConsulService service -ErrorAction SilentlyContinue) { $s.Node } else {"Service Error"}
#>
function Get-ConsulService
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [string]$Service,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=1)]
        [string]$Server = 'http://localhost:8500'
    )

        if ($env:Consul)  { 
            $Server=$env:Consul 
        }
        $URI = $Server + '/v1/catalog/service/' + $Service

        try {
            $data = Invoke-WebRequest -Uri $Uri
            if ($data.content -eq '[]') { throw 'Service not found' }
            return $data.content -replace 'Address','Addr' | ConvertFrom-Json
        }
        catch {
            $e = new-object System.Management.Automation.ErrorRecord "", "", ([System.Management.Automation.ErrorCategory]::NotSpecified), ""
            $PSCmdlet.WriteError( $e )
       }

}


<#
.Synopsis
   Get list of registered services
.DESCRIPTION
   Get list of registered services
.EXAMPLE
   $env:Consul = 'http://22.33.44.55:8500' #defaults to localhost
   Get-ConsulServices
   
   Returns all services
.EXAMPLE
   (Get-ConsulServices).Where({$_.Value -like 'stack1'})

   Returns services with tag 'stack1'
#>
function Get-ConsulServices
{
    [CmdletBinding()]
    Param
    (

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=0)]
        [string]$Server = 'http://localhost:8500'
    )

        if ($env:Consul)  { 
            $Server=$env:Consul 
        }
        $URI = $Server + '/v1/catalog/services'

        try {
#            $data = Invoke-WebRequest -Uri $Uri
#            return $data.content.Split(',[]{}') -match ':' -replace '\W',''
            $data = Invoke-RestMethod -Uri $Uri
            return $data.psobject.Properties | Select-Object Name, Value
            
        }
        catch {
            $e = new-object System.Management.Automation.ErrorRecord "", "", ([System.Management.Automation.ErrorCategory]::NotSpecified), ""
            $PSCmdlet.WriteError( $e )
       }

}

<#
.Synopsis
   Get list of ACL tokens
.DESCRIPTION
   Get list of ACL tokens
.EXAMPLE
   $env:Consul = 'http://22.33.44.55:8500' #defaults to localhost
   Get-ConsulToken

#>
function Get-ConsulToken
{
    [CmdletBinding()]
    Param
    (

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=0)]
        [string]$Server = 'http://localhost:8500',
        
        [Parameter()]
        [AllowEmptyString()]
        [string]$Token = $env:CONSUL_TOKEN
    )

        if ($env:Consul)  { 
            $Server=$env:Consul 
        }
        $URI = $Server + '/v1/acl/list'
        if ($Token)  { $URI += "?token=$token" }
        try {
#            $data = Invoke-WebRequest -Uri $Uri
#            return $data.content.Split(',[]{}') -match ':' -replace '\W',''
            $data = Invoke-RestMethod -Uri $Uri
#            return $data.psobject.Properties | Select-Object Name, Value
            return $data
            
        }
        catch {
            $e = new-object System.Management.Automation.ErrorRecord "", "", ([System.Management.Automation.ErrorCategory]::NotSpecified), ""
            $PSCmdlet.WriteError( $e )
       }

}


<#
.Synopsis
   Get value from Consul key
.DESCRIPTION
   Get value from Consul key
.EXAMPLE
   Get-ConsulValue -Key /test/folder/key1 -Server http://22.33.44.55:8500
.EXAMPLE
   $env:Consul = 'http://22.33.44.55:8500' #defaults to localhost
   Get-ConsulValue /test/folder/key1
.EXAMPLE
    if ( $y = Get-ConsulValue myapp/database/url -ErrorAction SilentlyContinue ) { $y } else { echo "Error" }
#>
function Get-ConsulValue
{
    [CmdletBinding()]
#    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$false, Position=0)]
        [string]$Key,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=1)]
        [string]$Server = 'http://localhost:8500',
        
        [Parameter()]
        [AllowEmptyString()]
        [string]$Token = $env:CONSUL_TOKEN

    )

        if ($env:Consul)  { $Server=$env:Consul }
        if ($Key[0] -ne '/') { $Key = '/' + $Key }
        $URI = $Server + '/v1/kv' + $Key + '?raw'
        if ($Token)  { $URI += "&token=$token" }

        try {
            $data = Invoke-RestMethod -Uri $Uri 
            return $data
        }
        catch {
            Write-Error $_
       }

}



<#
.Synopsis
   Remove value from Consul key
.DESCRIPTION
   Remove value from Consul key
.EXAMPLE
   Remove-ConsulValue -Path /test/folder/key1 -Server http://22.33.44.55:8500
.EXAMPLE
   $env:Consul = 'http://22.33.44.55:8500' #defaults to localhost
   Remove-ConsulValue /test/folder/ -Recurse

   !!! Deletes ALL matching keys _RECURSIVELY_!
#>
function Remove-ConsulKey
{
    [CmdletBinding()]
#    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [string]$Key,

        [Parameter(Mandatory=$false, Position=1)]
        [string]$Server = 'http://localhost:8500',

        [Parameter(Mandatory=$false, Position=2)]
        [switch]$Recurse,
        
        [Parameter()]
        [AllowEmptyString()]
        [string]$Token = $env:CONSUL_TOKEN
        
    )
    Begin {
        if ($env:Consul)  { $Server=$env:Consul }
        $query = @()
        if ($Token)  { $query += "token=$token" }
        if ($Recurse.IsPresent) { $query += 'recurse' }
        if ($query.count -gt 0) {$query = '?' + ($query -join '&')} else {$query=''}
    }
    Process {
        if ($Key[0] -ne '/') { $Key = '/' + $Key }
        $URI = $Server + '/v1/kv' + $Key + $query
        try {
			$data = Invoke-RestMethod -Uri $Uri -Method Delete 
			Write-Verbose $data
        }
        catch {
            Write-Error $_
       }
    }

}


<#
.Synopsis
   Set value for Consul key
.DESCRIPTION
   Set value for Consul key
.EXAMPLE
   Set-ConsulValue -Key /test/folder/key1 -Value 'Val' -Server http://22.33.44.55:8500
.EXAMPLE
   $env:Consul = 'http://22.33.44.55:8500' #defaults to localhost
   Get-ConsulValue /test/folder/key1
#>
function Set-ConsulValue
{
    [CmdletBinding()]
#    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$false, Position=0)]
        [string]$Key,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$false, Position=1)]
		[AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=2)]
        [string]$Server = 'http://localhost:8500',

        [Parameter()]
        [AllowEmptyString()]
        [string]$Token = $env:CONSUL_TOKEN

    )
    
        if ($env:Consul)  { $Server=$env:Consul }
        if ($Key[0] -ne '/') { $Key = '/' + $Key }
        $URI = $Server + '/v1/kv' + $Key
        if ($Token)  { $URI += "?token=$token" }
        $Body = [Text.Encoding]::UTF8.GetBytes( $Value )
        try {
			$data = Invoke-RestMethod -Uri $Uri -Method Put -Body $Body
        }
        catch {
            Write-Error $_
       }

}


<#
.Synopsis
   Register consul service
.DESCRIPTION
   Register new service with /v1/agent/service/register endpoint, or update existing one
.EXAMPLE
   Register-ConsulService -Name wwww -Port 443 -Tags @("nginx","wap") -Server http://22.33.44.55:8500    
   Register-ConsulService -Name iis -Port 443 -Server http://22.33.44.55:8500
   Register-ConsulService -Name web -Tags @("nginx","test") -Server http://22.33.44.55:8500
.EXAMPLE
   $env:Consul = 'http://22.33.44.55:8500' #defaults to localhost
   Register-ConsulService -Name rdc-multitenant-service1 -Port 443
#>
function Register-ConsulService
{
    [CmdletBinding()]
#    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$false, Position=0)]
        [string]$Name,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=1)]
        [int]$Port,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=2)]
        [string[]]$Tags,
		
		[Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=3)]
        [string]$Server = 'http://localhost:8500'
    )
    
        if ($env:Consul)  { $Server=$env:Consul } 
        $URI = $Server + '/v1/agent/service/register'
        $RAW_Body = @{
		    Name = $Name
		  	Port = $Port
		  	Tags = $Tags			
		}
		$Body = $RAW_Body | ConvertTo-Json
        try {
			$data = Invoke-RestMethod -Uri $Uri -Method Put -Body $Body
        }
        catch {
            Write-Error $_
        }

}



<#
.Synopsis
   Remove consule service
.DESCRIPTION
   Remove consule service by ID
.EXAMPLE
   Remove-ConsulService -ServiceID serviceid -Server http://22.33.44.55:8500
#>
function Remove-ConsulService
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [string]$ServiceID,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=1)]
        [string]$Server = 'http://localhost:8500'
    )

    if ($env:Consul)  { $Server=$env:Consul } 
        $URI = $Server + '/v1/agent/service/deregister/'+$ServiceID
        try {
			$data = Invoke-RestMethod -Uri $Uri -Method Get 
			Write-Verbose $data
        }
        catch {
            Write-Error $_
        }

}


<#
.Synopsis
   Set/remove service maintenance
.DESCRIPTION
   Set or remove service maintenance mode, Reason parameter is mandatory, even Consul does not require it)
.EXAMPLE
   Set-ConsulServiceMaintenance -ServiceID www -Enable $true - Reason 'Reconfiguring backend'    
   Set-ConsulServiceMaintenance -ServiceID www -Enable $False - Reason 'Maintenance completed'
#>
function Set-ConsulServiceMaintenance
{
    [CmdletBinding()]
#    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$false, Position=0)]
        [string]$ServiceID,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$false, Position=1)]
        [boolean]$Enable,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=2)]
        [string[]]$Reason,
		
		[Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=3)]
        [string]$Server = 'http://localhost:8500'
    )
    
        if ($env:Consul)  { $Server=$env:Consul } 
        $URI = $Server + '/v1/agent/service/maintenance/' + 
				$ServiceID + '?enable=' + $Enable + '&reason=' + $Reason
				
        try {
			$data = Invoke-RestMethod -Uri $Uri -Method Put
			Write-Verbose $data
        }
        catch {
            Write-Error $_
        }

}

<#
.Synopsis
   Register consul check
.DESCRIPTION
   Register new service with /v1/agent/service/register endpoint, or update existing one
.EXAMPLE
   Register-ConsulCheck -Name Test -Type HTTP -Value "https://api.ipify.org/" -Interval "60s" -Notes "Test check" 
.EXAMPLE
   Register-ConsulCheck -Name "My Script" -Type Script -Value "c:\check.bat" -Interval "600s" -ID "myscript"
#>
function Register-ConsulCheck
{
    [CmdletBinding()]
#    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$true,  Position=0)]
        [string]$Name,

        [Parameter(Mandatory=$true,  Position=1)]
        [ValidateSet("HTTP", "Script", "TTL")]
        [string]$Type,

        [Parameter(Mandatory=$true,  Position=2)]
        [string]$Value,

        [Parameter(Mandatory=$true,  Position=3)]
        [string]$Interval = "30s",

        [Parameter(Mandatory=$false, Position=4)]
        [string]$ID = $Name,

        [Parameter(Mandatory=$false, Position=5)]
        [string]$ServiceID,

        [Parameter(Mandatory=$false, Position=6)]
        [string]$Notes,
		
		[Parameter(Mandatory=$false, Position=7)]
        [string]$Server = 'http://localhost:8500'
    )
    
        if ($env:Consul)  { $Server=$env:Consul } 
        $URI = $Server + '/v1/agent/check/register'
     
        $RAW_Body = @{
            ID    = $ID
		    Name  = $Name
		  	$Type = $Value
            Interval = $Interval
		}
		if ($ServiceID) { $RAW_Body.Add("ServiceID", $ServiceID) }
		if ($Notes)     { $RAW_Body.Add("Notes", $Notes) }
        
		$Body = $RAW_Body | ConvertTo-Json

        try {
			$data = Invoke-RestMethod -Uri $Uri -Method Put -Body $Body
        }
        catch {
            Write-Error $_
        }

}

<#
.Synopsis
   Remove consul check
.DESCRIPTION
   Remove check with /v1/agent/check/deregister/<ID> endpoint
.EXAMPLE
   Remove-ConsulCheck -ID "myscript"
#>
function Remove-ConsulCheck
{
    [CmdletBinding()]
#    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$true,  Position=0)]
        [string]$ID,

		[Parameter(Mandatory=$false, Position=7)]
        [string]$Server = 'http://localhost:8500'
    )
    
        if ($env:Consul)  { $Server=$env:Consul } 

        $URI = $Server + '/v1/agent/check/deregister/' + $ID
     

        try {
			$data = Invoke-RestMethod -Uri $Uri
        }
        catch {
            Write-Error $_
        }

}


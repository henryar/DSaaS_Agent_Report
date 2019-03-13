Clear-Host
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$Config = (Get-Content "$PSScriptRoot\DS-Config.json" -Raw) | ConvertFrom-Json

$Manager = $Config.MANAGER
$Port = $Config.PORT
$APIKEY = $Config.APIKEY
$REPORTFILE = $Config.REPORTFILE

$ErrorActionPreference = 'Stop'

$DSM_URI="https://" + $Manager + ":" + $Port

$Computers_apipath = "/api/computers"
$Computers_Uri= $DSM_URI + $Computers_apipath

$Policies_apipath = "/api/policies"
$Policies_Uri= $DSM_URI + $Policies_apipath

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("api-secret-key", $APIKEY)
$headers.Add("api-version", 'v1')

$Computers = Invoke-RestMethod -Method Get -Uri $Computers_Uri  -Headers $Headers
$Policies  = Invoke-RestMethod -Method Get -Uri $Policies_Uri -Headers $Headers

$ReportHeader = 'Host_ID, HostName, DisplayName, AgentStatus, AgentVersion, AgentOS, InstanceID, PolicyName, AntiMalwareState'
Add-Content -Path $REPORTFILE -Value $ReportHeader

foreach ($Item in $Computers.computers){
	$Host_ID = $Item.ID
	$PolicyID = $Item.policyID
	$PolicyName = $Policies.policies | Where-Object {$_.ID -eq $PolicyID}

	$HostName = $Item.hostName
	$DisplayName = $Item.displayName
	$AgentStatus = $Item.computerStatus.agentStatusMessages
	$AgentVersion = $Item.agentVersion
	$AgentOS = $Item.ec2VirtualMachineSummary.operatingSystem
	$InstanceID = $Item.ec2VirtualMachineSummary.instanceID
	$PolicyName = $PolicyName.name
	$AntiMalwareState = $Item.antiMalware.state

	$ReportData =  "$Host_ID, $HostName, $DisplayName, $AgentStatus, $AgentVersion, $AgentOS, $InstanceID, $PolicyName, $AntiMalwareState"
	Add-Content -Path $REPORTFILE -Value $ReportData
}


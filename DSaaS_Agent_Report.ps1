Clear-Host
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$ErrorActionPreference = 'Stop'

$Config     = (Get-Content "$PSScriptRoot\DS-Config.json" -Raw) | ConvertFrom-Json
$Manager    = $Config.MANAGER
$Port       = $Config.PORT
$APIKEY     = $Config.APIKEY
$REPORTNAME = $Config.REPORTNAME

$StartTime  = $(get-date)

$REPORTFILE          = $REPORTNAME + ".csv"
$DSM_URI             = "https://" + $Manager + ":" + $Port
$Computers_apipath   = "/api/computers"
$Computers_Uri       = $DSM_URI + $Computers_apipath
$Policies_apipath    = "/api/policies"
$Policies_Uri        = $DSM_URI + $Policies_apipath

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("api-secret-key", $APIKEY)
$headers.Add("api-version", 'v1')

$Computers = Invoke-RestMethod -Uri $Computers_Uri -Method Get -Headers $Headers
$Policies  = Invoke-RestMethod -Uri $Policies_Uri -Method Get -Headers $Headers

if ((Test-Path $REPORTFILE) -eq $true){
    $BackupDate          = get-date -format MMddyyyy-HHmm
    $BackupReportName    = $REPORTNAME + "_" + $BackupDate + ".csv"
    copy-item -Path $REPORTFILE -Destination $BackupReportName
    Remove-item $REPORTFILE
}

$ReportHeader = 'AWSAccountID, Host_ID, HostName, DisplayName, RelayID, AgentStatus, AgentVersion, AgentOS, InstanceID, InstancePowerState, PolicyName, AntiMalwareState, WebReputationState, FirewallState, IntrusionPreventionState, IntegrityMnitoringState, LogInspectionState, ApplicaionControlState'
Add-Content -Path $REPORTFILE -Value $ReportHeader

foreach ($Item in $Computers.computers){
	$Host_ID					= $Item.ID
	$PolicyID					= $Item.policyID
	$PolicyName					= ($Policies.policies | Where-Object {$_.ID -eq $PolicyID}).name
	$HostName					= $Item.hostName
	$DisplayName				= $Item.displayName
	$RelayID					= $Item.relayListID
	$AgentStatus				= $Item.computerStatus.agentStatusMessages
	$AgentVersion				= $Item.agentVersion
	$AgentOS					= $Item.ec2VirtualMachineSummary.operatingSystem
	$InstanceID					= $Item.ec2VirtualMachineSummary.instanceID
	$InstancePowerState			= $Item.ec2VirtualMachineSummary.state
	$AWSAccountID				= $Item.ec2VirtualMachineSummary.accountID
	$AntiMalwareState			= $Item.antiMalware.state
	$WebReputationState			= $Item.webReputation.state
	$FirewallState				= $Item.firewall.state 
	$IntrusionPreventionState	= $Item.intrusionPrevention.state
	$IntegrityMnitoringState	= $Item.integrityMonitoring.state
	$LogInspectionState			= $Item.logInspection.state
	$ApplicaionControlState		= $Item.applicationControl.state

	$ReportData =  "$AWSAccountID, $Host_ID, $HostName, $DisplayName, $RelayID, $AgentStatus, $AgentVersion, $AgentOS, $InstanceID, $InstancePowerState, $PolicyName, $AntiMalwareState, $WebReputationState, $FirewallState, $IntrusionPreventionState, $IntegrityMnitoringState, $LogInspectionState, $ApplicaionControlState"
	Add-Content -Path $REPORTFILE -Value $ReportData
}

$elapsedTime = $(get-date) - $StartTime
$totalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)

Write-Host "Report Generation is Complete.  It took $totalTime"

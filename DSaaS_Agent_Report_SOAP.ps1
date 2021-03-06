Clear-Host
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$ErrorActionPreference = 'Stop'

$Config     = (Get-Content "$PSScriptRoot\DS-Config.json" -Raw) | ConvertFrom-Json
$Manager    = $Config.MANAGER
$Port       = $Config.PORT
$Tenant     = $Config.TENANT
$UserName   = $Config.USER_NAME
$Password   = $Config.PASSWORD
$REPORTNAME = $Config.REPORTNAME

$WSDL       = "/webservice/Manager?WSDL"
$DSM_URI    = "https://" + $Manager + ":" + $Port + $WSDL
$objManager = New-WebServiceProxy -uri $DSM_URI -namespace WebServiceProxy -class DSMClass
$REPORTFILE = $REPORTNAME + ".csv"

Write-Host "[INFO]	Connecting to DSM server $DSM_URI"
try{
	if (!$Tenant) {
		$sID = $objManager.authenticate($UserName,$Password)
	}
	else {
		$sID = $objManager.authenticateTenant($Tenant,$UserName,$Password)
	}
	Remove-Variable UserName
	Remove-Variable Password
	Remove-Variable Tenant
	Write-Host "[INFO]	Connection to DSM server $DSM_URI was SUCCESSFUL"
}
catch{
	Write-Host "[ERROR]	Failed to logon to $DSM_URI.	$_"
	Remove-Variable UserName
	Remove-Variable Password
	Remove-Variable Tenant
	Exit
}

if ((Test-Path $REPORTFILE) -eq $true){
    $BackupDate         = get-date -format MMddyyyy-HHmm
    $BackupReportName   = $REPORTNAME + "_" + $BackupDate + ".csv"
    copy-item -Path $REPORTFILE -Destination $BackupReportName
    Remove-item $REPORTFILE
}

$ReportHeader = 'Region, Host_ID, HostName, DisplayName, AgentOS, InstanceID, AgentStatus, AgentVersion, PolicyName, ParentPolicyName, CurrentAMPatternVersion, AntiMalwarePatternVersion, LastSuccessfulUpdate, AntiMalwareState'
Add-Content -Path $REPORTFILE -Value $ReportHeader

$ComponentSummary = $objManager.componentSummaryRetrieve($sID)
foreach ($item in $ComponentSummary){
    $ComponentType      = $item.type
    $ComponentVersion   = $item.currentVersion
    If ($ComponentType -eq "1208090624"){
        $CurrentAMPatternVersion = $ComponentVersion
        break
    }
}

$Groups = $objManager.hostGroupRetrieveAll($sID)
foreach ($Group in $Groups) {

    $VPCGroupID     = $Group.parentGroupID
    $VPCGroup       = $objManager.hostGroupRetrieve($VPCGroupID, $sID)
    $RegionGroupID  = $VPCGroup.parentGroupID
    $RegionGroup    = $objManager.hostGroupRetrieve($RegionGroupID, $sID)

	$hostsPerGroup = $objManager.hostRetrieveByHostGroup($Group.ID, $sID)
	Foreach ($Item in $hostsPerGroup){
        If ($RegionGroup -eq ""){
            $Region = "NA"

        }Else{
            $Region = $RegionGroup.name
        }
        $HostStatus = $objManager.hostDetailRetrieveByName($Item.Name, "LOW", $sID)
        $Host_ID                    = $Item.ID
        $HostName                   = $Item.Name
        $DisplayName                = $HostStatus.displayName
        $AgentStatus                = $HostStatus.OverallStatus
		$AgentVersion               = $HostStatus.overallVersion
		$PolicyName                 = $HostStatus.securityProfileName
        $AgentOS                    = $HostStatus.Platform
        $InstanceID                 = $HostStatus.cloudObjectInstanceId
        $AntiMalwareState           = $HostStatus.overallAntiMalwareStatus
        $AntiMalwarePatternVersion  = $HostStatus.antiMalwareSmartScanPatternVersion
        $LastSuccessfulUpdate       = $HostStatus.overallLastSuccessfulUpdate

        $objCurrentSecurityProfile  = $objManager.securityProfileRetrieveByName($PolicyName,$sID)
        $ParentSecurityProfileID    = $objCurrentSecurityProfile.parentSecurityProfileID
        $objParentSecurityProfile   = $objManager.securityProfileRetrieve($ParentSecurityProfileID,$sID)
        $ParentPolicyName           = $objParentSecurityProfile.name

        $ReportData =  "$Region, $Host_ID, $HostName, $DisplayName, $AgentOS, $InstanceID, $AgentStatus, $AgentVersion, $PolicyName, $ParentPolicyName, $CurrentAMPatternVersion, $AntiMalwarePatternVersion, $LastSuccessfulUpdate, $AntiMalwareState"
        Add-Content -Path $REPORTFILE -Value $ReportData
        #Write-Host $ReportData
	}
}

Write-Host "Report Generation is Complete"

#TO SHOW VERBOSE MESSAGES SET $VerbosePreference="continue"
#SET ErrorLevel to 5 so show discovery info

#*************************************************************************
# Script Name - 
# Author	  -  - Progel srl
# Version	  - 1.1 24.09.2007
# Purpose     - 
#               
# Assumptions - 
#				
#               
# Parameters  - TraceLevel
#             - ComputerName
#				- SourceId
#				- ManagedEntityId
# Command Line - .\test.ps1 4 "serverName" '{1860E0EB-8C21-41DA-9F35-2FE9343CCF36}' '{1860E0EB-8C21-41DA-9F35-2FE9343CCF36}'
#
# Output properties
#
# Status
#
# Version History
#	  1.0 06.08.2010 DG First Release
#     1.5 15.02.2014 DG minor cosmetics
#
# (c) Copyright 2010, Progel srl, All Rights Reserved
# Proprietary and confidential to Progel srl              
#
#*************************************************************************


# Get the named parameters
param([int]$traceLevel=$(throw 'must have a value'))

	[Threading.Thread]::CurrentThread.CurrentCulture = "en-US"        
	[Threading.Thread]::CurrentThread.CurrentUICulture = "en-US"
	
#Constants used for event logging
$SCRIPT_NAME			= "Get-DPMDataSourcesSLAStatus"
$SCRIPT_ARGS = 1

$SCRIPT_STARTED			= 831
$PROPERTYBAG_CREATED	= 832
$SCRIPT_ENDED			= 835

$SCRIPT_VERSION = "1.0"

#region Constants
#Trace Level Costants
$TRACE_NONE 	= 0
$TRACE_ERROR 	= 1
$TRACE_WARNING = 2
$TRACE_INFO 	= 3
$TRACE_VERBOSE = 4
$TRACE_DEBUG = 5

#Event Type Constants
$EVENT_TYPE_SUCCESS      = 0
$EVENT_TYPE_ERROR        = 1
$EVENT_TYPE_WARNING      = 2
$EVENT_TYPE_INFORMATION  = 4
$EVENT_TYPE_AUDITSUCCESS = 8
$EVENT_TYPE_AUDITFAILURE = 16

#Standard Event IDs
$FAILURE_EVENT_ID = 4000		#errore generico nello script
$SUCCESS_EVENT_ID = 1201
$START_EVENT_ID = 1202
$STOP_EVENT_ID = 1203

#TypedPropertyBag
$AlertDataType = 0
$EventDataType	= 2
$PerformanceDataType = 2
$StateDataType       = 3
#endregion

#region Helper Functions
function Log-Params
{
	param($Invocation)
	$line=''
	foreach($key in $Invocation.BoundParameters.Keys) {$line += "$key=$($Invocation.BoundParameters[$key])  "}
	Log-Event $START_EVENT_ID $EVENT_TYPE_INFORMATION  ("Starting script. Invocation Name:$($Invocation.InvocationName)`n Parameters`n $line") $TRACE_INFO
}

function Log-Event
{
	param($eventID, $eventType, $msg, $level)
	
	Write-Verbose ("Logging event. " + $SCRIPT_NAME + " EventID: " + $eventID + " eventType: " + $eventType + " Version:" + $SCRIPT_VERSION + " --> " + $msg)
	if($level -le $P_TraceLevel)
	{
		Write-Host ("Logging event. " + $SCRIPT_NAME + " EventID: " + $eventID + " eventType: " + $eventType + " Version:" + $SCRIPT_VERSION + " --> " + $msg)
		$g_API.LogScriptEvent($SCRIPT_NAME,$eventID,$eventType, ($msg + "`n" + "Version :" + $SCRIPT_VERSION))
	}
}

Function Throw-EmptyDiscovery
{
	param($SourceId, $ManagedEntityId)

	$oDiscoveryData = $g_API.CreateDiscoveryData(0, $SourceId, $ManagedEntityId)
	Log-Event $FAILURE_EVENT_ID $EVENT_TYPE_WARNING "Exiting with empty discovery data" $TRACE_INFO
	$oDiscoveryData
	If($traceLevel -eq $TRACE_DEBUG)
	{
		#just for debug proposes when launched from command line does nothing when run inside OpsMgr Agent
		$g_API.Return($oDiscoveryData)
	}
}

Function Throw-KeepDiscoveryInfo
{
param($SourceId, $ManagedEntityId)
	$oDiscoveryData = $g_API.CreateDiscoveryData(0,$SourceId,$ManagedEntityId)
	#Instead of Snapshot discovery, submit Incremental discovery data
	$oDiscoveryData.IsSnapshot = $false
	Log-Event $FAILURE_EVENT_ID $EVENT_TYPE_WARNING "Exiting with null non snapshot discovery data" $TRACE_INFO
	$oDiscoveryData    
	If($traceLevel -eq $TRACE_DEBUG)
	{
		#just for debug proposes when launched from command line does nothing when run inside OpsMgr Agent	
		$g_API.Return($oDiscoveryData)
	}
}

#endregion

#Start by setting up API object.
	$P_TraceLevel = $TRACE_VERBOSE
	$g_Api = New-Object -comObject 'MOM.ScriptAPI'
	#$g_RegistryStatePath = "HKLM\" + $g_API.GetScriptStateKeyPath($SCRIPT_NAME)

	$dtStart = Get-Date
	$P_TraceLevel = $traceLevel
	Log-Params $MyInvocation
try
{
	if (!(get-Module -Name DataProtectionManager)) {Import-Module DataProtectionManager}
	if (!(get-command -Module DataProtectionManager -Name Get-DPMProtectionGroupSLA -ErrorAction SilentlyContinue)) {
		Log-Event $START_EVENT_ID $EVENT_TYPE_ERROR ("DPM Commandlet for SLA doesn't exist. Is DPM 2012 R2 at least at UR4?") $TRACE_ERROR
		Throw "DPM Commandlet for SLA doesn't exist. Is DPM 2012 R2 at least at UR4?"
	}
	$allPG = Get-DPMProtectionGroup

	foreach($pg in $allPG) {
		$pgSLA = $pg.ReadProtectedGroupSLAForAlert()
		$brokenDS = 0
		if ($pgSLA -gt 0) {
			$allDS = $pg.GetDatasources()
			foreach($ds in $allDS) {
				
				#Put the gathered statistics into the property bag.  
				#Includes a value for the folder name so that we can tell which folder the data is from.
				#the latest recovery point property is lazy so let's force it, since this can become taxing let's try some optimization
				if ($ds.LatestRecoveryPoint -lt ([DateTime]'2010-01-01')) {
					#this forces the field to get the correct value
					$ds.GetRecoveryPoint() | out-null
					#$lastRP = $ds.GetRecoveryPoint() # | Sort $_.BackupTime -Descending | select -First 1
				}
				$age = (Get-Date) - $ds.LatestRecoveryPoint
				$dsinSLA = ($age.TotalHours -le $pgSLA)
				#$dsinShortSLA = ($age.TotalHours -le $pgSLA/2) -and $ds.CurrentlyProtected
				#CurrentlyProtected
				if (! $dsinSLA) {$brokenDS ++}
				$bag = $g_api.CreatePropertyBag()			
				$bag.AddValue('Type','DS')
				$bag.AddValue('Id',$ds.DataSourceId.ToString())
				$bag.AddValue('SLA',$pgSLA)
				$bag.AddValue('LatestRP',$ds.LatestRecoveryPoint)
				$bag.AddValue('RPAgeHours',$age.TotalHours)
				$bag.AddValue('DSInSLA',$dsinSLA)
				$bag.AddValue('DSIsProtected',$ds.CurrentlyProtected)
				#Return each property bag as we create and populate it.
				$bag
				if ($P_TraceLevel -ge $TRACE_DEBUG) {$g_API.AddItem($bag)}
				Log-Event $START_EVENT_ID $EVENT_TYPE_INFO "$($ds.Name)-$($ds.DataSourceId) LatestRP:$($ds.LatestRecoveryPoint) AGe:$($age.TotalHours) InSLA:$dsinSLA" $TRACE_VERBOSE
			}
			$bag = $g_api.CreatePropertyBag()			
			$bag.AddValue('Type','PG')
			$bag.AddValue('Id',$pg.ProtectionGroupId.ToString())
			$bag.AddValue('SLA',$pgSLA)
			$bag.AddValue('NumberOfMissingDS',$brokenDS)
			#Return each property bag as we create and populate it.
			$bag
			if ($P_TraceLevel -ge $TRACE_DEBUG) {$g_API.AddItem($bag)}
			Log-Event $START_EVENT_ID $EVENT_TYPE_INFO "$($pg.Name) BroeknDS:$brokenDS" $TRACE_VERBOSE
		}
	}
	if ($P_TraceLevel -ge $TRACE_DEBUG) {$g_API.ReturnItems()}
	Log-Event $STOP_EVENT_ID $EVENT_TYPE_SUCCESS ("has completed successfully in " + ((Get-Date)- ($dtstart)).TotalSeconds + " seconds.") $TRACE_INFO
}
Catch [Exception] {
	Log-Event $FAILURE_EVENT_ID $EVENT_TYPE_WARNING ("Main " + $Error) $TRACE_WARNING	
	write-Verbose $("TRAPPED: " + $_.Exception.GetType().FullName); 
	Write-Verbose $("TRAPPED: " + $_.Exception.Message); 
}

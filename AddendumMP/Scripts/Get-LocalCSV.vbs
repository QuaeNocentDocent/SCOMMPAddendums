'*************************************************************************
' Script Name - 
' Author	  -  - Progel srl
' Version	  - 1.1 24.09.2007
'
' Purpose     - 
'               
' Assumptions - 
'				
'               
' Parameters  - TraceLevel
'             - 
' If discovery the following parameters must be added 
'				SourceId ($MPElement$ )
'				ManagedEntityId ($Target/Id$)
'
' Output properties
'
' Status
'
' Version History
'	  1.0 16.08.2007 FG First Release
'
' (c) Copyright 2009, Progel srl, All Rights Reserved
' Proprietary and confidential to Progel srl              
'
'*************************************************************************
  
Option Explicit
SetLocale ("en-us")


Const SCRIPT_VERSION = "1.0"
Const SCRIPT_ARGS = 4
'----------------------------------------------
'Debugging info
' ************** WARNING remove the extra space after the $ symbol, leaving in place this section can broke cookdown!
' MPElement: $_MPElement$ 
' MPElement/Name: $_MPElement/Name$
'
' System.Entity: $_MPElement[Name="System!System.Entity"]$
' DisplayName: $_MPElement[Name="System!System.Entity"]/DisplayName$
'
' Target Id: $_Target/Id$
' Target DisplayName: $_Target/Property[Type="System!System.Entity"]/DisplayName$
'----------------------------------------------
'
Const LOG_SUCCESS_EVENT_PARAMETER_NAME = "LogSuccessEvent"
Const MP_ELEMENT_PARAMETER_NAME = "MP Element"
Const MANAGED_ENTITY_ID_PARAMETER_NAME = "Managed Entity"
Const TARGET_COMPUTER_PARAMETER_NAME = "Target Computer"

'WMI constants
Const CIMV2_WMI_NAMESPACE = "root\cimv2"
Const WMI_MSCLUSTER_NAMESPACE = "root\MSCluster"
Const WMI_MSCLUSTER_CLUSTER_CLASS = "MSCluster_Cluster"
Const WMI_MSCLUSTER_CLUSTER_SHARED_VOLUME = "MSCluster_ClusterSharedVolume"
Const WMI_CLUSTER_SHARED_VOLUME_TO_PARTITION_ASSOCIATOR_CLASS = "MSCluster_ClusterSharedVolumeToPartition"
Const WMI_CLUSTER_SHARED_VOLUME_TO_RESOURCE_ASSOCIATOR_CLASS = "MSCluster_ClusterSharedVolumeToResource"
Const WMI_NAME_PROPERTY_NAME = "Name"
Const WMI_PATH_PROPERTY_NAME = "Path"
Const WMI_FILESYSTEM_PROPERTY_NAME = "FileSystem"
Const WMI_TOTALSIZE_PROPERTY_NAME = "TotalSize"
Const WMI_VOLUMELABEL_PROPERTY_NAME = "VolumeLabel"

Const WIN_SRV_2012_BUILD_NUMBER = 9200

'Scripting.FileSystemObject constants
Const FOR_READING = 1 'Open a file for reading only. You can't write to this file.
Const FOR_WRITING = 2 'Open a file for writing.
Const FOR_APPENDING = 8 'Open a file and write to the end of the file.

'Trace Level Costants
Const TRACE_NONE 	= 0
COnst TRACE_ERROR 	= 1
COnst TRACE_WARNING = 2
Const TRACE_INFO 	= 3
Const TRACE_VERBOSE = 4

'Event Type Constants
Const EVENT_TYPE_SUCCESS      = 0
Const EVENT_TYPE_ERROR        = 1
Const EVENT_TYPE_WARNING      = 2
Const EVENT_TYPE_INFORMATION  = 4
Const EVENT_TYPE_AUDITSUCCESS = 8
Const EVENT_TYPE_AUDITFAILURE = 16

' Standard Event IDs
Const FAILURE_EVENT_ID = 4000		'errore generico nello script
Const SUCCESS_EVENT_ID = 701
Const START_EVENT_ID = 702
Const STOP_EVENT_ID = 703

' TypedPropertyBag
const AlertDataType = 0
const EventDataType	= 2
const PerformanceDataType = 2
const StateDataType       = 3

'Globals
Dim g_API, g_oXML
Dim g_StdErr
Dim g_RegistryStatePath 'Used to store script related state in registry
Dim P_TraceLevel

On Error Resume Next

Dim dtStart, oArgs, bResult

  	dtStart = Now

	Globals

	Set oArgs = WScript.Arguments
	LogParams
	if oArgs.Count <> SCRIPT_ARGS Then
		Call LogEvent(FAILURE_EVENT_ID,EVENT_TYPE_ERROR,"called without proper arguments and was not executed.", TRACE_ERROR)
		Wscript.Quit -1
	End If
	P_TraceLevel = CInt(oArgs(0))

    Dim SourceID, ManagedEntityId, TargetComputer, oDiscoveryData, clusterName, objMSClusterSWbemServices
    SourceID = Replace(oArgs(1), Chr(34), "")
    ManagedEntityId = Replace(oArgs(2), Chr(34), "")
    TargetComputer = Replace(oArgs(3), Chr(34), "")

   'Return Immediately if OS is not at least 2012
    If Not CheckOSBuildNumber(WIN_SRV_2012_BUILD_NUMBER) Then
        Call ThrowEmptyDiscovery(SourceId, ManagedEntityId)
        WScript.Quit
    End If
    set oDiscoveryData = g_API.CreateDiscoveryData(0, SourceId, ManagedEntityId)
    If ConnectToWbemNS(".", WMI_MSCLUSTER_NAMESPACE, objMSClusterSWbemServices) Then
        clusterName = GetClusterName(objMSClusterSWbemServices)
        if Len(clusterName) > 0 Then
            bResult = DiscoverCSVs(objMSClusterSWbemServices, clusterName, oDiscoveryData, TargetComputer)
        else
            'to avoid discovery flip flops in case of wmi errors
             Call ThrowKeepDiscoveryInfo(SourceId, ManagedEntityId)
             WScript.Quit
        end if
    else
    'to avoid discovery flip flops in case of wmi errors
        Call ThrowKeepDiscoveryInfo(SourceId, ManagedEntityId)
        WScript.Quit        
    end if
    Call g_API.Return(oDiscoveryData)

	Call LogEvent(STOP_EVENT_ID,EVENT_TYPE_SUCCESS, "has completed successfully in " & DateDiff("s", dtStart, Now) & " seconds.", TRACE_INFO)
	
	ClearGlobals

Function DiscoverCSVs(objMSClusterSWbemServices, clusterName, oDiscoveryData, strTargetComputer)
Dim objClusterSharedVolumes, objClusterSharedVolume, objClusterDiskPartition, objClusterResource, intSuc

    On error resume next

    Set objClusterSharedVolumes = objMSClusterSWbemServices.ExecQuery("select * from " & WMI_MSCLUSTER_CLUSTER_SHARED_VOLUME)

    If Err.number <> 0 Then
	    Call LogEvent(FAILURE_EVENT_ID,EVENT_TYPE_ERROR, ErrorMsg(Err, "error reading CSVs info."), TRACE_ERROR)
        DiscoverCSVs = False
        Exit Function
    End If 
    'Loop through all returned cluster shared volumes
    For Each objClusterSharedVolume In objClusterSharedVolumes
        'Get the associated disk partition
        For Each objClusterDiskPartition In objClusterSharedVolume.Associators_(WMI_CLUSTER_SHARED_VOLUME_TO_PARTITION_ASSOCIATOR_CLASS, "", "", "", False, False, "", "", 0)
            'Get the associated resource
            For Each objClusterResource In objClusterSharedVolume.Associators_(WMI_CLUSTER_SHARED_VOLUME_TO_RESOURCE_ASSOCIATOR_CLASS, "", "", "", False, False, "", "", 0)
                intSuc = CreateDiscoveryData(objClusterSharedVolume, objClusterDiskPartition, objClusterResource, _
                                                   strTargetComputer, ClusterName, oDiscoveryData)
            Next 'objClusterResource
        Next 'objClusterDiskPartition

        If Err.number <> 0 Then
    	    Call LogEvent(FAILURE_EVENT_ID,EVENT_TYPE_ERROR, ErrorMsg(Err, "error reading CSVs info."), TRACE_ERROR)
            DiscoverClusterSharedVolumes = False
            Exit Function
        End If 
    Next 'objClusterSharedVolume
    DiscoverCSVs = true
End Function

Private Function CreateDiscoveryData(ByRef objClusterSharedVolume, ByRef objClusterDiskPartition, ByRef objClusterResource, _
                                     ByRef strTargetComputer, ByRef strClusterName, ByRef oDiscoveryData) 'As Integer
    Dim oCSVInstance, oCLusterInstance, oRel
    DIm aParts, volumeName, perfName
    
   'Create Cluster Instance
   Set oClusterInstance = oDiscoveryData.CreateClassInstance("$MPElement[Name='Cluster!Microsoft.Windows.Cluster']$")
   Call oClusterInstance.AddProperty("$MPElement[Name='Cluster!Microsoft.Windows.Cluster']/Name$", strClusterName)

    'Create the cluster shared volume instance hosted on the targeted cluster virtual server
    Set oCSVInstance = oDiscoveryData.CreateClassInstance("$MPElement[Name='QND.CSV.PerfWatcher']$")

    'PrincipalName (host, key)
    Call oCSVInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", strTargetComputer)

    'ClusterSharedVolumeName (key)
    Call oCSVInstance.AddProperty("$MPElement[Name='QND.CSV.PerfWatcher']/ClusterSharedVolumeName$", objClusterResource.Properties_(WMI_NAME_PROPERTY_NAME))



    'FriendlyVolumeName
    volumeName = objClusterSharedVolume.Properties_(WMI_NAME_PROPERTY_NAME)
    aParts = Split(volumeName, "\")
    perfName = aParts(UBound(aParts))
    Call oCSVInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.LogicalDisk']/VolumeName$", perfName)
    Call oCSVInstance.AddProperty("$MPElement[Name='QND.CSV.PerfWatcher']/FriendlyVolumeName$", volumeName)
    'PartitionName
    Call oCSVInstance.AddProperty("$MPElement[Name='QND.CSV.PerfWatcher']/PartitionName$", objClusterDiskPartition.Properties_(WMI_PATH_PROPERTY_NAME))
    'PartitionFileSystem
    Call oCSVInstance.AddProperty("$MPElement[Name='QND.CSV.PerfWatcher']/PartitionFileSystem$", objClusterDiskPartition.Properties_(WMI_FILESYSTEM_PROPERTY_NAME))
    'PartitionSize
    Call oCSVInstance.AddProperty("$MPElement[Name='QND.CSV.PerfWatcher']/PartitionSize$", objClusterDiskPartition.Properties_(WMI_TOTALSIZE_PROPERTY_NAME))
    'ClusterName
    Call oCSVInstance.AddProperty("$MPElement[Name='QND.CSV.PerfWatcher']/ClusterName$", strClusterName)
    'VolumeLabel
    Call oCSVInstance.AddProperty("$MPElement[Name='QND.CSV.PerfWatcher']/VolumeLabel$", objClusterDiskPartition.Properties_(WMI_VOLUMELABEL_PROPERTY_NAME))

    Call oDiscoveryData.AddInstance(oCSVInstance)

    Set oRel = oDiscoveryData.CreateRelationshipInstance("$MPElement[Name='Microsoft.Windows.Cluster.Contains.QND.CSV.PerfWatcher']$")
    oRel.Source = oClusterInstance
    oRel.Target = oCSVInstance
    oDiscoveryData.AddInstance(oRel)
        
    If Err.number <> 0 Then
       CreateDiscoveryData = False
       Exit Function
    End If 

    CreateDiscoveryData = True
    
End Function

'****************************************************************************************************************
'   FUNCTION:       GetClusterName
'   DESCRIPTION:    Returns the cluster name of the given cluster virtual name
'   PARAMETERS:     OUT String strClusterName: string to return the cluster name
'   RETURNS:        Boolean: True if successful
'****************************************************************************************************************
Private Function GetClusterName(objMSClusterSWbemServices)   

    Dim strWQLQuery 'As String
    Dim objClusters 'As SWbemObjectSet
    Dim objCluster 'As SWbemObject
   On error resume next
   GetClusterName=""
        strWQLQuery = "select * from " & WMI_MSCLUSTER_CLUSTER_CLASS
        Set objClusters = objMSClusterSWbemServices.ExecQuery(strWQLQuery)
        For Each objCluster In objClusters
                GetClusterName = objCluster.Name
        Next 'objCluster
        

End Function

'******************************************************************************
'   FUNCTION:       CheckOSBuildNumber
'   DESCRIPTION:    Returns True if the property BuildNumber from the Win32_OperatingSystem
'                   instance is greater or equal the given build number using the CIMv2 WMI namespace.
'   PARAMETERS:     IN Long lngBuildNumber: build number to check
'   RETURNS:        Boolean: True, if build is greater or equal than the given number
'******************************************************************************
Private Function CheckOSBuildNumber(ByRef lngBuildNumber) 'As Boolean

    Dim objSWbemServices 'As WbemScripting.SWbemServices
    Dim objSWbemObjectSet 'As WbemScripting.SWbemObjectSet
    Dim objSWbemObject 'As WbemScripting.SWbemObject
        
        'Connect to CIMv2 WMI namespace
        If ConnectToWbemNS(".", CIMV2_WMI_NAMESPACE, objSWbemServices) Then
            'Get the computersystem instance
            Set objSWbemObjectSet = objSWbemServices.ExecQuery("select * from Win32_OperatingSystem")
            For Each objSWbemObject In objSWbemObjectSet
                'If the OS build number is larger than the given number return True
                If CLng(objSWbemObject.BuildNumber) >= lngBuildNumber Then
                    CheckOSBuildNumber = True
                    Exit Function
                End If
            Next 'objSWbemObject
        End If

End Function

'******************************************************************************
'   FUNCTION:       ConnectToWbemNs
'   DESCRIPTION:    Connects to a WMI namespace
'   PARAMETERS:     IN String strServerName: name of the computer. If empty the local computer will be used.
'                   IN String strNameSpace: WMI namespace
'                   OUT Object objSWbemServices: WbemScripting.SWbemServices object connected to the given
'                                                namespace on the given server
'   RETURNS:        Boolean: True if successful
'******************************************************************************
Private Function ConnectToWbemNS(ByRef strServerName, ByRef strNameSpace, ByRef objSWbemServices) 'As Boolean

    Dim objSWbemLocator 'as WbemScripting.SWbemLocator

    'Create a new WMI Locator object
    Set objSWbemLocator = CreateObject("WbemScripting.SWbemLocator")

    'Connect to WMI namespace on strServerName computer and create WMI Services object
    Set objSWbemServices = objSWbemLocator.ConnectServer(strServerName, strNameSpace)

    'Connect to WMI namespace on strServerName computer with alternative credentials and create WMI Services object
    'Set objSWbemServices = objSWbemLocator.ConnectServer(strServerName, strNameSpace, strUserName, strPassWd)

    'If object is initialised function will be successful
    If objSWbemServices Is Nothing Then ConnectToWbemNS = False Else ConnectToWbemNS = True

End Function

'**********************************************
'**** HELPER FUNCTIONS SCOM sempre necessarie
'**********************************************

Sub Globals
	P_TraceLevel = TRACE_VERBOSE
    Set g_API = CreateObject("MOM.ScriptAPI")
    Set g_oXML = CreateObject("MSXML.DOMDocument")  
    Set g_StdErr = WScript.StdErr
	' only if needed g_RegistryStatePath = "HKLM\" & g_API.GetScriptStateKeyPath(WScript.ScriptName)
end Sub

Sub LogParams
	DIm scmdLine, I, oArgs
	sCmdLine = ""
	Set oArgs = WScript.Arguments
	for I=0 to oArgs.Count -1
	 sCmdLine = sCmdLine & " " & oArgs(I)
	next
	LogEvent START_EVENT_ID,EVENT_TYPE_INFORMATION,"Starting script. " & sCmdLine, TRACE_INFO
End Sub

Sub LogEvent(eventID, eventType, msg, level)
	If level <= P_TraceLevel Then
        If level = TRACE_ERROR Then
            g_StdErr.WriteLine "Logging event. " & WScript.ScriptName & " EventID: " & eventID & " eventType: " & eventType & " Version:" & SCRIPT_VERSION & " --> " & msg
        else
		    WScript.Echo "Logging event. " & WScript.ScriptName & " EventID: " & eventID & " eventType: " & eventType & " Version:" & SCRIPT_VERSION & " --> " & msg
        end if
		Call g_API.LogScriptEvent(WScript.ScriptName,eventID,eventType, msg & vbCrLf & "Version: " & SCRIPT_VERSION)
	end if
End Sub

Sub ClearGlobals
    Set g_API = Nothing
    Set g_oXML = Nothing
End Sub

Function GetXMLDate(dDate)
    Dim oNode
          
    Set oNode = g_oXML.CreateNode(1,"startTime","")
    oNode.DataType = "datetime.tz"
    oNode.nodeTypedValue =dDate
    GetXMLDate = oNode.Text
    Set oNode = Nothing
End Function
'strValueName = "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation\ActiveTimeBias"
'minTimeOffset = shell.regread(strValueName)
'toffset = datediff("h",DateAdd("n", minTimeOffset, now()),now())

Function FormatErr(oErr)
	FormatErr =  "0x" & Hex(oErr.Number) & "(" & oErr.Number & ") - " & oErr.Description
end function

Function ThrowEmptyDiscovery(SourceId, ManagedEntityId)
Dim oDiscoveryData
	set oDiscoveryData = g_API.CreateDiscoveryData(0, SourceId, ManagedEntityId)
	LogEvent FAILURE_EVENT_ID, EVENT_TYPE_WARNING, "Exiting with empty discovery data", TRACE_INFO
	Call g_API.Return(oDiscoveryData)
End Function

Function ThrowKeepDiscoveryInfo(SourceId, ManagedEntityId)
Dim oDiscoveryData
	Set oDiscoveryData = g_API.CreateDiscoveryData(0,SourceId,ManagedEntityId)
	'Instead of Snapshot discovery, submit Incremental discovery data
	oDiscoveryData.IsSnapshot = false
	LogEvent FAILURE_EVENT_ID, EVENT_TYPE_WARNING, "Exiting with null non snapshot discovery data", TRACE_INFO
    Call g_API.Return (oDiscoveryData)
End Function

Function ErrorMsg(oErr, Message)
    Dim temp
    temp = FormatErr(oErr)
    ErrorMsg = Message & " - " & temp
end Function

 Function GetTempFileName(sFile)
      Dim tfolder, tfile, fso
      Const TemporaryFolder = 2
      Set fso = CreateObject("Scripting.FileSystemObject")
      Set tfolder = fso.GetSpecialFolder(TemporaryFolder)
      If sFile = "" Then 
        sFile = fso.GetTempName    
      end if
      GetTempFileName = tfolder.Path & "\" & sFile
      Set fso = Nothing
End Function
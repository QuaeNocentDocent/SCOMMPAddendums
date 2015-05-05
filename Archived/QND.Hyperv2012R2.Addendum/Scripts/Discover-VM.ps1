				  #Copyright (c) Microsoft Corporation. All rights reserved.
				  param($SourceId, $ManagedEntityId, $ComputerIdentity)

				  # Common Functions
				  function ThrowScriptError
				  {
				  param($msg, $errorDetails)
				  $errorMsg = $msg + $errorDetails;
				  $oApi.LogScriptEvent("DiscoverHyperV2012R2VirtualMachine.ps1", 1000, 1, $errorMsg);
				  }

				  function ThrowScriptInfo
				  {
				  param($msg)
				  $oApi.LogScriptEvent("DiscoverHyperV2012R2VirtualMachine.ps1", 1000, 4, $msg);
				  }
				  # End Common Functions

				  function DiscoverVirtualNetworkAdapters()
				  {
				  param($vmId, $vmName)

				  $query = "select InstanceID, HostResource from Msvm_EthernetPortAllocationSettingData where InstanceID LIKE 'Microsoft:" + $vmId + "%'";

				  $nics = @(gwmi -Query $query -Namespace $namespace -ComputerName $ComputerIdentity)
				  foreach ($nic in $nics)
				  {
				  $deviceName = "Network Adapter";
				  $deviceID = "";
				  $ConnectedNetworkId = "";
				  $ConnectedNetworkName = "";
				  if  ( $nic.InstanceID -ne $null)
				  {
				  $instanceIdArray = $nic.InstanceID.split("\");
				  if ($instanceIdArray -ne $null -and $instanceIdArray.Count -gt 1)
				  {
				  $deviceID = $instanceIdArray[1];
				  }
				  }
				  if ($nic.HostResource -ne $null)
				  {
				  $hostResourceArray = $nic.HostResource.split("`"");
				  if ($hostResourceArray -ne $null -and $hostResourceArray.Count -gt 3)
				  {
				  $ConnectedNetworkId = $hostResourceArray[3];
				  $switchQuery = "select ElementName from Msvm_VirtualEthernetSwitch where Name = '" + $ConnectedNetworkId + "'";
				  $switches =  @(gwmi -Query $switchQuery -Namespace $namespace -ComputerName $ComputerIdentity)
				  if ($switches -ne $null -and $switches.Count -gt 0)
				  {
				  $ConnectedNetworkName = $switches[0].ElementName;
				  }
				  }
				  }
				  $oInstance = $oDiscoveryData.CreateClassInstance("$MPElement[Name='Hyperv2012R2!Microsoft.Windows.HyperV.2012.R2.VirtualNetworkAdapter']$")
				  $oInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $deviceName)
				  $oInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $ComputerIdentity)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.ServerRole']/ServerId$", $ComputerIdentity)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualMachine']/VirtualMachineId$", $vmId)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualHardwareComponent']/DeviceId$", $deviceID)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualHardwareComponent']/Name$", $deviceName)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualHardwareComponent']/VirtualMachineName$", $vmName)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualNetworkAdapter']/ConnectedNetworkId$", $ConnectedNetworkId)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualNetworkAdapter']/ConnectedNetworkName$", $ConnectedNetworkName)
				  $oDiscoveryData.AddInstance($oInstance)


				  }

				  if ($error -eq $null -or $error.Count -eq 0)
				  {
				  $errormsg = "Successfully discovered Virtual Nic instances ";
				  ThrowScriptInfo -msg $errormsg
				  }
				  else
				  {
				  $errormsg =  "Failed discovering Virtual Nic instances ";
				  ThrowScriptError -msg $errormsg -errorDetails $error
				  $error.Clear();
				  }
				  }


				  function DiscoverVirtualDisks()
				  {
				  param($vmId, $vmName)
				  $query = "select InstanceID, HostResource, ElementName from Msvm_StorageAllocationSettingData where InstanceID LIKE 'Microsoft:" + $vmId + "%'";
				  $vhds = @(gwmi -Query $query -Namespace $namespace  -ComputerName $ComputerIdentity)

				  $vhdsvc = gwmi -query "SELECT * FROM Msvm_ImageManagementService" -Namespace $namespace  -ComputerName $ComputerIdentity;


				  foreach ($vhd in $vhds)
				  {
				  $deviceID = ""
				  if ($vhd.InstanceID -ne $null)
				  {
				  $deviceID = $vhd.InstanceID;
				  }

				  $filePath = ""
				  $driveType = ""
				  $deviceName = "Hard Disk"
				  $hostResourceArray = $vhd.HostResource;
				  if ($hostResourceArray -ne $null -and $vhdsvc -ne $null)
				  {
				  $filePath = $hostResourceArray[0];
				  $outParams = $vhdsvc.GetVirtualHardDiskSettingData($filePath);
				  $xmlDoc = new-object -comObject 'Microsoft.XMLDOM';
				  $xmlDoc.async = "false";
				  $xmlDoc.loadXML($outParams.SettingData)
				  $xPath = "/INSTANCE/PROPERTY[@NAME='Type']/VALUE/child:text()"
				  $node = $xmlDoc.selectSingleNode($xPath)
				  if ($node -ne $null)
				  {
				  if ($node.Text -ne "")
				  {
				  $driveType = $node.Text;
				  }
				  }
				  }

				  $oInstance = $oDiscoveryData.CreateClassInstance("$MPElement[Name='Hyperv2012R2!Microsoft.Windows.HyperV.2012.R2.VirtualDrive']$")
				  $oInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $deviceName)
				  $oInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $ComputerIdentity)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.ServerRole']/ServerId$", $ComputerIdentity)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualMachine']/VirtualMachineId$", $vmId)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualHardwareComponent']/DeviceId$", $deviceID)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualHardwareComponent']/Name$", $deviceName)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualHardwareComponent']/VirtualMachineName$", $vmName)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualDrive']/ImageFile$", $filePath)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualDrive']/DriveType$", $driveType)
				  $oDiscoveryData.AddInstance($oInstance)


				  $filePathParts = $filePath.split("\");
				  $driveLetter = "";
				  if ($filePathParts -ne $null -and $filePathParts.Count -gt 0)
				  {
				  $driveLetter = $filePathParts[0].ToUpper();
				  $oLogicalDisk = $oDiscoveryData.CreateClassInstance("$MPElement[Name='WSLib!Microsoft.Windows.Server.6.2.LogicalDisk']$")
				  $oLogicalDisk.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $ComputerIdentity)
				  $oLogicalDisk.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.LogicalDevice']/DeviceID$", $driveLetter)

				  # Create Relationship
				  $oRelationship = $oDiscoveryData.CreateRelationshipInstance("$MPElement[Name='Hyperv2012R2!Microsoft.Windows.Server.2012.R2.LogicalDisk.Contains.HyperV.VirtualDrive']$")
				  $oRelationship.Source = $oLogicalDisk;
				  $oRelationship.Target = $oInstance;
				  $oDiscoveryData.AddInstance($oRelationship);

				  }
				  }


				  if ($error -eq $null -or $error.Count -eq 0)
				  {
				  $errormsg = "Successfully discovered Virtual HardDisk instances ";
				  ThrowScriptInfo -msg $errormsg
				  }
				  else
				  {
				  $errormsg =  "Failed discovering Virtual HardDisk instances: " ;
				  ThrowScriptError -msg $errormsg -errorDetails $error
				  $error.Clear();
				  }
				  }


				  $error.Clear();
				  $oApi = new-object -comObject 'MOM.ScriptAPI'
				  $oDiscoveryData = $oApi.CreateDiscoveryData(0, $SourceId, $ManagedEntityId);
									$oApi.LogScriptEvent("DiscoverHyperV2012R2VirtualMachine.ps1", 1001, 2, 'Starting VM discovery');
				  $namespace = "root/virtualization/v2";

				  $virtualMachineList = @(gwmi -Query  "SELECT Name, ElementName FROM MSVM_ComputerSystem" -namespace $namespace -ComputerName $ComputerIdentity);
				  $hostComputerName = @(gwmi Win32_ComputerSystem -ComputerName $ComputerIdentity);

				  foreach ($oVirtualMachine in $virtualMachineList)
				  {
				  if ($oVirtualMachine.Name.ToLowerInvariant() -eq $hostComputerName.Name.ToLowerInvariant())
				  {
				  continue;
				  }

				  $query = "select GuestIntrinsicExchangeItems from MSVM_KvpExchangeComponent where SystemName='" + $oVirtualMachine.Name + "'";
				  $associators = @(gwmi -Query $query -namespace $namespace -ComputerName $ComputerIdentity);
				  $computerName = "";
				  if ($associators -ne $null -and $associators.Count -gt 0)
				  {
				  $KVP = $associators[0];
				  if ($KVP -ne $null)
				  {
				  $xmlDoc = new-object -comObject 'Microsoft.XMLDOM';
				  $xmlDoc.async = "false";
				  if ($KVP.GuestIntrinsicExchangeItems -ne $null)
				  {
				  foreach ( $dataItem in $KVP.GuestIntrinsicExchangeItems)
				  {
				  $xmlDoc.loadXML($dataItem); #dataItem is in xml
				  $xPath = "/INSTANCE/PROPERTY[@NAME='Name']/VALUE/child:text()";
				  $node = $xmlDoc.selectSingleNode($xPath)
				  if ($node.Text -eq "FullyQualifiedDomainName")
				  {
				  $xPath = "/INSTANCE/PROPERTY[@NAME='Data']/VALUE/child:text()" ;
				  $node = $xmlDoc.selectSingleNode($xPath);
				  $computerName = $node.Text;
				  break;
				  }
				  }
				  }
				  }
				  }

				  $oInstance = $oDiscoveryData.CreateClassInstance("$MPElement[Name='Hyperv2012R2!Microsoft.Windows.HyperV.2012.R2.VirtualMachine']$")
				  $oInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $oVirtualMachine.ElementName)
				  $oInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $ComputerIdentity)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.ServerRole']/ServerId$", $ComputerIdentity)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualMachine']/VirtualMachineId$", $oVirtualMachine.Name)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualMachine']/VirtualMachineName$", $oVirtualMachine.ElementName)
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualMachine']/ServerName$", $ComputerIdentity)
				  if ($computerName -ne "")
				  {
				  $oInstance.AddProperty("$MPElement[Name='HypervLib!Microsoft.Windows.HyperV.VirtualMachine']/ComputerName$", $computerName)
				  }



				  $oDiscoveryData.AddInstance($oInstance);

				  DiscoverVirtualNetworkAdapters -vmId $oVirtualMachine.Name -vmName $oVirtualMachine.ElementName;

				  DiscoverVirtualDisks -vmId $oVirtualMachine.Name -vmName $oVirtualMachine.ElementName;


				  }

				  if ($error -eq $null -or $error.Count -eq 0)
				  {
				  $errormsg = "Successfully discovered Virtual Machine instances ";
				  ThrowScriptInfo -msg $errormsg
				  }
				  else
				  {
				  $errormsg = "Failed discovering Virtual Machine instances "
				  ThrowScriptError -msg $errormsg -errorDetails $error
				  $error.Clear();
				  }

				  $oDiscoveryData

				
# SCOMMPAddendums

**Preliminary ported documentation**

QND.ClusterDisk.Addendum - improves cluster disks and CSV monitoring and performance collection http://nocentdocent.wordpress.com/2014/03/15/cluster-csv-disk-monitoring-with-scom-sysctr/

QND.DPM2012.Addendum - integrates Microsoft provided DPM 2012 Management Packs with new monitoring scenarios. For more info see https://nocentdocent.wordpress.com/2015/02/06/dpm-2012-addendum-management-pack-sysctr/.
MP documentation here QND.DPM2012.Addendum.

Project Description
This project collects a community based effort to improve di management capabilities of the Microsoft provided management packs for the Operating System.


Short list of included management packs:
QND.ClusterDisk.Addendum - improves cluster disks and CSV monitoring and performance collection http://nocentdocent.wordpress.com/2014/03/15/cluster-csv-disk-monitoring-with-scom-sysctr/

QND.DPM2012.Addendum - integrates Microsoft provided DPM 2012 Management Packs with new monitoring scenarios.
https://scomosmpaddendums.codeplex.com/releases/view/127620

urrent Version: 1.0.0.47
The relevant configuration requirements and monitoring defaults are detailed in the Management Pack internal Knowledge base.

Scenarios

The management pack implements the following monitoring scenarios:
Storage Pool consumption
The DPM Storage Pool is the collection of all the disks assigned to DPM. The Management pack collects the precentage of free space and alerts on when this percentage falls below 15% and 5%.
Protection Group SLA breaches
Starting with UR4 it is possibile to define a specific SLA for Protection groups
Data Source protection SLA breaches
For data sources contained in PG with defined SLA it checks for any breach

Classes
QND.DPM2012.SLAProtectionGroup (Protection Group with SLA) derived from Microsoft.SystemCenter.DataProtectionManager.2011.Library.ProtectionGroup
Adds SLA property to keep track of protection group defined SLA, discovered by default every 5 hours and 20'
QND.DPM2012.DataSourceswithSLA.Group (DPM Data Sources with SLA)
QND.DPM2012.DataSourceswithoutSLA.Group (DPM Data Sources without SLA)

Monitors
QND.DPM2012.Addendum.SPFreeSpace (DPM: Storage Pool Free Space)
Monitors Storage Pool Free Space
QND.DPM2012.Addendum.DSSLA (DPM: DS In SLA)
Monitors the datasource recopery point SLA
QND.DPM2012.Addendum.PGSLA (DPM: PG In SLA)
Monitors the Protection Group SLA

Rules
QND.DPM2012.Addendum.SPFreeSpace.Rule (DPM: Storage Pool Free Space %)
Collects DPM Storage Pool Free Space %

Overrides
QND.DPM2012.DisableRPMonitorForSLADS
disables alert generation for Microsoft.SystemCenter.DataProtectionManager.2011.Discovery.RecoveryPointCreationFailed targeted at QND.DPM2012.DataSourceswithSLA.Group
QND.DPM2012.DisableSLAMonitorForNoSLADS
disables SLA monitoring (QND.DPM2012.Addendum.DSSLA) targeted at QND.DPM2012.DataSourceswithoutSLA.Group
QND.DPM2012.DisableStandardSLARule
disables Standard SLA rules (QND.DPM2012.DisableStandardSLARule) targeted at Microsoft.SystemCenter.DataProtectionManager.2011.Library.DPMServer

parameter($P_DiskLabel, $TargetComputer )

$disk = gwmi -computer $TargetComputer -query "select * from Win32_volume where Name = '$P_DiskLabel\\' or DriveLetter='$P_DiskLabel' or DeviceId='$P_DiskLabel'"
$result = @"
Server: $TargetComputer. Disk: $P_DiskLabel
Disk Size (MB): $($disk.Capacity/(1024*1024))
Disk Free Space (MB): $($disk.FreeSpace/(1024*1024))
Disk Free Space (%): $($disk.FreeSpace/$Disk.Capacity*100)
"@
Write-Output $result
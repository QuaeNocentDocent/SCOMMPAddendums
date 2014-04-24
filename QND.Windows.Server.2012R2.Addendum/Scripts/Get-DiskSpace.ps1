param($DiskLabel, $TargetComputer )

$disk = gwmi -computer $TargetComputer -query "select * from Win32_volume where Name = '$DiskLabel\\' or DriveLetter='$DiskLabel' or DeviceId='$DiskLabel'"
$result = @"
Server: $TargetComputer. Disk: $DiskLabel
Disk Size (MB): $($disk.Capacity/(1024*1024))
Disk Free Space (MB): $($disk.FreeSpace/(1024*1024))
Disk Free Space (%): $($disk.FreeSpace/$Disk.Capacity*100)
"@
Write-Output $result
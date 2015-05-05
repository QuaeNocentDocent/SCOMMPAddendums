
#quick and dirty
param([string] $source)

New-EventLog –LogName 'Operations Manager' –Source 'Hyper-V Dynamic Discovery' -ErrorAction SilentlyContinue

Write-EventLog -LogName 'Operations Manager' -Source 'Hyper-V Dynamic Discovery' -EntryType Information -EventId 62001 -Message $source
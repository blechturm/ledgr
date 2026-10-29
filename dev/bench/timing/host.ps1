# Shared timing harness (LDG-3155): one host snapshot, read by host.R.
#
# Prints one "host" line and one "proc" line per running process:
#   host,<power plan GUID>,<CPU load percent>,<CPU name>
#   proc,<pid>,<parent pid>,<created>,<affinity>,<affinity created>,<name>
# <created> is the CIM process creation time. <affinity> and
# <affinity created> come from one Get-Process object: its affinity mask and
# its own start time, so host.R can refuse a mask whose process is not the
# one CIM listed under that PID (a PID reused between the two enumerations).
# Times are integer Unix milliseconds, so no culture-specific decimal
# separator or exact-second formatting enters the record. A process that
# cannot be opened (another user's or an elevated one) reports -1 for both.

$plan = (powercfg /getactivescheme) -join ' '
$guid = ''
if ($plan -match '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}') { $guid = $Matches[0] }
$cpu = Get-CimInstance Win32_Processor
$load = [int]($cpu | Measure-Object LoadPercentage -Average).Average
$cpuName = (($cpu | Select-Object -First 1).Name -replace ',', ' ').Trim()
'host,{0},{1},{2}' -f $guid, $load, $cpuName

$mask = @{}
foreach ($p in Get-Process) {
  try {
    $mask[$p.Id] = '{0},{1}' -f $p.ProcessorAffinity.ToInt64(), ([DateTimeOffset]$p.StartTime).ToUnixTimeMilliseconds()
  } catch {
    $mask[$p.Id] = '-1,-1'
  }
}
foreach ($w in Get-CimInstance Win32_Process) {
  $created = 0
  if ($w.CreationDate) { $created = ([DateTimeOffset]$w.CreationDate).ToUnixTimeMilliseconds() }
  $m = '-1,-1'
  if ($mask.ContainsKey([int]$w.ProcessId)) { $m = $mask[[int]$w.ProcessId] }
  'proc,{0},{1},{2},{3},{4}' -f $w.ProcessId, $w.ParentProcessId, $created, $m, ($w.Name -replace ',', '_')
}

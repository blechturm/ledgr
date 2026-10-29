# Shared timing harness (LDG-3155): one host snapshot, read by host.R.
#
# Prints one "host" line and one "proc" line per running process:
#   host,<power plan GUID>,<CPU load percent>,<CPU name>
#   proc,<pid>,<parent pid>,<created>,<affinity>,<affinity created>,<cpu ms>,<name>
# <created> is the CIM process creation time. <affinity>, <affinity created>
# and <cpu ms> come from one Get-Process object: its affinity mask, its own
# start time and its cumulative CPU time, so host.R can refuse values whose
# process is not the one CIM listed under that PID (a PID reused between the
# two enumerations). All are integers (Unix or CPU milliseconds), so no
# culture-specific decimal separator enters the record. A process that
# cannot be opened (another user's or an elevated one) reports -1 for each.

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
    $mask[$p.Id] = '{0},{1},{2}' -f $p.ProcessorAffinity.ToInt64(), ([DateTimeOffset]$p.StartTime).ToUnixTimeMilliseconds(),
      [int64]$p.TotalProcessorTime.TotalMilliseconds
  } catch {
    $mask[$p.Id] = '-1,-1,-1'
  }
}
foreach ($w in Get-CimInstance Win32_Process) {
  $created = 0
  if ($w.CreationDate) { $created = ([DateTimeOffset]$w.CreationDate).ToUnixTimeMilliseconds() }
  $m = '-1,-1,-1'
  if ($mask.ContainsKey([int]$w.ProcessId)) { $m = $mask[[int]$w.ProcessId] }
  'proc,{0},{1},{2},{3},{4}' -f $w.ProcessId, $w.ParentProcessId, $created, $m, ($w.Name -replace ',', '_')
}

# Shared timing harness (LDG-3155): one host snapshot, read by host.R.
#
# Prints one "host" line and one "proc" line per running process:
#   host,<power plan GUID>,<CPU load percent>,<CPU name>
#   proc,<pid>,<parent pid>,<creation time, Unix ms>,<affinity mask or -1>,<name>
# Creation times are integer milliseconds so no culture-specific decimal
# separator or exact-second formatting can enter the record. Affinity is -1
# when the process cannot be opened (another user's or an elevated process).

$plan = (powercfg /getactivescheme) -join ' '
$guid = ''
if ($plan -match '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}') { $guid = $Matches[0] }
$cpu = Get-CimInstance Win32_Processor
$load = [int]($cpu | Measure-Object LoadPercentage -Average).Average
$cpuName = (($cpu | Select-Object -First 1).Name -replace ',', ' ').Trim()
'host,{0},{1},{2}' -f $guid, $load, $cpuName

$affinity = @{}
foreach ($p in Get-Process) {
  try { $affinity[$p.Id] = $p.ProcessorAffinity.ToInt64() } catch { $affinity[$p.Id] = -1 }
}
foreach ($w in Get-CimInstance Win32_Process) {
  $created = 0
  if ($w.CreationDate) { $created = ([DateTimeOffset]$w.CreationDate).ToUnixTimeMilliseconds() }
  $mask = -1
  if ($affinity.ContainsKey([int]$w.ProcessId)) { $mask = $affinity[[int]$w.ProcessId] }
  'proc,{0},{1},{2},{3},{4}' -f $w.ProcessId, $w.ParentProcessId, $created, $mask, ($w.Name -replace ',', '_')
}

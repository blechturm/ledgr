# WS45 scale record under the recorded timing method
# (inst/design/manual/benchmark_methodology.qmd, "Timing Gates On The
# Maintainer Host"): High performance plan, affinity 0xFFFF inherited by
# every Rscript, BASE and candidate alternating, three repetitions.
#   powershell -File run_scale.ps1 <base_tree> <candidate_tree> <cache_dir> <out_csv>
param(
  [string]$Base,
  [string]$Candidate,
  [string]$Cache,
  [string]$Out
)
$ErrorActionPreference = "Stop"
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF
$rscript = "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe"
$stageScript = Join-Path $PSScriptRoot "scale_stage.R"
$plan = (powercfg /getactivescheme) -join " "
"power_plan: $plan" | Out-File -FilePath "$Out.conditions.txt" -Encoding ascii
"process_affinity: 0x{0:X}" -f [int][System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity |
  Out-File -FilePath "$Out.conditions.txt" -Append -Encoding ascii

foreach ($rows in 100000, 400000) {
  & $rscript $stageScript $Base base prepare $rows $Cache $Out
  & $rscript $stageScript $Candidate candidate prepare $rows $Cache $Out
}
$plans = @(
  @{ stage = "lineage"; rows = 100000; base = $true },
  @{ stage = "lineage"; rows = 400000; base = $true },
  @{ stage = "resolve"; rows = 100000; base = $true },
  @{ stage = "resolve"; rows = 400000; base = $true },
  @{ stage = "hash"; rows = 100000; base = $true },
  @{ stage = "hash"; rows = 400000; base = $true },
  @{ stage = "conflicts"; rows = 100000; base = $true },
  @{ stage = "conflicts"; rows = 400000; base = $false }
)
foreach ($rep in 1, 2, 3) {
  foreach ($p in $plans) {
    $arms = if ($rep % 2 -eq 1) { @("base", "candidate") } else { @("candidate", "base") }
    foreach ($arm in $arms) {
      if ($arm -eq "base" -and -not $p.base) { continue }
      $tree = if ($arm -eq "base") { $Base } else { $Candidate }
      & $rscript $stageScript $tree $arm $p.stage $p.rows $Cache $Out
    }
  }
}

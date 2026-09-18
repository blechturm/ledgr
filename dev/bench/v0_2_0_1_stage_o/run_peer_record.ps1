param(
  [string]$RepoRoot = "C:\Users\maxth\Documents\GitHub\ledgr",
  [string]$Rscript = "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$results = Join-Path $repo "dev\bench\results"
$started = [DateTime]::UtcNow
$stdout = Join-Path $env:TEMP ("ledgr_stage_o_peer_" + [guid]::NewGuid() + ".out")
$stderr = Join-Path $env:TEMP ("ledgr_stage_o_peer_" + [guid]::NewGuid() + ".err")
$sampleTemp = Join-Path $env:TEMP ("ledgr_stage_o_peer_" + [guid]::NewGuid() + ".csv")
$env:R_PROFILE_USER = "C:\tmp\ledgr-batch10-profile.R"
$env:LEDGR_BATCH10_LIB = "C:\tmp\ledgr-quantstrat-batch10-lib"

$arguments = @(
  "dev/bench/peer_benchmark/peer_benchmark.R",
  "--preset", "record",
  "--release", "v0.2.0.1",
  "--engine-set", "all",
  "--n-inst", "500",
  "--n-days", "1260",
  "--fast", "5",
  "--slow", "10",
  "--seed", "20260530",
  "--compiled-accounting-model", "spot_fifo"
)

$process = Start-Process `
  -FilePath $Rscript `
  -ArgumentList $arguments `
  -WorkingDirectory $repo `
  -WindowStyle Hidden `
  -RedirectStandardOutput $stdout `
  -RedirectStandardError $stderr `
  -PassThru

$samples = [System.Collections.Generic.List[object]]::new()
while (-not $process.HasExited) {
  $process.Refresh()
  $all = Get-CimInstance Win32_Process -Property ProcessId,ParentProcessId
  $ids = [System.Collections.Generic.HashSet[int]]::new()
  [void]$ids.Add([int]$process.Id)
  $changed = $true
  while ($changed) {
    $changed = $false
    foreach ($row in $all) {
      if ($ids.Contains([int]$row.ParentProcessId) -and
          -not $ids.Contains([int]$row.ProcessId)) {
        [void]$ids.Add([int]$row.ProcessId)
        $changed = $true
      }
    }
  }
  $workingSet = 0.0
  $live = 0
  foreach ($id in $ids) {
    $p = Get-Process -Id $id -ErrorAction SilentlyContinue
    if ($null -ne $p) {
      $workingSet += [double]$p.WorkingSet64
      $live += 1
    }
  }
  $samples.Add([pscustomobject]@{
    sampled_at_utc = [DateTime]::UtcNow.ToString("o")
    elapsed_sec = ([DateTime]::UtcNow - $started).TotalSeconds
    working_set_mib = $workingSet / 1MB
    process_count = $live
  })
  Start-Sleep -Milliseconds 1000
}
$process.WaitForExit()
$process.Refresh()
$samples | Export-Csv -LiteralPath $sampleTemp -NoTypeInformation
Write-Output ("STAGE_O_SAMPLE_TEMP=" + $sampleTemp)

$outText = if (Test-Path -LiteralPath $stdout) {
  Get-Content -LiteralPath $stdout -Raw
} else { "" }
$errText = if (Test-Path -LiteralPath $stderr) {
  Get-Content -LiteralPath $stderr -Raw
} else { "" }
Write-Output $outText
if ($errText) { Write-Output $errText }
$status = Get-ChildItem -LiteralPath $results -Filter "peer_benchmark_record_*_status.csv" |
  Where-Object {
    $_.Name -notlike "*_surface_status.csv" -and
    $_.LastWriteTimeUtc -ge $started.AddSeconds(-5)
  } |
  Sort-Object LastWriteTimeUtc
if ($status.Count -ne 1) {
  throw "Expected exactly one new peer status artifact, found $($status.Count)."
}
$stem = $status[0].FullName -replace "_status[.]csv$", ""
Copy-Item -LiteralPath $sampleTemp -Destination ($stem + "_working_set_samples.csv")
$peak = ($samples | Measure-Object -Property working_set_mib -Maximum).Maximum
$summary = [pscustomobject]@{
  record_prefix = $stem.Replace("\", "/")
  source_commit = "bcced9457de58f10f9c862c2890576a7370b1140"
  sampling_interval_sec = 1
  sample_count = $samples.Count
  peak_working_set_mib = $peak
  clock = "complete peer benchmark process tree"
}
$summary | Export-Csv -LiteralPath ($stem + "_working_set_peak.csv") -NoTypeInformation
$exitCode = $process.ExitCode
if ($null -ne $exitCode -and $exitCode -ne 0) {
  throw "Stage O peer benchmark exited with code $exitCode."
}
Write-Output ("PEER_RECORD_PREFIX=" + $stem.Replace("\", "/"))
Write-Output ("PEER_PEAK_WORKING_SET_MIB=" + $peak.ToString("0.0"))

Remove-Item -LiteralPath $stdout,$stderr,$sampleTemp -Force -ErrorAction SilentlyContinue

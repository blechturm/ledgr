param(
  [string]$RepoRoot = ".",
  [string]$Rscript = "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe",
  [string]$Release = "v0.2.1.0",
  [ValidateSet("ttr-first", "builtin-first")]
  [string]$LedgrOrder = "ttr-first",
  [string]$RProfile = "C:\tmp\ledgr-batch10-profile.R",
  [string]$QuantstratLib = "C:\tmp\ledgr-quantstrat-batch10-lib"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$results = Join-Path $repo "dev\bench\results"
$started = [DateTime]::UtcNow
$token = [guid]::NewGuid().ToString("N")
$stdout = Join-Path $env:TEMP ("ledgr_peer_" + $token + ".out")
$stderr = Join-Path $env:TEMP ("ledgr_peer_" + $token + ".err")
$sampleTemp = Join-Path $env:TEMP ("ledgr_peer_" + $token + ".csv")
$env:R_PROFILE_USER = $RProfile
$env:LEDGR_BATCH10_LIB = $QuantstratLib

$arguments = @(
  "dev/bench/peer_benchmark/peer_benchmark.R",
  "--preset", "record",
  "--release", $Release,
  "--engine-set", "all",
  "--n-inst", "500",
  "--n-days", "1260",
  "--fast", "5",
  "--slow", "10",
  "--seed", "20260530",
  "--compiled-accounting-model", "spot_fifo",
  "--ledgr-order", $LedgrOrder
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

$outText = if (Test-Path -LiteralPath $stdout) {
  Get-Content -LiteralPath $stdout -Raw
} else { "" }
$errText = if (Test-Path -LiteralPath $stderr) {
  Get-Content -LiteralPath $stderr -Raw
} else { "" }
Write-Output $outText
if ($errText) { Write-Output $errText }

$status = Get-ChildItem -LiteralPath $results `
  -Filter "peer_benchmark_record_*_status.csv" |
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
$sourceCommit = (& git -C $repo rev-parse HEAD).Trim()
$summary = [pscustomobject]@{
  record_prefix = $stem.Replace("\", "/")
  source_commit = $sourceCommit
  sampling_interval_sec = 1
  sample_count = $samples.Count
  peak_working_set_mib = $peak
  clock = "complete peer benchmark process tree"
}
$summary | Export-Csv -LiteralPath ($stem + "_working_set_peak.csv") -NoTypeInformation
if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
  throw "Peer benchmark exited with code $($process.ExitCode)."
}

& $Rscript `
  "dev/bench/peer_benchmark/write_quantstrat_environment.R" `
  $stem `
  $QuantstratLib
if ($LASTEXITCODE -ne 0) {
  throw "Could not write the quantstrat environment sidecar."
}
Write-Output ("PEER_RECORD_PREFIX=" + $stem.Replace("\", "/"))
Write-Output ("PEER_PEAK_WORKING_SET_MIB=" + $peak.ToString("0.0"))

Remove-Item -LiteralPath $stdout,$stderr,$sampleTemp `
  -Force -ErrorAction SilentlyContinue

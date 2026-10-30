param(
  [Parameter(Mandatory=$true)][string]$Out,
  [Parameter(Mandatory=$true)][string]$SourceRevision,
  [string]$Root = ''
)
$ErrorActionPreference = 'Stop'
$Rscript = 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe'
$Rexe = 'C:/Program Files/R/R-4.6.1/bin/x64/R.exe'
$Git = 'C:/Program Files/Git/cmd/git.exe'
$Here = $PSScriptRoot
$Utf8 = New-Object System.Text.UTF8Encoding($false)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $Here '../../../..')).Path }
$Root = (Resolve-Path -LiteralPath $Root).Path

function Write-Json($Path, $Value) {
  [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 12), $Utf8)
}
function Invoke-Tool($Exe, $Arguments, $Log, [switch]$AllowFailure) {
  $si = New-Object Diagnostics.ProcessStartInfo
  $si.FileName = $Exe
  $si.Arguments = $Arguments
  $si.UseShellExecute = $false
  $si.CreateNoWindow = $true
  $si.RedirectStandardOutput = $true
  $si.RedirectStandardError = $true
  $tool = New-Object Diagnostics.Process
  $tool.StartInfo = $si
  [void]$tool.Start()
  $output = $tool.StandardOutput.ReadToEndAsync()
  $errors = $tool.StandardError.ReadToEndAsync()
  $tool.WaitForExit()
  [IO.File]::WriteAllText($Log, ($output.GetAwaiter().GetResult() + $errors.GetAwaiter().GetResult()), $Utf8)
  if ($tool.ExitCode -ne 0 -and -not $AllowFailure) {
    throw "Preparation tool failed: $Exe; see $Log"
  }
  $tool.ExitCode
}

if (Test-Path -LiteralPath $Out) { throw 'Use a new output directory; no overwrite or retry.' }
[void](New-Item -ItemType Directory -Path $Out)
$Self = [Diagnostics.Process]::GetCurrentProcess()
$Self.ProcessorAffinity = [IntPtr]0xFFFF
$env:R_ENABLE_JIT = '3'
$env:OMP_NUM_THREADS = '1'
$env:OPENBLAS_NUM_THREADS = '1'
$env:MKL_NUM_THREADS = '1'
$env:NUMEXPR_NUM_THREADS = '1'

$SourceRevision = (& $Git -C $Root rev-parse $SourceRevision).Trim()
$HarnessRevision = (& $Git -C $Root rev-parse HEAD).Trim()
$HostR = Join-Path $Root 'dev/bench/timing/host.R'
$HostPs1 = Join-Path $Root 'dev/bench/timing/host.ps1'
$HostRBlob = (& $Git hash-object $HostR).Trim()
$HostPs1Blob = (& $Git hash-object $HostPs1).Trim()
$ExpectedHostR = (& $Git -C $Root rev-parse "${HarnessRevision}:dev/bench/timing/host.R").Trim()
$ExpectedHostPs1 = (& $Git -C $Root rev-parse "${HarnessRevision}:dev/bench/timing/host.ps1").Trim()
if ($HostRBlob -ne $ExpectedHostR -or $HostPs1Blob -ne $ExpectedHostPs1) {
  throw 'Shared host files differ from the recorded harness commit.'
}

$Work = Join-Path $env:TEMP ('ledgr-ws3-timing-' + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $Work)
$Library = Join-Path $Work 'library'
$Inputs = Join-Path $Work 'inputs'
[void](New-Item -ItemType Directory -Path $Library)

function Invoke-HostProbe($Label) {
  $Probe = Join-Path $Work ($Label + '.host.rds')
  $Summary = Join-Path $Out ($Label + '.host.csv')
  $Log = Join-Path $Out ($Label + '.host.log')
  $Args = '--vanilla "{0}" --mode=host "--repo={1}" --root-pid={2} "--probe-out={3}" "--summary-out={4}"' -f `
    (Join-Path $Here 'timing.R'),$Root,$Self.Id,$Probe,$Summary
  [void](Invoke-Tool $Rscript $Args $Log)
  Import-Csv -LiteralPath $Summary
}

# The shared probe and all input-identity work are outside both measured arms.
$PreflightHost = Invoke-HostProbe 'preflight'
Write-Json (Join-Path $Out 'preflight.json') @{
  source_revision=$SourceRevision; harness_revision=$HarnessRevision;
  host_r_blob=$HostRBlob; host_ps1_blob=$HostPs1Blob;
  host_r_path='dev/bench/timing/host.R'; host_ps1_path='dev/bench/timing/host.ps1';
  parent_affinity=$Self.ProcessorAffinity.ToInt64(); host=$PreflightHost; scratch=$Work
}

# Installation and deterministic common-input generation are outside the clocks.
$Zip = Join-Path $Work 'source.zip'
$Source = Join-Path $Work 'source'
& $Git -C $Root archive --format=zip "--output=$Zip" $SourceRevision
if ($LASTEXITCODE -ne 0) { throw 'git archive failed' }
Expand-Archive -LiteralPath $Zip -DestinationPath $Source
[void](Invoke-Tool $Rexe ('CMD INSTALL --no-multiarch "--library={0}" "{1}"' -f $Library,$Source) (Join-Path $Out 'installation.txt'))
[void](Invoke-Tool $Rscript ('--vanilla "{0}" --mode=prepare "--library={1}" "--out={2}"' -f (Join-Path $Here 'timing.R'),$Library,$Inputs) (Join-Path $Out 'preparation.txt'))

$Attempts = New-Object System.Collections.Generic.List[object]
$Batch = [Diagnostics.Stopwatch]::StartNew()
$Stop = $false
for ($Rep = 1; $Rep -le 5 -and -not $Stop; $Rep++) {
  $Shapes = if ($Rep % 2 -eq 1) { @('12x90','500x1260') } else { @('500x1260','12x90') }
  foreach ($Shape in $Shapes) {
    $Id = '{0}_{1:00}' -f $Shape,$Rep
    $AttemptDir = Join-Path $Work $Id
    $Before = Invoke-HostProbe ($Id + '.before')
    $a = [ordered]@{
      id=$Id; shape=$Shape; repetition=$Rep; status='not_started'; exit_code=-1;
      source_revision=$SourceRevision; harness_revision=$HarnessRevision;
      host_r_blob=$HostRBlob; host_ps1_blob=$HostPs1Blob;
      library=$Library; scratch=$AttemptDir;
      plan_guid=$Before.plan_guid; parent_affinity=$Self.ProcessorAffinity.ToInt64(); child_affinity=0; pid=0;
      cpu_before=[double]$Before.cpu_percent; cpu_after=[double]::NaN;
      foreign_r_before=$Before.foreign_r; foreign_r_after='';
      threads='OMP=1;OPENBLAS=1;MKL=1;NUMEXPR=1'; configured_jit=3;
      started_utc=[DateTime]::UtcNow.ToString('o'); elapsed_sec=0.0
    }
    if ($Batch.Elapsed.TotalSeconds -ge 5400) {
      $a.status = 'budget_unavailable'
      $Attempts.Add($a)
      $Stop = $true
      break
    }
    $Start = New-Object Diagnostics.ProcessStartInfo
    $Start.FileName = $Rscript
    $Start.Arguments = '--vanilla "{0}" --mode=worker "--library={1}" "--out={2}" --source={3} --shape={4} --repetition={5} "--input={6}"' -f `
      (Join-Path $Here 'timing.R'),$Library,$AttemptDir,$SourceRevision,$Shape,$Rep,(Join-Path $Inputs ($Shape+'.rds'))
    $Start.UseShellExecute = $false
    $Start.CreateNoWindow = $true
    $Start.RedirectStandardOutput = $true
    $Start.RedirectStandardError = $true
    $p = New-Object Diagnostics.Process
    $p.StartInfo = $Start
    $Launch = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000).ToString('R', [Globalization.CultureInfo]::InvariantCulture)
    $p.StartInfo.Arguments += " --launch=$Launch"
    $Watch = [Diagnostics.Stopwatch]::StartNew()
    [void]$p.Start()
    $a.pid = $p.Id
    $a.child_affinity = $p.ProcessorAffinity.ToInt64()
    $Stdout = $p.StandardOutput.ReadToEndAsync()
    $Stderr = $p.StandardError.ReadToEndAsync()
    $Limit = [Math]::Min(1200.0, 5400.0 - $Batch.Elapsed.TotalSeconds)
    if (-not $p.WaitForExit([int]($Limit * 1000))) {
      $p.Kill()
      $p.WaitForExit()
      $a.status = 'censored'
    }
    $a.elapsed_sec = $Watch.Elapsed.TotalSeconds
    $a.exit_code = $p.ExitCode
    if ($a.status -eq 'not_started') { $a.status = if ($p.ExitCode -eq 0) { 'complete' } else { 'failed' } }
    [IO.File]::WriteAllText((Join-Path $Out ($Id+'.stdout.txt')), $Stdout.GetAwaiter().GetResult(), $Utf8)
    [IO.File]::WriteAllText((Join-Path $Out ($Id+'.stderr.txt')), $Stderr.GetAwaiter().GetResult(), $Utf8)
    $After = Invoke-HostProbe ($Id + '.after')
    $a.cpu_after = [double]$After.cpu_percent
    $a.foreign_r_after = $After.foreign_r
    if ($a.status -eq 'complete' -and $a.child_affinity -ne 65535) { $a.status = 'host_invalid' }
    $Attempts.Add($a)
    Write-Json (Join-Path $Out 'attempts.json') @($Attempts.ToArray())
    if (Test-Path -LiteralPath (Join-Path $AttemptDir 'environment.txt')) {
      Copy-Item -LiteralPath (Join-Path $AttemptDir 'environment.txt') -Destination (Join-Path $Out ($Id+'.environment.txt'))
    }
    Write-Host $Id $a.status $a.elapsed_sec
    if ($a.status -ne 'complete') { $Stop = $true; break }
  }
}
Write-Json (Join-Path $Out 'attempts.json') @($Attempts.ToArray())
Write-Json (Join-Path $Out 'session.json') @{
  source_revision=$SourceRevision; harness_revision=$HarnessRevision;
  host_r_blob=$HostRBlob; host_ps1_blob=$HostPs1Blob;
  host_r_path='dev/bench/timing/host.R'; host_ps1_path='dev/bench/timing/host.ps1';
  measurement_window_sec=$Batch.Elapsed.TotalSeconds; attempt_limit_sec=1200; repetitions=5
}
& $Rscript --vanilla (Join-Path $Here 'timing_check.R') "--collect=$Out"
if ($LASTEXITCODE -ne 0 -or $Stop) { throw 'Baseline incomplete/invalid; preserved every attempt; stop for disposition, no retry.' }

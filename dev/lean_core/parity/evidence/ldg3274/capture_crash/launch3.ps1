param([string]$Script, [string]$Log, [string]$Profile = "", [string]$RArgs = "")
if ($Profile -ne "") { $env:R_PROFILE_USER = $Profile }
$a = @("--no-save", "--no-restore", "--no-echo", "-f", $Script)
if ($RArgs -ne "") { $a += "--args"; $a += $RArgs.Split(" ") }
$p = Start-Process -FilePath "C:\Program Files\R\R-4.6.1\bin\x64\Rterm.exe" -ArgumentList $a -RedirectStandardOutput $Log -RedirectStandardError ($Log + ".err") -PassThru -NoNewWindow
$null = $p.Handle
$p.WaitForExit()
"{0} exit code 0x{1:X8} ({2})" -f (Get-Date -Format HH:mm:ss), $p.ExitCode, $p.ExitCode | Out-File -Append ($Log + ".exit")

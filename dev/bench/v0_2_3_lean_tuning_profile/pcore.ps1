# Runs Rscript on the P-cores (affinity 0xFFFF; children inherit the mask)
# with the given arguments; output goes to the log named first.
param([string]$Log, [Parameter(ValueFromRemainingArguments = $true)][string[]]$RArgs)
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" @RArgs *> $Log
exit $LASTEXITCODE

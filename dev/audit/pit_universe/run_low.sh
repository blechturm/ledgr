#!/bin/sh
# Runs an R script at idle CPU priority so audit probes never compete with
# interactive work on this machine (Windows). Output goes to <log>.
#   sh dev/audit/pit_universe/run_low.sh <script.R> <log> [args...]
script=$1; log=$2; shift 2
powershell -NoProfile -Command "\$p = Start-Process -FilePath 'C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe' -ArgumentList @('$script' $(for a in "$@"; do printf ", '%s'" "$a"; done)) -RedirectStandardOutput '$log' -RedirectStandardError '$log.err' -NoNewWindow -PassThru; \$p.PriorityClass = 'Idle'; \$p.WaitForExit(); exit \$p.ExitCode"
status=$?
cat "$log.err" >> "$log" 2>/dev/null; rm -f "$log.err"
exit $status

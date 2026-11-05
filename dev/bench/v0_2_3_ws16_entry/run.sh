#!/usr/bin/env bash
# WS16 cut-entry record: every probe against the pinned reference build.
#
#   run.sh <installed pinned lib> <pinned source tree> <evidence dir> <scratch dir>
#
# The source tree is `git archive d5b3a151` (load_all compiles it in place);
# the lib is the same commit installed with R CMD INSTALL. Run the timing
# step (fifo_cost.R) on a quiet host: High performance power plan, P-core
# affinity 0xFFFF, no other R process. The private H1 memory shape runs
# separately, from ledgr-research, and records aggregates only.
set -euo pipefail
LIB="$1"; SRC="$2"; EVID="$3"; WORK="$4"
RS="${RSCRIPT:-/c/Program Files/R/R-4.6.1/bin/x64/Rscript.exe}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$EVID" "$WORK"

"$RS" "$HERE/stage_inventory.R" --pkg="$SRC" --out="$EVID"
for source in a0 fill_heavy tests; do
  "$RS" "$HERE/fifo_census.R" --pkg="$SRC" --out="$EVID" --source="$source"
done

for days in 1260 2520 5040; do
  db="$WORK/ws16_mem_500x$days.duckdb"
  [ -f "$db" ] || "$RS" "$HERE/memory_probe.R" --lib="$LIB" --mode=prepare --db="$db" --inst=500 --days="$days"
  for rep in 1 2; do
    "$RS" "$HERE/memory_probe.R" --lib="$LIB" --mode=measure --db="$db" --out="$WORK/mem_500x${days}_$rep"
  done
done
"$RS" "$HERE/summarize.R" --work="$WORK" --out="$EVID"

"$RS" "$HERE/fifo_cost.R" --lib="$LIB" --out="$EVID"

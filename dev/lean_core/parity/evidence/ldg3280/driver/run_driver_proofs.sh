#!/usr/bin/env bash
# LDG-3280: the suite driver's own proofs, written to this directory.
# - smoke: the guard on the candidate (pass);
# - broken_<kind>: the three broken candidates of suite_driver_broken.R
#   (each refused with status 2 before any test runs);
# - witness_silent: the silent break with --witness=1 (recorded, tests run);
# - ltb0519_stock / ltb0519_no_reload: LTB-0519 on the candidate and on the
#   no-reload copy of evidence/ldg3280/ltb0519/no_reload.R.
# Usage: bash run_driver_proofs.sh <pin source archive> <scratch dir>
set -u
R="C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
HERE="$(cd "$(dirname "$0")" && pwd -W)"
PARITY="$HERE/../../.."
PIN="$1"
SCRATCH="$2"
DRV="$PARITY/suite_driver.R"
"$R" "$PARITY/suite_driver_broken.R" --out="$SCRATCH/broken" > "$HERE/broken_write.log" 2>&1
"$R" "$HERE/../ltb0519/no_reload.R" --out="$SCRATCH/no_reload" > "$HERE/no_reload_write.log" 2>&1
"$R" "$DRV" --pin="$PIN" --out="$SCRATCH/smoke" --smoke-only=1 > "$HERE/smoke.log" 2>&1
echo "smoke exit $?" >> "$HERE/exits.txt"
for b in crash reconciled silent; do
  "$R" "$DRV" --pin="$PIN" --lean="$SCRATCH/broken/$b/dev/lean_core" --out="$SCRATCH/broken_$b" > "$HERE/broken_$b.log" 2>&1
  echo "broken_$b exit $?" >> "$HERE/exits.txt"
done
"$R" "$DRV" --pin="$PIN" --lean="$SCRATCH/broken/silent/dev/lean_core" --files=output-handler-sinks --witness=1 --out="$SCRATCH/witness_silent" > "$HERE/witness_silent.log" 2>&1
echo "witness_silent exit $?" >> "$HERE/exits.txt"
"$R" "$DRV" --pin="$PIN" --files=output-handler-sinks --out="$SCRATCH/ltb0519_stock" > "$HERE/ltb0519_stock.log" 2>&1
echo "ltb0519_stock exit $?" >> "$HERE/exits.txt"
"$R" "$DRV" --pin="$PIN" --lean="$SCRATCH/no_reload/dev/lean_core" --files=output-handler-sinks --out="$SCRATCH/ltb0519_no_reload" > "$HERE/ltb0519_no_reload.log" 2>&1
echo "ltb0519_no_reload exit $?" >> "$HERE/exits.txt"
for d in smoke broken_crash broken_reconciled broken_silent witness_silent ltb0519_stock ltb0519_no_reload; do
  mkdir -p "$HERE/$d"
  for f in identity.csv smoke.txt tests.csv summary.txt; do
    [ -f "$SCRATCH/$d/$f" ] && cp "$SCRATCH/$d/$f" "$HERE/$d/$f"
  done
done
echo done >> "$HERE/exits.txt"

#!/bin/sh
# Run from anywhere: sh dev/bench/v0_2_3_lean_tuning_profile/summary_check_refusals.sh
# Demonstrates summary_check.R's refusals (LDG-3225): each fault must exit 1
# with its own message; the clean tree must exit 0. Restores every file with
# git checkout after each case.
cd "$(dirname "$0")/../../.."
R="C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
P=dev/bench/v0_2_3_lean_tuning_profile
D=$P/results/cost_map_cut15
OUT=$P/results/summary_check_refusals.csv
SC=$(mktemp -d)
mkdir -p $SC
echo "case,exit,message" > $OUT
check() {
  msg=$("$R" $P/summary_check.R 2>&1 | grep -Ev "rows checked|LF will|original line" | head -1 | tr -d ',' | sed 's/^ *//')
  "$R" $P/summary_check.R > /dev/null 2>&1
  echo "$1,$?,$msg" >> $OUT
}
check clean
mv $D/rank.csv $SC/rank.csv; check missing_input; mv $SC/rank.csv $D/rank.csv
sed -i '2s/"8edacba437a2e8a13e5ab54bf39c34e8"/"00000000000000000000000000000000"/' $D/clock_raw.csv; check signature_mismatch; git checkout -q -- $D/clock_raw.csv
sed -i '/"lean","20x23400","E advance"/d' $D/cells.csv; check missing_required_cell; git checkout -q -- $D/cells.csv
sed -i '2s/,\([0-9.]*\),"/,99,"/' $D/rank.csv; check stale_rank; git checkout -q -- $D/rank.csv
echo "# stale probe" >> dev/lean_core/loop.R; check stale_lean_source; git checkout -q -- dev/lean_core/loop.R
echo "# harness only" >> dev/lean_core/parity/loop_parity.R; check harness_change_not_stale; git checkout -q -- dev/lean_core/parity/loop_parity.R
check clean_again
cat $OUT
git status --short dev/lean_core $D

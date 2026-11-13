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
sed -i -e '2s/,0.4025,/,0.5025,/' -e '3s/,0.365427631578947,/,0.265427631578947,/' $D/rank.csv; check stale_rank_compensating; git checkout -q -- $D/rank.csv
# Cut 16 (LDG-3229, LDG-3231): historical records are checked against their
# recorded source, so a live lean edit stales only the final Cut 16 rerun (exit 1,
# its message first: Cut 15 and the Cut 16 base pass); a recorded head whose lean sources differ stales a record.
echo "# live edit" >> dev/lean_core/loop.R; check live_edit_stales_only_final; git checkout -q -- dev/lean_core/loop.R
sed -i 's/^head: .*/head: 1a420b31abcdd7c3107fa1d381720f79d8c25ba8/' $D/identity.txt; check stale_recorded_source; git checkout -q -- $D/identity.txt
echo "# harness only" >> dev/lean_core/parity/loop_parity.R; check harness_change_not_stale; git checkout -q -- dev/lean_core/parity/loop_parity.R
# Cut 16 (LDG-3229): the baseline and the slice2_10x7200 pin capture
B=$P/results/cost_map_cut16_base
PC=$P/results/cost_map_cut16_pin
mv $B/rank.csv $SC/rank.csv; check cut16_missing_input; mv $SC/rank.csv $B/rank.csv
mv $PC/reach.csv $SC/reach.csv; check cut16_pin_capture_missing; mv $SC/reach.csv $PC/reach.csv
sed -i '/slice2_10x7200/s/"[0-9a-f]\{32\}"/"00000000000000000000000000000000"/' $B/clock_raw.csv; check cut16_signature_mismatch; git checkout -q -- $B/clock_raw.csv
sed -i '/"lean","slice2_10x7200","P2 risk"/d' $B/cells.csv; check cut16_missing_required_cell; git checkout -q -- $B/cells.csv
sed -i 's/^head: .*/head: 21e89c279a2dedfe8fef33bc79abd698091ad683/' $B/identity.txt; check cut16_stale_recorded_source; git checkout -q -- $B/identity.txt
sed -i '2s/,[0-9.]*,"pin"$/,0,"pin"/' $PC/reach.csv; check cut16_reach_not_established; git checkout -q -- $PC/reach.csv
# Cut 16 final (LDG-3231): the rerun on the closing code
FN=$P/results/cost_map_cut16
mv $FN/cells.csv $SC/cells.csv; check cut16_final_missing_input; mv $SC/cells.csv $FN/cells.csv
sed -i '/"lean","10x7200"/s/"[0-9a-f]\{32\}"/"00000000000000000000000000000000"/' $FN/clock_raw.csv; check cut16_final_signature_mismatch; git checkout -q -- $FN/clock_raw.csv
sed -i '/"lean","slice2_10x7200","P2 sizing"/d' $FN/cells.csv; check cut16_final_missing_required_cell; git checkout -q -- $FN/cells.csv
check clean_again
cat $OUT
git status --short dev/lean_core $D $B $PC $FN

#!/bin/sh
# Overnight WS22 measurement queue (2026-10-09). One measurement at a time;
# a failing step is logged and the queue continues. Vendor rows stay under E:.
set -u
R=/c/Users/maxth/Documents/GitHub/ledgr
B=$R/dev/bench/v0_2_2_real_data_scale
EV=$B/evidence
A=/c/tmp/ws22-a; C=/c/tmp/ws22-b; SP=/c/tmp/ws22-spike
P="/c/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
SN=E:/ledgr-data/sharadar/experiments/LDG-2976/sp500-1998-2026.duckdb
U=sharadar_sp500
E=/e/ledgr-data/sharadar/experiments/LDG-2982
PRE=a87bb7e; FINAL=1df4d3f
mkdir -p "$E"
LOG=$E/overnight.log
say() { echo "$(date '+%F %T') $*" >> "$LOG"; }

say "waiting for clocks batch 2"
while [ ! -f "$EV/clocks/LDG-2988-meta/summary.csv" ]; do sleep 60; done
sleep 120
say "batch 2 done"

# 1. Direct reader checks, pre-cut and final alternating.
git -C $A checkout -q --detach $PRE && git -C $C checkout -q --detach $FINAL
mkdir -p "$EV/reader_check"
for i in 1 2; do
  "$P" "$B/reader_check.R" $A "$EV/reader_check/pre_cut-$i.csv" >> "$LOG" 2>&1 || say "reader_check pre_cut-$i failed"
  "$P" "$B/reader_check.R" $C "$EV/reader_check/final-$i.csv" >> "$LOG" 2>&1 || say "reader_check final-$i failed"
done
say "reader checks done"

# 2. LDG-2992 prerequisite probe on the final tree.
"$P" "$SP/dev/spikes/compiled_availability_accounting/probe.R" $C "E:/ledgr-data/sharadar/experiments/LDG-2992/work" \
  "$SN" $U "$SP/dev/spikes/compiled_availability_accounting/prerequisite.csv" >> "$LOG" 2>&1 || say "spike probe failed"
say "spike probe done"

# 3. LDG-2988 on Sharadar: final minus both LDG-2988 commits against final.
git -C $A checkout -q --detach $FINAL
if git -C $A revert --no-edit $FINAL acc6f58 >> "$LOG" 2>&1; then
  say "measuring commit $(git -C $A rev-parse --short HEAD)"
  "$P" "$B/run_pair.R" $A $C "E:/ledgr-data/sharadar/experiments/LDG-2982/clock_2988" 3 \
    --lane=sharadar --snapshot=$SN --universe=$U --phases=run_equal_weight >> "$LOG" 2>&1 || say "clock_2988 failed"
  mkdir -p "$EV/sharadar_clock_2988"
  cp "$E/clock_2988/summary.csv" "$E/clock_2988/phases.csv" "$EV/sharadar_clock_2988/" 2>/dev/null
else
  say "revert for clock_2988 failed"
  git -C $A revert --abort >> "$LOG" 2>&1
fi
say "clock_2988 done"

# 4. Sharadar pre-cut against final, every phase, one pair.
git -C $A checkout -q --detach $PRE
"$P" "$B/run_pair.R" $A $C "E:/ledgr-data/sharadar/experiments/LDG-2982/sharadar_pair" 1 \
  --lane=sharadar --snapshot=$SN --universe=$U >> "$LOG" 2>&1 || say "sharadar pair failed"
mkdir -p "$EV/sharadar_pair"
cp "$E/sharadar_pair/summary.csv" "$E/sharadar_pair/phases.csv" "$EV/sharadar_pair/" 2>/dev/null
for arm in accepted-1 candidate-1; do
  "$P" "$B/summarize_record.R" "E:/ledgr-data/sharadar/experiments/LDG-2982/sharadar_pair/$arm" "$EV/sharadar_pair/$arm.csv" >> "$LOG" 2>&1
done
"$P" "$B/check_record.R" "E:/ledgr-data/sharadar/experiments/LDG-2982/sharadar_pair/accepted-1" \
  "E:/ledgr-data/sharadar/experiments/LDG-2982/sharadar_pair/candidate-1" > "$EV/sharadar_pair/check.txt" 2>&1
say "sharadar pair done: $(tail -n 1 $EV/sharadar_pair/check.txt)"

# 5. Peer benchmark ledgr rows, pre-cut then final.
for t in pre_cut:$A final:$C; do
  name=${t%%:*}; tree=${t#*:}
  (cd $tree && "$P" dev/bench/peer_benchmark/peer_benchmark.R --preset record --engine-set ledgr-cost \
    --n-inst 500 --n-days 1260 --fast 5 --slow 10 --seed 20260530 \
    --out-dir "E:/ledgr-data/bench/ws22_peer/$name") >> "$LOG" 2>&1 || say "peer $name failed"
done
say "peer rows done; queue complete"

#!/bin/sh
# Runs every registered text mutation of loop_parity.R against the
# workloads that must catch it (loop_checklist.md), debug off and on, and
# writes one CSV per run plus the verdict lines. Each CSV row carries the
# variant's expected signal and every signal that fired.
#
#   sh dev/lean_core/parity/loop_mutations.sh <pinned library> <out dir>
lib="$1"
out="$2"
rscript="/c/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
base="crossover_3x40,tight_cash,reconciliation_stop"
backstops="witness_backstop,witness_backstop_kind,witness_caught_backstop,witness_caught_rethrow,witness_outer_handler,witness_backstop_sweep,witness_caught_backstop_sweep,witness_caught_rethrow_sweep"
run() {
  m="$1"; w="$2"; d="$3"; b="$4"
  "$rscript" dev/lean_core/parity/loop_parity.R --lib="$lib" --debug="$d" --batch-rows="$b" \
    --mutation="$m" --workloads="$w" --out="$out/mutation_${m}_debug${d}.csv" 2>&1 \
    | grep "verdicts" | sed "s/^/debug $d $m: /"
}
for d in 0 1; do
  for m in fill_price_ulp drop_hold hold_position write_in_loop store_execute store_bind store_query store_append \
           hold_in_loop batch_fault fault_before_append; do
    run "$m" "$base" "$d" 8
  done
  # with debug on the per-pulse comparison calls the pin's validator and masks this patch
  [ "$d" = 0 ] && run patch_container witness_state_container "$d" 65536
  run zero_pulse_completion witness_zero_pulses "$d" 65536
  run zero_pulse_align witness_zero_pulses "$d" 65536
  run entry_guard_off witness_walk_forward,witness_checkpoint_control,witness_checkpoint_null "$d" 65536
  run workers_guard_off witness_sweep_workers "$d" 65536
  run backstop_off "$backstops" "$d" 65536
  run rng_restore_off "$backstops" "$d" 65536
  run capacity_late witness_capacity "$d" 65536
  run commit_late witness_prefix_reads,witness_prefix_reads_sweep,witness_state_refusal "$d" 65536
  run expand_whole crossover_3x40,tight_cash "$d" 1
  run expand_extra crossover_3x40,tight_cash "$d" 1
done
# The read-method shortcut is caught by the per-pulse debug comparison only.
run read_fast_path crossover_3x40 1 65536

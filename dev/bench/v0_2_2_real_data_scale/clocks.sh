#!/bin/sh
# Per-ticket paired clocks (Cut 11 Workstream 22).
#
#   sh clocks.sh <accepted_worktree> <candidate_worktree> <out_dir> <pairs> \
#     <ticket>:<predecessor>:<commit>:<phase,phase> ...
#
# For each step, checks the predecessor out in the accepted worktree and the
# ticket commit in the candidate worktree (both clean and precompiled), runs
# run_pair.R on the named phases and keeps its summary.csv and phases.csv.
# Full records are removed; byte identity is ladder.sh's job.
set -u
here=$(cd "$(dirname "$0")" && pwd)
a=$1; b=$2; out=$3; pairs=$4; shift 4
rscript="/c/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
mkdir -p "$out"
for step in "$@"; do
  ticket=$(echo "$step" | cut -d: -f1)
  pred=$(echo "$step" | cut -d: -f2)
  commit=$(echo "$step" | cut -d: -f3)
  phases=$(echo "$step" | cut -d: -f4)
  git -C "$a" checkout -q --detach "$pred" || exit 1
  git -C "$b" checkout -q --detach "$commit" || exit 1
  dir="$out/$ticket"
  "$rscript" "$here/run_pair.R" "$a" "$b" "$dir" "$pairs" "--phases=$phases" > "$out/$ticket.log" 2>&1
  for rec in "$dir"/accepted-* "$dir"/candidate-*; do [ -d "$rec" ] && rm -rf "$rec"; done
  echo "== $ticket $pred..$commit ($phases)"
  cat "$dir/summary.csv"
done

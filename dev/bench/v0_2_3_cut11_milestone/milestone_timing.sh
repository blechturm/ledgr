#!/usr/bin/env bash
# LDG-3209 rule-16 milestone: registered timing protocols, run sequentially
# from the package root. Launch under P-core affinity (children inherit).
set -u
cd /c/Users/maxth/Documents/GitHub/ledgr || exit 1
RS="C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
CAND=cad309f4
SHAPES=fixed_nofill_run,declared_nofill_run,fixed_sparse_run,declared_sparse_run,fixed_wide_run,declared_wide_run
step() {
  echo "$(date +%H:%M:%S) STEP_START $1"
  shift
  "$RS" dev/bench/timing/runner.R "$@"
  local s=$?
  echo "$(date +%H:%M:%S) STEP_END exit=$s"
  if [ $s -ne 0 ]; then echo "MILESTONE_STEP_FAILED"; exit 1; fi
}
step accounting-ldg3200 --protocol=dev/bench/timing/protocols/cut11-accounting-1 \
  --base=0d6c0b11 --candidate=$CAND --label=cut11-milestone-ldg3200
step shapes-v022 --protocol=dev/bench/timing/protocols/ws5-timing-1 \
  --base=7539be45 --candidate=$CAND --label=cut11-milestone-v022 --cells=$SHAPES
step shapes-ldg3200 --protocol=dev/bench/timing/protocols/ws5-timing-1 \
  --base=0d6c0b11 --candidate=$CAND --label=cut11-milestone-ldg3200 --cells=$SHAPES
echo "MILESTONE_TIMING_DONE"

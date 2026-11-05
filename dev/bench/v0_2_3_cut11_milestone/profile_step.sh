#!/usr/bin/env bash
# LDG-3209 milestone profiles: fill-heavy stage profile (the registered
# v0_2_3_fill_heavy_profile probe and classifier) and the quiet 10 x 7,200
# probe, for v0.2.2 (7539be45), LDG-3200 (0d6c0b11) and cad309f4.
set -u
RS="C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
R="C:/Program Files/R/R-4.6.1/bin/x64/R.exe"
LEDGR=C:/Users/maxth/Documents/GitHub/ledgr
FH=$LEDGR/dev/bench/v0_2_3_fill_heavy_profile
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:?usage: profile_step.sh <scratch_out_dir>}"
mkdir -p $OUT/lib-v022 $OUT/src-v022 $OUT/src-0d6c0b11 $OUT/src-cad309f4
if [ ! -d $OUT/lib-v022/ledgr ]; then
  git -C $LEDGR archive --format=tar 7539be45 | tar -xf - -C $OUT/src-v022
  "$R" CMD INSTALL --no-docs --library=$OUT/lib-v022 $OUT/src-v022 > $OUT/install-v022.log 2>&1 || { echo "INSTALL_FAILED"; exit 1; }
fi
git -C $LEDGR archive --format=tar 0d6c0b11 R | tar -xf - -C $OUT/src-0d6c0b11
git -C $LEDGR archive --format=tar cad309f4 R | tar -xf - -C $OUT/src-cad309f4
declare -A LIB=([v022]=$OUT/lib-v022 [ldg3200]=E:/ledgr-data/sharadar/experiments/WS23-private-gate/lib/base [cad309f4]=E:/ledgr-data/sharadar/experiments/WS25-private-gate/lib/candidate-cad309f4)
declare -A VAR=([v022]=old [ldg3200]=new [cad309f4]=new)
declare -A SRC=([v022]=$OUT/src-v022/R [ldg3200]=$OUT/src-0d6c0b11/R [cad309f4]=$OUT/src-cad309f4/R)
[ -f $OUT/fixture.rds ] || "$RS" $FH/fixture.R ${LIB[cad309f4]} $OUT/fixture.rds
for b in v022 ldg3200 cad309f4; do
  echo "$(date +%H:%M:%S) fill-heavy $b"
  "$RS" $FH/probe.R ${LIB[$b]} $b ${VAR[$b]} $OUT/fixture.rds $OUT/fill-$b > $OUT/fill-$b.log 2>&1 || { echo "FILL_FAILED $b"; exit 1; }
  "$RS" $FH/classify.R $OUT/fill-$b/rprof.out ${SRC[$b]} $OUT/fill-$b/classified > $OUT/fill-$b-classify.log 2>&1 || { echo "CLASSIFY_FAILED $b"; exit 1; }
  echo "$(date +%H:%M:%S) quiet $b"
  "$RS" $HERE/quiet_probe.R ${LIB[$b]} $b $OUT/quiet-$b > $OUT/quiet-$b.log 2>&1 || { echo "QUIET_FAILED $b"; exit 1; }
  tail -1 $OUT/quiet-$b.log
done
echo "PROFILES_DONE"

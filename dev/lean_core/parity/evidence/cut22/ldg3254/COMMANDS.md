# LDG-3254 evidence: commands

Cut 22 decision 8, the FIFO census follow-up (Cut 21 F2). `<pin>` is the
pin library `C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151`; `<src>` the pinned
source archive (`git archive d5b3a151` unpacked, with a
`LEDGR_SOURCE_COMMIT` file reading d5b3a151); `<p>` is
`dev/lean_core/parity`; `S = C:/Users/maxth/ledgr-wt/ws41-scratch`. Captures
are large and not committed.

| file | command |
| --- | --- |
| captureA.log, captureB.log | `Rscript <p>/fifo_capture_tests.R --src=<src> --out=$S/fifo/testsA` and, in an independent process, `--out=$S/fifo/testsB` |
| population.log | `Rscript <p>/fifo_population.R --a=$S/fifo/testsA --b=$S/fifo/testsB --out=<p>/evidence/fifo_population.csv` |
| recorder.log | `Rscript dev/lean_core/recorder/run.R --lib=<pin> --captures=$S/fifo/captures --boundaries=lot` |
| fifo_check_before.log | `Rscript <p>/fifo_check.R --lib=<pin> --captures=$S/fifo/captures --tests=$S/fifo/testsA --tests2=$S/fifo/testsB --scratch=$S/fifo/check1` before the committed fifo_parity.csv was replaced |
| fifo_check.log | the same into `$S/fifo/check2` after `$S/fifo/check1/fifo_parity.csv` replaced `<p>/evidence/fifo_parity.csv` |
| population_negative.log | `fifo_population.R` on capture A against copies of capture B with one deterministic call omitted (replaced by a copy of the next) and with one call's key changed, the totals agreeing in both (both refuse) |

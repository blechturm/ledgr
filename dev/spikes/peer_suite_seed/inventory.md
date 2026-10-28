# Peer-suite seed probe inventory

- Runner: `probe.R`; native tables and observed detector behavior are in `evidence/`.
- Checker: `check.R`; reruns into scratch, diffs recorded CSVs, guards tracked package/design scope, then guts the exact-fill detector.
- Gut: `probe.R --gut` makes exact comparisons always succeed. The observations diff must fail; `evidence/check.txt` records the demonstration.
- Learned: the existing equity-level peer classification can remain green after a fill publication mutation. C1 needs a distinct exact native regression oracle.
- Demoted: this 2-by-120 fixture is prerequisite evidence only. It completes neither A0 nor the dense lane and supplies no performance, memory or external-peer claim.
- Deleted: nothing. The existing runner, native execution and tests remain intact.

Run the two scripts with Rscript. They use absolute repository paths. Git metadata requires the normal repository-owner execution context on this Windows host; no Git trust configuration is changed.

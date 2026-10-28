# Peer-suite response probe inventory

- Runner: `probe.R` (about 140 lines). Writes four native fill tables, the
  extra availability fills of the late-opening case, two decision timelines,
  the holdings cross-check and `observations.csv` into `evidence/`.
- Checker: `check.R`; reruns into scratch, diffs every recorded CSV, guards
  tracked package/design scope, then guts the transition-only rule.
- Gut: `probe.R --gut` drops the prior-usable-state requirement, so the
  transition-only timeline equals the first-state timeline. The recorded
  observations (6 differing decisions, first divergence 2020-01-14T21:00Z)
  no longer reproduce; `evidence/check.txt` records the demonstration.
- Learned: dense and availability fills agree by recording pulse at the data
  start and differ by execution stamp (bar time versus session open) and by
  diagnostics volume (0 versus 1,291 rows); a later opening changes fills by
  accepted design; the recipe's first-state entry is a contract choice the
  peers' crossover idioms do not share; ledger events give holdings by asset.
- Demoted: this 12-by-90 fixture is response evidence only. It completes no
  lane, supplies no timing, memory or peer claim and does not stand in for A0.
- Deleted: nothing. No product source, test, existing benchmark or seed probe
  was changed. The existing harness is only sourced for its recipe functions.
- Not probed: no peer environment was installed; peer behaviour is cited from
  official documentation and source in the response, not executed here.

Run both scripts with Rscript. They use absolute repository paths; Git metadata
requires the normal repository-owner execution context on this host.

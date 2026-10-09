# Real-data scale oracle (Cut 11 LDG-2982)

Gate for Workstream 22: every change must leave every result family
byte-identical and must remove the growth shape it targets or improve its
measured clock or peak memory by at least 5 percent.

```sh
# one record of a tree (fixture lane, about 9 minutes before the cut)
Rscript dev/bench/v0_2_2_real_data_scale/run_record.R <repo> <out_dir>
# byte identity between two records, and the checker's own self-test
Rscript dev/bench/v0_2_2_real_data_scale/check_record.R <accepted_dir> <candidate_dir>
Rscript dev/bench/v0_2_2_real_data_scale/check_record.R <record_dir> --self-test
# paired clocks and per-phase peak memory, fresh interleaved processes
Rscript dev/bench/v0_2_2_real_data_scale/run_pair.R <accepted_repo> <candidate_repo> <out_dir> <pairs> [run_record options]
# growth-shape micro-probes for findings F1, F2 and F4 to F13
Rscript dev/bench/v0_2_2_real_data_scale/probes.R <repo> <out_dir> [F1 ...]
```

## Files

- `fixture.R`: the vendor-neutral availability fixture (default 800
  instruments, 1,260 sessions, 300 members in rotating monthly complete sets,
  ten labelled delistings disposed under the research policy, about 0.5
  percent missing member bars, five ordinary cash dividends of which the held
  ones post) and a small dense snapshot; fixed snapshot IDs keep run, sweep and
  walk-forward identities comparable. The LDG-2976 momentum and equal-weight
  strategies.
- `run_record.R`: one tree, the whole public cycle: snapshot build; snapshot
  table digests; refusal and quarantine outcomes; momentum and equal-weight
  runs with equity, returns, fills, trades, ledger, diagnostics, run info,
  completion, metrics, valuation and corporate-action summaries, persisted
  features and strategy state; the active availability plane and
  `ledgr_run_explain()` (momentum); the dense run and its availability
  branch; a three-candidate equal-weight sweep with retained returns and
  trades, in which every candidate holds the dividend payers and posts through
  its own corporate-action state; a promotion; and a contiguous rolling
  walk-forward. Run-specific columns (recording timestamps, timings, versions,
  paths) are dropped; identity hashes go to the informational `identity`
  family. `--lane=sharadar --snapshot=<copy> --universe=<id>` runs the same
  cycle on a private snapshot copy with the LDG-2976 parameters, minus build,
  refusals and the dense run.
- `check_record.R`: per-family byte comparison; a missing family fails; the
  `identity` family is reported, never gated, because ledgr fingerprints
  implementation bodies. `--self-test` perturbs each family alone and
  requires that exactly that family fails.
- `run_pair.R`: paired, interleaved fresh processes, alternating the first
  arm; samples each child's resident memory every 0.25 s and attributes
  elapsed time and peak memory to the logged phases.
- `probes.R`: one growth-shape probe per finding.

## Measurement method (declared before the baseline, 2026-10-09)

- One measurement process at a time; no tests or builds run alongside.
- A failing child is retried once; a second failure stops the pair.
- Noise rule: a registered phase regresses when the candidate/accepted median
  elapsed or peak ratio exceeds 1.05.
- Per ticket: the fixture lane's full family comparison against the
  predecessor commit, and paired clocks (three pairs) on the phases the
  ticket touches; the growth-shape probe for its finding before and after.
- Once, at the start: a pre-cut baseline of every phase (two self-pairs of the
  pre-cut tree, which also measure noise) and the pre-cut Sharadar lane.
- Once, at the end: the final tree against the pre-cut tree on every phase,
  on the fixture (three pairs) and on Sharadar (family hashes and clocks). A
  Sharadar family difference is bisected by ticket. Repeating the multi-hour
  Sharadar lane for every ticket is not practical; per-ticket Sharadar clocks
  run only for the phase a ticket targets.
- Sharadar outputs leave the private store only as family hashes, row counts
  and clocks.

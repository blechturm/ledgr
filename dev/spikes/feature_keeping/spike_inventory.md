# Feature-keeping spike inventory

## Question and record

- `inst/design/spikes/feature_keeping_spike/charter.md`: registered question,
  evidence and terminal rule.
- `probe.R`: smallest public-API prerequisite probe.
- `probe_findings.md`: observed stale-cache and reader-boundary findings.
- `runner.R`: alternating fresh-process timing, correctness, walk-forward and
  Sharadar-shape memory runner.
- `spike_checker.R`: scope guard, record checks, quick rerun and terminal-rule
  verification.
- `inst/design/spikes/feature_keeping_spike/closeout.md`: RED result and
  routing.
- `evidence/probe/runs.csv`: three-run captured-state probe.
- `evidence/probe/feature_reader.txt`: public result-reader refusal.
- `evidence/run/timings.csv`: 18 fresh-process timing arms.
- `evidence/run/correctness.csv`: capture, engine-version and equal-hash cases.
- `evidence/run/walk_forward.csv`: repeated five-fold session.
- `evidence/run/memory.csv`: full 1,166 by 7,213 shape.
- `evidence/run/decision.csv`: recomputed gates and RED verdict.
- `evidence/run/metadata.csv`: base and environment.

No private data, production changes, frozen stores or credential material are
included. Scratch databases and reruns are deliberately excluded.

## Gut

Runner mode `gut` clears the cache before the captured-value warm run. That
removes the stale result while leaving the rest of the harness intact. The
checker rejects it with `Rerun correctness evidence differs from the
registered record`, demonstrating failure sensitivity at the gate that makes
the cache RED.

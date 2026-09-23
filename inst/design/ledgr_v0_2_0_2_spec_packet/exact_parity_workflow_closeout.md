# Cut 4 Closeout: Exact-Parity And Workflow Corrections

**Status:** Accepted after independent Type 1 close review, one corrective
round, and focused re-review.

**Date:** 2026-09-22

**Workstream:** 8, tickets LDG-2792 through LDG-2799 and LDG-2803.

**Authority:** `tickets.yml`, the accepted cut review, and the maintainer's
post-review LDG-2803 amendment.

## What shipped

- The pulse feature path no longer computes discarded alias identity, rebuilds
  one schema per pulse, or uses `match.arg()` for a closed two-value option.
  The last change deliberately narrows an unexported helper: partial values and
  an explicitly forwarded default vector no longer receive `match.arg()`'s
  partial/default selection. Its only production caller omits the argument.
- `ledgr_features_wide()` fills its matrix with integer indices in one write.
- A review-profile source guard proves that identity and hash helpers are not
  reachable from the three feature-bundle pulse entry points.
- Availability timestamps, session rows, and timestamp tokens are prepared
  once after one fail-closed facts assertion. Standalone helpers keep their
  original validation behavior.
- Availability result marks use one bulk bars query, one pivot, and a forward
  valuation walk rather than an instrument-by-pulse prefix-query loop.
- `ledgr_opening()` rejects zero cash where execution already rejected it.
- Zipline output sessions are mapped positionally to source sessions only
  after equal-count validation. Peer parity records retained-row counts and
  fails below a 0.99 floor.

LDG-2795 remains deferred to a maintenance cut. A shared matrix validator must
preserve the return-panel candidate-ID rule, condition fields, and error order;
this workstream did not widen that error-contract surface.

## Exactness and failure sensitivity

`tests/testthat/test-workstream8-exact-parity.R` retains the replaced logic as
an independent oracle where that is the cheapest exact witness. It covers the
populated and null alias paths; schema column type and order; both feature
table modes and invalid input; the three matrix shapes; missing values;
duplicate last-write behavior; five timestamp branches; repeated valid and
malformed timestamps; report, quarantine and snapshot-hash parity; and every
pulse of an availability run with fills.

LDG-2803 authorized changing `R/availability-ingest.R`, so the Stage L and
Stage N whole-file SHA freezes from v0.2.0.1 could not remain meaningful and
were removed rather than updated into new source-shape pins. The testing-
architecture cycle rejected such pins as behavioral oracles. Their surviving
constraint is retained directly: one review block requires the distinct-value
parser and exactly one fail-closed facts assertion in the same complete
validation call. Reintroducing either the row-wise parser or the nested facts
assertion fails that block, so the exact observation optimization did not ship
alone. The two unrelated unused source-hash constants removed with the helper
were already dead.

The recorded mutations are detecting:

- reintroducing `ledgr_alias_map_storage()` makes the source guard fail;
- changing a schema column or accepting a third feature-table value fails;
- replacing `<=` with `<` at the marks cutoff loses the first-pulse price;
- removing the marks query cutoff returns rows beyond a deliberately early
  cutoff and fails the bounded-read witness;
- row-wise timestamp parsing or a nested facts assertion violates the spies;
- retaining only 1,008 of 1,260 peer rows violates the 0.99 floor.

For the source guard, the protected defect is identity work reachable from a
pulse accessor. Its oracle is a parsed namespace call graph, independent of
runtime values. The smallest breaking change is one call to the forbidden
alias-storage helper. Review is the cheapest adequate lane because this is a
source-shape contract, and no other block traverses the three entry points and
checks the forbidden set.

Existing availability tests retain the point-in-time, terminal-event, reopen,
and missing-evidence shapes. The new old-prefix oracle adds per-pulse valuation
parity and a cutoff mutation. Query count changes from about 382,288 per full
read to one.

## Measurements

All component clocks used R 4.6.1 (2026-06-24 ucrt), DuckDB 1.5.2 and
collapse 2.1.8 on Windows. Baseline was the clean detached worktree at
`9cb8c2e692c821cd7fb57831fc81865ffc96b080`; candidate was the uncommitted
Workstream 8 review tree over that base. Raw rows are in
`dev/bench/v0_2_0_2_workstream8/evidence/paired_measurements.csv`.

The reproduction entry point is:

```powershell
Rscript dev/bench/v0_2_0_2_workstream8/measure_workstream8.R `
  <repo-root> <operation> <arm> <repetition> <output.csv>
```

`LEDGR_MEASURE_GIT_SHA` and `LEDGR_MEASURE_DIRTY` bind the measured source.
The normalizer, validation, cold snapshot, sweep and matrix clocks are three
interleaved process-isolated pairs; the deliberately expensive marks read is
one complete pair.

| boundary | before | after | result |
| --- | ---: | ---: | ---: |
| observation timestamps, 426,191 rows | 16.31 s median | 0.04 s median | 408x |
| complete availability validation | 36.58 s median | 10.72 s median | 3.41x |
| cold availability snapshot | 59.56 s median | 32.53 s median | 1.83x |
| registered 12-candidate sweep | 63.07 s median | 23.29 s median | 2.71x |
| availability marks, 757 pulses | 732.70 s | 10.76 s | 68.1x |

The 2.71x sweep result is specific to the measured strategy's
`ctx$features(instrument_id)` authoring idiom, where discarded alias identity
was the dominant cost. A strategy reading `ctx$features_wide` does not enter
that accessor path and receives none of this particular gain.

At the largest matrix shape, 563 by 5, 100 calls measured 66.6 ms median
before and 58.9 ms after. Per-cell time remains flat across 40 by 2, 200 by 5
and 563 by 5. The ingestion clocks are cold, paid when a snapshot is prepared;
they are not presented as warm-run improvements. The earlier 16.19/0.03-second
timestamp probe, 5.83-second duplicate assertion, sister-repository
799.56-second marks read, and promoted peer records were orientation only.

## Peer record

The exact sampled record is the ignored local prefix
`dev/bench/results/peer_benchmark_record_20260923T001439Z`, created with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  dev/bench/v0_2_0_2_workstream8/run_peer_record.ps1
```

It uses 500 instruments, 1,260 sessions, SMA 5/10, seed 20260530, and the
same pinned peer environments as v0.2.0.1. Zipline retained 1,260 of 1,260
rows and recorded daily-return correlation 0.987974. That remains just below
the article's unchanged 0.99 strong-return threshold, so the rendered report
keeps the weak-return review label. The old 0.146064 result remains visible as
the disclosed misaligned historical record. Backtrader retained 1,250 rows,
0.992063, above the floor. LEAN remained unavailable rather than zero-valued.

The complete process tree peaked at 1,753.8 MiB over 892 one-second samples.
The direct preliminary record was rejected by the renderer because it lacked
this sidecar. The sampled harness completed, then its wrapper rejected a null
PowerShell exit-code property after all artifacts were written. The wrapper
now uses the established null-or-zero rule; the dependency sidecar was
generated from the installed packages used by the completed run. The rendered
report is `dev/bench/peer_benchmark/peer_benchmark.md`.

## Verification

- Ordinary fast profile: 438 expected and executed, zero skipped or failed,
  85.280 seconds against the 90-second gate.
- Ordinary review profile: 249 expected and executed, 27 disclosed optional
  dependency skips, zero failed, 373.760 seconds.
- Focused availability, snapshot, opening, parity, peer-boundary and
  hash-deduplication files all pass.
- The Zipline Python adapter compiles; the Quarto report renders from the
  sampled record; `git diff --check` is clean.
- Built-source `R CMD check --no-manual --no-build-vignettes` completed with
  tests and examples green. Its two warnings are the packet's existing
  intentional absence of built `inst/doc` vignette outputs under that command.

## Review gate

The ticket-cut review, Type 1 close review and focused re-review are three
review invocations over eight completed tickets, 0.375, below the 0.5 gate.
The close review found two record-level defects and two observations; all four
were corrected and the focused re-review returned `PASS`. The maintainer
accepted Workstream 8 and Cut 4 on 2026-09-23.

## Declined and deferred work

- `list.files()` in the worker-setup dry run: verify behavior on an installed
  package before changing it.
- The broader feature-accessor family: product and API design question.
- The derived-context spike: parked; no accepted implementation route.
- Primitive session-close comparison alone: its historical candidate missed
  its speed gate; this work retained the scalar parser contract instead.
- Global fact-hash caching: would change the tamper-detection boundary.
- Matrix-validator consolidation: LDG-2795, deferred with its candidate-ID
  and error-order requirements intact.

The maintainer accepted this record and implementation on 2026-09-23.

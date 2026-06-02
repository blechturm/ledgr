# v0.1.8.10 Per-Lane Attribution

This file is the rolling attribution ledger required by the v0.1.8.10
measurement discipline. Rows are appended as lanes reach review. Final release
claims belong in `v0_1_8_10_release_closeout.md`.

## Ledger Template

Each implementation lane should record:

- ticket ID and status;
- change summary;
- verification commands / test files;
- helper or mechanism benchmark, if applicable;
- workload-grid before/after rows;
- peer-benchmark before/after rows, if applicable;
- parity gates and any accepted caveats;
- interpretation, separating within-run subphase evidence from wall-to-wall
  sanity checks.

## LDG-2518: Ephemeral Subphase Telemetry

Status: completed.

Change summary:

- Added sweep telemetry fields `t_engine`, `t_results`, and
  `t_fills_extract`.
- Wrapped `ledgr_execute_fold()` and ephemeral event-materialization /
  reconstruction summary work in `ledgr_sweep_candidate_execute()`.
- Exposed the sweep subphases through workload-grid `engine_sec`,
  `results_sec`, and `fills_extract_sec` columns. The existing durable
  `t_loop_sec` / `t_residual_sec` columns remain intact; durable rows also
  receive the shared phase-column aliases.

Verification:

- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-sweep.R', reporter='summary')"`
- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-sweep-parallel.R', reporter='summary')"`
- Tiny workload-grid sweep probe through `bench_run_sweep_once()` confirmed
  finite `engine_sec`, finite `results_sec`, and `fills_extract_sec = 0`.

Measurement status:

- Large/xlarge ephemeral workload-grid reruns are recorded in the Batch 7
  closeout record `dev/bench/results/ledgr_bench_record_20260602T155628Z_*`.
  The xlarge ephemeral canonical row reports 375.14s wall / 342.25s engine /
  0.00s results and zero failures.

Interpretation:

- This lane is measurement infrastructure. The code should not be interpreted
  as a wall-recovery claim; it makes the ephemeral path phase-visible for the
  subsequent substrate/accounting and compiled-hot-frame decisions.
- `t_fills_extract = 0` on ephemeral sweep rows means no standalone
  fills-extraction subphase ran. Fills materialization for ephemeral sweeps is
  included inside `t_results` through `ledgr_sweep_summary_from_ordered_events()`;
  closeout language must not frame this as "fills extraction is free."
- `engine_sec` is not an identical bracket across persistence modes. Durable
  rows alias the existing internal fold-loop telemetry (`t_loop`) while
  ephemeral rows use a wall-clock bracket around `ledgr_execute_fold()`.
  Cross-mode comparisons are useful but should note the boundary difference.
- The benchmark markdown summary now reports `Engine s` and `Results s` instead
  of the previous single `Loop s` column. This is internal report churn, but any
  local parser of the markdown artifact needs the new column shape.

## LDG-2519: Matrix-Canonical Substrate And Accessors

Status: completed.

Change summary:

- Added an execution-spec `id_to_idx` map and validation for the 1-based
  universe-index contract.
- Converted fold-internal `state$positions` to a primitive numeric vector while
  preserving the public `ctx$positions` named pulse-start snapshot.
- Added `ctx$idx(id, missing = c("error", "na"))`, `ctx$vec` OHLCV/positions
  vector views, and `ctx$vec$feature(feature_id)`.
- Preserved scalar helper contracts and updated `signal_return()` /
  `target_rebalance()` to consume `ctx$vec` internally when available.
- Replaced per-fill next-bar data-frame row extraction with matrix-backed
  scalar lookup while preserving fill-proposal execution-bar context.

Verification:

- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-execution-spec.R', reporter='summary'); testthat::test_file('tests/testthat/test-pulse-context-accessors.R', reporter='summary'); testthat::test_file('tests/testthat/test-fill-model.R', reporter='summary'); testthat::test_file('tests/testthat/test-strategy-reference.R', reporter='summary')"`

Measurement status:

- Large/xlarge workload-grid reruns are recorded in the Batch 7 closeout record
  `dev/bench/results/ledgr_bench_record_20260602T155628Z_*`. The closeout
  interprets this lane as substrate/contract work; wall effects are folded into
  later accounting and B2 measurements.

Interpretation:

- This lane lands the matrix-canonical substrate and accepted accessor RFC
  surface. It should be reviewed as a contract/substrate lane first and a wall
  recovery lane second.
- Public strategy compatibility is intentionally preserved: existing scalar
  helpers remain first-class, and `ctx$positions` remains a named snapshot.
  The primitive representation is internal plus `ctx$vec$positions`.

## LDG-2520: Fold-Owned FIFO Accounting And Inline State Capture

Status: completed.

Change summary:

- Added fold-owned `lot_state` initialized from opening positions/cost basis or
  reconstructed from prior events on resume.
- Applied FIFO lot accounting immediately after fill resolution and before
  output-handler accounting fact emission.
- Preserved materialized event rows and `meta_json` identity; inline
  accounting is emitted through typed memory-handler facts.
- Added memory-handler inline equity and fill facts so fresh ephemeral sweep
  summaries can use fold-owned accounting without the reconstruction pass.
- Kept durable extraction, reconstruction, and readback compatible as verifier
  and fallback paths.

Verification:

- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-sweep.R', reporter='summary')"`
- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-fifo-opening-positions.R', reporter='summary'); testthat::test_file('tests/testthat/test-fifo-torture.R', reporter='summary'); testthat::test_file('tests/testthat/test-sweep-parity.R', reporter='summary'); testthat::test_file('tests/testthat/test-backtest-wrapper.R', reporter='summary')"`
- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-ledger-writer.R', reporter='summary'); testthat::test_file('tests/testthat/test-derived-state.R', reporter='summary'); testthat::test_file('tests/testthat/test-release-coverage-branches.R', reporter='summary')"`

Measurement status:

- Large/xlarge durable and ephemeral workload-grid reruns are recorded in the
  Batch 7 closeout record
  `dev/bench/results/ledgr_bench_record_20260602T155628Z_*`. The canonical R
  xlarge durable row records the expected engine increase from moving FIFO work
  into the fold; the xlarge ephemeral row records the fresh-summary bypass with
  results near zero.

Interpretation:

- This lane is an accounting-ownership substrate lane first. Event rows remain
  canonical; inline accounting facts are a fresh-sweep acceleration surface and
  are not a replacement for durable reconstruction/readback.
- The memory summary bypass is gated by parity tests against reconstruction.
  Closeout language must report both any `t_results` movement and any `t_engine`
  increase from moving FIFO work into the fold.

## LDG-2521: yyjsonr Options Hoist

Status: completed.

Change summary:

- Hoisted fixed `yyjsonr::opts_read_json()` objects for nested and config read
  helpers.
- Hoisted the fixed `yyjsonr::opts_write_json()` object for canonical JSON v2
  writes.
- Preserved helper signatures, canonical byte-format v2, and read-shape
  behavior.

Verification:

- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-canonical-json-byte-format.R', reporter='summary'); testthat::test_file('tests/testthat/test-config.R', reporter='summary'); testthat::test_file('tests/testthat/test-fingerprint-stability.R', reporter='summary'); testthat::test_file('tests/testthat/test-ledger-writer.R', reporter='summary')"`

Helper benchmark:

- Shape: 50k flat event `meta_json` payloads matching the Spike 7 production
  metadata fixture.
- Old inline `opts_read_json()` construction: 1.100s median, 22.00 us/payload.
- New hoisted `ledgr_json_read_nested()` helper: 0.120s median,
  2.40 us/payload.
- Recovery: 9.17x.

Measurement status:

- This lane does not claim fresh-fold wall recovery. The measured recovery is
  for JSON read/reopen/replay helper surfaces that still parse persisted
  metadata.

Interpretation:

- Batch 4 closes the LDG-2501 yyjsonr read-path caveat by removing avoidable
  options-construction overhead. The canonical JSON v2 migration remains in
  place; this is a helper implementation fix, not an identity-format change.

## LDG-2522: Compiled Hot Frame B2 Gate

Status: completed.

Scope guard:

- Record the Sub-A `ledgrcore-spike` verdict as feasibility evidence for a
  spot-asset FIFO fill-batch accelerator, not as a production wall claim.
- Sub-B attribution must name the ledgr gate as
  `compiled_accounting_model = "spot_fifo"` and keep `NULL` as the canonical R
  fold baseline.
- Unsupported accounting models must be treated as fail-closed scope guards, not
  as auto-routed fallbacks.
- Report wall recovery, parity outcome, build flags, and disposition with
  "spot-asset FIFO" / "spot-FIFO" language. Do not summarize the lane as a
  general compiled fold core, derivatives-capable engine, or public compiled
  execution mode.

Implementation:

- Added `cpp11` as the package-local compiled bridge and registered one
  internal spot-FIFO batch kernel. The kernel is reached only through the
  existing fold execution path when the unexported execution spec carries
  `compiled_accounting_model = "spot_fifo"`.
- Kept public defaults on the canonical R path: default and explicit `NULL`
  both route through the R fold. Unsupported model values such as
  `"futures_margin"` fail closed with `ledgr_unsupported_accounting_model`.
- The compiled hot frame owns only post-resolution spot BUY/SELL FIFO batch
  work: lot-state transition, cash/positions mutation, event-row value
  construction, typed event accumulation, and inline fill rows. R still owns
  strategy execution, ctx construction, target validation, target risk,
  next-open proposal, cost resolution, features, equity facts, metrics, durable
  persistence, and replay.
- Added a dev-benchmark-only `--compiled-accounting-model NULL|spot_fifo`
  switch to `dev/bench/shared/run_benchmarks.R`; it sets the internal model
  option consumed by sweep candidate construction and does not add a public
  `ledgr_sweep()` argument.

Parity and verification:

- `tests/testthat/test-execution-spec.R` covers the enum default, explicit
  `NULL`, `"spot_fifo"`, unsupported-model failure, live-mode dispatch failure,
  missing-handler dispatch failure,
  and direct compiled-vs-R fold parity across opening-position/CASHFLOW,
  long-to-short, and short-to-long FIFO transitions.
- `tests/testthat/test-execution-spec.R` also covers multi-instrument same-pulse
  batch parity so the compiled path is not validated only on a one-instrument
  fixture.
- `tests/testthat/test-sweep.R` covers production `ledgr_sweep()` dispatch via
  the internal model option on a small FIFO fixture and confirms scoped option
  restoration returns the sweep to canonical R semantics.
- Targeted tests passed:
  `testthat::test_file('tests/testthat/test-execution-spec.R')` and
  `testthat::test_file('tests/testthat/test-sweep.R')`.
- Full local suite passed:
  `testthat::test_local('.', reporter='summary')`; one expected Yahoo adapter
  skip remained.

Sub-A handoff:

- The sister `ledgrcore-spike` repo reported Stage 6 committed at `a4a87e1`.
  Verdict: B2 Sub-A succeeds; handoff to ledgr LDG-2522 proceeds with caveats.
  C++ cpp11 is the recommended Sub-A language on measured speed and R-package
  integration. Rust extendr remains a viable alternate. Windows C++ timing used
  LTO with effective optimization potentially `-O2`, not proven `-O3`.

Sub-B record-cell measurement:

The measured production cell is the workload-grid
`density_high_xlarge_ephemeral` scenario from the record preset:
1000 instruments, 1260 pulses, 2 SMA features, 1 sweep candidate, high-density
SMA 5/10 crossover strategy, ephemeral persistence. This current-source
production scenario produced 66,280 fills in both the canonical R and
`"spot_fifo"` runs. The larger ~130k-fill counts cited in some spike fixtures
are synthetic/stress-shape references, not this production record-cell fill
count.

| Run | Record | Model | Wall s | Engine s | Results s | Fills | Engine us/fill | Failures |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Canonical R | `dev/bench/results/ledgr_bench_record_20260602T134744Z_summary.csv` | `NULL` | 327.02 | 293.94 | 0.01 | 66,280 | 4434.82 | 0 |
| Pattern B spot-FIFO | `dev/bench/results/ledgr_bench_record_20260602T134953Z_summary.csv` | `"spot_fifo"` | 65.86 | 32.92 | 0.02 | 66,280 | 496.68 | 0 |

Outcome:

- Wall recovery: 261.16s, above the 30s pass threshold.
- Engine recovery: 261.02s; engine cost fell from 4434.82 to
  496.68 us/fill (-88.8%).
- Both record passes report zero failures and the same 66,280 fill count.
- Local compiled artifacts are ignored by `.gitignore` / `.Rbuildignore` and
  are not part of the commit set; the committed compiled surface is source-only.
- Disposition: pass for the scoped internal spot-asset FIFO fill-batch
  accelerator gate. This does not authorize a public compiled execution path,
  durable compiled integration, derivatives/margin/options accounting, or a
  general compiled fold core.

## LDG-2523: Parked Spike Disposition

Status: completed.

Change summary:

- Reviewed the four parked v0.1.8.10 spike outputs after the main lanes landed:
  split/gsplit reconstruction bucket, reusable pulse-context env, pulse-seed
  mixer, and alias-map normalization.
- Landed no code. Each parked item remains below the current implementation
  threshold, is covered by an already-landed v0.1.8.10 substrate surface, or is
  routed to a future profile-driven window.
- Promoted `LDG-2522` to completed after the approved Batch 5 review and commit.

Disposition table:

| Spike | Source evidence | Post-main-lane read | Disposition |
| --- | --- | --- | --- |
| Spike 2: split/gsplit reconstruction bucket | Current `which()` bucket loop measured 0.36s at 1000 instruments / 130k synthetic events; `collapse::gsplit()` was 18x faster but recovers only about 0.34s. | `LDG-2520` keeps reconstruction as verifier/fallback and fresh ephemeral summaries use fold-owned inline facts; `LDG-2522` then shifts the dominant fresh xlarge ephemeral recovery into the spot-FIFO hot frame. The bucket loop is not a current release-scale wall lever. | Park as fallback-only cleanup. If a future durable/replay/reconstruction profile shows the reconstruction path hot again, use the Spike 2 `collapse::gsplit()` variant as a small B1/collapse-doctrine cleanup. |
| Spike 4: reusable pulse-context env | Bare fresh-list allocation measured about 6 us/pulse, under timer floor at the production pulse count. The spike identified helper attachment, not list allocation, as the plausible production cost surface. | `LDG-2519` already landed the accepted public-list / internal-fast-context accessor shape. Replacing the public ctx list with a reusable env would reopen snapshot/class semantics for no measured wall recovery. | Park reusable-env implementation. Route any future work to helper-attachment profiling, not env reuse. The existing horizon ephemeral-attribution entry already names ctx construction with helper attachment as a candidate sub-frame. |
| Spike 8: pulse-seed mixer | Production SHA-256 + canonical JSON pulse seed derivation measured 0.14s at 1260 pulses and 0.57s at 5000 pulses. Faster mixers need overflow-safe `bit64` or C implementation to preserve cross-platform determinism. | No post-main-lane profile made per-pulse seed derivation material. The `LDG-2522` xlarge ephemeral gain is fill-accounting dominated, not pulse-seed dominated. | Park for v0.1.8.10. Revisit only if a future per-pulse attribution shows seed derivation above threshold; any production mixer needs explicit determinism parity across platforms. |
| Spike 9: alias-map normalization | Fold entry already normalizes `active_alias_map` once. The expensive shape is legacy `ctx$features()` re-normalizing per accessor call; the synthetic microbench worst case measured 5.43s at 1.26M per-instrument calls. | `LDG-2519` landed `ctx$vec$feature(feature_id)`, which collapses the hot cross-sectional read pattern to one vector read per feature and removes the per-instrument legacy call shape. The landed vector accessor takes engine feature IDs; alias-map vector interactions and bulk multi-feature reads remain future feature-engine extension work. | No standalone alias-normalization cleanup. Treat the hot cross-sectional case as resolved by `ctx$vec$feature(feature_id)`; keep legacy `ctx$features()` behavior for scalar/bundled alias access; route alias-map vector interactions to the existing future feature-engine vector-extension horizon. |

Verification:

- Source review:
  `dev/spikes/spike-reconstruction-split-bucket.md`,
  `dev/spikes/spike-pulse-context-env-reuse.md`,
  `dev/spikes/spike-pulse-seed-mixer.md`, and
  `dev/spikes/spike-alias-map-normalize.md`.
- Current code spot-checks:
  `R/fold-engine.R` normalizes the active alias map once at fold entry;
  `R/pulse-context.R` attaches `ctx$vec` through the pulse lookup refresh;
  `R/runtime-projection.R` implements the vector feature accessor over engine
  feature IDs.
- Existing horizon routing:
  the ephemeral wall attribution entry already names ctx helper attachment,
  feature engine / alias-map resolution, reconstruction residuals, and
  pulse-seed derivation as candidate future sub-frames; the strategy-helper
  horizon queue names alias-map vector interactions as a future feature-engine
  RFC surface.

Measurement status:

- No cleanup landed, so no targeted tests or new benchmark row are required for
  `LDG-2523`. The verification artifact is this post-main-lane disposition
  review.

Interpretation:

- Batch 6 is release-hygiene work. It prevents the small v0.1.8.10 spike
  findings from being lost before closeout, while avoiding sub-threshold code
  churn after the main lanes materially changed the wall profile.
- The alias-map disposition should be worded carefully in closeout: vector
  feature reads cover the hot cross-sectional pattern, but legacy
  `ctx$features()` alias-bundle semantics remain intentionally supported and
  are not replaced by this batch.

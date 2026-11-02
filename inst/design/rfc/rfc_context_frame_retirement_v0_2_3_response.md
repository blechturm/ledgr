# RFC Response: Context Frame Retirement

- Status: Type 2 response v1; response review is next
- Author: Claude (not the seed author)
- Date: 2026-11-03
- Mode: Type 2, per the maintainer brief
- Seed reviewed: `rfc_context_frame_retirement_v0_2_3_seed.md` v1 (uncommitted)
- Baseline reviewed: `e3bb4cec` (`release/v0.2.3`)
- Budget: `spike_protocol.md` Section 4, 300 lines

## 1. Disposition

**ACCEPT_WITH_CHANGES.** Retiring `ctx$bars`, `ctx$feature_table`,
`ctx$features_wide` and `ctx$bar(id)` without aliases is still the right
problem. Flat named columns stay the only strategy read surface. There is no
frame DSL, no successor to `features_wide`, and no hashing in helpers. All of
that survives.

Four parts do not survive as written. The one new export,
`ledgr_pulse_bars()`, is not shown to be necessary (F1). Three behaviours the
seed calls unchanged would change: the inspection helpers' alias source, row
order and empty-axis result (F3 to F5). The seed lets callbacks use helpers
that today cost up to 0.9 s per call at 600 instruments (F2). The migration
would rewrite registered fixture setup and a frozen oracle without need (F9,
F10). Each correction removes something or names a change; none adds
architecture.
The synthesis can absorb this response once the maintainer settles Section 6.
A seed v2 is optional.

## 2. What was executed

A response probe ran on the current tree: R 4.6.1, collapse 2.1.8, Windows,
`pkgload::load_all(compile = FALSE)`, one host, one session. It is not in the
repository (Section 7). Timings are descriptive; none is a gate under
macro-plan rule 16.

| Id | Fixture and check | Result |
| --- | --- | --- |
| E0 | Old probe's dependencies | `ledgr_bars_pulse_views()` and `ledgr_projection_pulse_views()` no longer exist; `probe.R:56-57` cannot run. |
| E1 | Declared-session run: AAA, BBB members; OLD held, leaves membership on day 4; BBB has no bar on day 6. Callback at day 6. | Daxis `AAA,BBB,OLD`; `member` `T,T,F`. BBB's OHLCV are `NA`, its `gap_type` is `MISSING_EXPECTED_SESSION`, and `gap_type == MISSING` equals `is.na(ctx$close)` exactly. `is_synthetic` is all `FALSE`. `features_wide` is keyed by engine IDs (`return_1`, `sma_2`) and its `ts_utc` is text, not POSIXct. |
| E2 | `ledgr_pulse_features()` inside that callback | Engine IDs with `alias = NA`, although the prepared resolver holds `ret = return_1, sma = sma_2`. Runtime contexts store no `active_alias_map`. |
| E3 | The saved day-6 context, re-inspected after the run | Long-feature, wide and `bars` outputs are `identical()` to their in-callback values. |
| E4 | `ledgr_pulse_snapshot(exp, ts_utc = day 1)` against the day-1 callback | Equal helper results and identical `bars`; no alias map stored here either. |
| E5 | Snapshot-and-universe form, universe `c("BBB","AAA")` | Universe order is kept; rows are aliased (`ret`, `sma`); `names(pulse)` adds `feature_params`, `active_alias_map`, `alias_map_json`, `alias_map_hash`, `alias_map_version`. A gapped bar-native snapshot refuses with `LEDGR_SNAPSHOT_COVERAGE_ERROR`. |
| E6 | Real runtime context at an empty-membership session | `bars` and `features_wide` are typed zero-row frames. With no map both helpers return; with a map both refuse with `ledgr_unknown_feature_id`. Contexts built by the internal constructor fail both helpers with `ledgr_unknown_context_field`. |
| E7 | Bar-native run, 600 instruments, 60 sessions, three return features; P2 inputs captured at pulse 40 | Medians: current P2 frame block 411 µs; binding the P1 data columns 1.8 µs; on-demand bars through public `$` 474 µs, of which one `ledgr_utc(ctx$ts_utc)` is 231 µs; a three-feature flat matrix 165 µs. Single calls: `ledgr_pulse_features()` 0.22 s (active map), 0.06 s (one-feature explicit map); `ledgr_pulse_wide()` 0.91 s. |

## 3. Necessity: is retirement still the right problem?

Yes, and the current tree gives a stronger reason than the 2026-10-04 one.

- **Two representations, two vocabularies.** D1 makes aliases the feature
  column names, but `features_wide` keys by engine ID and carries `ts_utc` as
  text while `bars` carries POSIXct (E1). That is drift, not just
  duplication.
- **P2 pays for frames strategies do not read.** P2 builds `bars` with base
  `data.frame()` (`R/history-substrate.R:492-515`) and builds the wide frame
  over the whole run axis before subsetting it with `%in%`
  (`R/fold-engine.R:773-795`). At 600 by 3 that is 411 µs per decision pulse
  against 1.8 µs for binding columns (E7). The seed's "about 41 µs, 0.2
  percent of a run" measured a prebuilt-view P2 that no longer exists.
- **No taught consumer.** The census holds for vignettes; every `$bars` hit
  there is `pit$bars`.

The smallest coherent design is the seed's minus F1.

## 4. Findings

### F1. `ledgr_pulse_bars()` is not shown to be necessary. Disposition: REJECT as proposed; decision M1

Every column of the proposed frame is a flat column, `ctx$universe`, the
repeated cutoff, or one of two flags that add nothing. `is_synthetic` is the
constant `FALSE` (`R/history-substrate.R:511`). `gap_type` equals
`is.na(ctx$close)` (E1), and not only in this fixture: every stored price is
positive (Bar Validation, `contracts.md:928-935`), and bar-native substrates
require complete coverage, so `gap_type` is always `NONE` there
(`R/history-substrate.R:103-105`; E5).

The label is also not honest. `gap_type` is derived from `observed` alone and
never consults the expected-session mask that history reads resolve
(`contracts.md:2275-2281`); history evidence has a separate
`missing_reason = not_expected`. Retaining `observed` privately reproduces
today's bytes, but the frame would still call every unobserved cell
MISSING_EXPECTED_SESSION, including cells the history vocabulary would call
not expected. Frozen holdings stay on the axis (`contracts.md:2447-2452`).
The derivation is verified by reading the code; whether a terminal or
lifetime-inactive cell reaches a pulse context was not executed.

No consumer is lost. The test reads are one-line flat reads, for example
`ctx$bars$close[[1]]` becomes `ctx$close[[1]]`
(`test-backtest-audit-log-equivalence.R:25`, `test-integration-full.R:45`).
`ledgr_pulse_wide()` already shows every instrument's OHLCV for inspection.
Recommendation: no bars helper; teach `is.na(ctx$close)` as "no bar at this
session". M1(b) covers a frame if the maintainer wants one.

### F2. The existing helpers are inspection-grade, not callback-grade. Disposition: CHANGE

At 600 by 3, `ledgr_pulse_features()` takes 0.22 s per call and
`ledgr_pulse_wide()` 0.91 s (E7): about 5 and 19 minutes if called on every
pulse of a 1,260-session run. The causes are a nested instrument-by-feature
loop with `which()` row slices and `rbind` (`R/feature-inspection.R:485-506`;
manual shapes 1 and 2) and one tibble column assignment per instrument and
field (`:572-606`). The wide helper's one-row layout with radix-ordered
instrument blocks (`:562`) is not a decision surface at all.

Seed Section 7's shape rule is accepted and must bind: allocate once, no row
loop, no `rbind`, no growth. Over flat columns the long frame is `rep()` plus
one constructor call, so the rebuild is mechanical.

What should not bind is a callback-use promise. The Section 11 "Strategy
Preflight" row is a no-op, because exported ledgr helpers are already Tier 1
(`R/strategy-preflight.R:7-8`). The contract should instead say that the
helpers accept any pulse context, including one a callback saved, under F7's
cutoff, axis and freezing guarantees; that they are inspection boundaries
with no decision-time cost promise; and that strategies read flat columns.
This keeps the existing "read-only inspection views" wording
(`contracts.md:2463-2466`). See M2.

### F3. The alias source changes; the seed calls it unchanged. Disposition: CHANGE (mechanical)

Today the helpers alias only when the context stores `active_alias_map`
(`R/feature-inspection.R:437-446`), and only the snapshot-and-universe form
stores it (`R/pulse-snapshot.R:260`). Runtime and experiment-form contexts
therefore return engine IDs with `alias = NA` (E2, E4) while their own
resolver holds the map. That contradicts feature-map synthesis D4 ("When a
feature map applies ... aliases").

Rebasing on the prepared resolver, as seed Section 7 proposes, fixes this,
but it visibly changes two of the three ways to obtain a context and must be
named as a change. Bind the resolver as the single alias source and delete
the stored route (`R/pulse-snapshot.R:259-263`). That route computes a
SHA-256 `alias_map_hash` whenever a snapshot-form pulse is built
(`R/pulse-snapshot.R:183`, via `R/feature-alias-map.R:137`). No reader uses
it, and it adds five metadata names to `names(pulse)` (E5), against the
strategy-context synthesis Section 7 rule that interactive-only metadata must
not look like a runtime field. Deleting it also removes the only hashing on
the inspection path.

### F4. Row order changes for unmapped output. Disposition: CHANGE (mechanical)

Unmapped long rows are radix-ordered by instrument
(`R/feature-inspection.R:357-362`); mapped rows follow axis order (`:487-498`).
Accept the seed's axis order for both and name the unmapped-path change.

### F5. An empty axis with a map refuses today. Disposition: CHANGE (mechanical)

On a real empty-membership pulse both helpers refuse a map with
`ledgr_unknown_feature_id` (E6). Requested IDs are checked against the rows
present (`R/feature-inspection.R:449-476`), behind an explicit empty-universe
abort (`:477-483`). The seed promises typed empty results and unchanged
unknown-ID rules; both cannot hold. Validate the map against the resolver's
registered features, the lookup that serves flat reads, then manifest the
typed empty result. Name this as a refusal becoming a result.

### F6. P2 can stop building frames without moving the work. Disposition: ACCEPT Section 9, with one correction

Today the bars frame carries the flat OHLCV columns: the P2 lookup stores
`bars_current` with `bars_aligned = TRUE` and `ctx$close` reads from it
(`R/pulse-context.R:587`, `:687-693`; `R/fold-engine.R:815-835`). "Stop
building bars" therefore means binding the P1 data-packet columns instead.
Those are fresh gathers (`R/fold-engine.R:605-611`), frozen by value
semantics, and binding them costs 1.8 µs against 411 µs (E7). Removing the
wide frame and the long-table schema is pure deletion, because feature columns
already come from the projection accessor (`R/pulse-context.R:407-412`,
`:520-524`). Under M1(a), `observed` need not be retained at all.

### F7. Axis, cutoff and freezing are preserved. Disposition: ACCEPT Sections 8-9, with one correction

A saved context's helper outputs survive the rest of the run unchanged (E3).
Feature reads index prepared read-only matrices and then restrict to the
context's axis (`R/runtime-projection.R:367-374`; `R/pulse-context.R:520-523`).
A helper that takes only a context cannot widen the axis or move the cutoff.
Correction: keep a numeric cutoff in the private lookup. Re-parsing
`ctx$ts_utc` costs 231 µs per call (E7), against the manual's "keep
timestamps as timestamps".

### F8. The old probe no longer measures the current tree. Disposition: CHANGE Section 3

The probe cannot run (E0); the P2 it measured is gone and its fixture stored
`gap_type` directly. Keep it as history and cite E7 or a cut-time re-run. The
structural gate (no frame unless a helper is called) remains right.

### F9. The test-fixture seam. Disposition: CHANGE

The internal constructor is called 35 times in 9 test files, and every call
supplies `bars`, because the argument has no default (`R/pulse-context.R:1-4`).
`ledgr_update_pulse_context_helpers()` is called directly at 13 sites in 6
files. These are mostly fixture inputs for strategy-helper semantics, not
assertions about frames. Dropping frame input from the constructor (seed
Section 5) rewrites registered test setup, which AGENTS.md allows only with a
stated reason per test.

The smaller change keeps a long bar and feature frame as constructor *input*,
normalized once into aligned columns and never stored: input format and
context field are different things. While there, vectorize the validator's
per-row timestamp normalization (`R/pulse-context.R:920`, shape 3). Helper
tests must use real contexts, as seed Section 12 item 2 already does:
constructor-made contexts cannot run the helpers today, because strict `$`
refuses the missing `.feature_table_current` (E6;
`R/feature-inspection.R:396`).

### F10. The benchmark recipe and the frozen oracle. Disposition: CHANGE

The shared recipe reads `features_wide` three times
(`dev/bench/shared/run_benchmarks.R:278`, `:300`, `:503`); the seed's fourth
read is `dev/bench/archive/peer_three_way.R:62`. The frozen peer oracle
records the old strategy source
(`dev/bench/peer_benchmark/dense/oracles/20261030-pre-ws4/*/run_provenance.csv`).
Do not re-record it. Compare targets, fills and results, and name strategy
and config source identity as the only exclusions (the manual's identity
boundary rule).

The flat migration costs 165 µs for three features (E7), but it exposes a cost
the seed does not list. Every `$` read recomputes the run-constant set of
feature names twice (`R/pulse-context.R:69-75`, called at `:152` and
`:175-176`): O(features) per read, quadratic per pulse for a wide recipe.
This is a compute-at-frequency-of-change finding, not WS6 semantics; route it
to the cut or the holistic core review.

### F11. No successor to `features_wide`. Disposition: ACCEPT

A cross-sectional instrument-by-feature matrix is one `vapply()` over the
declared names (E7); multi-period panels belong to history; feature-map
synthesis D2 already rejected bulk multi-feature reads. Add one line to the
context reference teaching that idiom, which `predict()` and the benchmark
need, as an idiom rather than an API.

### F12. Trust boundary and mechanical corrections. Disposition: ACCEPT Section 8; CHANGE as listed

Helpers neither hash nor seal; F3 removes the inspection path's only hash.

- Preflight: drop `.feature_table_current` from the private and carrier lists
  (`R/strategy-preflight.R:397`, `:410`); no contract row is needed.
- `print()` uses `nrow(x$bars)` (`R/pulse-snapshot.R:298`); use
  `length(x$universe)`.
- The error wrapper takes feature names from `features_wide` engine IDs
  (`R/backtest-runner.R:16-29`); reuse the resolver's prebuilt
  `available_message` (`R/runtime-projection.R:400-403`).
- `ledgr_features_wide()` (`R/pulse-context.R:342-378`, per-row timestamp
  formatting) and the uncalled `ledgr_feature_accessor()` and
  `ledgr_feature_bundle_accessor()` (`:224-309`) go with the fields.
- Seed Section 12 item 3 ("a carried price never changes `is_synthetic`") is
  vacuous, because current-pulse columns never carry (E1). Drop it.
- The cut's census must not count `ctx$bars_since_entry` or
  `ctx$bars_since_exit`, which a plain `ctx$bars` pattern also matches.
- Keeping the four names reserved follows the Cut 7 precedent
  (`ledgr_pulse_context_retired_fields()`, `R/pulse-context.R:47-49`) and is
  accepted.

## 5. What survives, what changes, what is rejected

| Seed item | Outcome |
| --- | --- |
| Retire the four fields without aliases; keep the names reserved | Survives. |
| Flat columns as the sole strategy surface; no DSL, cache or `features_wide` successor | Survives (F11). |
| `ledgr_pulse_bars()` | Rejected as proposed; M1. |
| Feature and wide helpers rebased on the frozen flat context, with no row loops | Survives, with the alias, order and empty-axis changes named (F3 to F5). |
| Callback use as a supported path; the Section 11 preflight row | Changed (F2); M2. |
| P2 binds primitives; trust boundary; frozen carrier | Survives, with a numeric cutoff (F6, F7, F12). |
| Constructor drops frame input; peer source re-recorded | Changed (F9, F10). |
| Section 3 timing figures | Replaced by E7 or a cut-time re-run (F8). |
| Section 11 rows | Keep the four group amendments with F2 to F5 wording; delete the Strategy Preflight row. |

Seed Section 12 changes to match. Item 2 includes F3's alias change. Add
`names()` parity across runtime, experiment-form and snapshot-form contexts
once F3's metadata is gone, plus the empty-axis mapped result (F5) and axis
row order (F4). Drop item 3, and drop the bar items under M1(a).

## 6. Maintainer decisions

**M1. Does ledgr add a current-pulse bars helper?** Example: at a session
where BBB has no bar, a user wants to see the day's bars.

(a) No helper (recommended): they read `ctx$close` and see BBB as `NA`;
`gap_type` and `is_synthetic` leave the public surface. (b) An
inspection-only helper with `instrument_id`, `ts_utc`, OHLCV and `observed`,
without the constant flag or the misleading label; one new export. (c) The
seed's helper, byte-identical to today's `ctx$bars`.

**M2. Do `ledgr_pulse_features()` and `ledgr_pulse_wide()` get a
decision-time promise?** Example: a strategy calls `ledgr_pulse_wide(ctx)`
every day on 600 stocks. That is 0.9 s per call today, faster after the
rebuild, and slower than reading flat columns either way.

(a) No (recommended): inspection boundaries, usable on any context including
a saved one, with no cost promise. (b) Yes: their cost becomes a contract
surface with its own evidence.

Everything else in Section 4 is a mechanical correction or a change that an
accepted decision (D1, feature-map D4) already implies.

## 7. Left to the ticket cut and next stage

The cut keeps seed Section 14's ticket grain, carrier names and peer-ticket
choice, and decides whether F10's read-name recomputation is fixed here or in
the core review. The response probe lives outside the tree and reproduces from
the repository root at `e3bb4cec` with the E1 to E7 fixtures; it can be added
under `dev/spikes/ctx_frame_views/` in a separate commit if the maintainer
wants it as durable evidence. Next stage: response review. No synthesis,
ticket cut or implementation starts from this response.

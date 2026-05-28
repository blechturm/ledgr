# RFC Seed: Feature Projection Shape, Materialization Policy, And Lookback Access

**Status:** Design seed - response required before synthesis or ticket cut.
**Date:** 2026-05-28
**Author:** Claude
**Inputs:**

- QuantConnect, "10x Speed-Up On Fundamental Data"
  (`https://www.quantconnect.com/announcements/16151/10x-speed-up-on-fundamental-data/p1`)
  - the external benchmark that motivated the spike. On a 5,000-equity x
    50-field fundamental universe (Piotroski F-Score), QC went 4K -> 76K DPS
    ("up to 75% faster than zipline", 40min -> 4:20) by switching ZIP-JSON ->
    Parquet, loading only the 50 needed fields of 4,900, and right-sizing
    column types. The win was in DATA LOADING, not the strategy loop.
- `dev/spikes/spike-feature-payload-dps.R`
  - v0.1.8.5 high-dimensional feature-payload throughput/memory spike
    (500 instruments x 2520 pulses x 50 features) that triggered this RFC.
- `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`
  - accepted LDG-2413 consolidation; named the "accreted multiple
    representations" problem and moved per-pulse view construction to setup.
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
  - wide runtime view lineage; grid-union sharing (shipped v0.1.8.4).
- `inst/design/rfc/rfc_collapse_primitive_internals_v0_1_9.md`
  - primitive-internals discipline; collapse acceleration; the deterministic
    `set_collapse()` wrapper this RFC depends on for any collapse-backed path.
- `inst/design/horizon.md` (2026-05-25 entries)
  - "Future ctx$feature_table deprecation review" (LDG-2413 audit: no strategy
    usage) and the pulse-view construction spike (collapse 11.8x).
- `R/runtime-projection.R`, `R/fold-core.R`, `R/pulse-context.R`
  - current projection, fold setup, and pulse-context implementation.
- Maintainer discussion (2026-05-28) on long-vs-wide importance across strategy
  archetypes (including ML), lookback access, and the collapse convenience idea.

---

## 1. Problem Statement

This RFC is motivated by QuantConnect's "10x Speed-Up On Fundamental Data"
announcement (see Inputs): on a 5,000-equity x 50-field fundamental universe,
QC moved from 4K to 76K DPS - "up to 75% faster than zipline" - almost entirely
by fixing DATA LOADING (ZIP-JSON -> Parquet, selective field loading, type
right-sizing), leaving the strategy itself largely unchanged. The v0.1.8.5
feature-payload spike (`spike-feature-payload-dps.R`) mirrors that benchmark
shape (500 instruments x 2520 pulses x 50 features, ~63M data points,
cross-sectional scoring) to locate ledgr on the same curve.

**Methodological correction stated up front:** QC's win was in the
loading/materialization phase, not the strategy loop. ledgr's clean fold-loop
metric (`t_loop`/DPS(loop)) deliberately caches feature materialization out, so
it measures the phase QC did **not** optimize. The QC-comparable figures are
`t_wall`/`dps_wall` and specifically the **`t_wall - t_loop` gap** - because
`ledgr_projection_pulse_views` (including the unused long build) runs pre-loop
inside `t_wall`. That gap is ledgr's analogue of QC's ZIP-JSON loading tax.

QC's three wins map onto ledgr almost line-for-line:

| QuantConnect win | ledgr analogue | Status |
| --- | --- | --- |
| ZIP-JSON -> Parquet (columnar load) | DuckDB-backed projection | v0.1.8.6 spike |
| Load 50 of 4,900 fields | ledgr declares features, but eagerly builds the unused 2GB long view | Direction 5.1 |
| int/float/decimal type sizing | everything is `double` (8 bytes) today | minor, future |
| single-pass universe filter | already single-pass (dense panel + targets) | n/a |

The spike measures fold throughput (Pulses/sec, DPS) and the resident-memory
ceiling of the R-memory-backed `runtime_projection`.

Two findings, one expected and one sharper than expected:

1. **Memory ceiling (expected, now quantified).** The projection materializes
   feature matrices at `n_inst * n_pulses * n_feat * 8` bytes. At the spike
   scale that is ~0.5 GB for the feature matrices alone; with bars matrices and
   transient build forms the session reaches into the multi-GB range. The
   `rfc_pulse_context_data_model_consolidation` synthesis already predicted
   ~2.6 GB for a comparable parallelism-spike workload and named DuckDB-backed
   projection (v0.1.8.6) and grid-union sharing (shipped v0.1.8.4) as the
   responses. **Correction:** the current-source runs (Measurement Results)
   keep peak session memory at 330-611 MB at the tested scales - memory is a
   *scaling* concern for very wide universes, not the current speed wall.

2. **The dominant materialization is unused (sharper).** `ledgr_execute_fold`
   builds **both** per-pulse views via `ledgr_projection_pulse_views`
   ([R/fold-core.R:94](../../../R/fold-core.R)): the wide view
   (`features_wide`, instrument rows x feature columns) **and** the long view
   (`feature_table`, one row per instrument x feature). At the spike scale the
   long view is a **63,000,000-row data.frame** (~2 GB; ~1 GB in the `ts_utc` +
   `feature_value` double columns, plus repeated key columns), built fresh on
   every `ledgr_run()` call (the feature-series cache is hit, but the pulse-view
   split is not cached across runs; the single-candidate path passes no
   `static_feature_views`). The LDG-2413 usage audit recorded in
   `horizon.md` (2026-05-25) found **no strategy reads `ctx$feature_table`** -
   its only consumers are internal validators (need the schema only), the
   feature-inspection helper (needs one pulse), and test scaffolds. **On
   current source** this build is the `gap_viewbuild` phase and is the dominant
   cost at *high* pulse counts (Direction 5.1); at *low* pulse counts the larger
   cost is feature fingerprinting (Direction 5.0). It is no longer "paid four
   times over and dominant" - that was the stale v0.1.8.0 reading.

> **MEASUREMENT RESULTS (2026-05-28) - with a critical correction.**
>
> The first spike runs were accidentally executed against the **installed**
> ledgr (`v0.1.8.0`), not current source (`v0.1.8.5`): the spike loader prefers
> `library(ledgr)` when the package is installed. v0.1.8.0 predates the v0.1.8.3
> fast-context consolidation, so those runs measured the *old* per-pulse
> `ledgr_features_wide` rebuild. All numbers below are re-taken against current
> source via `pkgload::load_all(".")`. (See Direction 5.0 and the spike's new
> version guard.)
>
> **Stale v0.1.8.0 vs current v0.1.8.5** (100 inst x 126 pulses x 20 feat, profiled):
>
> | | v0.1.8.0 (stale) | v0.1.8.5 (current) |
> | --- | ---: | ---: |
> | total | 41.1s | 10.7s (~3.8x) |
> | fold loop (`t_loop`) | 36.2s (~290 ms/pulse) | 0.61s (~5 ms/pulse, **~59x**) |
> | per-pulse `ledgr_features_wide` rebuild | ~28% | **gone** (fast-context path) |
>
> The v0.1.8.3 consolidation did its job: the per-pulse rebuild that dominated
> the stale profile is gone. **The "loop is the bottleneck" reading was an
> artifact of stale code.**
>
> **Current-source scale sweep** (100 inst x 20 feat, `load_all`):
>
> ```text
>  pulses  t_pre  gap_viewbuild  t_loop  t_wall  peak_mb  dps_wall_perbar
>     126   6.27           4.86    0.61   11.74    330             1073
>     252   6.23           4.78    1.33   12.34    355             2042
>     504   6.64           7.17    2.83   16.64    433             3029
>    1008   7.06          12.77    9.25   29.08    611             3466
> ```
>
> Phase split (current source), and a **crossover**:
> - **`t_pre` ~6-7s, flat / pulse-independent** = feature **fingerprinting**
>   (`deparse`+`digest`+`serialize` per instrument x feature). Dominates at low
>   pulse counts. Redundant (same function fingerprinted once per instrument) ->
>   Direction 5.0.
> - **`gap_viewbuild` grows with pulses** (4.9 -> 12.8s) = pulse-view
>   construction incl. the unused long table -> Direction 5.1. Dominates at high
>   pulse counts.
> - **`t_loop` now small** (~5 ms/pulse), grows ~linearly (mild super-linear
>   bump at 1008; peak 611 MB, possible GC pressure worth a glance).
> - **Memory is NOT the wall** (peak 330-611 MB here). The "memory ceiling" is a
>   *scaling* concern for very wide universes, not the current speed bottleneck.
>
> **QC comparison, corrected** (security-bars, `dps_wall / n_feat`): ledgr
> full-wall ~3,500 bars/s (1008 pulses) = **~22x slower** than QC's 76K;
> loop-only ~17,800 bars/s (504 pulses) = **~4x slower**. The morning's "~200x"
> was the stale build. The ~22x is mostly the two fixable costs above (5.0 +
> 5.1); after them the full pipeline plausibly lands within ~5-10x of QC - the
> expected interpreted-R-vs-compiled range.
>
> Caveats: `load_all` adds one-time JIT (`cmpfun` ~15%) an installed build would
> not pay; the 500 x 2520 x 50 monster extrapolates to ~13 min/run on current
> source (vs 10+ hours on v0.1.8.0), dominated by 5.0 + 5.1, not the loop.

Memory-projection table (already emitted by the spike; deterministic, matches
the maintainer's scaler widget):

```text
 instruments features feature_matrix_gb est_peak_gb
         500       50              0.50        1.26
         500      100              1.01        2.52
         500      200              2.02        5.04
        1000       50              1.01        2.52
        1000      100              2.02        5.04
        1000      200              4.03       10.08
        2000       50              2.02        5.04
        2000      100              4.03       10.08
        2000      200              8.06       20.16
```

(`est_peak_gb` uses a provisional 2.5x session multiplier; the run's measured
`peak_session_mb` recalibrates it.)

---

## 2. Background: Four Feature Surfaces And Why They Exist

The pulse context exposes **four** ways to read features, all backed by one
projection:

| surface | shape | backing | role |
| --- | --- | --- | --- |
| `ctx$feature(id, name)` | scalar | projection accessor | one instrument, one feature |
| `ctx$features(id, map)` | named vector | projection accessor | one instrument, mapped features (the interface the vignettes teach) |
| `ctx$features_wide` | data.frame (inst rows x feat cols) | prebuilt wide view | cross-sectional / vectorized access |
| `ctx$feature_table` | data.frame (long: inst x feat rows) | prebuilt long view | tidy / filter access |

The consolidation RFC states the cause plainly: the data model "has **accreted**
multiple representations of the same static per-pulse data." Lineage:

- `feature_table` (long) is the **original** canonical strategy shape (the
  v0.1.2 demo called it "the canonical feature output"). `NEWS.md` records the
  later rename that demoted the field and turned `ctx$features` into the
  accessor **function**.
- `features_wide` was added afterward as the vectorized view.
- The scalar/vector accessors are projection-backed and need **neither** table.

They survived consolidation deliberately, not because all four are load-bearing:
LDG-2413 refused to delete `feature_table` without a usage audit (a stated
non-goal) and rejected lazy/active-binding fields for that cycle. The audit
then ran, found no strategy usage, and `horizon.md` flagged the field as "a
plausible future simplification target" pending "a later RFC ... based on
strategy-author usage evidence." **This is that later RFC**, and the payload
spike supplies the missing piece the audit lacked: the **cost** of keeping it.

---

## 3. The Architectural Seam: Decision-Time (Wide) vs Training-Time (Long)

The governing constraint: under no-lookahead, a strategy at pulse `t` sees only
the **current cross-section** (all instruments x all features at `t`); history
is encoded into features, never handed to the strategy as a panel. So inside
`strategy(ctx)`, "long vs wide" is always about **one pulse's** cross-section.

Strategy archetypes and the data shape they want **at decision time**:

| archetype | per-pulse computation | natural shape | wants long? |
| --- | --- | --- | --- |
| per-instrument rules | loop / accessor | accessor or wide row | no |
| cross-sectional factor / ranking | rank/score across universe | wide (design matrix) | no |
| ML inference (tabular GBM/NN) | `predict(model, X)`, `X = n_inst x n_feat` | wide (design matrix) | no |
| pairs / relative value | spreads across instruments | wide | no |
| portfolio optimization (MVO, risk parity) | Sigma + mu across instruments | wide / matrix + **lookback** | no |
| RL / bandit policy | state = cross-section -> action weights | wide (state tensor) | no |
| event / sparse signals | act where signal fired | wide (`which`) ~ long edge | marginal |
| ML / stat **training** | fit over full panel (all pulses) | **long / tidy** | **yes - but not from ctx** |

Two structural facts settle the seam:

1. **ML decomposes against the format, not for it.** *Inference* wants a design
   matrix (rows = instruments, cols = features) - that is `features_wide`; long
   must be pivoted to wide before `predict()`. *Training* genuinely wants
   long/tidy, but it needs the **full panel across all pulses**, which
   no-lookahead forbids the ctx from exposing. Training reads exports / the
   feature store, never `ctx$feature_table`.

2. **The dense-panel invariant (Policy A) removes long's classic advantage.**
   Long usually wins on ragged/sparse entity-feature sets; ledgr guarantees a
   rectangular cross-section, so wide never suffers NA-sprawl here.

Conclusion: **wide is canonical at decision time; long is an edge format**
(export, storage, training, analysis). The future-ML lens strengthens this
rather than weakening it.

---

## 4. Canonical Representation: Columnar Matrices

`runtime_projection$feature_values[[feature_id]]` is already a numeric matrix
`[n_inst x n_pulses]` per feature - the single source of truth. Every
strategy-facing shape is a derived view of it, and the cost asymmetry runs the
right direction:

```text
current cross-section (wide)  = mat[, i]            # one column slice  (near free)
lookback window (Section 5.4) = mat[, (i-w+1):i]    # column-range slice (cheap)
long (feature_table)          = melt of the above   # adds duplicated keys (expensive)
```

Wide and long carry the same information but are **not** transpose-symmetric in
cost: long re-materializes the key columns per cell (`ts_utc` repeated
`n_inst * n_feat` times, etc.), which is ~75% of the 2 GB long table. So the
expensive representation is the one no strategy reads, and the cheap
representations (current slice, lookback window) are exactly what the archetypes
in Section 3 want.

This is the same lesson as `rfc_collapse_primitive_internals_v0_1_9` Section 1:
keep matrices/lists internal, attach `data.frame` only at the public boundary.

---

## 5. Proposed Directions (separable)

Seven directions (5.0-5.6), each independently acceptable or deferrable, plus a
closing alignment rule (5.7).

**Priority order from the current-source measurements:** 5.0 (fingerprint
memoization - ~50% at low/moderate pulse counts), 5.1 (stop building the unused
long table - the `gap_viewbuild` cost at high pulse counts), then 5.6 (typed
persistent event columns - ~13.6% on the sweep/high-turnover path) are the
wall-clock levers. The fold loop itself is already cheap post-v0.1.8.3
(~5 ms/pulse), so loop micro-optimization, collapse Phase B, and a compiled core
are **deprioritized for speed**. 5.2-5.5 are ergonomics/scaling, not speed; 5.7
records the collapse discipline-vs-dependency rule.

### 5.0 Memoize feature fingerprints across instruments (top wall-clock lever)

Current-source profiling shows **~50% of a run** is `ledgr_feature_cache_key` ->
`ledgr_function_fingerprint` -> `deparse` + `serialize` + `digest`. The cache
key fingerprints each feature function, but it is computed **once per
(instrument x feature)** in the precompute loop
([R/backtest-runner.R:1213-1220](../../../R/backtest-runner.R)) - so the *same*
feature function is deparsed and hashed `n_inst` times (100x at the profiled
scale). The fingerprint is identical across instruments.

Fix: compute each feature definition's fingerprint **once** and reuse across
instruments (cache by `feature_def` identity within the precompute). This turns
O(n_inst x n_feat) fingerprinting into O(n_feat); at low/moderate pulse counts
it is the single largest cost. It does **not** weaken the determinism contract -
the fingerprint value is unchanged, only deduplicated. Highest value, lowest
risk, independent of the shape/lookback directions below.

### 5.1 Stop eager full-panel long materialization

`ledgr_projection_pulse_views` should not unconditionally build the long
`feature_table` for all pulses. Default to **not** building it; serve the three
audited consumers narrowly:

- **validators** need only the **schema** (column names/types), not data;
- the **feature-inspection helper** needs a **single pulse**;
- **tests** can **opt in**.

Crucially, this is a **construction-time gate**, not an access-time lazy field -
so it respects the LDG-2413 non-goal that rejected active-binding / function-
valued ctx data fields. `ctx$feature_table` remains a plain data.frame field;
it is simply empty (or schema-only) unless a consumer declares need.

This deletes the dominant memory term and a large share of the per-run wall
cost with **zero strategy impact** (no strategy reads the field), and it is a
*smaller* change than the lazy-everything rewrite that LDG-2413 deferred.

### 5.2 Formalize wide as the canonical decision-time surface

Document `ctx$features_wide` (plus the scalar/vector accessors) as the
contract-blessed strategy-facing cross-sectional interface, per the Section 3
archetype analysis. No code change; a contract/teachability statement that
anchors 5.1, 5.3, and 5.4.

### 5.3 Per-pulse long convenience, decoupled from collapse

For tidyverse-preferring authors, offer a convenience that melts the **current
pulse's** wide view to long on demand (e.g. `ledgr_features_long(ctx)` or a
`ctx`-level helper). Two deliberate constraints:

- **Scope = current pulse only** (~`n_inst x n_feat` -> ~25k rows at spike
  scale): trivially cheap in **base R**; collapse is not needed for speed here.
- **Decouple the API from the dependency.** Ship the helper against an internal
  base-R melt now; swap to `collapse::pivot()` only if/when collapse is adopted
  for load-bearing reasons under `rfc_collapse_primitive_internals_v0_1_9`.
  Powering one convenience with a package-wide Imports is exactly the "broad
  dependency decision from a narrow optimization surface" the v0.1.8.3 spike
  used to defer collapse.

Any future collapse-backed implementation MUST run inside the deterministic
`ledgr_with_collapse_deterministic()` wrapper from the collapse RFC Section 5.

### 5.4 Lookback window primitive (`ctx$window()`)

Introduce a causal lookback accessor returning an `n_inst x w` matrix (or
per-instrument vector) for a feature over the trailing `w` pulses:

```r
W   <- ctx$window("return", lookback = 60)   # n_inst x 60, a column-range slice
Sig <- cov(t(W))                             # n_inst x n_inst covariance
```

Rationale:

- **Portfolio optimization needs it.** A covariance matrix requires a trailing
  return window across instruments; encoding pairwise covariances as scalar
  features is O(n_inst^2) and degenerate. MVO / risk-parity / min-variance all
  need a window primitive.
- **Causally safe.** Lookback != lookahead. The window is bounded to
  `(pulse_idx - w + 1):pulse_idx`, entirely behind the no-lookahead boundary;
  the accessor binds to `pulse_idx` exactly as the current cross-sectional
  accessor does.
- **Cheap in the canonical form.** It is a contiguous column-range slice of the
  resident feature matrix - O(window), not O(panel). Long format makes the same
  window a `w`-fold row filter over a giant table.
- **Aligns with v0.1.8.6.** A DuckDB "load pulse block `[i:j]`" naturally
  contains the trailing window, so lookback and out-of-core block-loading want
  the same boundary.

Open design points: warmup semantics for the first `w-1` pulses; per-feature vs
multi-feature window; matrix vs list-of-vectors return; interaction with
`stable_after` on indicators. (See Section 10.)

### 5.5 Long as a first-class export / research-layer format

Where long genuinely wins - ML training frames, feature-store dumps, tidy EDA -
make it first-class at the **export / research layer** over the **full panel**,
which is where the no-lookahead boundary permits full history and where
`collapse::pivot()`'s C-speed reshape actually pays. This ties to the
research<->production boundary work and the deferred v0.2.x PIT-regressor track
(external data arrives long at ingestion; decision-time still pivots to wide).

### 5.6 Typed persistent event columns (write serialize + replay parse)

`ledger_events` stores `cash_delta` / `position_delta` / `commission` inside the
`meta_json` blob, not as typed columns. That costs twice:

- **Write side:** `ledgr_fill_event_payload(serialize_meta_json = TRUE)` runs
  `canonical_json(meta)` per fill - measured at ~13.6% of the fold in the
  v0.1.8.3 sweep residual report ("typed event write overhead").
- **Replay side:** `ledgr_reconstruct_positions/_cash`
  ([R/derived-state.R](../../../R/derived-state.R)) parse
  `jsonlite::fromJSON(meta_json)` per row on reopen/resume.

Promoting those deltas to typed columns removes both: no per-fill serialize, and
replay becomes a vectorized grouped sum (`fsum` / SQL `GROUP BY SUM`). This is
the **persistent counterpart to LDG-2410**, which typed only the *in-memory*
sweep events (`scope: sweep_memory_path`). Note the buffered write handler is
*already* column-primitive and boundary-correct
([R/backtest-runner.R:362-485](../../../R/backtest-runner.R)) - the remaining
cost is purely the JSON blob. A no-schema-change interim for the replay side is
to push aggregation into DuckDB SQL (`json_extract` + `GROUP BY`) - see
`horizon.md` 2026-05-28. High-turnover strategies and large-run reopen are where
this bites.

### 5.7 Per-loop collapse alignment, and the discipline-vs-dependency rule

A collapse-alignment review of the full per-loop pipeline (against the
`developing_with_collapse` recommendations) found the hot path is **already
primitive** post-v0.1.8.3 (feature matrices, prebuilt views, column-buffered
event writes). Ranked by *measured* wall-clock impact on current source:

| Item | Collapse pattern? | Measured impact (v0.1.8.5) | Priority |
| --- | --- | --- | --- |
| Fingerprint memoization (5.0) | No - redundant work | ~50% at low/mid pulses | 1 |
| Don't build unused long table (5.1) | Partly | `gap` growth, high pulses | 2 |
| Typed persistent events (5.6) | Adjacent | ~13.6% on sweep/high-turnover | 3 |
| Per-pulse delta diff: vectorize + positional index | Yes | small (loop ~5 ms/pulse) | low |
| Trim per-fill validation of sealed/internal data | Yes (trust boundary) | small | low |
| FIFO lot replay | Exception - non-vectorizable, parked | n/a | n/a |

**Uncomfortable finding:** the two biggest wall-clock levers (5.0, 5.1) are
**not** collapse patterns - they are "stop doing redundant work." The loop no
longer needs collapse.

**Discipline vs dependency (rule):** adopt the *primitive-internals discipline*
(vectors/matrices/lists internally, `data.frame` only at the boundary)
**broadly** - it is dependency-free and is the real lesson. Adopt the *collapse
dependency* **surgically** - only at measured hot frames, behind the
deterministic `set_collapse()` wrapper, phase-by-phase per
`rfc_collapse_primitive_internals_v0_1_9`. Do **not** "use collapse everywhere":
most of ledgr is cold-path, the hot path is already primitive, the measured wins
need no collapse, blanket adoption multiplies the determinism-audit surface and
single-maintainer dependency exposure, and it contradicts collapse's own
minimalism ("do I need this complexity?"). Typed columns (5.6) come before any
new collapse import.

---

## 6. Relationship To Other Work

- **v0.1.8.3 pulse-context consolidation (shipped).** This RFC is its successor:
  consolidation moved view *construction* out of the loop; this RFC questions
  whether one of those views should be *built at all* by default, and adds the
  lookback primitive.
- **v0.1.8.4 grid-union shared views (shipped).** Reduces cross-candidate
  duplication; orthogonal to the eager-long question (5.1 removes the long
  build for every candidate at once).
- **v0.1.8.6 DuckDB-backed projection.** 5.1 (don't build long) and 5.4
  (lookback = block range) both simplify the block-loading interface; columnar
  canonical maps cleanly to DuckDB columns.
- **v0.1.9 collapse / primitive internals.** 5.3 and 5.5 are the natural homes
  for `collapse::pivot()`; this RFC must not pre-empt that dependency decision.
  5.7 records the discipline-broad / dependency-surgical rule that constrains it.
- **LDG-2410 typed memory events (shipped v0.1.8.3).** Typed the *in-memory*
  sweep events (`scope: sweep_memory_path`); 5.6 is the *persistent* counterpart
  (typed DB columns). The DB-replay path 5.6 targets was never in LDG-2410 scope.
- **v0.2.x PIT regressors / Rust harness.** 5.5 (long ingestion at the edge)
  and the matrix-canonical direction both reduce downstream FFI marshalling.

---

## 7. Memory And Performance Evidence

Primary evidence is the Measurement Results in Section 1 (current-source sweep
via `load_all`). Supporting structural facts (verified against current source
this cycle):

- `ledgr_execute_fold` calls `ledgr_projection_pulse_views` when
  `execution$static_feature_views` is NULL ([R/fold-core.R:92-98](../../../R/fold-core.R));
  the single-candidate `ledgr_run()` path passes NULL, so the long+wide split
  is rebuilt per run.
- `ledgr_projection_pulse_views` builds the long `feature_table` unconditionally
  ([R/runtime-projection.R:276-307](../../../R/runtime-projection.R)).
- `t_loop` is bracketed around the loop only
  ([R/fold-core.R:339-341](../../../R/fold-core.R)); the pulse-view build is
  pre-loop, so it inflates `t_wall`/peak but **not** `t_loop`/DPS(loop).

> **[PER-DIRECTION SAVINGS]**
> Baseline (current source) is the Section 1 sweep. Targets to verify after each
> lands, always via `load_all` (not the installed build):
> - **5.0** should remove almost all of the flat ~6-7s `t_pre` fingerprinting
>   (O(n_inst x n_feat) -> O(n_feat)); dominant at low/moderate pulse counts.
> - **5.1** should remove the `gap_viewbuild` growth with pulses (the unused
>   long-table build); dominant at high pulse counts.
> - Neither touches `t_loop`, which is already cheap post-v0.1.8.3.

> **[QC-COMPARABLE - initial measurement taken]**
> Current source, security-bars (`dps_wall / n_feat`): full-wall ~3,500 bars/s
> (~22x slower than QC's 76K), loop-only ~17,800 bars/s (~4x slower). For a
> rigorous head-to-head: measure the COLD path (first run, `t_pre` included),
> match universe/horizon, and note that EOD vs intraday is only a pulse-count
> scaling difference. QC's loading win maps to Direction 5.0 + 5.1 + the
> v0.1.8.6 columnar projection; the interpreted-R loop will sit below a compiled
> engine on raw loop throughput regardless, but the ~22x is mostly the two
> fixable costs, not the loop.

---

## 8. Verification Requirements

Any accepted direction must require:

- **5.0 fingerprint memoization must be a pure dedup:** the per-feature
  fingerprint *value* is bit-identical to today's (computed once, reused across
  instruments, not recomputed differently); fingerprint-stability pins stay green;
- **bit-exact fold parity** with and without the eager long build on the
  reference workload event stream (5.1 changes nothing a strategy observes);
- `ctx$feature_table` schema preserved when present; validators still get the
  schema, the inspection helper still gets a single pulse;
- **no-lookahead invariant** for `ctx$window()`: a window at pulse `t` reads no
  column `> t`; add fixtures analogous to the existing accessor causal-boundary
  tests (5.4);
- **5.6 typed persistent events must reconstruct bit-exact:** derived state from
  typed columns equals derived state from the `meta_json` path; the DuckDB-SQL
  interim replay (`json_extract` / `GROUP BY`) must match the R replay to the
  LDG-2403 tolerance, including float casting;
- LDG-2413 state-leak fixtures (in-run capture, in-strategy mutation,
  cross-candidate isolation) carry forward for any view touched;
- fingerprint-stability pins and LDG-2403 accounting parity remain green;
- if any collapse-backed melt (5.3/5.5) is used on a result-affecting path,
  the collapse RFC determinism + floating-point parity gates apply
  (`ledgr_with_collapse_deterministic`, max-abs-diff < 1e-12);
- per-direction remeasurement via the current-source scale sweep (`load_all`,
  never the installed build), recorded in the cycle residual report.

---

## 9. Non-Goals

This RFC does not propose:

- deleting `ctx$feature_table` outright (5.1 makes it lazy-built, not removed;
  formal deprecation is a separate decision per `horizon.md`);
- active-binding / function-valued ctx **data** fields (LDG-2413 non-goal
  preserved; 5.1 is a construction-time gate);
- a second execution engine or vectorized strategy execution;
- exposing history panels to the strategy beyond the bounded `ctx$window()`
  (no-lookahead preserved);
- adding collapse as an Imports dependency *for this RFC* (5.3/5.5 are
  collapse-ready but dependency-decoupled; the decision lives in v0.1.9);
- blanket collapse adoption ("use collapse everywhere"): 5.7 binds the
  discipline-broad / dependency-surgical rule; new collapse imports are
  measured-and-wrapped only, and come after typed columns (5.6);
- DuckDB-backed projection storage itself (v0.1.8.6);
- public ML training-frame APIs (5.5 names the layer, not the API);
- FIFO lot redesign, compiled fold kernels, or parallel dispatch;
- weakening snapshot, no-lookahead, FIFO accounting, metric-context, or
  execution-seed contracts.

---

## 10. Open Questions For Response

1. **5.1 gating.** Is "build long only when a consumer declares need" the right
   mechanism, and what is the declaration surface - an experiment-level flag, a
   per-strategy capability hint, or inferred from whether `ctx$feature_table`
   is referenced (not statically knowable in R)?
2. **Validator schema.** Can validators be re-pointed at the projection's
   feature-id list / an empty-schema frame so they need no row data at all?
3. **Inspection helper.** Is per-pulse on-demand long for the inspection helper
   acceptable, or does it need the full panel for any documented workflow?
4. **5.4 return shape.** `n_inst x w` matrix vs list-of-per-instrument-vectors?
   Single-feature vs multi-feature window? How does warmup
   (`stable_after`, first `w-1` pulses) report - NA rows, short window, or
   error?
5. **5.4 vs features.** Some lookback uses (rolling means) are already
   expressible as indicators. Where is the line between "make it a feature" and
   "use `ctx$window()`"? Covariance is clearly the latter; rolling mean is
   arguably the former.
6. **5.3 placement.** Convenience as a free function (`ledgr_features_long`),
   a ctx helper, or both? Does a ctx helper risk re-opening the
   function-valued-field non-goal (note: `ctx$features`, `ctx$flat`, etc. are
   already functions, so a *helper* function differs from a lazy *data* field)?
7. **Sequencing.** Which directions land when? The measured priority is 5.0
   (cheap, high-value, no contract change) first, then 5.1, then 5.6. 5.4
   (lookback) is the largest new surface; 5.6's typed-columns route is a schema
   call. v0.1.8.6 (DuckDB) vs v0.1.9 (collapse) vs later for each?
8. **Deprecation coupling.** Should 5.1 (lazy build) and the eventual
   `feature_table` public-field deprecation be one arc or kept separate per the
   `horizon.md` note?
9. **5.0 memoization scope.** Confirm it is a pure internal dedup (cache the
   fingerprint by `feature_def` identity within the precompute, reuse across
   instruments) with no contract change and no fingerprint-value change. Any
   reason it cannot be a drop-in?
10. **5.6 route and migration.** DuckDB-SQL interim (no migration; fixes replay
    only, leaves the per-fill write serialize) vs typed DB columns (schema
    migration + parity for existing stored runs; fixes both)? SQL interim first
    and columns later, or straight to columns?

---

## 11. Suggested Next Step

Write a response that takes positions on:

- **5.0** as the cheap, no-contract-change first move (fingerprint dedup);
- the 5.1 declaration mechanism and validator/inspection re-pointing;
- **5.6** route (DuckDB-SQL interim vs typed-columns migration) and ordering;
- the `ctx$window()` return contract and warmup semantics (5.4);
- convenience placement and the collapse-decoupling rule (5.3);
- per-direction sequencing across v0.1.8.6 / v0.1.9 / later.

If the response accepts the direction, draft a synthesis binding: the 5.0
memoization (with the fingerprint-stability gate); the eager-long removal
mechanism and parity gates; the 5.6 route and reconstruction-parity gate; the
lookback primitive contract and causal fixtures; the convenience API; and
per-direction cycle placement. The current-source measurements (Section 1) are
already the empirical baseline; re-measure via `load_all` after each direction
lands.

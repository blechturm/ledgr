# RFC Seed v2: Feature Projection Shape, Materialization Policy, And Lookback Access

**Status:** Position-bearing seed (v2). Incorporates the Codex response and the
seed-author response review. Supersedes v1 as the position-bearing document; v1
is retained as history. Awaiting synthesis (Codex, per role rotation).
**Date:** 2026-05-28
**Author:** Claude (seed author; owns architectural intent)
**Cycle (per `inst/design/rfc_cycle.md`):** seed v1 (Claude) -> response (Codex)
-> response review (Claude) -> **seed v2 (this doc, Claude)** -> synthesis
(**Codex**, did not write v2) -> final review (Claude, did not write synthesis).
**Reads in order:**

- v1 seed: `rfc_feature_projection_shape_and_lookback_v0_1_8_x.md`
- response: `rfc_feature_projection_shape_and_lookback_v0_1_8_x_response.md`

No "v1" feature-shorthand is used here; directions map to named roadmap windows
(v0.1.8.6 / v0.1.9 / later), not a feature "v1".

---

## 0. What v2 changes from v1

The response **accepted** the corrected performance reading, the 5.0/5.1
ordering, the wide-canonical/long-edge seam, and the discipline-vs-dependency
rule. v2 folds in its refinements and one correction.

**Unchanged from v1** (not repeated; read v1 for detail): the QuantConnect
motivation and stale-build correction (v1 §1), the four-surface accretion history
(v1 §2), the decision-time-wide / training-time-long archetype seam incl. ML
(v1 §3), and the columnar-canonical argument (v1 §4).

**Five things v2 binds differently or adds:**

1. **Direction 5.0 memoizes TWO things, not one.** `ledgr_feature_cache_key()`
   recomputes both `ledgr_feature_def_fingerprint(def)` **and**
   `ledgr_feature_engine_version()` per (instrument, feature). Both must be
   hoisted; target is **exact cache-key equivalence**, not a new key format.
2. **Direction 5.1's mechanism is an internal construction-time view policy** -
   not an experiment flag, not strategy-source inference, not a per-strategy
   capability hint - and it **must** fix the non-fast context helper that
   silently rebuilds the long table when `features` is empty and a projection is
   present.
3. **Direction 5.6: typed columns are the complete fix; the DuckDB-SQL interim
   is a narrow replay patch only** (removes neither the write-side serialize nor
   the immediate run read-back parse).
4. **Width-invariance is withdrawn.** v1 inferred it from a pulse-only sweep; v2
   does not claim it. A two-mode instrument x feature sweep is a hard gate before
   any width/throughput claim enters roadmap or benchmark language.
5. **Sequencing tightened (§4) and a synthesis gate list added (§5).**

---

## 1. Accepted performance frame (current source v0.1.8.5)

Measured via `pkgload::load_all` against current source (the v1 first runs were
against a stale installed `v0.1.8.0`; the spike now hard-fails on a version
mismatch). 100 inst x 20 feat:

```text
 pulses  t_pre  gap_viewbuild  t_loop  t_wall   notes
    126   6.27           4.86    0.61   11.74    t_pre dominates (low pulses)
   1008   7.06          12.77    9.25   29.08    gap dominates (high pulses)
```

- The **fold loop is cheap** (~5 ms/pulse; ~59x faster than the stale build).
  The v0.1.8.3 consolidation removed the old per-pulse `features_wide` rebuild.
- Wall cost is **setup**: `t_pre` fingerprinting (flat, ~50% at low pulse counts)
  and `gap_viewbuild` (the unused long-table build, grows with pulses).
- **Memory is not the wall** (peak 330-611 MB here); it is a scaling concern.
- **vs LEAN** (security-bars, `dps_wall / n_feat`): ~22x slower wall, ~4x slower
  loop - and the ~22x is mostly the two fixable setup costs. After 5.0 + 5.1 the
  wall hugs the loop; pure R lands ~5-10x off LEAN. (See v1 for why the "pure R
  beats LEAN" reading was a unit error.)

---

## 2. Bound directions (refined by the response)

### Direction 5.0 - Memoize feature fingerprints across instruments. ACCEPT; v0.1.8.6; first.

- Hoist **both** `ledgr_feature_def_fingerprint(def)` and
  `ledgr_feature_engine_version()` out of the per-(instrument, feature) loop in
  `ledgr_run_fold()`; route key construction through an internal helper that
  takes the already-computed `indicator_fingerprint` + `feature_engine_version`.
- Memoize by **resolved concrete feature-definition identity** - NOT R object
  address or environment identity.
- **Precompute scope**, not the persisted feature-cache registry.
- Pure dedup: no public-contract change, no cache-schema change, no
  fingerprint-value change. **Gate:** byte-identical keys vs
  `ledgr_feature_cache_key()` for scalar, multi-output, parameterized, and
  explicit-fingerprint feature definitions.

### Direction 5.1 - Stop eager full-panel long materialization. ACCEPT; v0.1.8.6; second.

- **Mechanism = internal construction-time view policy.** Default: build
  `features_wide` + a **zero-row / schema-only** `feature_table`. Full long is
  an **explicit internal opt-in** (tests, debugging, compatibility paths).
  Inspection: a **single-pulse** long table on demand, never the full panel.
- Reject the flag / source-inference / per-strategy-capability-hint options
  (contract surface for a representation we intend to demote).
- Respects the LDG-2413 non-goal: `ctx$feature_table` stays a plain data.frame
  field (not active binding, not function-valued) - the change is construction
  policy, not access-time laziness.
- **Hard implementation requirement:** `ledgr_attach_feature_helpers` currently
  rebuilds a full pulse long table when `features` is empty **and** a projection
  is available ([R/pulse-context.R:233-235](../../../R/pulse-context.R)) - so a
  schema-only frame would silently become full long on the non-fast path. 5.1
  must change this. **Gate:** a fixture proving no rebuild unless full long is
  requested.
- **Keep separate** from public `ctx$feature_table` deprecation (a later
  lifecycle decision once docs/usage guidance catch up). Existing feature-table
  tests opt into full long or move to `features_wide`.

### Direction 5.2 - Wide as canonical decision-time surface. ACCEPT.

Bind as a documentation/contract statement: decision-time cross-sectional work
uses scalar/vector accessors or `ctx$features_wide`; long is an export,
inspection, compatibility, or research shape.

### Direction 5.3 - Per-pulse long convenience. ACCEPT as a free function only.

`ledgr_features_long(ctx)` (exported), base R, melts the current pulse from
`features_wide` / projection state. No collapse. No new callable ctx field (a
free function is cleaner for the deprecation arc).

### Direction 5.4 - `ctx$window()` lookback. ACCEPT the need; DEFER the public API until after 5.0/5.1.

First contract, deliberately small:

- single feature per call; returns an `n_inst x lookback` numeric matrix;
- rows in `ctx$universe` order; columns oldest -> current;
- early pulses return **leading `NA_real_` columns** (not a short matrix, not an
  error); `stable_after` stays encoded in feature values - the window adds **no
  second warmup contract**;
- column naming (timestamps vs stable positional) decided at spec-cut;
- no list returns / multi-feature tensors in the first public version.

Feature-vs-window line: instrument-local reusable transforms are **features**
(rolling mean/vol, RSI, lagged return); cross-instrument / model-local / matrix
calculations use **`ctx$window()`** (covariance, risk parity, PCA, policy state).
Enters v0.1.9 if target-risk / portfolio-risk needs covariance windows; else
later.

### Direction 5.5 - Long as export/research-layer format. ACCEPT as later work.

Research/export boundary, full panel, never rebuilt per run by default.

### Direction 5.6 - Typed persistent event columns. ACCEPT direction; sequence after 5.0/5.1; storage-cycle work.

- **Typed columns are the complete fix; the DuckDB-SQL interim is a narrow replay
  patch only** - it removes neither the write-side `canonical_json()` cost nor
  the JSON parse on immediate run read-back.
- Typed-column route: add nullable typed columns for at least `cash_delta` and
  `position_delta`; keep `meta_json` for compatibility/rare metadata; write typed
  deltas from the existing fill payload; backfill old rows during migration or
  read via compatibility fallback; repoint run read-back, resume, and
  derived-state replay to prefer typed columns.
- Migration cost is **moderate** - the hard part is parity across old, new, and
  mixed stores. **Gate:** typed-column replay parity vs JSON replay for cash,
  positions, equity, fills, and resume state.
- Implement only if the packet **explicitly** accepts storage/schema work;
  otherwise leave designed, not half-implemented.

### Direction 5.7 - Primitive internals & collapse. ACCEPT (rule).

Primitive-internals discipline **broad** (dependency-free). **No** collapse
Imports for 5.0 / 5.1 / 5.3 / 5.4. Collapse stays a measured,
determinism-wrapped v0.1.9 decision per `rfc_collapse_primitive_internals_v0_1_9`
- not a blanket style change. Typed columns (5.6) come before any new collapse
import.

---

## 3. Width-invariance: withdrawn; required sweep

v1's width-invariance inference is **withdrawn**. The pulse-only sweep justifies
the setup-bottleneck reordering but does not prove loop throughput is invariant
across instruments or features. A strategy that scores `ctx$features_wide` does
work proportional to `n_inst * n_feat`; a high-turnover strategy adds fill/event
work proportional to changed targets.

Before any width/throughput claim enters roadmap or benchmark language, run a
sweep that **varies instruments and features at fixed pulses**, with two strategy
modes:

- **read/score, no fills** - isolates context + feature access;
- **turnover** - includes event-write and replay pressure.

---

## 4. Sequencing

**v0.1.8.6 (primary):**

1. Land 5.0 fingerprint/cache-key dedup.
2. Land 5.1 schema-only `feature_table` default (+ the non-fast-path fix).
3. Remeasure after each change **separately**, via source `load_all`.
4. Run the instrument x feature sweep (§3) before publishing any width claim.

**v0.1.8.6 (secondary, only if storage work is explicitly accepted):** decide and
implement 5.6 typed columns; otherwise leave 5.6 designed, not half-implemented.
The DuckDB-backed projection (separate horizon item) consumes the **simplified**
projection contract after 5.1 - no per-pulse DBI, no full-panel long.

**v0.1.9:** collapse / primitive-internals stays surgical; collapse does not gate
5.0/5.1. `ctx$window()` (5.4) enters here only if target-risk / portfolio-risk
needs covariance windows.

**Later:** full-panel long export/training APIs; multi-feature window/tensor
extensions; PIT-regressor feature-store interchange; broader typed event metadata
beyond the deltas needed for replay.

---

## 5. Synthesis gates (bind these)

- **5.0** exact cache-key parity - covering **both** the def fingerprint and the
  engine version - vs `ledgr_feature_cache_key()`, before and after memoization.
- **Source-version guard** in all performance spikes (done for the payload spike;
  generalize as a dev/spikes convention).
- **Separate remeasurement** after 5.0 and after 5.1.
- **Instrument x feature sweep** (two modes, §3) before any width-invariance /
  benchmark claim.
- **5.1** event-stream parity: full-long-enabled vs schema-only-default produce
  identical event streams.
- A **fixture** proving the non-fast context path does **not** rebuild long rows
  unless full long is requested.
- Existing feature-table tests opt into full long views or move to
  `features_wide`.
- **5.6** (if implemented) typed-column replay parity vs JSON replay for cash,
  positions, equity, fills, and resume state, across old / new / mixed stores.

---

## 6. Open questions: status after response

Resolved by the response (now positions in §2): 5.1 gating (construction-time
policy); validator schema (projection IDs / zero-row frame); inspection helper
(single-pulse on demand); 5.4 return shape (single-feature `n_inst x lookback`,
leading NA); feature-vs-window line; 5.3 placement (free function); deprecation
coupling (kept separate); 5.0 dedup scope (drop-in, identity not address); 5.6
route (typed columns; SQL interim is a patch only).

**Promoted to spec-cut (within-window decisions):**

- `ctx$window()` column naming (pulse timestamps vs stable positional).
- The exact "full long requested" opt-in surface (function argument vs internal
  sentinel) for 5.1.

**Future obligations (separate later cycles):** 5.4 multi-feature/tensor windows;
5.5 export/training APIs; PIT-regressor interchange; broader typed event metadata.

---

## 7. Handoff

Per `rfc_cycle.md` role rotation: **synthesis -> Codex** (did not write v2);
**final review -> Claude** (did not write the synthesis). The synthesis should:

- bind the §2 direction positions, the §4 sequencing, and the §5 gates;
- promote the §6 spec-cut questions and record the §6 future obligations;
- write the post-synthesis horizon entry (deferrals: 5.4 lookback API, 5.5 export
  long, 5.6 if not taken this cycle), per the cycle's horizon pattern;
- note which stages were run/skipped.

No new design space is needed for synthesis; v2 is intended to be
synthesis-ready.

# ledgr Horizon Archive

**Status:** Historical evidence only.
**Authority:** None. This file is neither current design authority nor a
backlog.

Bodies are preserved from `horizon.md`. Current decisions and executable
work live in contracts, accepted RFC syntheses, the roadmap and spec packets.
<a id="resolved-001"></a>

### 2026-06-05 [planning] v0.1.9.4 walk-forward Section 17 gate-row obligations from the v0.1.9.x arc -- resolved by v0.1.9.4

Resolved by the v0.1.9.4 walk-forward packet. The packet treated the horizon
entry as the cross-cycle enforcement record, named both `cost_model_hash` and
`risk_chain_hash` in `candidate_key` and `session_id`, and shipped identity
tests exercising those components.

The accepted obligations remain traceable through:

- `inst/design/ledgr_v0_1_9_4_spec_packet/v0_1_9_4_spec.md`;
- `inst/design/ledgr_v0_1_9_4_spec_packet/v0_1_9_4_tickets.md`;
- `tests/testthat/test-walk-forward-identity.R`.

<a id="resolved-002"></a>

### 2026-06-05 [planning] v0.1.9.1 cost-API spec-cut decisions on synthesis Section 13 open questions -- resolved by v0.1.9.1

The accepted cost-API synthesis
(`rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`)
left five questions to the spec-cut writer in Section 13. The v0.1.9.1 packet
bound and implemented them with the aggressive pre-CRAN-no-users posture:
reject legacy shapes, no transitional auto-translation, no silent defaults.

**Decision 1: legacy `fill_model = list(...)` shape.** Reject with classed
error.

Rationale: the API restructures (`fill_model` splits into `timing_model` +
`cost_model`) AND the spread semantics shift from full-bps-per-leg to
quoted-spread (half-bps-per-leg). Auto-translation would silently halve
`spread_bps` values -- a numeric footgun. Forcing users to re-author surfaces
the semantic shift explicitly. Pre-CRAN policy makes this affordable.

Implementation shape:

- `ledgr_experiment(... fill_model = list(...))` raises
  `ledgr_legacy_fill_model_shape` at construction.
- Error message points at `timing_model = ledgr_timing_next_open()` and
  `cost_model = ledgr_cost_chain(ledgr_cost_spread_bps(...),
  ledgr_cost_fixed_fee(...))`.
- Error message explicitly names the quoted-spread convention shift:
  "spread_bps in the new API is quoted-spread (half per leg); divide your old
  value by 2".

**Decision 2: cost plan execution shape.** Confirm "implementer's choice with
stable outputs and identity."

Rationale: synthesis already notes "likely defer to implementer." Spec-cut just
confirms. Implementation gated on:

- identity stability tests pass;
- `cost_plan_json` reconstruction parity tests pass;
- no per-pulse DB writes in cost resolution (already in synthesis Section 9).

Row-wise resolver, vectorized per-pulse, or hybrid is the implementer's call
subject to those gates.

**Decision 3: cost component diagnostic retention.** `meta_json` only in v1.

Rationale: reserving a future diagnostic table shape pre-commits to schema
without binding text -- the exact pattern the closed `compiled_accounting_model`
enum scope-guard discipline rejects. `meta_json` is the flexible v1 surface.
Structured diagnostic tables, if needed, get their own RFC (alongside the
diagnostic-retention RFC that walk-forward already defers to in its Section 12
Future Obligations).

**Decision 4: reopen-path compatibility for stored configs.** Reject with
classed error.

Rationale: matches the pre-CRAN policy in horizon's 2026-05-25 entry:
"users should expect to rerun experiments after upgrading when the cycle
changes storage/hashing/execution contracts." No translation logic for zero
current users.

Implementation shape:

- `ledgr_run_open()` reading a stored `config_json` containing `fill_model`
  raises `ledgr_legacy_config_shape`.
- Error message points at recreating the experiment with the new API surface.

**Decision 5: `cost_model = NULL` default.** Require explicit argument; no
implicit default.

Rationale: cost is part of run identity, not an afterthought. Three lenses
converge:

- Walk-forward synthesis Section 3 binding for `opening_state_policy`:
  "no hidden hardcoded behavior is allowed." Same principle for cost.
- An implicit `ledgr_cost_zero()` default is a real footgun: user runs backtest,
  sees great Sharpe, does not realize the experiment had zero costs.
- ledgr's broader pattern is explicit-at-construction for
  identity-participating arguments.

Implementation shape:

- `ledgr_experiment()` without explicit `cost_model` raises
  `ledgr_cost_model_unspecified` at construction.
- Error message hints at `ledgr_cost_zero()` for users who genuinely want
  zero-cost (must be explicit).

**Resolution:** v0.1.9.1 implemented the five decisions through the public
cost API, explicit timing / required cost model surface, classed legacy-shape
rejections, cost identity (`cost_model_hash`, `cost_plan_json`), and
documentation / NEWS closeout. The v0.1.9.x sequencing entry, v0.1.9.2 sweep
RFC schedule, and v0.1.9.4 walk-forward gate-row obligations remain open
because they are forward dependencies, not v0.1.9.1 implementation claims.

<a id="resolved-003"></a>

### 2026-06-04 [documentation] Documentation, structure, and cleanup release shipped v0.1.8.11

v0.1.8.11 shipped the planned documentation and cleanup pass before v0.1.9:
maintainer manual, RFC decision index, contract audit and structure pass,
post-B2 documentation refresh, user-facing disclaimer, internal performance arc,
benchmark methodology, roadmap / horizon / design-index housekeeping, and the
`adr/` + `architecture/` + `maintainer_review/` wind-down. No v0.1.8.12
documentation follow-on is planned; future bounded documentation belongs in
v0.1.9.x only if a later packet cuts it explicitly.

<a id="resolved-004"></a>

### 2026-05-15 [adapters] Multi-output indicator authoring bundles — shipped v0.1.8.1

`ledgr_indicator_bundle` / `ledgr_ind_ttr_outputs()` shipped in v0.1.8.1 with
the accepted design: flatten-at-declaration to single-output indicators,
output-specific fingerprints, normalized prefix (`bbands_dn`), `prefix = NULL`
raw opt-in, instrument IDs never in feature IDs. See the v0.1.8.1 packet and
`rfc_multi_output_indicator_ux_synthesis.md`.

<a id="resolved-005"></a>

### 2026-05-15 [ux] Parameter-grid construction helpers — shipped (core) v0.1.8.4

`ledgr_feature_grid()`, `ledgr_strategy_grid()`, and `ledgr_grid_cross()`
shipped in v0.1.8.4 as candidate-set construction helpers with no
objective/ranking semantics. The `ledgr_grid_named()` /
`ledgr_grid_add_baseline()` variants were not built and remain low-priority
optional ideas if a future cycle wants them.

<a id="resolved-006"></a>

### 2026-05-25 [optimization] Grid-union shared pulse views — shipped v0.1.8.4

v0.1.8.4 adopted the grid-level concrete-feature-union: shared concrete
features computed once across a sweep grid, not once per candidate. See the
v0.1.8.4 packet.

<a id="resolved-007"></a>

### 2026-05-15 [execution] Single-core sweep hot-path optimization — shipped v0.1.8.3

v0.1.8.3 shipped the runtime projection + R-memory backend + fast context and
the summary-only in-memory accounting path
(`ledgr_sweep_summary_from_ordered_events`), addressing the pulse-context churn
and event-replay reconstruction costs this entry identified.

<a id="resolved-008"></a>

### 2026-05-13 [execution] Compact execution semantics article — shipped v0.1.8.5

`vignettes/execution-semantics.qmd` shipped in the v0.1.8.5 teachability cycle
(Batch 4) as the consolidated reference for next-open fills, targets-as-
holdings, decision-time sizing, final-bar no-fill, and open positions.

<a id="resolved-009"></a>

### 2026-05-13 [data] Data input and snapshot creation article — resolved v0.1.8.5

Resolved without a separate article: the v0.1.8.5 cycle moved the low-level CSV
bridge to the `?ledgr_snapshot_import_bars_csv` help page (reference boundary)
and kept experiment-store centered on run management, so the split this entry
proposed is no longer needed.

<a id="resolved-010"></a>

### 2026-06-01 [optimization] Feature projection materialization + storage spike + benchmark closeout — shipped v0.1.8.6

The v0.1.8.6 cycle shipped per the feature projection synthesis: 5.0 feature
cache-key dedup (fingerprint + engine-version), 5.1 schema-only
`ctx$feature_table` default with non-fast-path rebuild fix, and the
post-5.0/5.1 remeasurement + instrument x feature sweep. The DuckDB feature
storage spike ran independently and informed direction. Structured benchmark
+ attribution closeout established the LDG-2476 baseline for v0.1.8.9. Typed
persistent `cash_delta` / `position_delta` columns (5.6) were deliberately
deferred to a later storage RFC; LDG-2451 snapshot administration was
deferred to v0.2.0-class per the 2026-05-29 entry. See the v0.1.8.6 packet
and `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`.

<a id="resolved-011"></a>

### 2026-06-01 [optimization] v0.1.8.7 Optimization Round 2 — shipped v0.1.8.7

The v0.1.8.7 cycle shipped per the optimization-round synthesis: surface-
preserving event-buffer capacity/write fix (B0), hot-path representation /
formatting cleanup with durable-identity bytes fenced off (R), read-back
reconstruction behind a deterministic collapse gate (C), ADR 0004
dependency moves (drop cli + R6, add collapse, keep tibble), and explicit
legacy cleanup (raw `bars` execution, R6 strategy execution, run-time
`data_hash` identity removed from modern execution). Per-lane real-run
re-profile and parity gates landed alongside. See the v0.1.8.7 packet and
`rfc_optimization_round_v0_1_8_7_synthesis.md`.

<a id="resolved-012"></a>

### 2026-06-01 [infrastructure] Parallel sweep dispatch + typed execution spec — shipped v0.1.8.8

The v0.1.8.8 cycle shipped public parallel sweep dispatch, parallel worker
setup with Tier-2 packages, mori transport, worker-local read-only DuckDB,
parallel interrupt + measurement contract, typed `ledgr_execution_spec_v1`
(LDG-2472), deterministic-only RNG with `ctx$pulse_seed` (LDG-2471), and
the `inst/design/manual/` skeleton (without authoring the full internal
manual - that work moves to v0.1.8.11 per the 2026-05-30 maintainer-manual
backlog entry). LDG-2479 self-profiling workload grid extension landed as
the v0.1.8.9 baseline. See the v0.1.8.8 packet.

<a id="resolved-013"></a>

### 2026-06-01 [optimization] v0.1.8.9 single-core optimization round — shipped v0.1.8.9

The v0.1.8.9 cycle shipped the single-core optimization round per the
LDG-2476 / LDG-2479 per-pulse complexity finding. Highlights: fills
extractor `setv` (Batch 5 wins per LDG-2496), durable + memory output
handler `setv` rewrites, durable handler character-write fix, vectorized
fold position valuation and target-delta scan, canonical JSON migration to
yyjsonr (LDG-2493 / LDG-2494). High-density xlarge durable cell moved
445.02s → 232.03s wall, 413.47s → 199.06s loop, 197.11s → 23.36s fills
extraction. Per-fill engine cost fell 3107 → 1495 us/fill; per-fill
extraction cost fell 1481 → 175 us/fill. Phase-separated peer-benchmark
engine ratio 1.74x → 1.12x Backtrader; total wall ratio 1.50x. See the
v0.1.8.9 packet and the 2026-05-31 LDG-2476 entry's Batch 8 closeout
addendum for the substrate / read-path / ephemeral-mode residuals that
forward into the v0.1.8.10 spike round.

<a id="resolved-014"></a>

### 2026-06-03 [optimization] v0.1.8.10 single-core substrate and B2 closeout - shipped v0.1.8.10

The v0.1.8.10 cycle closed the v0.1.8.x single-core arc with ephemeral
subphase telemetry, matrix-canonical fold substrate and strategy accessors,
event-preserving fold-owned FIFO accounting, yyjsonr options hoisting, a B2
compiled spot-FIFO measurement gate, scoped public memory-backed sweep opt-in,
per-lane attribution, and workload-grid / peer-benchmark measurement closeout.
Default execution remains canonical R. Durable compiled integration,
non-spot compiled accounting, target risk, walk-forward, cost/liquidity, OMS,
and public benchmark claims remain deferred. See the v0.1.8.10 packet.

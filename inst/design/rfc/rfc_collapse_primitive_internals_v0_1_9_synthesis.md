# RFC Synthesis: Primitive Internals And Conditional collapse Acceleration

**Status:** Accepted synthesis - binding planning direction for v0.1.9 and
later primitive-internals work. Does not amend the active v0.1.8.3 implementation
packet.
**Date:** 2026-05-25
**Author:** Codex
**Thread:**

- `inst/design/rfc/rfc_collapse_primitive_internals_v0_1_9.md`
- `inst/design/rfc/rfc_collapse_primitive_internals_v0_1_9_response.md`
- `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `inst/design/spikes/ledgr_v0_1_8_3_pulse_view_construction/pulse_view_construction_report.md`
- `inst/design/spikes/ledgr_v0_1_8_3_sweep_optimization/post_change_report.md`
- LDG-2403 persistent-versus-memory accounting parity gate.
- LDG-2413 pulse-context data model consolidation.

---

## 1. Decision Summary

Accept primitive internals as the architectural direction. The core decision is
not whether ledgr should add `collapse`; it is that ledgr should stop treating
`data.frame` objects as the default internal runtime representation.

The accepted internal discipline is:

```text
primitive internal state
  -> centralized public-boundary helper
  -> data.frame-shaped public object
```

`collapse` remains a conditional acceleration layer. It is not added to
`Imports` up front, and it is not pulled into the already-shipped LDG-2413 pulse
view path during v0.1.8.3. ledgr may import `collapse` later only after a
non-Phase-A production surface proves measured value and passes determinism and
parity gates.

This synthesis binds the v0.1.9 planning scope:

- write the primitive-internals developer guide;
- run a deterministic `collapse` wrapper spike;
- run a Phase B event-boundary micro-profile;
- run a Phase C.1 safe cumulative reconstruction parity spike.

Implementation tickets for Phase B or Phase C.1 belong to v0.1.9.x unless the
spikes complete early and the maintainer explicitly pulls one forward.

---

## 2. Bound Architecture Rule

Future ledgr internals should prefer:

- numeric matrices for instrument x pulse numeric payloads;
- atomic vectors for homogeneous columns and series;
- named lists for heterogeneous records and keyed collections;
- plain lists for event rows, result rows, and internal view records.

Public APIs may still expose `data.frame` or tibble-shaped objects. The public
shape is a boundary contract, not a reason to keep data.frames as hot-path
internal state.

The boundary conversion must be centralized. A future helper file such as
`R/internal-views.R` should own:

- column order;
- row.names construction;
- class chains;
- timestamp type normalization;
- optional `collapse::qDF()` use if `collapse` is later imported.

Do not scatter ad hoc `structure(..., class = "data.frame")`, `data.frame()`,
or `as.data.frame()` boundary code across implementation tickets.

---

## 3. Required Developer Guide

v0.1.9 must include a short architecture guide before broad implementation
starts:

```text
inst/design/architecture/primitive_internals.md
```

The guide must define:

- allowed primitive internal shapes;
- when an internal helper may accept or return a `data.frame`;
- how public boundary helpers preserve schema, row names, class, and timestamp
  behavior;
- how state-leak and parity tests should be written for boundary rewrites;
- how optional acceleration packages must be wrapped;
- how this discipline interacts with DuckDB-backed storage and future compiled
  fold work.

All v0.1.9.x implementation tickets for primitive-internals conversion must
depend on this guide.

---

## 4. collapse Dependency Policy

Do not add `collapse` to `Imports` at the start of v0.1.9.

`collapse` may be added only after all of these gates pass:

1. The deterministic wrapper spike clears.
2. At least one non-Phase-A production surface shows clear measured value.
3. Relevant parity tests pass under hostile caller-side collapse settings.

"Clear measured value" means either Phase B or Phase C.1 shows more than 5%
wall-clock improvement on the LDG-2402 reference workload with parity intact.
The 5% threshold is a dependency gate, not a per-ticket success rule.

If accepted, `collapse` must be an `Imports` dependency. Do not use
`Suggests` plus conditional production paths. Deterministic execution must not
depend on whether an optional acceleration package happens to be installed.

Initial version policy, if imported:

```text
collapse (>= 2.1.7)
```

Use no upper bound unless a later release breaks parity. Record the tested
version in the adoption spike and follow-up measurement reports.

---

## 5. Deterministic Wrapper Spike

The first `collapse`-specific v0.1.9 task is a spike, not a production rewrite.
It must produce:

- `ledgr_with_collapse_deterministic()` implemented in spike form;
- tests proving caller-side `collapse::set_collapse()` state is restored after
  success;
- tests proving caller-side `collapse::set_collapse()` state is restored after
  error;
- tests proving ledgr output is independent of caller-side collapse settings;
- wrapper overhead measurement.

The wrapper must set and restore only the settings ledgr controls:

```r
changed_options <- c("nthreads", "na.rm", "sort", "stable.algo")
previous <- collapse::get_collapse(changed_options)
collapse::set_collapse(
  nthreads = 1L,
  na.rm = FALSE,
  sort = TRUE,
  stable.algo = TRUE
)
on.exit(do.call(collapse::set_collapse, previous), add = TRUE)
```

The hostile-settings fixture must include:

```r
collapse::set_collapse(
  nthreads = parallel::detectCores(),
  na.rm = TRUE,
  sort = FALSE,
  stable.algo = FALSE
)
```

Then run ledgr parity fixtures through the wrapper and assert that ledgr outputs
match the base-R reference. The test must also assert that the caller's hostile
collapse settings are restored after ledgr returns.

Do not mutate collapse defaults at package load time.

---

## 6. Phase Scope

### Phase A: Pulse Views

Closed for v0.1.8.3. LDG-2413 shipped the base split implementation and
delivered the cycle's measured win.

Do not reopen Phase A just to chase `collapse::rsplit()`. If `collapse` is
imported later for Phase B or C.1, revisiting Phase A is allowed as an
incidental follow-up. It should be a small measured patch, not a dependency
justification.

### Phase B: Event Boundary And Buffer Assembly

Phase B is a v0.1.9 measurement target. It is not automatically an
implementation ticket.

The micro-profile must decompose the current event path into:

- primitive list construction;
- `ledgr_event_row_df()` / list-to-data.frame conversion;
- output handler append and row-binding work;
- `meta_json` serialization.

Phase B targets the data-frame boundary and buffer assembly:

```text
fill intent
  -> primitive event row list
  -> primitive event buffer
  -> data.frame only at flush / persistence / public result boundary
```

`meta_json` optimization is not Phase B scope. Serialization belongs with typed
event work, including LDG-2410 or a later event-shape RFC. The Phase B
micro-profile may report `meta_json` cost, but Phase B must not silently expand
into serialization redesign.

If the micro-profile shows a material boundary cost, a v0.1.9.x implementation
ticket may replace per-fill data-frame boundary work with primitive buffering
and bulk materialization.

### Phase C.1: Safe Cumulative Reconstruction

Phase C.1 is a v0.1.9 parity and determinism spike target. Candidate surfaces:

- cash curve from cash deltas;
- per-instrument position curves from position deltas;
- equity curve from cash plus positions value;
- grouped cumulative summaries with explicit grouping and ordering.

The spike must compare base-R and collapse-backed cumulative work under LDG-2403
fixtures and adversarial cumulative fixtures.

Gate for any production implementation:

- LDG-2403 parity passes;
- max absolute drift is less than 1e-12 for accounting-adjacent outputs;
- hostile caller-side collapse settings do not affect ledgr outputs;
- caller collapse settings are restored after success and error.

### Phase C.2: FIFO Lot Replay

Out of scope.

`ledgr_lot_apply_event()` and realized/unrealized PnL replay are sequential,
stateful, and parity-critical. A vectorized FIFO algorithm may be possible, but
it requires a separate RFC with an explicit equivalence proof and parity suite.

### Phase D: Sweep Result Assembly

Not core v0.1.9 scope.

Phase D may be revisited after `collapse` is imported for Phase B or C.1, or if
a base-R primitive rewrite is clearly low-risk. It must not justify the
dependency by itself.

### Phase E: Metric Computation And Comparison

Opportunistic only.

Do not cut a focused Phase E ticket unless a later residual report shows metric
table assembly as a material frame. Public metric outputs and metric-context
identity must remain stable.

---

## 7. Verification Requirements

Every primitive-internals implementation ticket must include:

- public schema parity for affected outputs;
- state-leak tests where public views can be captured or mutated;
- LDG-2403 accounting parity when accounting or reconstruction is touched;
- fingerprint stability tests when feature, metric, or provenance payloads are
  touched;
- before/after performance measurement against the relevant LDG-2402 workload;
- residual profile notes if the ticket claims performance improvement.

Every `collapse`-backed ticket must also include:

- hostile `collapse::set_collapse()` fixture coverage;
- wrapper success and error restoration tests;
- deterministic output tests under caller-side collapse settings;
- collapse version recorded in the measurement artifact.

Measurement gates are required, but they are not rigid per-ticket thresholds.
A phase may ship if it materially improves performance with parity intact, or
if it simplifies architecture with no material regression and reduces future
implementation risk. The `collapse` dependency gate is stricter: more than 5%
reference workload wall-clock improvement from one non-Phase-A production
surface.

---

## 8. Non-Goals

This synthesis does not authorize:

- a second execution engine;
- vectorized user strategy execution;
- public `ctx` field type changes;
- FIFO lot replay redesign;
- compiled C, C++, Fortran, or Rust fold kernels;
- DuckDB-backed projection storage;
- active aliases or alias-map identity;
- public ML training-frame APIs;
- `collapse` as `Suggests` with conditional production behavior;
- package-load mutation of caller collapse state;
- weakening snapshot, no-lookahead, FIFO accounting, metric-context, or
  execution-seed contracts.

---

## 9. Required Document Updates

When this synthesis is promoted into a v0.1.9 packet, update:

- the v0.1.9 spec packet with the cycle scope in Section 1 of this synthesis;
- `tickets.yml` with separate tickets for the developer guide, deterministic
  wrapper spike, Phase B micro-profile, and Phase C.1 parity spike;
- `inst/design/architecture/primitive_internals.md`;
- `inst/design/horizon.md` to link the v0.1.8.3 pulse-view spike to this
  accepted planning direction;
- `DESCRIPTION` only if and when the collapse dependency gate clears;
- `NEWS.md` only when user-visible performance or dependency behavior changes.

Do not amend the active v0.1.8.3 ticket packet solely because this synthesis is
accepted. v0.1.8.3 already shipped the base split LDG-2413 path.

---

## 10. Sequencing

Recommended sequence:

1. Finish v0.1.8.3 residual measurement and close the current optimization
   cycle.
2. Start v0.1.9 planning with `primitive_internals.md`.
3. Run the deterministic wrapper spike.
4. Run Phase B micro-profile.
5. Run Phase C.1 parity and floating-point spike.
6. Decide whether `collapse` has cleared the dependency gate.
7. Cut implementation tickets for v0.1.9.x only after the gates name the
   winning surfaces.

This keeps ledgr's correctness posture intact while preserving the architectural
lesson from LDG-2413: primitive internal shapes compound across R performance,
DuckDB storage, and any future compiled fold core.

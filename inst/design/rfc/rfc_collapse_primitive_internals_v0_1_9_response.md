# RFC Response: Collapse-Backed Primitive Internals And Accounting Acceleration

**Status:** Reviewer response - accepts primitive internals as an architecture
discipline, defers `collapse` as an Imports dependency until a measured
non-Phase-A production surface justifies it, and narrows the first implementation
scope to documentation, determinism scaffolding, and event/reconstruction
spikes.
**Date:** 2026-05-25
**RFC:** `inst/design/rfc/rfc_collapse_primitive_internals_v0_1_9.md`
**Reviewer:** Codex

---

## Overall Assessment

The seed identifies the right strategic lesson from LDG-2413: the important
move is not "use `collapse`" but "stop treating `data.frame` as ledgr's
internal runtime representation." LDG-2413 succeeded because it moved a
data-frame-heavy construction pattern out of the pulse loop and then replaced
many tiny `data.frame()` calls with one bulk table plus a split. That points to
a broader internal design discipline:

```text
primitive internal state
  -> narrow boundary helper
  -> public data.frame-shaped object
```

That discipline is worth adopting independently of the dependency decision.
`collapse` is promising because it is optimized for the same primitive-object
style, but the dependency decision should follow measured value on a real
production surface, not the pulse-view spike alone. v0.1.8.3 already shipped the
base-R split path and delivered the cycle's speed win.

The response therefore accepts the architectural direction and rejects an
up-front `collapse` import. The near-term plan should be: document the
primitive-internals discipline, build determinism scaffolding for possible
`collapse` use, then test one or two non-Phase-A surfaces with parity and
measurement gates.

---

## Accepted Positions

### 1. Primitive Internals Are The Real Decision

Accept the primitive-internals discipline as a multi-cycle architecture rule:

- matrices for instrument x pulse numeric payloads;
- atomic vectors for homogeneous columns and series;
- named lists for heterogeneous records and keyed collections;
- public `data.frame` objects only at documented user-facing boundaries.

This should not be a code-review vibe. It needs a short developer document, for
example `inst/design/architecture/primitive_internals.md`, with concrete rules:

- when an internal helper may accept or return `data.frame`;
- how to build public boundary views;
- how to preserve column order, row names, classes, and timestamp types;
- how to test parity and state-leak behavior when replacing a data-frame path;
- how optional acceleration packages such as `collapse` must be wrapped.

The guide should be written before broad implementation work starts, because it
will prevent every ticket from relitigating the same boundary rules.

### 2. Do Not Import collapse Up Front

Do not add `collapse` to `Imports` at the start of v0.1.9. Add it only after:

- a deterministic wrapper spike proves ledgr can isolate caller-side
  `collapse::set_collapse()` state;
- at least one non-Phase-A production surface shows clear measured value;
- the relevant parity tests pass under hostile caller-side collapse settings.

Once ledgr adopts `collapse`, it should be an `Imports` dependency, not a
`Suggests` dependency with conditional production paths. Deterministic execution
should not depend on whether an optional acceleration package happens to be
installed.

### 3. Phase A Is Done For Now

Phase A pulse-view construction shipped in LDG-2413 with base split and delivered
the v0.1.8.3 speed win. Do not reopen it in v0.1.9 solely to chase the remaining
`collapse::rsplit()` delta.

If `collapse` is imported later for Phases B-D, then revisiting Phase A is a
reasonable incidental follow-up. It should not be the justification for the
dependency.

### 4. Collapse Requires A Scoped Determinism Wrapper

Accept the RFC's scoped wrapper direction. Prefer per-entry-point wrapping over
load-time mutation:

```r
ledgr_with_collapse_deterministic({
  # collapse-backed work
})
```

Do not set collapse defaults at package load time. That would alter caller
state and make ledgr a poor citizen in shared R sessions. Each ledgr helper that
uses `collapse` should set and restore only the relevant collapse settings
around its own work:

- `nthreads`;
- `na.rm`;
- `sort`;
- `stable.algo`.

Where a function accepts relevant arguments directly, pass them explicitly too.
The wrapper is still required because key functions such as `rsplit()`,
`rowbind()`, and `qDF()` do not expose every relevant option per call.

### 5. Phase B Should Target Event Boundaries

Phase B should keep fill construction primitive as long as possible. The first
candidate implementation should target the output-handler boundary:

```text
fill intent
  -> primitive event row list
  -> primitive event buffer
  -> data.frame only at flush / persistence / public result boundary
```

Do not force data-frame materialization per fill. For memory sweeps, a later
step may allow reconstruction helpers to consume primitive event buffers
directly, but that should not be required for the first Phase B ticket.

Before implementation, run a micro-profile that decomposes the current
`ledgr_fill_event_row` profile share into:

- primitive list construction;
- `ledgr_event_row_df()` / boundary data-frame conversion;
- handler append / row-binding work;
- `meta_json` serialization.

That decomposition decides whether Phase B is worth implementing with base R,
`collapse`, or not at all.

### 6. Phase C Must Stay Away From FIFO Replay

Accept Phase C.1 only: safe cumulative reconstruction. Candidate surfaces:

- cash curve from cash deltas;
- position curve from per-instrument deltas;
- equity curve from cash plus positions value;
- grouped cumulative summaries where order and grouping are explicit.

Keep FIFO lot replay out of this RFC. `ledgr_lot_apply_event()` is sequential,
stateful, and directly tied to LDG-2403 parity. A vectorized FIFO algorithm may
be possible, but it is a separate design problem with its own proof burden.

For any collapse-backed C.1 experiment, require a floating-point parity spike
before production code:

- LDG-2403 parity fixtures;
- opening positions;
- same-timestamp events;
- sparse events;
- multi-instrument cumulative deltas;
- hostile caller-side `collapse::set_collapse()` state;
- max absolute drift below `1e-12` for accounting-adjacent outputs.

### 7. Phase D And E Are Not Core v0.1.9 Scope

Phase D sweep result assembly is plausible but secondary. It should not be a
driver for importing `collapse`. Pull it in only after B or C.1 justifies the
dependency, or if a base-R primitive rewrite is obviously low-risk.

Phase E metric/comparison table construction is opportunistic. It is not a
focused ticket unless a later residual report shows metric table assembly in a
material frame.

---

## Answers To Open Questions

### 1. collapse Imports Decision

Evaluate phase-by-phase. Do not import `collapse` up front. Add it only when a
non-Phase-A surface proves measured production value and passes determinism
tests. Once accepted, make it `Imports`, not `Suggests`.

### 2. Phase B Boundary

Target the output-handler boundary first. Keep per-fill construction as
primitive lists and batch materialize at flush, persistence, or public result
boundaries. If measurement shows post-fold summary helpers can consume primitive
events directly, that becomes a later extension.

### 3. Floating-Point Determinism Evidence

Require a dedicated spike before using `collapse` in accounting-adjacent paths.
Gate on LDG-2403 fixtures plus adversarial cumulative cases. Expected equality
should remain exact; otherwise max absolute drift must be below `1e-12`, leaving
headroom under the existing `1e-10` parity tolerance.

### 4. v0.1.9 Phase Scope

Recommended v0.1.9 scope:

- primitive-internals developer guide;
- deterministic collapse wrapper spike;
- Phase B event-boundary micro-profile and, if justified, implementation;
- Phase C.1 safe cumulative reconstruction spike or implementation if the spike
  clears.

Defer Phase D and Phase E unless they become low-risk follow-ups after the
dependency question is already settled.

### 5. collapse Version Pin

Use a conservative lower bound at the tested version when the dependency is
adopted, for example `collapse (>= 2.1.7)`, and record the tested version in the
spike/report. Avoid an upper bound unless a future collapse release breaks
parity. ledgr is still pre-CRAN, so over-constraining too early is unnecessary.

### 6. Primitive-Internals Documentation

Yes. Write `inst/design/architecture/primitive_internals.md`. This is
load-bearing architecture, not only a code style preference.

### 7. Wrapper Architecture

Use per-entry-point scoped wrapping. Do not use a package-level load-time
`set_collapse()` reset. The wrapper should restore caller state even on error
and should only touch the collapse settings ledgr needs to control.

### 8. Additional Parity Fixtures

LDG-2403 parity is necessary but not sufficient for Phase C.1. Add
collapse-specific reconstruction fixtures for:

- sparse events;
- same-timestamp event ordering;
- opening positions;
- partial closes;
- multi-instrument deltas;
- missing or empty event streams;
- hostile caller-side collapse settings.

### 9. as.data.frame Methods

No public `as.data.frame.ledgr_*` change is required by default. Public methods
should continue to operate on public objects. The primitive-internals guide
should require boundary helpers so public objects are already data-frame-shaped
before those methods see them.

### 10. Measurement Gates

Use per-phase measurement gates, but not rigid thresholds. Each phase must
report before/after wall-clock and profile deltas. A phase should ship if it
either:

- materially improves performance with parity intact; or
- simplifies architecture with no material regression and reduces future
  implementation risk.

The `collapse` dependency itself should require measured value from at least one
non-Phase-A production surface.

---

## Recommended Synthesis Shape

The synthesis should bind these positions:

1. Primitive internals accepted as architecture discipline.
2. Developer guide required before broad refactors.
3. `collapse` not imported up front.
4. Deterministic wrapper spike required before any production collapse use.
5. Phase A not reopened unless `collapse` is already imported for other phases.
6. Phase B and C.1 are the only serious near-term implementation candidates.
7. FIFO replay, Rust, DuckDB-backed projection storage, active aliases, and ML
   export remain out of scope for this RFC.
8. Per-phase parity and measurement reports are required.

That gives ledgr a disciplined path: adopt the primitive-object lesson now,
prove the dependency before taking it, and keep accounting correctness ahead of
speed.

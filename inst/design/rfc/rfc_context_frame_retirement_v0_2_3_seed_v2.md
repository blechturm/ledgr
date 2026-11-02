# RFC Seed v2: Context Frame Retirement

- Status: Seed v2 after Type 2 response and maintainer decisions; synthesis is next
- Author: Codex
- Date: 2026-11-03
- Target window: v0.2.3, macro-plan WS6
- Baseline reviewed: `e3bb4cec` (`release/v0.2.3`)
- Supersedes: `rfc_context_frame_retirement_v0_2_3_seed.md`
- Inputs: Type 2 response, response review, accepted strategy-context and
  strategy-authoring syntheses, current-tree response probe, current contracts
  and current P2/context/inspection code

This RFC uses "first implementation" only for this retirement, not for a
ledgr 1.0 milestone. ledgr is pre-CRAN and has no external user corpus that
requires the four experimental context fields to remain callable.

## 1. Question And Answer

How should ledgr remove the eager current-pulse frames while preserving exact
point-in-time inspection and one flat decision axis?

Retire `ctx$bars`, `ctx$feature_table`, `ctx$features_wide` and `ctx$bar(id)`
without aliases. Strategies continue to read flat named columns. Existing
`ledgr_pulse_features()` and `ledgr_pulse_wide()` remain explicit inspection
boundaries, rebuilt from the pulse-frozen flat context. No current-bars helper,
generic frame DSL, replacement feature matrix, cache or provenance layer is
added.

The change owns P2 context construction and current-pulse inspection. It does
not change P1 observation, causal history, indicator calculation, the decision
axis, schedules, target meaning, fills, P3-P5, snapshot identity, durable
evidence or result readers.

## 2. Why Retirement Is Due

The strategy-context synthesis retained the frames because it lacked a
complete inspection replacement. It required this seed to bind inspected
state, axis, cutoff, freezing and materialization. Cut 7 then made runtime and
interactive contexts flat, lazy and pulse-frozen.

Current P2 still builds a bars frame and an instrument-by-feature frame before
every strategy call. It also carries a schema-only long frame and a private
closure able to materialize the actual long table. These representations use
different timestamp and feature-name vocabularies from the flat context.

No current vignette teaches the four fields. Remaining consumers are tests,
internal adapters and benchmark recipes. Removing them simplifies an
experimental surface; it does not withdraw a taught workflow.

## 3. Evidence And Its Boundary

The October 2026 context-frame probe is historical. Two functions it used no
longer exist, so its 41-microsecond manifestation figure is not evidence about
the current P2 implementation.

The runnable current-tree probe is
`dev/spikes/ctx_frame_views/response_probe.R`. On Windows, R 4.6.1, collapse
2.1.8 and baseline `e3bb4cec`, its 600-instrument, three-feature fixture found:

- 409.85 microseconds for the isolated current P2 frame block;
- 1.70 microseconds to construct the corresponding primitive binding list;
- 163.75 microseconds for a three-feature flat matrix;
- about 0.21 seconds for active-map `ledgr_pulse_features()`; and
- about 0.85 seconds for active-map `ledgr_pulse_wide()`.

An independent response-review run reproduced the behavior and timing order.
These are descriptive one-host measurements. The 409.85-to-1.70 comparison is
an isolated removed-work comparison, not a whole-P2 or whole-run speedup.
Macro-plan rule 16 forbids a broad timing gate here.

The probe also established current inconsistencies that v2 changes openly:
runtime and experiment-form contexts ignore the active alias map during
inspection; snapshot-and-universe inspection alone carries alias metadata;
mapped and unmapped long output use different instrument order; and a known
mapped feature refuses on an empty decision axis.

## 4. Bound Decisions

### D1. Retire the four fields without compatibility

After WS6, the four names are absent from `names(ctx)` and `str(ctx)`. `$` and
`[[` reads fail with `ledgr_unknown_context_field`. No active binding, warning
period, fallback or compatibility argument keeps them working.

The names stay reserved against feature aliases. A feature named `bars` must
not acquire the structural meaning of a removed context field. The package is
pre-CRAN; retaining hidden aliases would preserve two representations and make
the removal unverifiable.

One value uses ordinary named indexing, such as `ctx$close[[id]]`. A complete
current cross-section uses the flat columns already aligned to
`ctx$universe`.

### D2. Add no current-bars helper

The maintainer accepted response decision M1(a). There is no
`ledgr_pulse_bars()`.

Its proposed columns added no information: instrument identity is the context
axis, the cutoff is `ctx$ts_utc`, OHLCV are flat columns, `is_synthetic` is
always false and the old `gap_type` was only the `is.na(ctx$close)` mask. The
label `MISSING_EXPECTED_SESSION` did not consult the expected-session mask and
was therefore too strong.

Documentation may say that `is.na(ctx$close)` means no observed bar at that
pulse. It must not infer why the observation is absent. Causal missingness,
expected-session evidence and carry treatment remain history concerns.

### D3. Inspection helpers are not strategy-performance APIs

The maintainer accepted response decision M2(a).
`ledgr_pulse_features()` and `ledgr_pulse_wide()` accept a valid pulse context,
including a retained in-process pulse-frozen context. They make no durability,
serialization or decision-time cost promise.

Strategies read flat columns. The helpers are read-only inspection boundaries
and must still follow the optimization manual: typed columns are allocated
once, results are stamped once, and no nested instrument-feature row loop,
`rbind()`, repeated data-frame growth, per-row timestamp formatting or
repeated ID scan is permitted. "No speed promise" does not authorize a known
scale-growing implementation.

### D4. One alias source, one row order and honest empty output

The prepared resolver is the sole source of active aliases for all context
entrances.

- With an active or explicit map, `ledgr_pulse_features()` reports the stable
  alias and concrete feature ID, and `ledgr_pulse_wide()` uses aliases in its
  feature keys.
- Without a map, both helpers use concrete engine IDs.
- Explicit maps retain their collision, memo and unknown-ID rules.
- Long rows follow Daxis instrument order. Feature order is map declaration
  order when mapped and radix feature-ID order otherwise.

Map validity is checked against the resolver's registered features, not the
rows present at the pulse. A known mapped feature over an empty Daxis returns
the typed empty long result and a wide result with only its metadata columns.
An unknown feature still refuses.

This deliberately changes the current runtime alias omission, the unmapped
alphabetical instrument order and the mapped-empty refusal.

### D5. Remove inspection-only metadata from contexts

Snapshot-and-universe inspection no longer adds `feature_params`,
`active_alias_map`, `alias_map_json`, `alias_map_hash` or
`alias_map_version` to the returned context. `feature_params` remains an input
to validation and resolution. The prepared resolver retains the resolved
run-local lookup needed by flat reads and inspection.

No production reader consumes those five context fields, and no contract made
them public. Their removal gives runtime, experiment-form and
snapshot-and-universe contexts the same names for the same state. It also
removes the inspection path's redundant alias-map hash.

### D6. P2 binds primitives and manifests no frame

P1 remains the sole observer. P2 receives its primitive packet and binds the
flat context. It no longer:

- calls the current bar-frame constructor for strategy context;
- builds the current instrument-by-feature frame;
- stores `bars`, `feature_table` or `features_wide`;
- installs `.feature_table_current`; or
- retains `observed` solely to reconstruct the rejected bars view.

P2 binds aligned OHLCV columns, portfolio and availability state, feature
lookup metadata and the current projection ordinal into the existing private
pulse lookup. The lookup retains a numeric cutoff so inspection never reparses
the public timestamp string. Flat columns remain built at most once per
context.

`ledgr_pulse_snapshot()` stops forcing a long table. Context printing counts
the Daxis and prepared feature names. Strategy-error wrapping uses the
resolver's prepared availability message. Preflight drops the retired private
carrier names; no new preflight exception is needed for exported helpers.

### D7. A retained context is frozen only in process

The context owns or closes over pulse-frozen values restricted to its Daxis
and cutoff. A retained in-process context and helper result cannot observe
later book state or reusable fold buffers. A private closure may retain
read-only prepared matrices plus one pulse ordinal.

This is not a promise that contexts serialize, persist, reopen or survive a
process boundary. Durable ledgr evidence remains the run and its native result
surfaces.

### D8. The private constructor is a fixture adapter, not compatibility

The private `ledgr_pulse_context()` constructor may continue accepting bar and
feature frames as test-fixture input. It validates and vectorizes them once
into the same aligned primitive lookup used by real contexts, then discards
the frames. Its timestamp validation uses one vectorized normalization call.

P2 does not call this adapter. Its result neither stores nor lazily rebuilds a
retired field. This is a named test seam, not a public or runtime compatibility
contract. Tests whose subject is an inspection helper use a real run or pulse
inspection context.

### D9. Prepare readable feature names once

The current strict `$` path recomputes the run-constant aliases and concrete
IDs on every read. WS6 prepares the readable-name set once with the resolver
and reuses it for enumeration and lookup. The cut must structurally detect
restoration of per-read feature-name assembly.

This is part of completing the flat migration: the benchmark reads several
feature columns per pulse, so postponing the defect would multiply work at the
wrong frequency.

### D10. Inspection does not cross the trust boundary again

The pulse context is already downstream of snapshot verification and causal
preparation. Helpers accept no timestamp, universe, snapshot, policy or
connection. They cannot widen the Daxis or advance the cutoff.

They perform only shape checks introduced by manifestation. They do not seal,
hash, authenticate, query DuckDB or attach provenance. Returned frames are
ephemeral R values, not durable evidence.

## 5. Inspection Results

`ledgr_pulse_features()` keeps its public signature and columns:

```
ts_utc, instrument_id, feature_id, feature_value, alias
```

It manifests one long frame from Daxis-aligned flat vectors and the prepared
resolver. It does not read a long-table carrier.

`ledgr_pulse_wide()` keeps its existing one-row external-inspection layout and
stable names `{instrument_id}__ohlcv_{field}` and
`{instrument_id}__feature_{key}`. It is not an
instrument-rows-by-features strategy matrix. Wide report columns retain their
existing radix instrument-block ordering.

There is no successor to `ctx$features_wide`. A strategy needing a
cross-sectional feature matrix assembles its declared flat feature columns
with ordinary named R operations. Multi-period panels remain exclusively with
`ledgr_history_frame()` and `ledgr_history_matrix()`.

## 6. Migration And Teaching

Reference documentation teaches:

- flat named columns for strategy decisions;
- `ledgr_pulse_features()` and `ledgr_pulse_wide()` for explicit inspection;
- ordinary named-column assembly for a cross-sectional strategy matrix; and
- history helpers for causal windows.

Tests of removed representation are deleted or rewritten with the stated
reason that the experimental representation was retired. Inspection tests use
the public helpers over real contexts. Internal constructor tests retain only
the D8 fixture contract.

The shared benchmark recipe reads its declared flat feature columns. The
frozen peer oracle is not re-recorded: targets, fills and public results remain
equal, while strategy/config source identity is the sole expected exclusion.
The migration must not introduce another frame manifestation.

## 7. Contract Amendments

Acceptance authorizes these amendments alongside implementation:

| Contract group | Amendment |
| --- | --- |
| Pulse Data And Axis-Aligned Accessors | Remove the four retained fields, keep their names reserved and bind the primitive-only P2 carrier. |
| Prepared Views And Eligibility | Remove prepared-frame availability; eligibility and frozen-holding semantics remain unchanged. |
| Inspection And Signal Views | Rebase feature and wide inspection on the pulse-frozen flat context; bind alias source, row order, empty-axis behavior and the no-performance-promise boundary. |
| Documentation Strategy Context | Remove the old members and distinguish flat pulse data, current-pulse inspection and causal history. |

No store schema, fingerprint, snapshot hash, config identity or result schema
changes. Strategy source that used an experimental retired field receives its
ordinary new strategy identity after rewrite.

## 8. Detecting Evidence Required By The Ticket Cut

1. Runtime and both pulse-snapshot forms omit all four retired names. `$` and
   `[[` refuse them, and the names remain reserved against feature aliases.
2. The export census contains no bars helper or generic context-frame helper.
3. A real declared-session callback with a held nonmember, missing bar and
   active map proves flat OHLCV parity, alias consistency and Daxis order.
4. Runtime, experiment-form and snapshot-form contexts have name parity and
   none exposes the five D5 metadata fields.
5. Known mapped features over an empty Daxis return typed empty results;
   unknown IDs and collisions still refuse with the established classes.
6. A retained in-process context and its helper results remain unchanged after
   later pulses. No persistence or serialization claim is asserted.
7. A strategy reading only flat columns constructs no current bar, long or
   wide frame. Restoring either eager P2 frame constructor fails a registered
   structural or counted-constructor witness.
8. Restoring nested row assembly, `rbind()`, repeated frame growth or per-row
   timestamp formatting in either inspection helper fails a shape witness.
9. The private fixture constructor accepts its named frame inputs, normalizes
   once, stores no frame and is absent from P2.
10. Restoring per-read assembly of aliases and engine IDs fails a structural
    detector; the prepared set is demonstrably reused.
11. Strategy errors and `print(ctx)` report available features and Daxis size
    without constructing a frame or hash.
12. The migrated peer strategy reproduces targets, fills and public results;
    only strategy/config source identity differs from the frozen oracle.
13. The close review walks all seven optimization shapes and confirms no
    hashing, sealing, database query or provenance work entered P2 or the
    helpers.

The registered suites, documentation contracts, fixture lane and package
check remain required. The current response probe records descriptive clocks;
no broad timing ratio is a WS6 acceptance gate.

## 9. Rejected Alternatives

| Alternative | Reason |
| --- | --- |
| Add `ledgr_pulse_bars()` | It adds no information and preserves misleading gap labels. |
| Keep lazy compatibility fields | It retains two representations and makes retirement unverifiable. |
| Reintroduce `ctx$vec` | It contradicts the accepted flat context. |
| Use one-row history | History has selection, evidence and missingness semantics that current-pulse inspection does not. |
| Add a generic frame/layout DSL | No observed workflow requires it. |
| Replace `features_wide` with another matrix API | Flat feature vectors already provide the cross-sectional authority. |
| Promise callback-grade inspection performance | Strategies have the flat surface; inspection remains an explicit boundary. |
| Cache manifested frames | It restores retained memory and complicates frozen ownership without measured need. |
| Re-record the peer oracle | It would erase the source-identity boundary instead of explaining it. |
| Hash or seal helper results | The context is already downstream of the trust boundary. |

## 10. Scope And Next Stage

The ticket cut may choose ticket grain and private carrier names. It may not
add a bars helper, generic frame DSL, compatibility alias, durable context,
new history reader or helper performance contract without returning to Type 2.

The external-helper preflight obligation remains in its existing pipeline row.
Multi-feature historical panels remain with historical projection. The later
holistic core review may delete helpers made dead by WS6, but does not own this
public decision.

Next stage: decision synthesis by an author other than Codex, followed by Type
1 final review and maintainer acceptance. No ticket cut or implementation
starts from this seed.

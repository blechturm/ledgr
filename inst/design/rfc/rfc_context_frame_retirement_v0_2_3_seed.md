# RFC Seed: Context Frame Retirement

- Status: Seed v1; Type 2 response is next
- Author: Codex
- Date: 2026-11-02
- Target window: v0.2.3, macro-plan WS6
- Baseline reviewed: `e3bb4cec`
- Inputs: strategy-context synthesis Section 5, accepted strategy-authoring
  synthesis D1, context-frame probe, current contracts and current P2 code

This seed uses "first implementation" only for the frame-retirement change,
not for a ledgr 1.0 milestone. ledgr is pre-CRAN and has no external user
corpus that requires the four experimental context fields to remain callable.

## 1. Question And Boundary

How should ledgr remove the eager current-pulse frame fields from the strategy
context while preserving exact point-in-time inspection and the flat context's
single decision axis?

The fields are `ctx$bars`, `ctx$feature_table`, `ctx$features_wide` and
`ctx$bar(id)`. The change owns P2 context construction and the public pulse
inspection helpers. It does not change P1 observation, causal history,
indicator calculation, the decision axis, schedules, targets, fills, P3-P5,
snapshot identity, durable evidence or result readers.

## 2. Why The Cycle Is Due

The strategy-context synthesis retained the fields because no complete
inspection replacement existed. It required a focused seed to state what is
inspected, preserve axis and knowledge cutoff, keep captured views frozen and
locate materialization. The maintainer then decided to retire the fields in
the release after v0.2.2. Cut 7 supplied the missing prerequisite: runtime and
interactive contexts are now flat, lazy, pulse-frozen named views.

The old routing text expected builders over public `ctx$vec` primitives.
That is stale. Cut 7 retired `ctx$vec`; OHLCV, positions, eligibility and
features are now named flat columns (`R/pulse-context.R:39-50` and
`R/pulse-context.R:117-157`). WS6 must consume that accepted surface rather
than restore a second vector namespace.

Current P2 still constructs a bar data frame and a feature-wide data frame on
every decision pulse (`R/fold-engine.R:749-799`) before it calls the strategy.
It also carries a schema-only long feature frame and a private closure that can
materialize the real long frame (`R/pulse-context.R:380-462`). The validator,
error wrapper, pulse print and inspection functions still depend on these
representations.

The current-tree source census finds no vignette using any retired field.
Tests contain the remaining direct product expectations. The shared benchmark
still has four `ctx$features_wide` reads. Product code contains the adapters and
validation that keep the representations alive. This is cleanup of an
experimental surface, not preservation of a taught workflow.

## 3. Evidence And Its Limit

The 2026-10-04 probe used 757 pulses, 600 instruments and three features. It
found that:

- on-demand bars and wide feature frames matched the prepared frames at every
  pulse;
- bare-constructor manifestation cost about 41-43 microseconds per pulse for
  both frames together, around 0.2 percent of that run;
- the prepared views accounted for about 6-8 percent of R-heap peak; and
- the long feature table was already only one shared empty schema.

The micro-benchmark measured about 14 microseconds for bars, 12 for a wide
feature frame and 28 for a long feature table at 600 instruments and three
features. Base `data.frame()` was about ten times slower than the existing
bare constructor.

Those numbers show feasibility and shape, not a current performance promise.
The probe predates the flat context, typed carrier and history substrate. Its
bar fixture stored `gap_type` directly, while the current substrate stores one
`observed` plane and derives `gap_type`. WS6 therefore records current-tree
clocks but gates correctness structurally: no frame is built unless an
explicit boundary helper is called. Macro-plan rule 16 keeps timing out of an
ordinary cut gate until the named milestone.

## 4. Proposed Decision

Retire the four context fields without compatibility aliases. Keep the flat
named columns as the strategy surface. Manifest current-pulse data only through
explicit public pulse helpers:

```r
ledgr_pulse_bars(ctx)
ledgr_pulse_features(ctx, feature_map = NULL)
ledgr_pulse_wide(ctx, feature_map = NULL)
```

`ledgr_pulse_bars()` is the only new public helper. The other two already
exist and are the native inspection API. No generic `ledgr_context_frame()`,
layout DSL or replacement for `ctx$features_wide` is added.

Ordinary strategy code reads `ctx$close`, `ctx$volume` or a declared feature
column directly. A callback may call a pulse helper when an actual data frame
is the boundary it needs, but the package documentation does not teach frame
materialization as the default way to read one pulse.

## 5. The Retired Surface

After WS6:

- the four names are absent from `names(ctx)` and `str(ctx)`;
- `$` and `[[` reads of them fail with `ledgr_unknown_context_field`;
- no active binding, warning period, alias or missing-marker fallback keeps
  them working;
- the names remain reserved against feature aliases, because allowing a
  feature named `bars` to replace a retired structural meaning would be
  ambiguous; and
- the internal context constructor no longer takes or validates frame values.

The package is pre-CRAN. Keeping lazy fields for compatibility would retain
two public representations and make removal unverifiable. A targeted error may
name the explicit helper; it is guidance, not a compatibility path.

`ctx$bar(id)` receives no one-row replacement. One value is ordinary named
vector indexing, for example `ctx$close[[id]]`. A strategy needing the complete
current cross-section calls `ledgr_pulse_bars(ctx)` once.

## 6. Bar Manifestation

`ledgr_pulse_bars(pulse)` accepts one `ledgr_pulse_context` and returns a fresh
base data frame in decision-axis order with the existing columns and types:

```
instrument_id, ts_utc, open, high, low, close, volume,
gap_type, is_synthetic
```

`instrument_id` is `pulse$universe`; `ts_utc` repeats the pulse cutoff; the
five numeric fields equal the flat columns. `gap_type` is `NONE` where the
current substrate's pulse cell was observed and
`MISSING_EXPECTED_SESSION` otherwise. `is_synthetic` is always false, as it is
today: a policy-carried value is not a fabricated snapshot bar or execution
price. Empty axes keep the typed schema.

The helper does not read history, query DuckDB, reconstruct membership or
reapply missing-data policy. P1 has already selected the knowable pulse and
P2 has already fixed its decision axis. The private pulse lookup retains only
the aligned primitive `observed` vector needed for this existing disclosure.

The result owns its columns. Saving it at pulse t and then executing pulse
t+1 cannot change its values, names, row order or attributes.

## 7. Feature And Wide Inspection

`ledgr_pulse_features()` keeps its current public signature and result schema:
`ts_utc`, `instrument_id`, `feature_id`, `feature_value`, `alias`. It is rebuilt
over the prepared feature-name lookup and the flat pulse-frozen feature
columns. It no longer reads `ctx$feature_table` or
`ctx$.feature_table_current`.

Without an explicit map, an active alias map retains its current filtering and
alias behavior; without either map, every registered concrete feature is
returned. Explicit-map collision and unknown-ID rules stay unchanged. Rows
use decision-axis instrument order and stable map order, or radix feature-ID
order when no map defines one.

`ledgr_pulse_wide()` keeps its existing one-row external-inspection contract
and stable column names. It composes the same pulse-known bar and feature
values; it does not become the old instrument-rows-by-features frame. Its
existing radix instrument ordering remains a report-format rule, not the
context's positional axis.

An empty Daxis produces the typed zero-row bar and long-feature frames. The
wide inspection result retains its one metadata row (`ts_utc`, `cash`,
`equity`) and no instrument columns. Empty output does not bypass map or
argument validation.

Each helper allocates its typed column list once and stamps or converts the
result once. No nested instrument-by-feature row loop, repeated column growth,
`rbind()` or one-row data-frame construction is authorized. The implementation
uses prepared integer positions and block operations, not repeated ID matching.

There is no direct successor to `ctx$features_wide`. A cross-sectional
strategy already has named feature vectors on one Daxis. Adding another wide
strategy object would recreate the representation being removed. Multi-period
panels remain solely with `ledgr_history_frame()` and
`ledgr_history_matrix()`.

## 8. Cutoff, Authority And Trust

The pulse context supplied to a helper is the authority for the current view:

- its `ts_utc` is the knowledge cutoff;
- its `universe` is the complete Daxis for the view;
- its flat vectors are the values P1/P2 admitted at that cutoff; and
- its prepared feature resolver owns alias-first name resolution.

Helpers do not accept a timestamp, universe, snapshot, policy or connection.
They therefore cannot widen the axis or move the cutoff. For an
experiment-derived `ledgr_pulse_snapshot()`, they inspect the same context that
the run would pass to the callback. The snapshot-and-universe inspection form
has no causal history, but it still has one current pulse and may use these
current-pulse helpers.

The context is already downstream of snapshot verification and sealed-data
preparation. Pulse helpers perform shape checks needed for safe manifestation;
they do not seal, hash, authenticate or attach provenance. Repeating those
trust operations here would be both redundant and a violation of the prepared-
once boundary. Returned frames are ephemeral R values and never durable
evidence.

## 9. P2 And Internal Ownership

P1 remains the sole observer. P2 receives its primitive pulse packet and binds
the flat context. P2 no longer:

- calls `ledgr_history_bar_packet_frame()` for strategy context;
- calls `ledgr_projection_features_wide()` for strategy context;
- stores `bars`, `feature_table` or `features_wide` on the context; or
- installs `.feature_table_current`.

It instead binds aligned bar columns, `observed`, feature lookup metadata and
the current projection ordinal into the private pulse lookup already owned by
the flat context. Each public flat field remains built at most once per
context. Explicit frame helpers read those pulse-frozen values and manifest a
fresh result only when called.

`ledgr_pulse_snapshot()` stops forcing the private long table before return.
Context printing counts the decision axis and available feature names without
materializing a frame. Strategy-error wrapping names available features from
prepared resolver metadata. Validation checks primitive alignment rather than
reconstructing frames.

No mutable projection or fold buffer may be observable through a saved
context. A private closure may retain prepared read-only matrices and one
integer pulse ordinal, as the current feature resolver and history service do;
every supported read remains restricted to that context's Daxis and cutoff.

## 10. Migration And Teaching

There is no vignette migration for the retired fields because current
vignettes do not use them. Reference documentation removes them from the
context table and teaches:

- flat columns for normal strategy decisions;
- `ledgr_pulse_bars()` and `ledgr_pulse_features()` for explicit current-pulse
  frames; and
- `ledgr_history_frame()` / `ledgr_history_matrix()` for causal windows.

Tests that only assert the old representation are deleted or rewritten against
the flat-column authority. Tests of pulse inspection move to the explicit
helpers. The shared peer recipe moves from `ctx$features_wide` to its declared
flat feature columns; it must not materialize a frame merely to preserve old
benchmark source.

Internal manuals and help that still describe `feature_table` or
`features_wide` as context members are corrected in the same cut. The source
and documentation census must find no supported use after implementation.

## 11. Contract Changes

Acceptance authorizes these amendments alongside implementation:

| Contract group | Amendment |
| --- | --- |
| Pulse Data And Axis-Aligned Accessors | Remove the four retained fields; bind flat columns plus the explicit pulse helpers; keep the four names reserved. |
| Prepared Views And Eligibility | Replace prepared-frame availability with explicit manifestation and the unchanged eligibility rules. |
| Inspection And Signal Views | Add `ledgr_pulse_bars()`; rebase feature and wide inspection on the pulse-frozen flat context; bind cutoff, Daxis and freshness. |
| Strategy Preflight | Permit the exported pulse helpers as ordinary supported calls; private lookup access remains Tier 3. |
| Documentation Strategy Context | Remove the old members and distinguish current-pulse frames from causal history. |

No store schema, format fingerprint, snapshot hash, config identity or result
schema changes. Strategy source that used an experimental retired field must be
rewritten and therefore receives its ordinary new strategy identity.

## 12. Detecting Evidence Required By The Ticket Cut

1. **Surface removal.** Runtime and both pulse-snapshot forms omit all four
   names. `$` and `[[` refuse each one, while a feature alias using a reserved
   name refuses at declaration or context construction.
2. **Availability-aware parity.** In a real declared-session callback with a
   held nonmember, an observed member, a missing expected bar and an active
   feature map, `ledgr_pulse_bars()` matches the old bar schema and values and
   the existing feature/wide helpers match their pre-cut outputs.
3. **Bar evidence.** Flipping `observed` changes only `gap_type`; a carried
   price never changes `is_synthetic` or becomes an execution price. Empty
   Daxis keeps typed columns.
4. **Feature resolution.** Active aliases, concrete IDs, explicit maps,
   unknown IDs, empty axes and schema ordering remain detected. Removing the
   prepared resolver or using the full run axis must fail.
5. **Frozen values.** Save a context and all three helper results at pulse t,
   run a later pulse and verify byte-identical saved values. A reusable mutable
   column buffer must fail this block.
6. **No eager manifestation.** A strategy that reads only flat columns builds
   no bar, long-feature or wide-feature data frame. Calling one helper builds
   only its requested result. Restoring either P2 frame constructor must fail a
   registered structural or counted-constructor witness.
7. **Inspection parity.** `ledgr_pulse_snapshot(experiment, ...)` and the same
   run's first callback produce equal helper results. The minimal snapshot form
   works for current-pulse helpers and still refuses causal history.
8. **Error and print paths.** Strategy errors and `print(ctx)` report feature
   availability and axis size without forcing any frame.
9. **Peer recipe.** The migrated peer strategy produces the same targets,
   fills and public results; only the expected strategy/config source identity
   changes. It contains no replacement frame manifestation.
10. **Boundary review.** The close review walks the seven optimization shapes,
    confirms no hashing or identity work entered P2/helpers, and records
    current 600-by-three manifestation clocks as descriptive evidence only.
    Restoring row-wise feature assembly or repeated data-frame growth must fail
    a registered shape witness.

The ordinary registered suites, documentation contracts, fixture lane and
package check remain required by the cut. A broad timing ratio is not a WS6
acceptance gate under macro-plan rule 16.

## 13. Rejected Alternatives

| Alternative | Reason |
| --- | --- |
| Keep lazy active-binding fields | Preserves two public representations and makes access-triggered mutation harder to reason about. |
| Reintroduce `ctx$vec` as builder input | Contradicts the accepted flat context and Cut 7 removal. |
| Use `ledgr_history_frame(..., lookback = 1)` | History has different selection, evidence and policy semantics; current-pulse manifestation needs none of them. |
| Add `ledgr_context_frame()` with selectors/layouts | No observed strategy needs a generic current-pulse frame DSL; three native pulse helpers cover inspection. |
| Add a new instrument-by-feature wide helper | Flat feature vectors already provide the efficient cross-sectional surface; this would recreate `features_wide`. |
| Cache manifested frames on the context | Retains memory, complicates frozen-value ownership and gives no measured benefit for explicit inspection. |
| Hash or seal helper results | The verified context is the trust boundary; ephemeral views are not durable evidence. |
| Require collapse for manifestation | The existing bare constructor is faster in the recorded shape; use collapse only where a measured primitive improves the chosen block operation. |

## 14. Scope, Open Questions And Next Stage

This seed proposes no maintainer-level binary choice. The Type 2 response
should attack whether `ledgr_pulse_bars()` is necessary, whether reusing the
two existing inspection helpers is semantically complete, whether Daxis and
cutoff are actually frozen by the proposed carrier, and whether any current
consumer needs a frame that the proposal removes.

The spec cut may decide ticket grain, exact private carrier names and whether
the peer migration shares a ticket with surface removal. It may not add a
generic frame DSL, a compatibility alias, a durable artifact or another
history reader without returning to Type 2.

The external-helper preflight obligation remains in its existing pipeline row.
Multi-feature historical panels remain with historical-projection follow-ups.
The later holistic core review may delete now-dead compatibility helpers after
WS6, but it does not own this public decision.

Next stage: a Type 2 response by an author other than Codex, under a brief
written or accepted by the maintainer. No implementation or ticket cut starts
from this seed.

# RFC: Lean Core Observable Data (v0.2.3), Seed v1

- Status: **seed v1** of an active RFC cycle
  ([pipeline](README.md#lean-core-observable-data)). Not binding.
- Authors: maintainer with Claude, 2026-11-04.
- Parent: the accepted [lean fold core synthesis](rfc_lean_fold_core_v0_2_3_synthesis.md).
  Siblings: the accepted [lean core skeleton synthesis](rfc_lean_core_skeleton_v0_2_3_synthesis.md)
  (Section 3 decides the prepared data) and the accepted
  [core extension architecture synthesis](rfc_core_extension_architecture_v0_2_3_synthesis.md)
  (Sections 2 and 4 decide how the core is extended).
- No external research stage: this seed draws on ledgr's own records and the
  SF1 probe in ledgr-research (aggregate evidence only).
- Neighbour, not duplicated here: the later **External Data And
  Point-In-Time Regressors** RFC
  ([horizon](../horizon.md#2026-05-26-data-external-point-in-time-regressor-snapshots);
  pipeline row [instrument master, PIT regressors](README.md#instrument-master-data)).
  It owns vendor ingest, schemas, sealing, hash scope, filing-time
  resolution, restatements and the public surface. The maintainer placed it
  after the first CRAN release (2026-10-26).

## 1. The Question

The maintainer, 2026-11-04: ledgr should later carry external regressors,
"fundamental data about the companies or maybe additional macro indicators",
so "we need to be able to extend the data format as well."

The extension architecture RFC covered the execution and accounting side:
order management, order types, short selling, asset classes and accounting
events. It has no scenario for new **observable** data, meaning values a
strategy may read but that never enter the ledger. The skeleton's prepared
representation is designed around per-instrument numeric planes (bar fields
and features) on two clocks.

The lean core is being written now. If its preparation, P1 and the strategy
boundary fix "a plane is a bar field or a per-instrument feature", the
External Data RFC will later have to reshape preparation, P1 and `ctx`.
The question for this cycle:

> What must the lean core's prepared representation, P1 and the P2 view
> keep open so that later observable data (per-instrument fundamentals,
> market-level series, coded categories) enters through named owners,
> without designing or implementing that data now?

This RFC implements no data kind, adds no column, field or accessor, and
changes no public behavior (principle 0). It is the D1 guard for the data
side.

## 2. What Already Exists

| Record | What it says | Status |
| --- | --- | --- |
| [Skeleton synthesis Section 3](rfc_lean_core_skeleton_v0_2_3_synthesis.md#3-prepared-data-and-exact-history) | Time-major tiles: per session block, sessions-by-stored-instruments **double** matrices with a global-instrument-to-column map and explicit absence; masks and segment fields keep declared types; flat segment and change-point columns for facts. Bars use cutoff treatment, features keep their own pulse's knowledge and treatment (vintage). Admission counts finite values. | accepted |
| [Extension synthesis Section 2](rfc_core_extension_architecture_v0_2_3_synthesis.md#2-fixed-boundaries-and-present-owners) | Five fixed boundaries; causality: P1 alone reads the substrate, P2 sees its cutoff-bound view, effective and knowledge time both apply. Closed, validated vocabularies; no generic metadata. | accepted |
| [Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts) and the probe | Fact families are sessions, membership, lifetime, trading status and corporate actions. `ledgr_facts()` refuses a numeric table. | shipped |
| [Indicator computation](../contracts.md#contract-context-indicator-computation) | Features are per-instrument numeric series from bars. Post-warmup `NA` is invalid. | shipped |
| [Pulse data accessors](../contracts.md#contract-context-pulse-data) | `ctx` is a flat named lazy view over `ctx$universe`; every readable column is instrument-aligned. There is no market-level accessor. | shipped |
| Horizon, 2026-05-26 "External point-in-time regressor snapshots" | Fundamentals, macro releases, estimates, vendor factors, alternative data; sealed regressor snapshots with vintage metadata projected point-in-time into `ctx`. | parked |
| Horizon archive, 2026-05-25 "Point-in-time data tables" | Names `known_at`, `available_at`, `effective_at`, `event_time`, `revision_time` and an alignment policy to decision times. | archived, folded into the above |
| SF1 probe, ledgr-research `experiments/sf1-pit-probe/findings.md` (af261e9, fa49d62) | Green. As-reported ARQ/ARY/ART exist with a filing date; median ARQ filing lag 39 days; 3.9% of ARQ rows are later filings for the same period. A panel keyed on period end moves 4.4-8.2% of book-to-price quintiles; restatement alone 0-0.8%. The custom-indicator route works but is unsealed, lets the user's lookup choose the knowledge clock, and refuses not-yet-known values. | probe, not binding |

## 3. Three Shapes The Skeleton Does Not Yet Name

| Shape | Example | Axis | Value type | How it changes | Where it strains today's skeleton |
| --- | --- | --- | --- | --- | --- |
| Per-instrument, knowledge-timed values | quarterly EPS, book value, shares outstanding | instrument | double | a few times a year; later filings replace earlier ones | A dense sessions-by-instruments plane stores about 63 copies of each quarterly value. Change-point storage fits better, but the skeleton uses segments only for facts, not for readable values. |
| Market-level series | CPI, policy rate, VIX, an index level | none (one series per indicator) | double | at release times, with revisions | Tiles have an instrument column axis only, and every `ctx` column is aligned to `ctx$universe`. Carrying a series as a pseudo-instrument in bars would put it on the run axis with membership and tradability; that route is untested and probably wrong. |
| Coded categories | sector, industry, exchange, share class | instrument | integer code or text token | rarely; reclassifications | Tile planes are double matrices. A category needs a declared non-double type and its own closed vocabulary. |

A fourth case, sparse dated events such as earnings announcements, is
already close to the corporate-action fact shape. The response should say
whether it is a separate shape.

**Derived values cross clocks.** A price-to-book feature divides a bar
close (cutoff treatment) by a filed book value per share (known from its
filing time, on the share basis in force when filed). The probe found the
basis mismatch: the snapshot is split-adjusted, as-reported per-share fields
are not. The lean core does not decide that rule. It must not make the rule
impossible, for example by letting the feature service read only bar planes.

**Is there a third clock?** Earlier discussion called as-reported data a
third clock. It may instead be the existing two clocks applied to a new data
kind: at cutoff t a history read either shows each past pulse's value as
known then (vintage) or each past period's value as known at t (cutoff).
For as-reported data they differ only where a later filing replaced an
earlier one. The response should test this before anyone adds a clock.

## 4. Proposed Direction

Name a **plane descriptor** in the interface table: the closed set of
properties every prepared readable plane declares, so a later data kind is a
new descriptor value with its contract, not a new representation.

| Property | Values the lean core needs now | Values it must not foreclose |
| --- | --- | --- |
| Axis | instrument | market-level (no instrument axis) |
| Value type | double; the existing typed masks | integer code with a closed vocabulary; logical |
| Clock | cutoff (bars), vintage (features) | the same two clocks applied to filed values; a declared knowledge time per value |
| Storage | dense tile | change-point segments for values that change rarely |
| Absence | explicit missing; warmup | missing with a reason, such as not yet known or not covered, readable by the strategy without a refusal |

Owners, under the extension procedure's affected-owner check:

| Owner | What the descriptor asks of it now | What a later data kind would change |
| --- | --- | --- |
| Preparation | Build planes from descriptors, not from a fixed list of bar fields and features. | Add a descriptor value and its source. |
| P1 (sole reader) | Read every plane through one descriptor-driven access path. | Nothing beyond reading the new plane. |
| Feature service | Keep its inputs a declared set of planes, not "the bar matrix". | Admit non-bar planes as inputs under a contract that settles basis and clocks. |
| P2 view and `ctx` | No change now; public fields stay as they are. | A market-level or category accessor is a public API change and belongs to the External Data RFC. |
| P3 to P5 | None. Observable data never enters planning or accounting. | None. FX or financing terms that affect money are economic terms and take the cross-asset route. |
| Snapshot and identity | None now. | Sealing, hash scope, vendor acquisitions and identity belong to the External Data RFC. |

Add a **fifth scenario row**, "New observable data kinds", to the D1
affected-owner check, answered at every family close like the other four.

What this direction does not do: add a plane, a market-level axis, a
category type, an accessor, a fact family or a schema field. Every one of
those waits for its owning contract.

## 5. Gate

Proposed: until this RFC is accepted, the first-checkpoint cut may measure
and write the complete FIFO family and the stage recorder, but not the
memory-preparation code or the interface table's preparation, P1 and P2-view
rows. If the accepted synthesis changes a structure the skeleton synthesis
binds (Section 3 or the interface table rule in Section 2), the skeleton
synthesis is amended before that code is written, as D2 required for the
extension cycle.

## 6. Out Of Scope

Owned by the External Data RFC after CRAN, not decided here:

- storage as a numeric fact family in the snapshot or a separately sealed
  regressor snapshot, and its hash scope and rehash cost;
- when a date-only filing becomes known (session open, the same day's close,
  or the next session);
- several filings per period and whether replacement follows the
  trading-status correction rules;
- per-share basis rules;
- vendor edits and a transaction-time axis;
- the identity mapping from vendor keys to instrument ids;
- the public accessors, feature constructors and documentation.

## 7. Questions For The Response

1. **Shapes.** Are the three shapes in Section 3 the right set? Are sparse
   dated events a fourth shape or a fact family?
2. **Clock.** Is as-reported data a third clock, or the existing cutoff and
   vintage clocks applied to filed values? Name the case that would force a
   third clock, if one exists.
3. **Descriptor.** Is a plane descriptor the right guard, or does it
   overbuild against principle 0 and the extension synthesis's "no
   speculative columns" rule? What is the smallest form that keeps the
   shapes open?
4. **Storage.** Should change-point storage for readable values be allowed
   now by the descriptor, or only named as not foreclosed?
5. **Market-level axis.** Can a market-level series enter without a second
   reader in P1 or a second view in P2? What must the P2 adapter keep open?
6. **Absence.** The feature contract refuses post-warmup `NA`; history
   admission counts finite values. Where does a "not yet known" reason live
   so a later data kind can expose it without changing those rules for bars?
7. **Gate.** Is Section 5's partial gate right, or should all first-checkpoint
   code wait?
8. **Existing owners.** Does any accepted record already decide part of this
   (the feature projection or asset availability synthesis future
   obligations behind the instrument-master pipeline row)?

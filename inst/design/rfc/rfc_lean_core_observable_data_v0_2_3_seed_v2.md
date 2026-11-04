# RFC: Lean Core Observable Data (v0.2.3), Seed v2

- Status: **seed v2** of an active RFC cycle
  ([pipeline](README.md#lean-core-observable-data)). Not binding.
- Authors: maintainer with Claude, 2026-11-04.
- Written on the terms of the [response review](rfc_lean_core_observable_data_v0_2_3_response_review.md),
  which accepted the framing of the Codex Type 2
  [response](rfc_lean_core_observable_data_v0_2_3_response.md) (REVISE).
  [Seed v1](rfc_lean_core_observable_data_v0_2_3_seed.md) is historical.
- Parent: the accepted [lean fold core synthesis](rfc_lean_fold_core_v0_2_3_synthesis.md).
  Siblings: the accepted [lean core skeleton synthesis](rfc_lean_core_skeleton_v0_2_3_synthesis.md)
  and [core extension architecture synthesis](rfc_core_extension_architecture_v0_2_3_synthesis.md).
- Later owner, not duplicated here: the **External Data And Point-In-Time
  Regressors** RFC ([horizon](../horizon.md#2026-05-26-data-external-point-in-time-regressor-snapshots);
  pipeline row [instrument master, PIT regressors](README.md#instrument-master-data)),
  after the first CRAN release (maintainer, 2026-10-26).

## 1. The Question

The maintainer wants ledgr to carry external regressors later: company
fundamentals, macro indicators and similar data (seed v1 Section 1). The lean
core will be written soon. Its two accepted design records cover execution
and accounting extensions; neither names data a strategy reads that is not a
bar or a feature.

> What must the lean core's design text say now so that later contracted
> data can enter through named owners, without a second causal reader, a
> second execution path or a speculative representation?

This RFC adds no runtime mechanism, field, column, accessor, fact family or
storage format, and changes no public behavior (principle 0). It produces a
written guard, a fifth affected-owner scenario and a gate. Seed v1's plane
descriptor is withdrawn (Section 7).

## 2. What Already Exists

| Record | What it says |
| --- | --- |
| [Skeleton synthesis Section 3](rfc_lean_core_skeleton_v0_2_3_synthesis.md#3-prepared-data-and-exact-history) | Compact time-major tiles of numeric field and feature planes per session block, a global-instrument-to-column map, explicit absence, typed masks and segment columns. Bars use cutoff treatment; feature cells keep their own pulse's knowledge and treatment. Admission counts finite values. Section 2 requires an interface table naming each field's type, axis, unit, invariant, producer, validator and owner before code. |
| [Extension synthesis](rfc_core_extension_architecture_v0_2_3_synthesis.md) | Section 2: five fixed boundaries (one fold; strategy returns targets; causality and snapshot trust; typed ledger; ownership and read-only reconstruction). Section 3: closed validated vocabularies, typed fields only under contracted semantics, no generic metadata. Section 4: the six-step procedure and the four-scenario affected-owner check. |
| [Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts) | Separate effective and knowledge clocks. Fact families are sessions, membership, lifetime, trading status and corporate actions. |
| [Indicator Computation And Identity](../contracts.md#contract-context-indicator-computation), [Availability-Aware Strict Features](../contracts.md#contract-context-strict-features) | Features are numeric series computed from bar inputs. Readiness, calculation validity, input and output carry are separate planes. A post-warmup `NA` decision is pending ([decisions](../decisions.md#post-warmup-na-indicator-output)). |
| [Pulse Data And Axis-Aligned Accessors](../contracts.md#contract-context-pulse-data), [Context Planes And Strategy State](../contracts.md#contract-availability-context-and-state) | Asset and feature columns of `ctx` are aligned to `ctx$universe`; `ctx` also carries pulse and portfolio values such as `ts_utc`, `cash` and `equity` (`R/pulse-context.R:13-24`). There is no accessor for an external market-level series. |
| Horizon 2026-05-26 and horizon archive 2026-05-25 | The external regressor entry proposes sealed regressor snapshots projected point-in-time into `ctx`; the archived "Point-in-time data tables" entry names `known_at`, `available_at`, `effective_at`, `event_time` and `revision_time`. The two overlap and await a unified design. |
| SF1 probe, ledgr-research `experiments/sf1-pit-probe/findings.md` (commits `af261e9`, `fa49d62`) | Evidence, not binding, measured against ledgr `c6374bb2`. As-reported ARQ/ARY/ART carry a filing date. On the S&P axis the median ARQ filing lag is 39 calendar days (44 across all of SF1). 3.9% of ARQ rows are later filings for an already-filed period; 20% of those change a value. Over six dates (2000-2025, about 500 S&P members each, fixed price denominator) a naive restated panel keyed on period end moves 4.4-8.2% of book-to-price quintiles; restatement alone for already-filed quarters moves 0-0.8%. |

## 3. Scenarios

These are overlapping design scenarios, not a type system. A later data kind
may combine them.

| Scenario | Example | What distinguishes it |
| --- | --- | --- |
| Per-instrument filed values | quarterly EPS, book value, shares outstanding | Known from a filing time after the period it describes; later filings may replace a value; changes a few times a year. |
| Market-level series | CPI, a policy rate, VIX | No instrument position; release times and revisions. |
| Coded categories | sector, industry, exchange | A closed vocabulary rather than a quantity; reclassifications. |
| Sparse dated events | earnings announcements, index changes | Event identity, possibly several per pulse, scheduled versus actual dates. Close to the fact-family shape, but not corporate-action accounting events. |

## 4. Time

No third runtime clock. Ordinary filed data needs the existing coordinates
and an explicit read policy:

- **Coordinates.** Effective time (or the period a value describes) and
  knowledge time, as point-in-time facts already keep them.
- **Read policy on a declared observation axis.** A history read must say
  whether it is indexed by pulse (each pulse's value as known then, the
  vintage view) or by period (each period's value as known at the cutoff).
  These differ not only where a later filing replaced an earlier one: a
  quarter ending at p and first filed at f > p is absent at p and present at
  any cutoff after f, with no restatement involved.
- **Derived values.** A value computed at pulse s uses inputs knowable at s
  and keeps that vintage; a later history read must not restate it by
  accident. Combining a cutoff-treated price with a filed per-share value
  also raises a basis question, which the SF1 probe found for its
  split-adjusted snapshot. The later data RFC owns that rule.
- **Vendor acquisition time** is the one possible further coordinate: it
  would be needed to reproduce what a particular vendor download contained,
  as distinct from what was publicly known. Deferred to the later data RFC.

## 5. The Guard

Add to the skeleton's interface-table rule, as a written constraint:

> Later contracted observable data may extend preparation, P1's cutoff-bound
> read service and the P2 adapter. It enters through those existing owners:
> no second causal reader of prepared data, no second execution path, no
> tradable pseudo-instrument for a market-level series, and no change to
> today's numeric history admission or public semantics for bars and
> features. Names and indexes are resolved during preparation, as the
> optimization style requires.

The response located six places that a later data kind would extend. Each is
a change inside one named owner, not a whole-core reshape. The interface
table records them as known extension points, without implementing any:

| Place | Today | What a later data kind would add, under its own contract |
| --- | --- | --- |
| Numeric planes | OHLCV double matrices and logical masks (`R/history-substrate.R`, `ledgr_history_substrate_bar_matrices()`) | Numeric filed values fit a dense plane; change-point storage for rarely changing values is a possible physical optimization, measured then. Category codes can be stored exactly as small numbers; their semantic type and vocabulary come from the data contract. |
| Instrument map | One global instrument index on every plane | A market series needs a series axis or a scalar projection owned by the same read service. |
| Feature inputs | Inputs and callback frames name OHLCV (`R/history-features.R`, `ledgr_history_feature_inputs()`) | Non-bar inputs need contracted admission and identity. |
| P1 decision packet | Closed carrier fields and one cutoff-bound history service | A contracted field group or service extension; the packet does not become a bag of every readable value. |
| P2 adapter | Numeric, instrument-aligned feature reads (`R/pulse-context.R`) | A category or market-level accessor is a public API change for the later RFC. |
| History admission | Bar and feature requests; finite-value counting | Categories and events do not inherit numeric admission; their read contract says whether and how history applies. |

## 6. Owner Assessment

Observable data is not assumed to stay out of P3 to P5. A value used only by a
strategy may add nothing there; a value used for valuation, risk, costs or
diagnostics reaches several owners even if it never enters the ledger (marks
already serve valuation and risk; P3 and P5 carry decision and risk
evidence). Each later data kind assesses, by intended use:

| Responsibility | Owners to assess |
| --- | --- |
| Production | Ingest, sealing and identity mapping; preparation; feature input and output services. |
| Scheduling | E and P1 projection on existing pulses. A release-driven pulse schedule needs its own contract. |
| Application | P1 observation and valuation; P2 strategy and risk; P3 and P4 only where their contracts consume the value. |
| Publication | Existing feature, diagnostic, equity and accounting owners, including P4 and P5 where affected. No ledger row per observation. |
| Reconstruction | Frozen views, retained evidence, result readers and explanations, without user-code replay. |
| Identity | Snapshot or acquisition, feature definitions and dependencies, config and policy identity, cached and precomputed payload validity. |
| Failure ordering | Seal and preflight refusal, knowledge-bounded runtime failure, stop installation, append and flush prefixes. |

This is an assessment checklist, not permission to implement any of it now.
Missing values follow the same rule: today's numeric admission and indicator
rules stay as they are, and a later data contract may define typed absence
evidence beside its prepared values and expose it through its own accessor.

## 7. Fifth Scenario, Amendments And Gate

**Fifth scenario.** "New observable data kinds" joins the four scenarios of
the affected-owner check, answered at every family close with the Section 6
assessment and the Section 5 guard.

**Amendments at acceptance.** Install the scenario and the guard through
dated, addressed amendments, as the extension cycle did:

- skeleton maintainer decisions D1 (the scenario list);
- skeleton synthesis Section 2.1 as amended (the scenario table) and
  Section 2 (the interface-table rule gains the Section 5 guard);
- extension synthesis Section 4 step 2, which names "the four skeleton
  scenarios".

Skeleton Section 3 is amended only if the accepted synthesis changes its
binding representation; this seed proposes no such change.

**Gate.** Already active: macro
[WS16](../ledgr_v0_2_3_spec_packet/macro_plan.md#ws16-lean-fold-core-accepted-synthesis)
"Observable data guard" holds memory-preparation code and the interface
table's preparation, P1 and P2-view rows until this RFC is accepted. The FIFO
family and the stage recorder are not held; they claim no preparation parity
and do not freeze the held interfaces.

**Withdrawn from seed v1:**

| Seed v1 proposal | Reason |
| --- | --- |
| A plane descriptor driving preparation and P1 reads | Runtime machinery for data that does not exist; the extension synthesis allows typed fields only under contracted semantics. |
| "A later data kind is a new descriptor value, not a new representation" | Promises more than any design can; a later kind may need a representation change in its owner. |
| "Observable data never enters P3 to P5" | False for data used in valuation, risk or evidence (Section 6). |
| A possible third clock | Effective and knowledge time plus an observation-axis read policy suffice for filed data (Section 4). |
| Categories need non-double storage | Exact small codes fit doubles; the semantic type belongs to the data contract. |
| "About 63 copies per quarterly value" as evidence | Illustrative arithmetic (252 sessions over four changes), not a measurement. |

## 8. Out Of Scope

Owned by the External Data RFC: storage as a fact family or a separately
sealed regressor snapshot, hash scope and rehash cost; when a date-only filing
becomes known; several filings per period and replacement rules; basis rules;
vendor edits and acquisition time; identity mapping from vendor keys; public
accessors, feature constructors and documentation.

Not this RFC: the post-warmup `NA` difference between the `fn` and
`series_fn` feature paths, decided separately on 2026-11-04 and routed as a
WS12 chore ([decisions](../decisions.md#post-warmup-na-indicator-output)).

## 9. Questions For The Synthesis

1. Is the Section 5 guard text complete and checkable at a family close, or
   does any clause need tightening (for example "no tradable
   pseudo-instrument")?
2. Should the six extension points be recorded in the interface table, in
   this synthesis only, or both?
3. Is the Section 6 checklist the right form for the fifth scenario, given
   that the other four scenarios list owners rather than responsibilities?
4. Are the amendment targets in Section 7 exact and complete?
5. Should the gate lift entirely at acceptance, or should anything stay held
   until the External Data RFC?

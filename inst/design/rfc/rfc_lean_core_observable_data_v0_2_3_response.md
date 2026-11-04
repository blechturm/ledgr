# Lean Core Observable Data: Type 2 Response

REVISE

The seed asks the right question, and a fifth affected-owner scenario is useful.
Its descriptor-driven implementation requirement overbuilds, while its owner
table understates the effects of data used for valuation, risk and evidence.
Keep a documentation guard and the partial coding gate; leave new representations
and public semantics to the later data RFC.

Mode: Type 2, RFC response, Codex, 2026-11-04; maintainer-approved brief, drafted
by Claude. Review began on gpt-6-astra and was completed on gpt-6.1-sol after a
resumed session. Reviewed head: `94a10dc75f070ad8c859f6f9bbceee94e09a9f68`.
Evidence: source inspection and the small pure-R probe described below; nothing
else. Recommendations are non-binding.

Citation aliases (repository paths resolve under
`C:/Users/maxth/ledgr-wt/observable-data-response/`):

- **S**: `inst/design/rfc/rfc_lean_core_observable_data_v0_2_3_seed.md`.
- **K**: `inst/design/rfc/rfc_lean_core_skeleton_v0_2_3_synthesis.md`.
- **D**: `inst/design/rfc/rfc_lean_core_skeleton_v0_2_3_maintainer_decisions.md`.
- **X**: `inst/design/rfc/rfc_core_extension_architecture_v0_2_3_synthesis.md`.
- **P**: `inst/design/rfc/rfc_lean_fold_core_v0_2_3_synthesis.md`.
- **C**: `inst/design/contracts.md`; cited headings are stable rule groups.
- **M**: `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md`.
- **H**, **HA**: `inst/design/horizon.md`, `inst/design/horizon_archive.md`.
- **F**: `inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`.
- **A**: `inst/design/rfc/rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md`.
- **Pipeline**: `inst/design/rfc/README.md`.
- **SF1**: `C:/Users/maxth/ledgr-research/experiments/sf1-pit-probe/findings.md`.
- **Probe**: `C:/Users/maxth/ledgr-wt/observable-data-probes/observable_response_claims.R`;
  output: the sibling `observable_response_claims.txt`.

## 1. Preserve named access boundaries without a universal descriptor

**Claim.** S:89-107 turns a useful interface inventory into a preparation and
read-dispatch framework, promising that a later kind needs only a descriptor
value. Neither that implementation nor the promise is justified.

**Evidence.** K:105-109 already requires type, axis, unit, invariant, producer,
validator, owner and the feature input/output adaptation boundary. K:480-485
explicitly permits future contracted boundary changes. X:93-98 admits typed
fields only under contracted semantics; P:82-85 preserves services while allowing
their internal storage to change. The concrete constraints are local:

| Place | Accepted text and current code | Actual consequence for later data |
| --- | --- | --- |
| Double tiles | K:193-198; `R/history-substrate.R:422-460` constructs numeric OHLCV matrices. | Numeric fundamentals already fit a dense numeric plane. Value segments would be a later physical optimization. Typed categories require a contracted reader/type extension, but small integer codes are representable as doubles; a non-double storage type is not mathematically necessary. |
| Global instrument map | K:193-198; `R/history-substrate.R:1599-1603`. | A market series has no natural instrument position. Its named storage/access owner must gain a series axis or scalar projection; inventing a tradable instrument is unnecessary. This is an owner-local addition, not proof of a fold-wide reshape. |
| Feature inputs | K:221-234; `R/history-features.R:169-218`, `:230-244`; `R/precompute-features.R:663-682`. | Inputs and callback frames currently name OHLCV. Later non-bar dependencies require contracted input admission and identity changes. Keep the existing named input-access boundary; do not generalize its vocabulary now. |
| P1 decision packet | K:90-93; C:282-284, **Typed Fold Carrier**; `R/history-substrate.R:465-535`. | Today's packet has closed fields and a cutoff-bound history service. Later data needs an explicitly contracted field/group or service extension. The existing mark packet need not become a bag of every readable value. |
| P2 adapter | K:251-260; `R/pulse-context.R:100-162`, `:166-185`. | Feature reads coerce to numeric and align to instruments. A category or market accessor changes this public adapter later. Portfolio scalars already coexist with asset columns, so the adapter is not intrinsically limited to one axis. |
| History admission | K:236-247; `R/history-frame.R:991-1040`, `:1069-1149`; `R/history-treatment.R:500-597`. | The current request grammar is bar/feature and numeric; admission counts finite values. Categories and events cannot silently inherit numeric estimator admission. Their later read contract must say whether and how history applies. |

**Consequence.** There are concrete places to extend, but none of these sources
proves an unavoidable reshape outside the affected owners. A guarantee that all
future shapes require no representation change would contradict the accepted
extension procedure. The descriptor is therefore unnecessary as runtime machinery.

**Change for v2.** Keep current plane properties in the existing interface table,
and add one prose constraint: new contracted data may extend preparation, P1's
cutoff-bound read service and P2's adapter without adding a second causal owner or
execution path. Keep segments for values as a future option. Remove "build planes
from descriptors", universal dispatch and "not a new representation". Resolve
names/indexes during preparation, as the optimization manual requires
(`inst/design/manual/optimization_coding_style.qmd:140-157`, `:282-295`).

## 2. Separate time coordinates, read policies and observation axes

**Claim.** S:80-85 conflates effective/knowledge coordinates with cutoff/vintage
read policies, and its "only" replacement claim is false as a general statement.

**Evidence.** C:958-975, **Point-In-Time Facts**, separates effective and knowledge
time. K:209-219 and `R/history-frame.R:207-285` distinguish cutoff treatment from
each feature cell's own-pulse knowledge. SF1:25-26, :41-49 records delayed initial
filings as well as revisions. For the seed's period-indexed interpretation, a
quarter ending at p and first filed at f > p is absent under knowledge p but
present under knowledge t >= f, even without a replacement. Comparing a
pulse-indexed vintage series with a period-indexed cutoff series also changes
the observation axis, not merely the clock.

**Consequence.** A descriptor's two clock tokens do not settle projection,
first availability, revision precedence or basis. A derived feature computed at
pulse s must use inputs knowable at s and retain that vintage; it cannot inherit
a later history read's restatement accidentally. SF1:142-145 identifies both the
probe-specific share-basis mismatch and a separate acquisition-time concern.

**Change for v2.** No third clock is required for ordinary as-reported filings:
retain effective/period and knowledge coordinates, then define read policy on a
declared observation axis in the later RFC. Retrieving both what was publicly
known at decision time and what a particular vendor acquisition contained would
require an independent acquisition/transaction coordinate. Leave that deferred;
do not implement a third runtime clock now. Qualify the price-basis example as
the SF1 probe's snapshot, rather than a property of every ledgr snapshot.

## 3. The owner map cannot exclude P3-P5 by calling data observable

**Claim.** S:29-30 and :109 confuse a source's role with all uses of its values.
The Section 4 table is incomplete under X Section 4 step 2.

**Evidence.** X:168-184 requires production, scheduling, application, publication,
reconstruction, identity and failure ordering. K:93 permits typed values in
P3-P5 while excluding substrate handles. C:1315-1319, **Context Planes And
Strategy State**, gives marks both valuation and risk roles. P3 carries decision
and risk diagnostic segments (`R/fold-engine.R:1155-1176`, `:1280-1289`); P5 uses
decision marks for exposure reconciliation and drains diagnostics
(`R/fold-engine.R:1563-1599`). Absence from accounting-ledger payloads does not
imply absence from planning, reconciliation or other durable evidence.

**Consequence.** An ordinary fundamental used only by a strategy need not add any
raw field to P3-P5. But a later data source used for valuation, risk, costs or
diagnostics may affect several owners. Routing economic semantics through the
cross-asset RFC does not erase those data dependencies.

**Change for v2.** Define these scenarios by intended consumption and replace
"none" with an explicit affected/unchanged assessment:

| Responsibility | Owners the later capability must assess |
| --- | --- |
| Production | Ingest/seal and identity mapping; preparation and feature input/output services. |
| Scheduling | E and P1 projection on existing pulses; any new release-driven pulse schedule needs its own contract. |
| Application | P1 causal observation/valuation; P2 strategy and risk; P3-P4 economic consumers only when their contracts require them. |
| Publication | Existing feature, diagnostic, equity and accounting owners, including P4/P5 where affected. No automatic new ledger row per observation. |
| Reconstruction | Frozen views and retained evidence; result readers and explanation services, without user-code replay. |
| Identity | Snapshot/acquisition, feature definitions/dependencies, config and policy identity; caches and precomputed payload validity. |
| Failure ordering | Seal/preflight refusal, knowledge-bounded runtime failure, stop installation and append/flush prefixes. |

This is an assessment checklist, not permission to implement those changes now.

## 4. Missingness needs its own later contract; current refusal is not uniform

**Claim.** S:99 preselects strategy-readable non-refusal semantics, and S:55/:59
overstate the uniformity of current implementation behavior.

**Evidence.** C:2576-2583, **Indicator Computation And Identity**, requires numeric
series and rejects post-warmup missing outputs. The series normalizer enforces
that (`R/features-engine.R:343-371`). However, the scalar normalizer accepts
`NA_real_` (`R/features-engine.R:374-384`), and the scalar calculation path can
retain it after readiness (`R/history-features.R:316-323`, `:372-381`). Probe
reproduced both results: series refusal, scalar acceptance, and two ready scalar
calculation cells containing NA. This is a contract/source discrepancy for
separate disposition, not a new accepted missingness rule.

C:2641-2645, **Availability-Aware Strict Features**, already separates input
availability, readiness, calculation validity and output carry. C:2331-2339 and
:2380-2388, **Pulse Data And Axis-Aligned Accessors**, defines existing missing
reasons and finite-value admission. `ledgr_facts()` rejects the probe's numeric
table because it is not a fact-family object (`R/availability-facts.R:1000-1008`),
not because every fact-family payload must be non-numeric.

**Consequence.** A new descriptor token cannot bypass indicator validation or
make categories meaningful under `is.finite()`. Neither bars nor existing feature
semantics should change to make the future data route convenient.

**Change for v2.** Reserve the later data contract's ability to define typed
absence evidence beside its prepared values, projected through P1 and exposed by
its contracted P2 accessor. Do not add reason codes, accessor fields or a blanket
non-refusal guarantee now. Identify the scalar discrepancy explicitly; use the
parent's contract/oracle disposition route (P:204-208), without changing code or
registered tests in this RFC.

## 5. Keep the scenarios, but qualify the empirical and representation claims

**Claim.** The examples motivate review, but several statements are stronger
than their sources support.

**Evidence and recommended corrections for v2:**

| Seed claim | Source check and correction |
| --- | --- |
| About 63 copies per quarterly value (S:65) | This is the illustrative arithmetic 252 assumed sessions/year divided by four equally spaced changes, not a measured SF1 result. Filings, coverage, revisions and tile residency vary. State the assumptions or remove the number; "segments fit better" remains a performance hypothesis. |
| Three shapes (S:63-71) | Useful scenarios, not disjoint types: market series can be sparse and categorical. Sparse dated observations deserve an event scenario because multiple events per pulse, event identity and scheduled-versus-actual dates differ from held values. They may later use a fact family, but earnings announcements are not automatically corporate-action accounting events. C:987-1014, **Point-In-Time Facts**, binds specific corporate-action semantics, not generic announcements. |
| Every readable context column is instrument-aligned (S:56/:66) | True for the asset/feature columns, false for the whole context: cash, equity and timestamps are portfolio/pulse values (`R/pulse-context.R:13-24`). Say there is no public external market-series accessor. The pseudo-instrument objection is a reasonable design concern, explicitly untested, not demonstrated failure. |
| A category needs non-double storage (S:67) | Unsupported necessity; double storage can hold exact small integer codes. Preserve semantic type and vocabulary under its later contract rather than imposing a physical encoding now (finding 1; X:93-98). Logical masks already exist today (`R/history-substrate.R:429-437`); logical is not wholly a future type. |
| Green; ARQ/ARY/ART and filing date (S:59) | Matches SF1:10-14. Green answers its limited availability kill clause, not correctness of a future ledgr data model. |
| ARQ median filing lag 39 days (S:59) | Correct on the S&P axis (SF1:41-49); all-SF1 median is 44 days. Add the sample scope and say calendar-day filing lag. |
| 3.9% later ARQ filings (S:59) | Matches SF1:17-20: 26,428 later rows over 23,649 periods; only 20% of those change a value. Do not equate all later filings with changed values. |
| Quintile moves 4.4-8.2%; restatement 0-0.8% (S:59) | Matches SF1:72-81 for six dates in 2000-2025, about 500 S&P members each, holding the price denominator fixed. Name the naive restated period-end panel and already-filed-quarter comparison. These are not return effects or population estimates. |
| Custom-indicator route and basis mismatch (S:59/:73-78) | Reported at SF1:97-118 and :142-143 for ledgr `c6374bb2`, not the reviewed head. Current params enter fingerprints (`R/indicator.R:278-304`), so unsealed does not mean identity-free. Retain the user-controlled lookup limitation, qualify refusal as in finding 4, and avoid reviving the probe's retired `ctx$vec$feature()` spelling. |
| Probe commits `af261e9`, `fa49d62` (S:59) | SF1:3 names only `af261e9`. `fa49d62` is unverified from the permitted evidence. Supply its evidence pointer or remove it. |

All SF1 aggregates above were checked against the allowed findings file, not
recomputed from vendor/private data. The small local probe used R 4.6.1 and
`pkgload::load_all(..., compile = FALSE, quiet = TRUE)`; it exercised pure-R
helpers only. Loading emitted a DLL-registration warning; the rerun exited zero.
It establishes no native-path, full-run, memory or performance result.

## 6. Prior records route the work; they do not decide a descriptor

**Claim.** Existing obligations support the later data RFC, but some citations
need narrower attribution.

**Evidence.** H:2491-2525 lists the proposed external sources and suggests sealed
regressor snapshots, while expressly requiring a dedicated RFC. HA:5889-5907
lists the five named temporal concepts and alignment policy. H:2498-2502 says the
two entries overlap and should be unified; this is not evidence of a completed
unification. F:335-349 routes PIT interchange to the later provider track.
A:1034-1046 defers provider adapters, calendars, ML, financing and representation
work. Pipeline:99 preserves accepted PIT/provider boundaries; neither linked
future-obligation section chooses axes, category storage or an observable plane.

**Consequence and change for v2.** Keep the later owner and existing causality,
trust and identity obligations. Describe the archive entry as overlapping and
awaiting unified design. Attribute closed vocabularies/no generic metadata to
X Section 3 (:93-98), in addition to Section 2's five boundaries. The after-CRAN
fundamentals decision is recorded in SF1:3-8; the broader data routing is also in
Pipeline:112. The exact maintainer quotations at S:23-25 and the earlier
"third clock" discussion are unverified outside the seed; label them as seed
provenance, not independently checked evidence.
S:34's claim that core code is being written is also unverified; this worktree
has no `dev/lean_core/` directory. Describe the implementation as upcoming rather
than treating current candidate code as evidence for urgency.

## 7. Retain the partial gate and amend the operative records explicitly

**Claim.** The partial gate is proportionate; holding all FIFO/recorder work has
no demonstrated dependency benefit. Its current authority is misstated.

**Evidence.** M:684-691 already installs the observable-data hold, including the
interface rows; S:121 and Pipeline:112 still call it proposed. D:52-54's earlier
extension gate was cleared by acceptance (K:10-13; M:674-683). The accepted
affected-owner texts still say four scenarios (D:68; K:463-485; X:168-172).
K:369-378 requires complete semantic recorder boundaries and limits the first
checkpoint's coverage claims.

**Consequence and change for v2.** Cite the existing macro gate accurately and
retain it until acceptance or explicit adjustment. FIFO arithmetic and the
generic recorder can proceed, without freezing the held preparation/P1/P2
interfaces or claiming preparation parity. At acceptance, install the fifth
scenario through addressed amendments to D1, K Section 2.1 and X Section 4's
four-scenario reference; amend K Section 3 only if its binding representation
actually changes. Preserve existing numeric tiles and public semantics. A
documentation-only guard needs no new data implementation or storage amendment.

## Answers to questions 1-12

1. **Shapes:** useful intersecting scenarios; add sparse events as a scenario,
   without assigning them corporate-action semantics or building a family (5).
2. **Clock:** ordinary filings need effective/knowledge coordinates and explicit
   read/axis semantics. Acquisition-time reproducibility is the possible extra
   coordinate; no third runtime clock now (2).
3. **Descriptor:** documentation of current properties is sufficient. Reject the
   universal preparation/dispatch framework and representation promise (1).
4. **Storage:** name value segments as not foreclosed; decide and measure their
   implementation under the later data contract (1, 5).
5. **Market axis:** yes, through the same causal owner and cutoff-bound service;
   P2 can later adapt a contracted series/scalar without making it tradable.
   Preserve frozen ownership and target-axis validation; add no accessor now (1).
6. **Absence:** later typed data evidence belongs beside prepared values and in
   its contracted projection/accessor. Preserve today's numeric admission and
   separately disposition the scalar-output discrepancy (4).
7. **Gate:** keep the partial hold; FIFO and recorder need not all wait (7).
8. **Existing owners:** PIT/provider obligations and the after-CRAN route exist;
   they do not already choose the proposed representation (6).
9. **Principle 0:** no visible behavior, identity or stored-format change is
   required by a prose guard. A runtime descriptor can be parity-preserving but
   still speculative. Exposing new missingness, fields or input declarations now
   would affect **Pulse Data And Axis-Aligned Accessors**, **Indicator Computation
   And Identity**, **Availability-Aware Strict Features**, **Typed Fold Carrier**,
   and potentially **Execution And Feature Identity** (C:673-688) and **Current
   Store Format** (C:1489-1521). None is authorized here (1, 4).
10. **Foreclosure:** the six concrete local changes are in finding 1. No inspected
    boundary forces an unowned or whole-core reshape; that does not prove every
    later data model fits today's representation. Keep the small prose guard.
11. **Owner table:** incomplete and too categorical. Observable source values
    and their derived evidence can reach later stages; assess all seven
    responsibilities and preserve P1's exclusive substrate access (3).
12. **Evidence:** the seed's numerical/source qualifications and unsupported
    claims are enumerated in findings 1-7. SF1 aggregates were source-checked
    only; `fa49d62`, original quotations and unexecuted future designs remain
    unverified. No full suite or package check was run.

## Seed v2 edits

- Add one fifth scenario with the complete owner assessment and explicit
  amendments; retain the partial gate with its correct macro authority.
- Remove mandatory descriptor-driven machinery and the promise that new data
  never needs a new representation or changes to P3-P5.
- Reword clocks on a common observation axis, including delayed first filings;
  keep basis, vendor acquisitions and projection policy with the later RFC.
- Preserve current public and numeric-history contracts; defer new absence
  semantics and record the scalar/series discrepancy for separate disposition.
- Qualify the 63-session illustration, SF1 sample scopes, historical package
  baseline, category encoding and context-axis claims; repair evidence pointers.

# ledgr v0.1.9.5 Spec

**Status:** Spec review complete (Codex, 2026-06-12; review verdict
"revisions required before ticket cut" with no missing RFC/audit gates;
review delivered conversationally, not retained as a packet artifact).
The four required revisions were applied in place 2026-06-12: (1) Batch
12 names the release-playbook source reference, read task, and explicit
local-gate checklist per `release_ci_playbook.md:100-123` -- the
playbook forbids implicit referencing; (2) Batch 1 split into 1A/1B/1C
reviewable units (stale docs / runner-results / kernel-accounting); (3)
the scope note corrected: locator attributes are result-object shape,
not identity bytes; (4) Batch 5 retitled and scoped for the M-4/M-6
code/test implications, with the N-4 conditional tie-in added to Batch
2. The review also confirmed both spec-level bindings (the scope
supersession and the H-1 two-pulse fail-closed contract, the latter
verified against the runner hazard and walk-forward's existing rule).
Ready for ticket cut. Nothing below authorizes implementation until
tickets are cut.
**Target branch:** `v0.1.9.5`.
**Scope:** The naming-and-teaching consolidation release after the v0.1.9.x
feature arc: implementation of the accepted API naming-consistency synthesis
(hard renames, unexports, the candidate generic, the M-8 fix), the
v0.1.9.4-close audit hardening batch, the contracts.md structural pass, the
vignette restructuring and new teaching surfaces from the vignette screening
audit, maintainer-manual and identity-reference updates, and the roadmap /
release-surface audit. Mirrors the v0.1.8.11 entropy-management pattern,
extended by the two accepted 2026-06-12 RFC artifacts.
**Scope supersession note:** The roadmap's v0.1.9.5 section (written
2026-06-05) frames this release as documentation-only with "no execution
semantics" authorized. Two later, authoritative inputs extend that frame: the
accepted naming synthesis binds implementation work into v0.1.9.5 (renames,
unexports, the `ledgr_candidate()` walk-forward method with locator
attributes, and the M-8 correctness fix as a named prerequisite), and the
roadmap's own authoritative-inputs list routes the deep-code-review hardening
batch here. This spec binds that extension explicitly: the implementation
surface of this release is EXACTLY the naming-synthesis rename/generic scope
plus the audit findings routed below -- no other behavior changes are
authorized. Durable identity hash recipes do not change in this packet. The
candidate-generic work changes walk-forward result OBJECT SHAPE by adding
locator attributes and resolve-at-call verification; locator attributes are
durable strings on result objects, not identity bytes (spec-review L-1).
**Non-scope:** the v0.1.9.6 validation toolkit (accepted synthesis, own
packet); the strategy schedule decorator (staged seed, cycle not opened);
crypto-readiness spike; target-construction Pass 2 helpers; all parked
v0.2.x clusters; any new public API beyond the naming synthesis's bound
table; benchmark marketing; broad refactors hidden in documentation work.

---

## 0. Source Inputs

Binding artifacts (this spec implements them; it does not reopen them):

- `inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md`
  (accepted 2026-06-12, final review passed with patches F1-F4) -- Sections
  2 (rename/disposition tables), 3 (candidate generic contract), 4
  (unexports, Recovery docs), 5 (contracts rework ticket), 6 (ticket shape),
  7 (mechanical gates).
- `inst/design/audits/v0_1_9_4_deep_code_review_audit.md` -- severity index
  B-1, H-1..H-3, M-1..M-8, N-1..N-6 with the suggested order of attack.
- `inst/design/audits/v0_1_9_4_vignette_screening_audit.md` -- split designs
  A-E, missing-vignette list, Section 2 stale items, Section 7 consumption
  order.

Planning inputs:

- `inst/design/ledgr_roadmap.md` v0.1.9.5 section (Workstreams A-G) and
  authoritative-inputs list;
- `inst/design/horizon.md` entries: 2026-06-05 v0.1.9.5 planning entry, the
  two 2026-06-11 `[audit]` routing entries;
- `inst/design/vignette_styleguide.md` (the teachability bar and release-gate
  checks);
- `inst/design/ledgr_v0_1_8_11_spec_packet/` (the pattern precedent,
  including the Section 3.7 two-layer manual standard);
- `inst/design/contracts.md`, `inst/design/ledgr_ux_decisions.md`,
  `inst/design/release_ci_playbook.md`.

Carried-forward defect: the three stale vignette items from the screening
audit (Section 2) were NOT fixed at the v0.1.9.4 release gate and remain in
the tree (verified 2026-06-12: `vignettes/execution-semantics.qmd:161`
actively wrong cost-API callout; `vignettes/research-to-production.qmd:245`
"v0.1.9.4 plans walk-forward"; `vignettes/sweeps.qmd:620` and
`vignettes/research-workflow.qmd` "when that layer lands"). They are Batch 1A
scope here.

---

## 1. Thesis

v0.1.9.4 closed the feature arc; the corpus is coherent but the
user-experienced surface is not yet: the API has one accepted grammar that is
not yet applied, four vignettes carry two jobs each, three doc surfaces are
stale against shipped reality, the kernel carries one memory-safety blocker
and a small hardening backlog, and contracts.md teaches names that are about
to change. v0.1.9.5 cashes the design-layer coherence at the user layer: one
naming grammar applied everywhere at once, the audit findings fixed or
explicitly contract-bound, the teaching surface restructured to the
two-tier concept/technical architecture, and every planning surface audited
against shipped work. The release is the harvest of the 2026-06-11/12 audit
and RFC work; it deliberately ships zero new capabilities.

---

## 2. Batch Structure (indicative; ticket cut binds final shape)

Sequencing constraints that the ticket cut MUST preserve:

- the M-8 fix lands before or with the rename batch (naming synthesis
  Section 6.1);
- the rename batch lands before every teaching/vignette batch, so new docs
  teach final names exactly once (naming synthesis Section 9 closing rule);
- the contracts.md rework lands in the same release as the renames, never a
  later one (synthesis Section 5);
- vignette Split D (experiment-store) lands before or with the Recovery
  docs section so the landing surface is unambiguous (final-review patch F4);
- stale-item fixes (Batch 1A) land before any vignette that links to the
  affected articles is rewritten.

### Batch 0 -- Packet alignment

Flip active-packet pointers (roadmap header, `inst/design/README.md`,
AGENTS.md planning context) from v0.1.9.4 to v0.1.9.5; update the
doc-contract tests that lock those strings; record the packet-open
supersession note (Section "Scope supersession" above) in the packet record.
DESCRIPTION version bumps at the release-gate batch, not here, per the
v0.1.9.4 precedent.

### Batches 1A / 1B / 1C -- Correctness prerequisites and stale-item fixes

Split per spec-review M-2: five unrelated runtime subsystems plus doc fixes
are not one reviewable unit.

**Batch 1A -- release-blocking stale vignette fixes** (documentation only;
must land before any vignette that links to the affected articles is
rewritten):

- the three screening-audit Section 2 fixes: cost-API callout in
  execution-semantics rewritten to describe the shipped API;
  research-to-production delivered/planned section updated against the
  v0.1.9.4 closeout; walk-forward pointers in sweeps and research-workflow
  updated to `vignette("walk-forward")`.

**Batch 1B -- runner/results hardening:**

- **M-8**: `ledgr_results(bt, "fills")` dead-cursor path. Bound contract:
  borrowed connections are never captured into returned cursors;
  `ledgr_results()` is eager. Regression test through the internal impl seam
  with a small `stream_threshold` (audit addendum; naming synthesis gate
  7.4).
- **H-1**: single-pulse run guard. Contract decision bound HERE per the
  audit's note and confirmed by spec review (Section 3.2): fail closed at
  the coverage check with a classed "window must contain at least two
  pulses" error, consistent with the fill model's next-bar requirement and
  walk-forward's existing >= 2 scoring-pulse rule.
- **H-3**: `ledgr_time_now()` / `ledgr_time_elapsed()` return seconds by
  construction; the magnitude heuristic is deleted; telemetry for runs longer
  than 1000s is correct.

**Batch 1C -- kernel/accounting hardening:**

- **B-1**: spot_fifo.cpp PROTECT bug -- anchor freshly allocated string
  vectors into the protected output list before filling (audit fix sketch;
  ~10 lines, byte-identical behavior).
- **H-2**: `ledgr_lot_apply_fill()` fails closed on invalid input with a
  classed error, validity rules aligned to the C++ kernel (side known, qty
  finite > 0, price finite > 0, fee finite >= 0).

### Batch 2 -- Kernel and cost-model hygiene

- **M-1**: delete the legacy full-spread internal resolver
  (`ledgr_fill_next_open`, `ledgr_cost_spread_commission_internal`,
  `ledgr_default_cost_resolve`); port the internal tests that use it as
  fixtures to the public cost model.
- **M-2**: TYPEOF checks for the five unvalidated scalar args in
  `ledgr_cpp_spot_fifo_batch`.
- **M-3**: `ledgr_spot_check` raises via `cpp11::stop` so C++ frames unwind.
- **M-7**: bind the fee-vs-rounding order in `ledgr_cost_model_resolve` (round
  before fee computation, or one binding comment) plus the one-sentence
  fees-on-adjusted-notional doc note.
- Ride-along nits at implementer discretion: N-1 (replay double-parse), N-2
  (pack_lots growth). N-3/N-5/N-6 remain recorded, not scheduled. N-4
  (actionable-delta absolute tolerance) remains unscheduled by default,
  CONDITIONAL on the Batch 5 M-4 decision: if M-4 selects the epsilon-pop /
  fractional-quantity route rather than a whole-ish-quantity contract, the
  M-4 ticket must re-check N-4 tolerance semantics (spec-review L-3).
- **M-5** (db_live per-fill COUNT) is deferred -- it is a performance item in
  a mode the teaching surface does not promote; recorded for the next
  perf-attribution pass.

### Batch 3 -- Rename and unexport batch (naming synthesis Sections 2, 6.2)

Apply the full Section 2.1 table: six DSL prefixes, the eight verb-first
renames, `ledgr_snapshot_load` -> `ledgr_snapshot_open` with the same-commit
internal `ledgr_snapshot_connection` rename, `ledgr_ttr_warmup_rules` ->
`ledgr_ind_ttr_warmup_rules`, `ledgr_walk_forward_results` ->
`ledgr_walk_forward_open` (help-page caveat bound), and the four Bucket A
unexports. Update NAMESPACE, roxygen, man, the export lock (one update),
pkgdown reference groups, README, `ledgr_ux_decisions.md`, doc-contract
tests, and NEWS (consolidated rename/unexport table per gate 7.7). No
aliases.

### Batch 4 -- Candidate generic and walk-forward locator (synthesis Section 3)

`ledgr_candidate()` S3 generic; `ledgr_walk_forward_extract_candidate`
deleted; locator attributes (`db_path`, `snapshot_id`, `snapshot_hash`) on
live and reopened results objects; resolve-at-call verification; override
semantics (`snapshot_id` AND `snapshot_hash` must match, `db_path` free);
`ledgr_walk_forward_snapshot_override_mismatch` plus bound class reuse
(`LEDGR_SNAPSHOT_DB_NOT_FOUND`, existing walk-forward classes); Amendment 2
discipline carried; the v0.1.9.4 spec Section 4 supersession note recorded in
this packet. Gates: synthesis 7.5 test matrix.

### Batch 5 -- contracts.md structural rework plus M-4/M-6 contract-bound hardening (Workstream A + synthesis Section 5)

One ticket family, not a find-replace, and NOT prose-only (spec-review L-2):
clause-by-clause re-verification of every renamed/unexported/unchanged
citation; bind R1-R7 and the D2 constructor/infrastructure rule into
contracts.md; add the target-risk, walk-forward identity, sweep-persistence,
and cost-API structural language the Workstream A entry names; resolve the
two audit contract decisions routed here WITH their implementation and test
consequences:

- **M-4** (fractional-quantity dust lots): bind a whole-ish-quantity
  contract OR an epsilon-pop. If epsilon-pop is selected, BOTH the R and C++
  accounting paths change in the same ticket (or a directly adjacent one)
  with parity tests, and the N-4 tolerance re-check fires (Batch 2 note).
- **M-6** (snapshot-hash timestamp representation): bind POSIXct-only input
  with a classed failure, including a source-level test for non-POSIXct
  input -- not only contracts prose.

Release gate fails if contracts.md teaches an old public name outside
historical references.

### Batch 6 -- Identity contract reference v2 (Workstream E)

Extend `?ledgr_identity_fields` and `inst/design/manual/identity_contract.qmd`
to cover risk-chain identity, walk-forward `candidate_key` / `session_id`
composition, the new locator attributes, and the naming-synthesis
supersessions. Pull the cost-API forward-obligation rows and walk-forward
Section 17 gate-row obligations into the canonical reference. Fix the
Implementation Trace pointer (audit note: identity assembly lives in
`R/walk-forward-identity.R`, not the orchestrator).

### Batch 7 -- Vignette splits (screening audit Section 3; Workstream B)

Splits A-D as bound in the screening audit: strategy-development ->
"Strategy Basics" + "Strategy Authoring Tools"; indicators -> "Indicators And
Features" + "TTR And Adapter Indicators"; metrics-and-accounting -> "The
Accounting Model" + "Metric Contexts And Conventions"; experiment-store ->
"Data Input And Snapshots" + refocused "Experiment Store" (which receives the
Recovery section bound by naming-synthesis Section 4 / D4). Split E (sweeps)
is a cut-line candidate per the audit's ranking -- ticket cut decides. All
new/split articles teach post-rename names only; doc-contract locks move with
their content; pkgdown gains a third nav group ("Going Deeper" or equivalent)
so the two-tier architecture is visible.

### Batch 8 -- New teaching surfaces (screening audit Section 4; Workstream C)

- **Risk-and-cost execution policy** vignette (the largest hole: v0.1.9.3
  shipped with no vignette home): the layer order validated targets -> risk
  chain -> timing -> cost -> fill; half-spread convention; chain ordering;
  identity hashes.
- **Walk-forward research arc**: expand the design-only stub to an executable
  article (folds, selection rules, degradation table as the primary read,
  extraction via the new `ledgr_candidate()` generic, promotion). Resolves
  the standing `eval: false` tension. Demo-data span check is a packet-open
  verification item (screening audit Section 5).
- **Quickstart ("the whole game")**: ~150-line on-ramp; demo data -> snapshot
  -> one run -> a glance at a sweep -> pointer to research-workflow.
- The consolidated debugging article remains a cut-line candidate (audit
  item 6); ticket cut decides.

### Batches 8A / 8B / 8C -- Vignette audit rescope (2026-06-13)

Added after Batch 8 by the v0.1.9.5 vignette audit
(`inst/design/audits/v0_1_9_5_vignette_audit.md`, Codex-reviewed). Pulled into
this release per maintainer direction rather than deferred.

- **Batch 8A -- UX helpers (audit Section 3).** Record the walk-forward
  degradation and fold-list print methods already landed this cycle; implement
  `ledgr_sweep_review()` (review tables only; no selection/promotion) and
  `ledgr_temp_store()` (disposable `.duckdb` path plus stale-file removal; no
  store lifecycle). Both additive and identity-neutral.
- **Batch 8B -- stale-fact fixes (audit Section 2).** Four verified facts:
  `why-r` dependency list (`jsonlite` -> `yyjsonr`), `research-to-production`
  delivered-list and roadmap anchors, `execution-semantics` trades columns,
  `experiment-store` v0.1.8.5.
- **Batch 8C -- editorial cleanups and helper adoption (audit Sections 1 and
  5).** Callout de-duplication, weak-opening rewrites, missing "Where Next"
  sections, the strategy-article duplication and snapshot cross-link, the
  `eval: false`-hides-the-lesson chunks, TTR `dplyr::` qualifiers, adoption of
  the two new helpers in their consuming articles, and the equity-curve plot
  gap where the data already exists. Depends on 8A.

The `sweeps` and `metric-contexts-and-conventions` splits (audit Section 6) and
the lower-value helpers and trades-pairing decision (audit Sections 3.3-3.6)
are deferred to a later packet and recorded in horizon.

### Batch 9 -- Maintainer manual (Workstream D)

Cost resolver, target-risk layer, and walk-forward fold machinery articles,
each with Synthesis + Implementation Trace per the v0.1.8.11 Section 3.7
two-layer standard.

### Batch 10 -- Internal performance and decisions narrative (Workstream F)

The v0.1.9.x arc narrative: target-risk per-pulse restructure, walk-forward
wrapper-not-engine, cost-API spec-cut discipline, the audit-and-RFC cadence
of 2026-06-11/12. Internal-first, not marketing, per the v0.1.8.11 posture.

### Batch 11 -- Release surfaces and roadmap audit (Workstream G)

NEWS, design index, RFC index, performance-arc index, horizon housekeeping
(sweep consumed entries to `## Resolved`, including the Section 17 entry, the
bundling entry once v0.1.9.6 closes its trigger -- check each trigger
condition), AGENTS context, and the full roadmap audit of remaining
"Planned" rows (the primitive-internals row is pre-closed 2026-06-12; start
with the rest). Update the vignette styleguide's Section 12 reading flow to
the post-split article set.

### Batch 12 -- Release gate

Per `release_ci_playbook.md:100-123`, the release-gate ticket MUST name the
playbook explicitly, not by convention (spec-review M-1). The ticket cut
binds, verbatim:

- `inst/design/release_ci_playbook.md` in the ticket's source references;
- a task to read the playbook before running or updating release gates;
- the explicit local-gate checklist:
  - full package tests;
  - `Rscript --vanilla tools/check-readme-example.R` (README cold-start);
  - `R CMD check --no-manual --no-build-vignettes`;
  - `tools/check-coverage.R` when coverage behavior changed or coverage is
    part of release evidence;
  - pkgdown build (documentation, vignettes, README, and pkgdown references
    all change in this release, so it is required, not conditional);
  - the local WSL/Ubuntu gate (executable R code, vignettes, pkgdown, and
    persistence-adjacent code all change, so it is required);
  - branch / main / tag CI;
- a closeout note recording exactly which gates ran, which were skipped, and
  the accepted reason for every skipped or failed-then-rerun gate.

Plus this packet's bound gates: the naming synthesis Section 7 gate set in
full (export lock, old-name rg sweep with the bound exclusion list,
internal-definition collision gate, M-8 regression, candidate-generic
matrix, streaming-contract preservation, contracts/docs gates, NEWS table);
the styleguide Section 12 release-gate roadmap checks; audit-finding closure
verification (B-1, H-1..H-3, M-1..M-4, M-6..M-8 fixed or explicitly
re-routed with a recorded reason); executing vignettes green;
`tools::checkRd` over changed man pages.

---

## 3. Bound Gates (imported by reference)

The naming synthesis Section 7 gates are imported wholesale and are
release-blocking. The screening audit's Section 7 consumption order is
binding on batch sequencing. The audit severity routing in Section 2 above is
the disposition of record for every audit finding; any finding neither fixed
nor explicitly deferred with a reason fails the gate.

Packet-open verification items (before ticket cut completes):

- demo-data span check for the executable walk-forward vignette (compact
  folds vs. longer demo window);
- confirm the three stale items' exact current line numbers (they drift);
- confirm Split E and the debugging article cut-line decisions;
- confirm N-item dispositions (ride-along vs recorded).

---

## 4. Open Items For Ticket Cut

1. Split E (sweeps) in or out (audit ranks it lowest-priority split).
2. Debugging article in or out (stretch item).
3. Batch 2 ride-along nit selection.
4. Whether Batches 7/8 interleave (split-then-write vs write-then-split per
   article family) -- pure scheduling, no contract impact.
5. pkgdown third-group name ("Going Deeper" placeholder).

---

## 5. Verification

Spec review (Codex) checks this spec against the three binding artifacts for
faithfulness, completeness, and sequencing-constraint correctness, then
tickets are cut per `tickets.yml` / `v0_1_9_5_tickets.md` / `batch_plan.md`
in this directory. The release gate is Batch 12.

# ledgr Roadmap

**Role:** living; release-scope front door.
**Status:** working
**Authority:** Release scope only. Once an active cut exists, its packet's
`tickets.yml` is the sole within-release sequencing authority.
**Scope update, 2026-10-16:** Maintainer-selected next-release goal and
[scope dispositions](#next-release-scope-dispositions); no package semantics
or implementation tickets are changed.

This page answers which releases exist, what each release delivered or owns,
and where its packet lives. It does not duplicate ticket order, RFC
obligations, or parked ideas. Historical planning prose is preserved in
[roadmap history](roadmap_history.md).

**Latest release:** v0.2.2, published 2026-10-27. Its tag and GitHub Release
name commit `7539be45`; its packet is the durable release record.

## Release sequence

| Release | State | Release outcome | Authoritative packet |
| --- | --- | --- | --- |
| v0.1.0 | Released | Deterministic backtest MVP. | [packet](ledgr_v0_1_0_spec_packet/) |
| v0.1.1 | Released | Data ingestion and snapshotting. | [packet](ledgr_v0_1_1_spec_packet/) |
| v0.1.2 | Released | Snapshot correctness and research UX. | [packet](ledgr_v0_1_2_spec_packet/) |
| v0.1.3 | Released | Onboarding release. | [packet](ledgr_v0_1_3_spec_packet/) |
| v0.1.4 | Released | Research workflow stabilisation. | [packet](ledgr_v0_1_4_spec_packet/) |
| v0.1.5 | Released | Experiment-store core. | [packet](ledgr_v0_1_5_spec_packet/) |
| v0.1.6 | Released | Experiment comparison and strategy recovery. | [packet](ledgr_v0_1_6_spec_packet/) |
| v0.1.7 | Released | Core UX overhaul. | [packet](ledgr_v0_1_7_0_spec_packet/) |
| v0.1.7.1 | Released | Installed UX stabilisation. | [packet](ledgr_v0_1_7_1_spec_packet/) |
| v0.1.7.2 | Released | Auditr UX and strategy helpers. | [packet](ledgr_v0_1_7_2_spec_packet/) |
| v0.1.7.3 | Released | Accounting correctness and indicator documentation. | [packet](ledgr_v0_1_7_3_spec_packet/) |
| v0.1.7.4 | Released | External documentation review and auditr report. | [packet](ledgr_v0_1_7_4_spec_packet/) |
| v0.1.7.5 | Released | Indicator, diagnostic, and documentation hardening. | [packet](ledgr_v0_1_7_5_spec_packet/) |
| v0.1.7.6 | Released | DuckDB persistence architecture review. | [packet](ledgr_v0_1_7_6_spec_packet/) |
| v0.1.7.7 | Released | Risk-metrics contract. | [packet](ledgr_v0_1_7_7_spec_packet/) |
| v0.1.7.8 | Released | Strategy reproducibility preflight. | [packet](ledgr_v0_1_7_8_spec_packet/) |
| v0.1.7.9 | Released | Strategy ergonomics and execution stabilisation. | [packet](ledgr_v0_1_7_9_spec_packet/) |
| v0.1.8.00 | Released | Design-document governance and v0.1.8 readiness. | [packet](ledgr_v0_1_8_00_spec_packet/) |
| v0.1.8 | Released | Lightweight sweeps and the first fold-core split. | [packet](ledgr_v0_1_8_0_spec_packet/) |
| v0.1.8.1 | Released | Multi-output indicator authoring. | [packet](ledgr_v0_1_8_1_spec_packet/) |
| v0.1.8.2 | Released | Metric context, risk-free rate, and indicator cleanup. | [packet](ledgr_v0_1_8_2_spec_packet/) |
| v0.1.8.3 | Released | Single-core fold/runtime optimisation. | [packet](ledgr_v0_1_8_3_spec_packet/) |
| v0.1.8.4 | Released | Active feature aliases and parameter-grid helpers. | [packet](ledgr_v0_1_8_4_spec_packet/) |
| v0.1.8.5 | Released | Canonical research workflow and teachability. | [packet](ledgr_v0_1_8_5_spec_packet/) |
| v0.1.8.6 | Released | Feature projection, storage evidence, and performance attribution. | [packet](ledgr_v0_1_8_6_spec_packet/) |
| v0.1.8.7 | Released | Optimisation round two and legacy cleanup. | [packet](ledgr_v0_1_8_7_spec_packet/) |
| v0.1.8.8 | Released | Parallel sweeps and typed execution evidence. | [packet](ledgr_v0_1_8_8_spec_packet/) |
| v0.1.8.9 | Released | Single-core buffer and reconstruction optimisation. | [packet](ledgr_v0_1_8_9_spec_packet/) |
| v0.1.8.10 | Released | Matrix substrate and compiled spot-FIFO opt-in. | [packet](ledgr_v0_1_8_10_spec_packet/) |
| v0.1.8.11 | Released | Documentation, structure, and cleanup. | [packet](ledgr_v0_1_8_11_spec_packet/) |
| v0.1.9.1 | Released | Public transaction-cost API and cost identity. | [packet](ledgr_v0_1_9_1_spec_packet/) |
| v0.1.9.2 | Released | Durable sweep artifacts and retained returns. | [packet](ledgr_v0_1_9_2_spec_packet/) |
| v0.1.9.3 | Released | Target-risk and chainable risk identity. | [packet](ledgr_v0_1_9_3_spec_packet/) |
| v0.1.9.4 | Released | Walk-forward evaluation. | [packet](ledgr_v0_1_9_4_spec_packet/) |
| v0.1.9.5 | Released | Teaching, contract, and naming cleanup. | [packet](ledgr_v0_1_9_5_spec_packet/) |
| v0.1.9.6 | Released | Validation-toolkit substrate and selection diagnostics. | [packet](ledgr_v0_1_9_6_spec_packet/) |
| v0.1.9.7 | Released | Business-objective eligibility and robustness diagnostics. | [packet](ledgr_v0_1_9_7_spec_packet/) |
| v0.2.0.0 | Released | API hardening and point-in-time asset availability. | [packet](ledgr_v0_2_0_0_spec_packet/) |
| v0.2.0.1 | Released | Availability performance, resume repair, and benchmark closeout. | [packet](ledgr_v0_2_0_1_spec_packet/) |
| v0.2.1.0 | Released 2026-10-01 | Accounting consolidation, equity events, strategy context, and release hardening. | [packet](ledgr_v0_2_0_2_spec_packet/) |
| v0.2.2 | Released 2026-10-27 | Long-window point-in-time research, causal history, recursive indicators, scheduling, current-only persistence, and release evidence. | [packet](ledgr_v0_2_2_spec_packet/); [tickets](ledgr_v0_2_2_spec_packet/tickets.yml) |
| v0.2.3 | Active planning | Research-authoring completion, availability-only execution consolidation, structural memory reduction, and cleanup. | [packet](ledgr_v0_2_3_spec_packet/) |

<a id="next-release"></a>

## Current planning release

**Maintainer decision, 2026-10-16; activated 2026-10-27:** v0.2.3 will complete
the ordinary research-authoring workflow, consolidate execution onto the
availability path, and resolve the accumulated maintenance work explicitly
deferred to this release. Its active packet is
`inst/design/ledgr_v0_2_3_spec_packet/`; no cut or executable ticket is
accepted yet.

The intended user outcome is a coherent path from declared features and causal
history, through reusable ordinary-R strategy code and explicit scheduling,
to portfolio targets and inspectable results. Structural memory reduction and
practical parallel-worker budgets remain major release outcomes alongside
that UX goal, retaining the memory direction recorded in the
[history-wave register's Resume here section](rfc/rfc_history_wave_v0_2_2_decisions.md#resume-here).

This decision replaces the former theme-selection wording, with the
[dispositions below](#next-release-scope-dispositions). It binds release scope,
not exact APIs, package behavior or within-release order. The owning RFCs
settle design; the next packet's macro plan and `tickets.yml` settle uncut
order and cut implementation respectively.

### Research UX completion

- Use the [Research Strategy UX Brief](ledgr_v0_2_2_spec_packet/research_strategy_ux_brief.md)
  as design input, not as a wholesale accepted API. Reconcile its goals with
  the completed v0.2.2 tree before cutting work.
- Consume the existing [Portfolio Method UX Exercises](ledgr_v0_2_2_spec_packet/portfolio_method_ux_exercises.md),
  including the [Momento application case](ledgr_v0_2_2_spec_packet/portfolio_method_ux_exercises.md#application-case-momento-cross-sectional-momentum),
  and the implementation evidence produced by
  [WS7's public estimator proof](ledgr_v0_2_2_spec_packet/macro_plan.md#ws7-one-public-long-only-estimator-strategy).
  Address the remaining demonstrated gaps rather than repeating the broad
  design exercise. History interoperability and interactive inspection checks
  stay with their owning workstreams.
- Address the remaining reusable strategy-helper, scheduling and bounded
  portfolio-construction gaps exposed by real research workflows. Keep their
  separate design routes; this scope does not authorize an optimizer catalogue
  or trained-model lifecycle.

### Existing commitments carried forward

- **Committed before the first CRAN release:** consolidate the execution core
  onto the availability path. Dense mode is frozen meanwhile. The later
  accepted release-line decision in commit `4397f58f` supersedes Cut 15's
  earlier both-modes wording; the current owner is
  [macro-plan execution-core consolidation](ledgr_v0_2_2_spec_packet/macro_plan.md#execution-core-consolidation).
- **Scheduled surface work:** retire context-frame views through the
  [context-frame retirement RFC row](rfc/README.md#ctx-frame-retirement), and
  decide persisted-data execution placement through its
  [focused RFC row](rfc/README.md#persisted-data-execution-placement).
- **Pulse-seed hot path (maintainer, 2026-10-21):** replace per-pulse canonical
  JSON plus SHA-256 derivation with a cheap, versioned and platform-independent
  counter rule while preserving deterministic resume, sweep, promotion and
  parallel behavior and isolation from the caller's RNG. Gate the work on
  total-run improvement, not merely moving the same hash work into preparation.
  The exact mapping belongs to the owning cut. Source: the horizon note
  ["Cheap, versioned pulse-seed derivation"](horizon.md#2026-10-21-execution-cheap-versioned-pulse-seed-derivation).
- **Memory:** structural memory reduction, phase-level measurements and
  parallel-worker budgets remain in scope. The persisted-data placement
  decision above is substantive design work, not a documentation chore.
- **One output handler (maintainer, 2026-10-20):** replace the persistent and
  memory output handlers, which stage the same fill events, equity and
  diagnostics and are held equal by parity tests, with one handler behind a
  sink interface (DuckDB or memory). This removes the second implementation and
  its parity suite and closes most of the committed-run-versus-sweep gap,
  because the sweep stops being a separately optimized engine. It is
  independent of execution-core consolidation and may go first. Source: lever 2
  of the horizon entry
  ["Where the package's weight is"](horizon.md#2026-10-12-architecture-where-the-packages-weight-is-and-the-four-levers-that-reduce-it).
- **Typed P3-P5 execution batch (maintainer, 2026-10-21):** after the one-output-
  handler work and execution-core consolidation, remove representation churn
  across target-delta planning, fill and affordability resolution, accounting
  application and event publication on the surviving availability path. Start
  from a bounded comparison of no-fill pulse-heavy, sparse-rebalance and wide
  all-fill workloads. Candidate changes are reuse of prepared indices, a
  no-action fast path, one typed pulse batch, one cash/position delta
  computation, prepared built-in cost resolution and direct typed sink writes.
  The next macro plan must name the workstream and an end-to-end runtime plus
  allocation/memory gate; an isolated microbenchmark is not sufficient.
  Canonical economic output remains exact. An internal typed-R rewrite consumes
  the existing [fold-phase obligations](rfc/README.md#fold-execution-phase-ownership)
  without a new RFC. A persistent compiled carrier, fused P3-plus-P4 kernel,
  new compiled call site or compiled-default change remains with the
  [compiled-execution-envelope RFC](rfc/README.md#compiled-execution-envelope).
  Source:
  ["Typed P3-P5 execution batch"](horizon.md#2026-10-21-execution-typed-p3-p5-execution-batch).
- **One result reader (maintainer, 2026-10-20):** after execution-core
  consolidation leaves one run shape, merge the three result-reader families
  (`R/backtest-results.R`, `R/availability-results.R`,
  `R/corporate-action-results.R`), which each read the ledger and equity with
  their own helpers and print paths, into one reader with one print path.
  Acceptance: every public result table and print is byte-identical or each
  difference is decided by the maintainer, and no reader re-derives state
  another already provides. Source: lever 4 of the same horizon entry.
- **Explicit export tiering (maintainer, 2026-10-26):** after this release's
  cleanup work (the prove-or-retire pass over thin surfaces, the
  one-result-reader merge and the export-shape repairs) and before the first
  CRAN tag, decide one tier for every export: ordinary research surface,
  low-level and recovery, or fixtures and simulation. Express it through one
  mechanism (`@keywords internal`, a named reference group per tier, or
  unexport) rather than through the pkgdown grouping that holds the
  distinction today, and let the export lock test encode the tier so no
  export lands untiered. Source: the horizon entry
  ["Explicit export tiering before CRAN"](horizon.md#2026-10-26-ux-explicit-export-tiering-before-cran).
- **Core boundary and sister packages (maintainer, 2026-10-26):** measure,
  then decide, what stays in core and what incubates as a private sister
  package in ledgr-research.
  - Measure four inputs: an export census, a coupling and size map per
    candidate sister package, a seam audit of the private adapters and an
    inventory of public seams.
  - Then decide in one core-boundary ADR: the core list, the seams, the
    one-way rule that sister packages use only public API, versioning and
    graduation criteria.
  - The decision precedes export tiering and moves no code by itself.

  Source: the horizon entry
  ["Core boundary and incubated sister packages"](horizon.md#2026-10-26-architecture-core-boundary-and-incubated-sister-packages).
- **Still-live chores:** phase-level memory and parallel-worker budgets, plus
  the plotting, print/result-reader, and symbol-surface work retained by
  [macro-plan Section 5](ledgr_v0_2_2_spec_packet/macro_plan.md#5-explicit-non-goals)
  and the horizon. These remain scoped inputs, not an invented bundle.
- **Explicitly deferred:** the remaining Section 5 items stay with their
  named RFC or horizon route until a packet accepts them.
- **Cross-asset precision design:** after v0.2.2, run the focused
  [asset-precision and tradability RFC](rfc/README.md#asset-precision-tradability)
  before changing fixed-decimal price normalization or target quantity
  granularity. The crypto-readiness evidence is the trigger, not a reason for
  crypto-specific execution rules.
- **Affordability and execution policy (maintainer, 2026-10-27):** decide what
  fills when targets sized at the decision close cannot be afforded at the
  execution price.
  - Today the whole cash-consuming fill is rejected, in stable-ID order, and
    the rejection appears only in diagnostics.
  - The focused [execution-policy RFC](rfc/README.md#execution-policy)
    decides the default (rejection or proportional scaling), how it is
    disclosed, and its OMS lifecycle vocabulary.
  - It belongs before the first CRAN release because it changes default
    results for strategies that invest close to fully.
  - Reporting existing refusals in `print()`, the summary and run completion
    needs no RFC and may land earlier.

  Source: strategy-grammar spike stage 1 (`spike/strategy-grammar` at
  `55511d2f`).
- **Inventory decisions (maintainer, 2026-10-27):** these come from the
  [inventory reconciliation](ledgr_v0_2_3_spec_packet/inventory_reconciliation.md).
  - **First CRAN release:** a version below 0.3.0. No version number is
    committed. Work bound to "the first CRAN release" keys on that release,
    not on v0.2.3.
  - **Caller RNG:** with `seed = NULL`, save and restore the caller's RNG
    around worker start and stop. This is the 2026-10-22 decision that missed
    its cut.
  - **Stale RFC states:** persisted-data execution placement and
    portfolio-construction move from Parked to Due and are taken up in this
    release.
  - **Debt:**
    - the defensive-code and complexity audit, including the large test
      files;
    - the documentation surface: Rd pages without examples, `dontrun` pages,
      `@inheritParams`;
    - the roxygen collation pin.
  - **Print:** the run-list "INCOMPLETE" footer prints only when a run is
    INCOMPLETE. The last-bar no-fill warning is settled within execution-core
    consolidation.
  - **Plotting pass:** restored from `7aad7e1f`. It is a direct-ticket
    documentation workstream, and each plot needs maintainer sign-off at the
    cut before any is drawn. The six candidates, in priority order:
    1. *How Targets Become Fills*: decisions at the close and fills at the
       next open.
    2. *Selection Integrity*, K-Ratio: smooth and noisy paths with nearly
       equal endpoints.
    3. *Selection Integrity*, PBO: in-sample rank per segment for the
       rotating and stable panels.
    4. *Indicators And Features*: SMA warmup.
    5. *Missing Data And Session Calendars*: a session timeline.
    6. *Risk And Cost*: targets before and after the risk chain.

    Each plot replaces prose or a table, runs from the article's executed
    objects, follows the existing ggplot2 style, has a caption and alt text,
    and keeps the article's source length flat. Excluded: a first-run equity
    plot in the README or Quickstart, a Sweeps parameter heatmap, and a
    Walk-Forward degradation chart while the example has two folds.
- **Promotion proof after the next core release:** keep the completed crypto2
  readiness work private through v0.2.2 and the next release's performance,
  memory, execution-core and cleanup work. Once those outcomes are accepted,
  open a separately versioned public `ledgr.crypto2` sister package with a
  user-run downloader, local cache, native snapshot adapter, synthetic tests
  and one point-in-time top-100 article. It publishes no provider rows and is
  release-adjacent promotion evidence, not a blocker for the core tag.

### Deferred maintenance inventory

Carry forward the plotting, print/result-reader and symbol-surface work, and
every item explicitly deferred to this release in
[macro-plan Section 5](ledgr_v0_2_2_spec_packet/macro_plan.md#5-explicit-non-goals)
and the horizon. At packet preparation, reconcile each against the completed
v0.2.2 tree and record one disposition: already completed, included,
superseded with a named replacement, or explicitly deferred again by the
maintainer with a reason and route. Inclusion in the inventory does not turn
a design question into a cleanup ticket. Other v0.2.2 non-goals and parked
horizon ideas are not automatically promoted.

The [export shape audit](audits/v0_2_2_export_shape_audit.md) of 2026-10-26
is a named input to this inventory. Its nine findings carry their routes in
its Section 6 and in the horizon entry
["Export shape audit findings and their routes"](horizon.md#2026-10-26-ux-export-shape-audit-findings-and-their-routes);
the five that ride the result-reader and symbol-surface work are reconciled
here like every other item, and the tiering follow-up is the carried
commitment above.

<a id="next-release-scope-dispositions"></a>

| Target artifact | Addressed section/group | Disposition | Replacement or retained address |
| --- | --- | --- | --- |
| `ledgr_roadmap.md` | Next release: selection from themes | amended | Next release: dated goal, UX scope, carried commitments and maintenance inventory above |
| `ledgr_roadmap.md` | Later direction: portfolio construction | amended | Next release owns bounded research-authoring gaps; Later direction retains broader portfolio construction |
| `rfc/rfc_history_wave_v0_2_2_decisions.md` | Resume here: structural memory reduction and Session E budget work | unchanged | Resume here; memory remains a major next-release outcome and the WS3/WS4 budget decisions stay with Session E |

The [horizon](horizon.md) retains non-binding questions and the
[RFC pipeline](rfc/README.md) retains accepted obligations.

## Later direction

The [2026-10-16 scope decision](#next-release-scope-dispositions) promotes only
the bounded portfolio-authoring work named above from this later direction.

Later releases may take exact equity quantity settlement, opt-in factor or
prediction evidence (LFB-028), fitted-transform and ML lifecycle work,
broader portfolio construction, external point-in-time regressors, liquidity and
capacity, OMS/paper trading, and production observability. The accepted
[OMS synthesis sequencing](rfc/rfc_ledgr_oms_seed_synthesis.md#2-roadmap-sequencing)
still places a paper adapter before a live adapter and small-scale live trading
at v1.0.0; no calendar date is currently bound. These are directions, not
promises. Promotion starts in the RFC pipeline or an accepted packet; until
then the horizon remains non-binding.

## Boundary

The design tree stays under `inst/design` as source-checkout evidence and is
excluded from built packages by `.Rbuildignore`. Cut 14 established and tests
that build boundary. Cut 15 deliberately performs no path rewrite, mirror,
redirect tree, or compatibility shim.

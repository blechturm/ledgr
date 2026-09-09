# ledgr v0.2.0.0 Batch Plan

Status: Batches 0-1 complete after review. Batches 2-11 are pending.

Spec: `inst/design/ledgr_v0_2_0_0_spec_packet/v0_2_0_0_spec.md`
Tickets: `inst/design/ledgr_v0_2_0_0_spec_packet/v0_2_0_0_tickets.md`

## Review Protocol

A batch is the independent review unit. Ticket dependencies are the hard
readiness gate; numeric batch order is the default sequence. If an independent
ticket lands out of order, status text must name the completed and blocked
batches rather than implying linear progress.

For implementation batches:

- implement only the listed tickets;
- add detecting assertions before correctness fixes;
- preserve separate commits where the ticket or spec requires them;
- run targeted verification and the named regression net;
- update this plan, the ticket Markdown, `tickets.yml`, and packet README;
- stop for independent review before commit unless the maintainer directs
  otherwise.

The spike protocol's correction and extraction size budgets are stop signals.
Do not merge coordinator stages or conceal corrections in mechanical moves.
Batch 8 cannot close on parity alone; its economics and controlled-prefix
evidence require independent review before Batch 9. Batch 9 likewise requires
terminal recovery, idempotency, fresh-session inspection, and cross-path
completion review before Batch 10.

Batch 11 starts by reading `inst/design/release_ci_playbook.md`.

## Ticket-Cut Decisions

- The maintainer accepted the phase-specific failure, terminal idempotency,
  finalization-only recovery, schema/hash/calendar, committed decision trace,
  diagnostic gross-exposure, finite-window feature, state/index, quarantine,
  and active short-exposure contracts on 2026-09-09.
- Invalid observations fail by default. Explicit quarantine is available only
  on the dataframe path with complete declared sessions and remains hashed,
  non-runtime evidence.
- Availability-aware execution rejects opening, increasing, or reversing into
  short exposure. Dense negative-target behavior remains an uncontracted
  future shorting/financing issue.
- Achieved INCOMPLETE runs are terminal and idempotent. FAILED finalization
  with durable terminal intent recovers projections only and never reruns the
  pulse loop.
- Affected exposure is diagnostic gross exposure based on held quantities and
  the latest accepted observation knowable at the stop cutoff.
- The fills cursor, `lazy`, and `stream_threshold` are removed without aliases.
- Coordinator stage numbers are extraction order, never permission to reorder
  runtime effects.

## Batch 0 - Packet Alignment And Ticket Cut

Status: Complete After Review.

Tickets:

- LDG-2672

Scope:

- record maintainer acceptance and the two RFC amendments;
- allocate LDG-2672 through LDG-2703;
- record baseline `048b925e5411b7c1a7500d4163163aed72039062`, R
  4.5.2 ucrt on `x86_64-w64-mingw32`, duckdb 1.4.3, and dplyr 1.1.4;
- record that no named maintainer-owned store inventory was supplied at cut
  and make LDG-2684 inventory stores and wide artifacts before editing;
- create packet README, tickets, YAML, and this plan;
- align active design, roadmap, horizon, RFC, AGENTS, NEWS, and doc-contract
  pointers;
- make no runtime or public-API implementation change.

Review focus:

- every spec section, H1-H12 gate, U1-U24 gate, and first-review regression
  has a ticket owner;
- dependencies enforce correction before extraction and hardening before
  availability;
- no test is represented as passed by ticket cut.

Exit criteria:

- packet artifacts parse and agree on all IDs, statuses, and dependencies;
- governance surfaces identify v0.2.0.0 as active;
- the environment baseline and explicit LDG-2684 inventory handoff are
  recorded;
- independent review accepts the ticket cut before Batch 1.

## Batch 1 - Hardening Corrections

Status: Complete After Review.

Tickets:

- LDG-2673
- LDG-2674
- LDG-2675
- LDG-2676

Scope:

- correct reversal-fee projection with pro-rata derived allocation;
- make `ledgr_run_fills()` an eager one-argument reader;
- restore lineage on `review$ranked` while keeping `top` presentation-only;
- restore both retained risk fields explicitly.

Review focus:

- H1-H5 detect each correction independently;
- cash, basis, realized PnL, event order, candidate identity, and persistence
  remain intact;
- cursor code and former arguments are removed without compatibility aliases.

Exit criteria:

- H1-H5 pass;
- each correction is independently reviewable and committed separately;
- corrected outputs become the mechanical-refactor baseline.

Implementation evidence:

- H1-H2 assert pro-rata reversal-fee allocation and source-event conservation
  on the durable reader. The same allocation helper or algorithm is applied in
  event reconstruction, memory-backed sweep, and compiled spot-FIFO paths; the
  existing compiled parity fixture now pins the absolute fee splits and totals
  for both memory and reconstructed projections.
- H3 removes the cursor, `lazy`, and `stream_threshold` branches; empty,
  populated, borrowed-connection, and 220-row reads return eager full-schema
  tibbles through the one-formal public API.
- H4 restores `review$ranked` as a sweep result with source and risk lineage,
  preserves ranking order into promotion, and keeps `top` presentation-only.
- H5 restores both risk attributes explicitly and verifies direct restoration,
  base/dplyr subsetting, reopened persistence, and candidate identity.
- The focused hardening and contract tests, all 142 Rd files, and the full
  local suite pass; the full suite has one expected missing-package-path skip.
- `R CMD build --no-build-vignettes` succeeds and `R CMD check --no-manual
  --no-build-vignettes` completes with the two existing missing-`inst/doc`
  vignette warnings and one existing long-path note. A standard source build
  remains blocked by the repository's existing Quarto weave-output issue.
- Review follow-up bound the four corrections in `contracts.md` and NEWS,
  stripped sweep lineage from `review$top`, and added detecting reversal-fee
  assertions to the compiled parity fixture.

## Batch 2 - Inspection And Workflow Hardening

Status: Pending.

Tickets:

- LDG-2677
- LDG-2678

Scope:

- expose committed `risk_chain_hash` through `ledgr_run_info()`;
- verify run handles remain durable locators after `close()`;
- teach ordinary target extraction and explicit review/promotion/new-session
  workflow;
- repair only verified stale examples.

Review focus:

- H6-H8 use recorded evidence and public fields;
- reads remain read-only and release owned resources;
- no proposed `ledgr_target_values()` or new run reader is introduced.

Exit criteria:

- H6-H8 and installed README execution pass;
- lifecycle and teaching assertions remain useful through later file moves.

## Batch 3 - Mechanical Ownership And Coordinator Stages 1-2

Status: Pending.

Tickets:

- LDG-2679
- LDG-2680

Scope:

- split `R/backtest.R` into the accepted ownership files without changing
  bodies or formals;
- extract coordinator preparation stage 1 and snapshot stage 2 in separate
  bounded commits;
- keep clock, seed, status, transaction, cleanup, calendar, and handler effects
  at their current runtime positions.

Review focus:

- H11 runs after every move/stage;
- no shared mutable coordinator environment or second engine appears;
- wrapper deletion retargets callers without weakening assertions.

Exit criteria:

- full suite is green after each bounded commit;
- snapshot, resume, event-order, and acceptance regression nets are unchanged.

## Batch 4 - Failure And Boundary Corrections

Status: Pending.

Tickets:

- LDG-2681
- LDG-2682
- LDG-2683
- LDG-2684

Scope:

- add the real finalization fault and correct FAILED/error/recovery behavior;
- add the causal/leaking feature and future-perturbation gate;
- preserve caller RNG and tighten cleanup/warning/doc-contract fixtures;
- add reversible wide-name escaping last among artifact-shape corrections.
- inventory maintainer-owned stores and affected wide artifacts before the
  first escaping-related shape edit.

Review focus:

- H9, H10, and H12 are detecting tests, not self-confirming parity;
- the escaping implementation uses the prefix-plus-lowercase-hex rule already
  bound by spec Section 2.1 rather than selecting another syntax;
- committed fold/features survive finalization failure and resume without
  duplicates;
- original candidate IDs and long/matrix outputs remain unchanged.

Exit criteria:

- H9-H10 and H12 pass with their negative controls;
- the finalization correction is complete before coordinator stages 3-4.

## Batch 5 - Coordinator Stages 3-4

Status: Pending.

Tickets:

- LDG-2685
- LDG-2686

Scope:

- extract finalization and its second lot pass as stage 3;
- extract registration, resume, DONE shortcut, and tail cleanup as stage 4;
- keep coordinator-scoped cleanup and explicit handler/store dependencies.

Review focus:

- each stage is one bounded commit with H11 afterward;
- H12 and clean/resumed equality remain meaningful;
- extraction order does not become runtime reorder permission.

Exit criteria:

- H11-H12 and existing partial-run/resume tests pass after both stages;
- API hardening is complete before availability schema work begins.

## Batch 6 - Facts Calendar Snapshot Schema And Quarantine

Status: Pending.

Tickets:

- LDG-2687
- LDG-2688
- LDG-2689

Scope:

- add normalized fact constructors and the pre-seal validation report;
- add the complete venue-session clock and explicit EOD mapping;
- add store schema 113, saved-sweep schema 4, hash rule 2, transactional
  migration, and acknowledged quarantine;
- draft the public walkthrough fixture shape without advertising execution.

Review focus:

- U14-U16, U21, and U24 structural assertions distinguish omission, unknown,
  conflict, invalidity, and quarantine;
- dense snapshots remain byte-identical under hash rule 1;
- explicit quarantine never turns rejected evidence into runtime bars.

Exit criteria:

- fact/calendar/schema/hash/quarantine tests pass through fresh connections;
- no availability strategy is advertised before the connected path exists.

## Batch 7 - Activation Provider State And Strict Features

Status: Pending.

Tickets:

- LDG-2690
- LDG-2691
- LDG-2692

Scope:

- add availability activation, public universe/valuation constructors, and
  effective-plan disclosure;
- add the internal provider, dynamic axis/context planes, and stable-key
  `asset_state` lifecycle;
- add strict expected-session feature windows and causal cache identity.

Review focus:

- U2-U4, U6, U10, U20, U23, and the feature part of U24 pass;
- provider code contains no economic policy;
- compiled availability fails closed while dense compiled behavior remains.

Exit criteria:

- the same ordinary strategy reaches dense and active contexts;
- no shared-fold affordability, valuation, or fill policy is implemented here.

## Batch 8 - Shared-Fold Availability Economics

Status: Pending.

Tickets:

- LDG-2693
- LDG-2694
- LDG-2695
- LDG-2696

Scope:

- enforce target restrictions, helper safety, post-risk closure, and the
  active short-exposure guard;
- add fresh/stale mark selection and diagnostic gross exposure;
- add virtual-ledger affordability and execution reconciliation;
- add typed controlled stops, direct completion rows, and diagnostics.

Review focus:

- independent expected economics cover U5, U7-U8, U13, U17-U22, U24, and all
  five first-review regression rows;
- rejected sales fund nothing and no new short finances a purchase;
- expected stops commit only valid prefixes while unexpected fold exceptions
  retain rollback semantics.

Exit criteria:

- targeted economics and controlled-prefix suites pass;
- independent review accepts this boundary before Batch 9 starts.

## Batch 9 - Terminal And Cross-Path Evidence

Status: Pending.

Tickets:

- LDG-2697
- LDG-2698
- LDG-2699
- LDG-2700

Scope:

- implement terminal DONE/INCOMPLETE finalization-only recovery and idempotent
  same-ID reopening;
- propagate completion evidence through saved sweeps and parallel dispatch;
- propagate incomplete outcomes through walk-forward carry-state chains;
- expose durable diagnostics/availability/explanation views and verify
  run/sweep/parallel/walk-forward parity.

Review focus:

- achieved terminal reruns invoke no strategy and rewrite no projections;
- INCOMPLETE evidence stays visible but cannot be selected or promoted;
- inspection and explanation reconstruct no strategy targets.

Exit criteria:

- U1, U9, U11-U12 and fresh-connection recovery tests pass;
- independent review accepts terminal and cross-path semantics before Batch 10.

## Batch 10 - Teaching Reference And Deferral Closeout

Status: Pending.

Tickets:

- LDG-2701
- LDG-2702

Scope:

- ship the Survivorship Bias article and connected public workflow;
- generate help, pkgdown, condition/reason reference, and maintainer traces;
- update contracts, NEWS, roadmap, horizon, active indexes, and audit
  dispositions without overstated point-in-time or completeness claims.

Review focus:

- ingest-run-explain-close-reopen executes entirely through public APIs;
- strict rejection, quarantine, failed exit, retained holding, incomplete
  result, and disabled checks are taught plainly;
- deferred shorting, settlement, OMS, imputation, and optimization work stays
  deferred.

Exit criteria:

- U12, H8, generated documentation, pkgdown, and doc-contract checks pass;
- every scoped audit item is closed or explicitly routed.

## Batch 11 - Release Gate

Status: Pending.

Tickets:

- LDG-2703

Scope:

- read and follow the release CI playbook;
- run full local, installed-example, build/check, coverage, pkgdown, and Linux
  persistence/documentation gates;
- prepare closeout evidence for remote CI, merge, and tag.

Review focus:

- every ticket is complete after review or explicitly deferred by maintainer
  amendment;
- no generated local artifact or disposable spike implementation is committed;
- branch, main, and tag CI remain separate evidence.

Exit criteria:

- release checks pass or exceptions are explicitly documented and accepted;
- packet closeout is complete and the branch is ready for remote release work.

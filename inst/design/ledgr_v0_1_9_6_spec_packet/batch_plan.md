# ledgr v0.1.9.6 Batch Plan

Status: Batch 10 implementation complete; awaiting Claude review.
Spec: `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md`
Tickets: `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_tickets.md`

## Review Protocol

A batch is the unit of Claude review. Batches group atomic tickets that can be
implemented and reviewed together without mixing unrelated subsystems.

Work one review batch at a time.

For implementation batches:

- finish the scoped batch;
- run targeted verification;
- update `v0_1_9_6_tickets.md`, `tickets.yml`, and this batch plan together;
- stop and ask for Claude code review with an inline prompt;
- do not commit before review unless the maintainer explicitly directs it.

If a batch starts requiring broad unrelated diffs, generated-doc churn beyond
the expected surface, or implementation work outside the ticket, stop and ask
before continuing.

The release gate must begin by reading
`inst/design/release_ci_playbook.md` into context.

## Ticket-Cut Decisions

- PBO/CSCV implementation is cut only as LDG-2658 after LDG-2650 returned a
  maintainer-accepted green synthesis for a native implementation ticket.
- Business objective and objective-filtered walk-forward identity remain
  deferred. No narrowed objective override is cut.
- MinTRL is in scope as the first self-contained diagnostic.
- DSR/effective-trial clustering is in scope only if reference verification is
  green; it is independent of PBO.
- K-Ratio and Triple Penance are deferred.
- RPESE and `pbo` are not added to `Suggests` unless verification says the
  current packet needs them.
- Intraday audit runs after retained-return panel work.
- Peer benchmark redo is internal measurement only.

## Batch 0 - Packet Alignment And Ticket Cut

Status: Complete after Claude review; dependency patches applied.

Tickets:

- LDG-2645

Scope:

- create packet README, tickets, machine-readable tickets, and this batch
  plan;
- bind cut-line decisions from the spec;
- prepare the packet for Claude review.

Review focus:

- ticket coverage against every spec scope item;
- consistency between `v0_1_9_6_tickets.md`, `tickets.yml`, and this plan;
- no implementation work mixed into ticket cut.

Exit criteria:

- packet artifacts exist and are internally consistent;
- Claude review prompt is ready.

## Batch 1 - Packet-Open Gates

Status: Complete after Claude review.

Tickets:

- LDG-2646

Scope:

- verify optional package facts and dependency posture;
- confirm the Methodological Diagnostics styleguide gate and doc-contract
  lock;
- record packet-open decisions before validation implementation begins.

Review focus:

- no stale package/API assumptions;
- no optional packages promoted to `Imports`;
- styleguide test is non-vacuous and does not assert on future articles.

## Batch 2 - Canonical Run Returns

Status: Complete after Claude review.

Tickets:

- LDG-2647

Scope:

- add `as_tibble(bt, what = "returns")`;
- add `ledgr_results(bt, what = "returns")` as the delegating convenience view;
- update `contracts.md`, docs, and tests for the new closed result-set member.

Review focus:

- `as_tibble()` and `ledgr_results()` share one result-table path;
- return formula reuses the existing adjacent-equity source of truth;
- identity bytes and persisted evidence remain unchanged.

## Batch 3 - Retained-Return Panel And Projections

Status: Complete after Claude review.

Tickets:

- LDG-2648
- LDG-2649

Scope:

- normalize retained sweep returns into deterministic validation panels;
- add adapter-shaped matrix/data-frame/optional projections;
- enforce complete-grid and retained-evidence gates.

Review focus:

- panel shape is deterministic and evidence-derived;
- ragged or unretained evidence fails closed;
- optional adapter packages remain optional;
- no strategy evidence is recomputed from fills or positions.

Grouping note: these two tickets share the return-panel substrate and should be
reviewed together so projection behavior cannot drift from panel hygiene.

## Batch 4 - PBO Spike

Status: Complete after Claude review.

Tickets:

- LDG-2650

Scope:

- run the PBO/CSCV method and package spike;
- produce the reviewed synthesis and green/yellow/red verdict;
- decide whether a later conditional PBO implementation ticket may be added.

Review focus:

- no public PBO implementation is mixed in;
- known-answer/reference evidence is adequate;
- adapter-vs-native verdict is concrete;
- "what PBO cannot prove" is taught explicitly.

## Batch 5 - Native PBO/CSCV

Status: Complete after Claude review.

Tickets:

- LDG-2658

Scope:

- implement native PBO/CSCV over retained-return panels after the green spike;
- keep CRAN `pbo` optional as reference evidence only;
- add reference-value and known-direction tests;
- teach PBO interpretation and limits without selection, promotion, or
  business-objective filtering.

Review focus:

- native calculation matches the spike reference fixture;
- known-direction overfit/non-overfit examples are meaningful;
- input gates and failure classes are precise;
- result shape carries evidence metadata and is stable;
- no runtime dependency or winner-picking scope is introduced.

## Batch 6 - Minimum Track Record Length

Status: Complete after Claude review.

Tickets:

- LDG-2651

Scope:

- implement and document MinTRL as the first self-contained diagnostic;
- add reference or known-direction tests;
- keep it evidence-only, with no selection or promotion.

Review focus:

- input evidence contract and failure classes are precise;
- method output is stable and documented;
- article section satisfies the Methodological Diagnostics rule.

## Batch 7 - DSR And Effective-Trial Clustering

Status: Complete after Claude review.

Tickets:

- LDG-2652

Scope:

- verify and implement DSR with deterministic effective-trial clustering only
  if reference evidence is green;
- otherwise record deferral cleanly.

Review focus:

- DSR is not coupled to PBO;
- clustering/effective-trial behavior is deterministic;
- weak or unverifiable methodology defers rather than ships.

## Batch 8 - Selection Integrity Teaching Surface

Status: Complete after Claude review.

Tickets:

- LDG-2653

Scope:

- create/update the Selection Integrity article family for diagnostics that
  actually shipped;
- add executable and cautionary examples;
- add non-vacuous documentation-contract assertions.

Review focus:

- teaching coverage follows the styleguide;
- docs do not imply future profitability proof, winner-picking, promotion, or
  business-objective filtering;
- examples execute unless a standard exception is recorded.

## Batch 9 - Intraday-Readiness Audit

Status: Complete after Claude review.

Tickets:

- LDG-2654

Scope:

- run the intraday-readiness architecture audit after panel substrate work;
- write a versioned audit artifact;
- estimate refactor size for every material finding.

Review focus:

- audit-only boundary is preserved;
- every high/medium finding has source evidence;
- no intraday runtime implementation slips in.

## Batch 10 - Peer Benchmark Redo

Status: Complete after Claude review.

Tickets:

- LDG-2655

Scope:

- rerun or prepare the internal peer benchmark on the current cost/risk
  surface;
- keep compiled spot-FIFO rows opt-in and internal;
- update benchmark artifacts only after parity/methodology checks.

Review focus:

- benchmark language is internal measurement, not public ranking;
- parity is interpreted before timing;
- no runtime optimization or compiled-default flip is mixed in.

## Batch 11 - Release Surfaces

Status: Complete after Claude review.

Tickets:

- LDG-2656

Scope:

- update NEWS, README/pkgdown surfaces, roadmap, horizon, AGENTS, and design
  indexes as appropriate;
- record PBO spike verdict, native PBO shipped/deferred state, and deferrals;
- ensure public surfaces match actual shipped scope.

Review focus:

- no PBO/business-objective overclaim;
- shipped diagnostics and substrate are described accurately;
- deferrals are captured with reasons.

## Batch 12 - Release Gate

Status: Local release gate complete; branch ready for remote CI, merge, and tag.

Tickets:

- LDG-2657

Scope:

- follow the release playbook;
- run local gates;
- prepare merge/tag only after gates pass.

Review focus:

- release playbook was read first;
- full relevant verification passed or failures were explicitly accepted;
- no generated local artifacts are committed;
- release closeout is accurate.

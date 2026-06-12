# ledgr v0.1.9.5 Batch Plan

Status: Batch 1B implementation complete; awaiting Claude review.
Spec: `inst/design/ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md`
Tickets: `inst/design/ledgr_v0_1_9_5_spec_packet/v0_1_9_5_tickets.md`

## Review Protocol

A batch is the unit of Claude review, and batches GROUP tickets that can be
tackled together before one review (maintainer correction at ticket-cut
review, M-4: the original cut had degenerated into one ticket per batch).
Spec batch identifiers are preserved in ticket titles; the review batches
below regroup them where the work shares a subsystem or review type. The
spec-bound 1A/1B/1C hardening split is preserved as separate review stops
per the spec-review revision; Batch 2 joins 1C because it is the same
kernel/accounting/cost subsystem, not an unrelated one.

Work one review batch at a time.

For implementation batches:

- finish the scoped batch;
- run targeted verification;
- update `v0_1_9_5_tickets.md`, `tickets.yml`, and this batch plan together;
- stop and ask for Claude code review with an inline prompt;
- do not commit before review unless the maintainer explicitly directs it.

If a batch starts requiring broad unrelated diffs, generated-doc churn beyond
the expected surface, or implementation work outside the ticket, stop and ask
before continuing.

The release gate must begin by reading
`inst/design/release_ci_playbook.md` into context.

## Ticket-Cut Decisions

- Split E from the vignette-screening audit is deferred out of v0.1.9.5.
- The standalone debugging article is deferred out of v0.1.9.5.
- N-1 and N-2 are optional Batch 2 ride-alongs only if touched naturally.
- N-3, N-5, and N-6 remain recorded-not-scheduled.
- N-4 is conditional on the M-4 route.
- The pkgdown third-group label is `Going Deeper` unless implementation review
  identifies a better existing convention.

## Batch 0 - Packet Alignment And Ticket Cut

Tickets:

- LDG-2627

Scope:

- create packet README, tickets, machine-readable tickets, and this batch plan;
- bind cut-line decisions from the spec;
- prepare the packet for Claude review.

Review focus:

- ticket coverage against every spec batch;
- consistency between `v0_1_9_5_tickets.md`, `tickets.yml`, and this plan;
- no implementation work mixed into the ticket cut.

Exit criteria:

- packet artifacts exist and are internally consistent;
- Claude review prompt is ready.

## Batch 1A - Release-Blocking Stale Vignette Fixes

Tickets:

- LDG-2628

Scope:

- fix the three stale vignette items carried from the screening audit;
- update documentation-contract tests for intentional pointer-string changes;
- keep this docs-only and pre-rename.

Review focus:

- stale language genuinely removed;
- replacements do not imply validation toolkit, production deployment, or other
  deferred features;
- no API rename work mixed in.

## Batch 1B - Runner And Results Hardening

Tickets:

- LDG-2629

Scope:

- fix M-8 dead-cursor behavior;
- add H-1 fail-closed single-pulse/window guard;
- fix H-3 elapsed-time seconds reporting;
- add focused tests.

Review focus:

- M-8 is fixed before Batch 3 rename work;
- the H-1 condition is named and consistent with next-bar fill semantics;
- elapsed-time behavior is user-facing and coherent.

## Batch 1C+2 - Kernel, Accounting, And Cost Hygiene (one review)

Tickets:

- LDG-2630
- LDG-2631

Scope:

- fix B-1 compiled `spot_fifo` protection discipline;
- fix H-2 lot-application fail-closed behavior;
- remove legacy full-spread internal cost resolver and port tests to public
  cost models;
- add M-2 scalar argument validation;
- convert M-3 compiled errors to `cpp11::stop`;
- clarify M-7 fee-versus-rounding order;
- apply optional N-1/N-2 only if naturally touched;
- keep N-3/N-5/N-6 recorded and N-4 conditional;
- add focused regression coverage across both tickets.

Review focus:

- compiled protection fix is minimal and correct;
- accounting invalid-state behavior fails closed;
- existing event/accounting parity remains intact;
- no cost identity drift and no hidden execution-semantics change;
- optional nits do not expand the batch.

Grouping note: one subsystem family (kernel/accounting/cost), two tickets,
one review sitting. This does not contradict the spec-review 1A/1B/1C split,
which objected to UNRELATED subsystems sharing one review.

## Batch 3 - Rename And Unexport Batch

Tickets:

- LDG-2632

Scope:

- implement the accepted rename and unexport table;
- update exports, generated docs, examples, README, NEWS, pkgdown, UX decisions,
  doc-contract tests, and export lock;
- run the synthesis old-name sweep.

Review focus:

- complete synthesis Section 2.1 coverage;
- no compatibility aliases unless explicitly allowed;
- `ledgr_promote()` retained in the verb-first allowlist;
- Bucket A unexports are correct.

## Batch 4 - Candidate Generic And Walk-Forward Locator

Tickets:

- LDG-2633

Scope:

- implement `ledgr_candidate()` generic;
- remove the walk-forward-specific extractor surface;
- add durable locator attributes to walk-forward results;
- implement resolve-at-call verification and override semantics.

Review focus:

- no live handles stored on result objects;
- override requires `snapshot_id` and `snapshot_hash` match;
- `db_path` may differ;
- classed failure paths are correct.

## Batch 5+6 - Contracts Rework And Identity Reference (one review)

Tickets:

- LDG-2634
- LDG-2635

Scope:

- rework `contracts.md` for the post-rename surface;
- bind R1-R7 and D2;
- implement M-4 and M-6 hardening with tests;
- update identity reference docs after cost, sweep persistence, risk, and
  walk-forward features;
- explain locator attributes without treating them as identity bytes;
- fix the walk-forward identity implementation pointer.

Review focus:

- contracts match code and accepted synthesis;
- M-4 route is explicit and tested; M-6 POSIXct-only hash input is enforced;
- identity bytes are not changed and no new identity fields are invented;
- identity reference language is precise and mutually consistent with the
  reworked contracts (reviewing both together is the point of the pairing);
- generated docs remain coherent.

Grouping note: both tickets are post-rename reference surfaces; reviewing
contracts and the identity reference in one sitting catches
cross-inconsistencies a split review would miss.

## Batch 7 - Vignette Splits

Tickets:

- LDG-2636

Scope:

- implement vignette splits A-D on the correct source articles
  (strategy-development, indicators, metrics-and-accounting,
  experiment-store -- review-patch H-1);
- defer Split E (sweeps is NOT split);
- update navigation, pointer locks, and post-rename names.

Review focus:

- the split sources match the screening audit exactly;
- articles follow the styleguide;
- Split-D recovery landing satisfies the naming synthesis final-review patch;
- no stale anchors or old names remain.

Grouping note: kept as its own review stop -- eight resulting articles is a
full sitting on its own. Batch 8 stays separate for the same reason.

## Batch 8 - New Teaching Surfaces

Tickets:

- LDG-2637

Scope:

- add the risk-and-cost execution policy article;
- add the walk-forward research-arc executable article;
- add the quickstart;
- defer the debugging article.

Review focus:

- articles teach existing shipped behavior only;
- examples are runnable against demo data;
- no validation-toolkit or production claims slip in.

## Batch 9+10 - Maintainer Manual And Internal Narrative (one review)

Tickets:

- LDG-2638
- LDG-2639

Scope:

- add/update cost-resolver, target-risk, and walk-forward fold-machinery manual
  articles, following the Synthesis plus Implementation Trace pattern;
- update internal decision and performance narrative for the v0.1.9.x arc;
- update RFC or decision indexes as needed.

Review focus:

- implementation traces point to actual files;
- prose does not authorize new architecture work;
- manual links and the decision trail are discoverable;
- no public benchmark-marketing language; no broad historical rewrite.

Grouping note: both tickets are internal-facing documentation reviewed with
the same lens; one sitting.

## Batch 11 - Release Surfaces And Roadmap Audit

Tickets:

- LDG-2640

Scope:

- update NEWS, README, pkgdown entry points, roadmap, horizon, design index,
  RFC index, and AGENTS active-packet references;
- record deferred cut-line items and N-item dispositions.

Review focus:

- release surfaces match final implementation;
- NEWS carries the consolidated rename table;
- old-name sweep remains clean.

## Batch 12 - v0.1.9.5 Release Gate

Tickets:

- LDG-2641

Scope:

- follow `inst/design/release_ci_playbook.md`;
- run local release gates;
- push, monitor CI, merge, monitor main, tag;
- write closeout.

Review focus:

- playbook was read before gate work;
- diff-size guard was honored;
- all local and remote release gates have recorded outcomes;
- branch is clean before tag.

## Release-Blocking Gates

- Naming synthesis gates from
  `inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md` are
  release-blocking.
- M-8 must be fixed before or with the rename batch.
- `NEWS.md` must carry the consolidated rename table.
- Old-name references must be zero outside NEWS and design history after the
  rename batch.
- Vignette screening scheduled items must be fixed or explicitly deferred with
  rationale.
- The release gate must include pkgdown and local Ubuntu/WSL verification per
  the release playbook.

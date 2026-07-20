# ledgr v0.1.9.7 Batch Plan

Status: Batch 8 complete after Claude review; Batch 9 pending.
Spec: `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md`
Tickets: `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_tickets.md`

## Review Protocol

A batch is the unit of Claude review. Batches group atomic tickets that can be
implemented and reviewed together without mixing unrelated subsystems.

Work one review batch at a time.

For implementation batches:

- finish the scoped batch;
- run targeted verification;
- update `v0_1_9_7_tickets.md`, `tickets.yml`, and this batch plan together;
- stop and ask for Claude code review with an inline prompt;
- do not commit before review unless the maintainer explicitly directs it.

If a batch starts requiring broad unrelated diffs, generated-doc churn beyond
the expected surface, or implementation work outside the ticket, stop and ask
before continuing.

The release gate must begin by reading
`inst/design/release_ci_playbook.md` into context.

## Ticket-Cut Decisions

- `positive_trajectory` is a self-contained slope test over retained equity;
  K-Ratio is compatible but not a prerequisite.
- `ledgr_sweep_filter_result` must explicitly reject `ledgr_candidate()` and
  cannot rely on missing-method dispatch.
- Closed-trade retention persists `trade_seq` as the stable order key and
  updates saved-sweep schema gates.
- `stable_region` v1 is strict ordered-only; broader nominal/mixed topology is
  deferred.
- Intraday M-1 ships as a warning-only honesty guardrail.
- K-Ratio is conditional on named-variant reference verification.
- Diagnostic-threshold criteria v1 admit candidate-level MinTRL and DSR
  columns only; PBO/CSCV is not a v1 per-candidate threshold criterion.

## Batch 0 - Packet Alignment And Ticket Cut

Status: Complete after review.

Tickets:

- LDG-2659

Scope:

- patch the stale synthesis wording;
- bind `positive_trajectory` slope units;
- create packet README, tickets, machine-readable tickets, and this batch plan;
- bind ticket-cut decisions from the reviewed spec.

Review focus:

- ticket coverage against every spec scope item;
- consistency between `v0_1_9_7_tickets.md`, `tickets.yml`, and this plan;
- no implementation work mixed into ticket cut.

Exit criteria:

- packet artifacts exist and are internally consistent;
- Claude review prompt is ready.

## Batch 1 - stable_region Spike

Status: Complete after review.

Tickets:

- LDG-2660

Scope:

- produce the reviewed strict-lattice detector spike;
- verify ordered-only and fail-closed topology;
- decide whether `stable_region` ships or defers.

Review focus:

- the spike authorizes no API by itself;
- strict-lattice design matches the research input;
- nominal/mixed topology remains deferred.

Implementation notes:

- `stable_region_spike_synthesis.md` records a green, narrow verdict for the
  strict ordered-only lattice detector, pending Claude review and maintainer
  acceptance.
- `stable_region_spike_reference.R` verifies the known-direction fixture:
  broad plateau passes, isolated spike fails, and sparse / unordered /
  duplicate / collapsed grids fail closed.
- No package API or runtime implementation was added in this batch.

## Batch 2 - Closed-Trade Retention

Status: Complete after review.

Tickets:

- LDG-2661

Scope:

- add opt-in retained closed-trade evidence;
- update saved-sweep schema gates and validators;
- preserve no-retention byte stability and reopen compatibility.

Review focus:

- storage schema changes are additive and validated;
- retained evidence has deterministic trade ordering;
- no non-opt-in identity or artifact drift.

Implementation notes:

- `ledgr_sweep_retention()` now supports `trades = "closed"` while retaining
  the default `trades = "none"` behavior.
- `ledgr_sweep_trades()` exposes retained closed-trade evidence with
  `candidate_row`, deterministic `trade_seq`, `close_ts_utc`, `realized_pnl`,
  and `win_loss`.
- Saved-sweep schema v3 adds `sweep_trades`; write-time schema compatibility
  requires it, while pre-extension stores without the table still reopen as
  trade-unretained.
- `closed_trade_retention_storage_smoke.md` records the retained-trade row
  ratio gate (`4 / 12 = 0.3334`, threshold `0.50`) on the deterministic smoke
  fixture.

## Batch 3 - Selection Integrity Teaching Refit

Status: Review Pending.

Tickets:

- LDG-2662

Scope:

- add the worked-example craft clause to the styleguide;
- relax brittle doc-contract header checks without losing anti-overclaim guards.

Review focus:

- the craft clause states the worked-example standard;
- doc-contract tests remain non-vacuous;
- no diagnostic API or behavior changes.

Implementation notes:

- `vignette_styleguide.md` now requires recognizable worked examples with
  calibrating contrasts, not number-only fixtures.
- The documentation-contract test pins content, rendered outputs, and
  anti-overclaim guardrails without rigid section-header assertions.
- SUPERSEDED: the maintainer rejected the rebuilt article (hidden fake-sweep
  boilerplate, function-name-first prose, plots that did not explain). The first
  worked-example refit and the four plots are dropped; the article is rebuilt from
  scratch in Batch 9 (LDG-2671) on the return-panel entry point (Batch 8 /
  LDG-2670). The craft clause and the doc-contract relaxation here stand.

## Batch 4 - Intraday Metric-Context Guardrail

Status: Pending.

Tickets:

- LDG-2663

Scope:

- wire audit M-1 as a warning-only cadence honesty guardrail;
- keep M-2 and L-1 deferred.

Review focus:

- warning fires for sub-daily evidence with daily defaults;
- daily evidence remains quiet;
- no intraday runtime or identity behavior is introduced.

## Batch 5 - K-Ratio Diagnostic

Status: Pending.

Tickets:

- LDG-2664

Scope:

- verify and pin one K-Ratio variant;
- implement native K-Ratio only if verification is green;
- otherwise record a clean deferral.

Review focus:

- named variant and reference evidence are sufficient;
- K-Ratio remains independent of `positive_trajectory`;
- optional packages remain optional or test-only.

## Batch 6 - Business-Objective Core And Criteria

Status: Pending.

Tickets:

- LDG-2665
- LDG-2666

Scope:

- implement the internal criterion-step contract and objective hash;
- implement the D2 criteria and diagnostic-threshold criteria over retained
  evidence.

Review focus:

- all-pass composition, no scoring/ranking;
- criteria threshold only already-computed ledgr-owned evidence;
- missing evidence fails closed;
- no public third-party extension contract is exposed.

Grouping note: the criterion implementation depends on the internal step
contract. Reviewing them together keeps hash, serialization, and evidence
contracts aligned.

## Batch 7 - Sweep Eligibility Filter

Status: Pending.

Tickets:

- LDG-2667

Scope:

- add `ledgr_sweep_filter()` as all-candidates evidence;
- add the anti-selection rejection paths.

Review focus:

- full tear-down table is the default;
- ineligible candidates are preserved;
- candidate extraction, promotion, and walk-forward selection reject the result;
- no identity mutation or persisted artifact writes.

## Batch 8 - Public Return-Panel Entry Point

Status: Complete after review.

Tickets:

- LDG-2670

Scope:

- add a public return-panel constructor so the selection-integrity diagnostics
  accept a return table directly;
- make PBO/MinTRL/DSR/cluster accept a panel or a sweep over one shared contract;
- preserve the sweep path and identity behavior.

Review focus:

- a diagnostic runs on a plain return table with no sweep-object construction;
- sweep-vs-direct-panel diagnostic parity holds;
- malformed panels fail closed; no identity or criteria behavior change.

## Batch 9 - Selection Integrity Vignette Rebuild

Status: Pending.

Tickets:

- LDG-2671

Scope:

- rebuild the article from scratch on the return-panel entry point;
- concept-first teaching, visible input data, contrasts on the clean API;
- drop the rejected plots; add a plot only where it reveals the geometry.

Review focus:

- no hidden sweep-construction boilerplate; input is a visible return table;
- no function-name-first or jargon-first openings; data flow is explicit;
- doc-contract test non-vacuous and green; anti-overclaim intact;
- maintainer accepts the rendered pkgdown article.

## Batch 10 - Release Surfaces And Deferral Ledger

Status: Pending.

Tickets:

- LDG-2668

Scope:

- update NEWS, README/pkgdown, design index, roadmap, AGENTS, horizon, and docs;
- record conditional deferrals and non-scope boundaries.

Review focus:

- shipped surfaces are accurately described;
- no selection/promotion/profitability/identity overclaims;
- deferral ledger is complete and synchronized.

## Batch 11 - Release Gate

Status: Pending.

Tickets:

- LDG-2669

Scope:

- run the release playbook;
- complete local release gates;
- close the packet for remote CI, merge, and tag.

Review focus:

- playbook followed;
- full verification recorded;
- no generated local artifacts committed.

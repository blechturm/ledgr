# ledgr v0.1.9.7 Batch Plan

Status: All batches complete after review. Local release gates passed; the
branch is ready for remote CI.
Spec: `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md`
Tickets: `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_tickets.md`

## Review Protocol

A batch is the unit of Claude review. Batches group atomic tickets that can be
implemented and reviewed together without mixing unrelated subsystems.

Work one review batch at a time.

Ticket dependencies are the hard readiness gate. Numeric batch order is the
default review sequence; when an independent batch is completed out of order,
the packet status must list the completed and blocked batches explicitly rather
than treating the highest completed batch number as linear progress.

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

Status: Complete after review.

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

Status: Complete after review.

Tickets:

- LDG-2663

Scope:

- wire audit M-1 as a warning-only cadence honesty guardrail;
- keep M-2 and L-1 deferred.

Review focus:

- warning fires for sub-daily evidence with daily defaults;
- daily evidence remains quiet;
- no intraday runtime or identity behavior is introduced.

Implementation notes:

- replaced the count-based audit helper with a timestamp-cadence check over
  distinct ordered observations, using a classed
  `ledgr_metric_context_cadence_mismatch` warning for daily contexts over
  clearly subdaily evidence;
- wired the guardrail into the existing sweep metric kernel, single-run metric,
  and stored-run comparison boundaries; walk-forward receives it through its
  existing train-sweep and test-run metric paths;
- kept metric formulas, metric-context hashing, execution, persistence, and all
  run/sweep/candidate/session/promotion/walk-forward identity paths unchanged;
- made timestamp coercion compatible with the declared R 4.2.0 minimum and
  fail-open for malformed cadence evidence so the honesty guard cannot abort a
  metric read;
- updated the metric-context vignette and condition reference, and recorded M-2
  and L-1 as still deferred in `horizon.md`;
- targeted helper, run, comparison, walk-forward, documentation-contract, and
  Rd checks pass; the full local suite passed with one expected optional-package
  path skip;
- Claude review found no blocking issues; its R 4.2.0 coercion and boundary-test
  suggestions were folded in before commit.

## Batch 5 - K-Ratio Diagnostic

Status: Complete after review.

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

Implementation notes:

- pinned the compounded-return Kestner (2013) variant from
  *(Re)Introducing the K-Ratio*, DOI `10.2139/ssrn.2230949`; the 1996,
  2003, Zephyr, and additive-return variants remain non-scope;
- added `ledgr_k_ratio()` over a `ledgr_return_panel` or retained sweep,
  requiring explicit `periods_per_year` rather than inferring annualization
  from optional panel labels;
- added a stable result class, tibble and print methods, source-neutral
  `panel_hash`, nullable sweep provenance, schema/native-version metadata,
  and classed invalid-periodicity, risk-free, sample-size, and return-path
  failures;
- verified the native arithmetic against an independent `stats::lm()`
  reconstruction and a known-direction smooth-growth versus noisy-flat
  fixture, including direct-panel versus sweep parity;
- added the K-Ratio Methodological Diagnostics section to the existing
  Selection Integrity article and pinned its executed contrast in the
  documentation contract;
- review follow-up made the worked example discriminate the 2013 adjustment
  from the excluded 1996 scaling, removed an always-`ok` result column, and
  tightened the endpoint access and introductory prose;
- no optional dependency, execution path, persistence schema, or identity
  path changed.

## Batch 6 - Business-Objective Core And Criteria

Status: Complete after review.

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

Implementation notes:

- added the classed internal criterion-step contract and public
  `ledgr_business_objective()` all-pass constructor, with canonical plan JSON,
  deterministic ordered-step hashing, reconstruction from the canonical plan,
  curated printing, and tamper validation;
- added the seven ledgr-owned v1 criterion constructors. The trade-distribution
  operationalizations are explicit: `even_trades` uses four equal-duration
  scoring-window bins, `even_profit` uses absolute realized-P&L concentration,
  and `stable_runs` uses deterministic `trade_seq` ordering;
- implemented the accepted strict-lattice stable-region detector with
  Manhattan-1 level-index adjacency, data-derived median adjacent-difference
  tolerance, one `min_neighbors` decision control, audit-only support fields,
  and classed fail-closed topology checks;
- added DSR and MinTRL diagnostic-threshold criteria as embedded, hashed
  snapshots of already-computed candidate evidence. The admissible MinTRL value
  column is the shipped `min_track_record_length`; PBO remains ineligible
  because it is sweep-level evidence;
- added objective/criterion condition documentation, Rd pages, pkgdown and API
  export registration, Pardo methodology-reference updates, identity exclusion
  checks, serialization/tamper tests, and known-direction criterion fixtures;
- focused objective/API/documentation tests and the full local suite pass. The
  no-vignette source build passes; installed examples and static analysis pass
  under `R CMD check --no-tests --no-manual --no-build-vignettes`. Existing
  long-path and missing-`inst/doc` check findings remain;
- package checking also exposed and fixed two previously landed hygiene issues:
  the K-Ratio example now qualifies `tibble::as_tibble()`, and return-panel
  long-label generation qualifies `stats::ave()`. Neither changes behavior
  or the Batch 6 contract.
- review follow-up makes MinTRL `Inf` values determinate threshold evidence,
  gates stable-region verdicts on the criterion's own `min_neighbors`, pins the
  reconstructed v1 trade-bin count to four, treats all-BREAKEVEN streak length
  as zero, documents lattice-boundary effects, and removes per-trade vector
  growth from stable-run evaluation.
- Claude follow-up review verified all six fixes against the working tree and
  returned ready to commit. A final regression test also locks that encoded
  diagnostic `NA` and `NaN` values still fail closed.

## Batch 7 - Sweep Eligibility Filter

Status: Complete after review.

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

Implementation notes:

- Added `ledgr_sweep_filter()` with a classed candidate-by-criterion result,
  sweep-order preservation, all-pass `eligible` flags, full-table
  `as_tibble()` / print defaults, objective and sweep provenance, and adapters
  for summary, retained-return, retained-trade, strict-lattice, and embedded
  diagnostic evidence.
- Added source-panel verification for embedded diagnostic thresholds and kept
  missing, unretained, mismatched, or malformed evidence fail-closed.
- Added explicit rejection classes for `ledgr_candidate()`, `ledgr_promote()`,
  and walk-forward selection; no eligible-only shortcut was added.
- Integration against a reopened real sweep exposed that canonical
  `max_drawdown` is signed. The criterion now reports its positive loss
  magnitude before thresholding and records the source-sign convention.
- Targeted tests cover all seven owned criterion evidence adapters, diagnostic
  thresholds, ineligible-candidate retention, ordering, tamper detection,
  missing evidence, source mismatch, all three anti-selection paths, and
  saved-sweep reopen. All source test files completed green across the full
  run plus the separately completed final walk-forward group.
- `tools::checkRd()` passed for all 142 Rd files. The no-vignette package
  tarball built successfully; packaged installation, namespace/S3 checks,
  code/Rd checks, examples, and tests passed. The longer `R CMD check` then
  reached only the repository's known missing-`inst/doc` vignette warnings and
  timed out while executing vignette code.
- Claude review found that an auto-detected empty stable-region axis set reached
  the generic explicit-argument validator before its intended grid condition.
  The check now fails with `ledgr_stable_region_invalid_grid`, with a regression
  test; the main filter fixture also uses canonical signed drawdown values and
  verifies their end-to-end normalization.

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

Status: Complete after Claude review.

Tickets:

- LDG-2671

Scope:

- rebuild the article from scratch on the return-panel entry point;
- concept-first teaching, visible input data, contrasts on the clean API;
- drop the rejected plots; add a plot only where it reveals the geometry;
- consume the Selection Integrity-specific findings from the 2026-09-04
  all-vignette review while leaving the broader all-vignette cleanup parked.

Review focus:

- no hidden sweep-construction boilerplate; input is a visible return table;
- no function-name-first or jargon-first openings; data flow is explicit;
- references and convention attribution are stronger without over-teaching;
- doc-contract test non-vacuous and green; anti-overclaim intact;
- maintainer accepts the rendered pkgdown article.

Implementation notes:

- rebuilt `vignettes/selection-integrity.qmd` from scratch around
  `ledgr_return_panel()` and visible candidate-return tables;
- removed the hidden fake-sweep helper and dropped the rejected plots;
- kept the rotating/stable, short/longer, and clustered/independent contrasts
  as executed examples through the public diagnostics;
- rendered `vignettes/selection-integrity.md` and rebuilt the local pkgdown
  site; review article: `docs/articles/selection-integrity.html`;
- targeted doc-contract, forbidden-overclaim, ASCII, and whitespace checks are
  green, with only expected LF-to-CRLF notices from `git diff --check`.
- follow-up review fixes pinned MinTRL and DSR rendered outcome values, added
  the retained-sweep cross-link beside the shape-only block, removed the stray
  DSR console label, split effective-trials output into clean chunks, and
  explained the `steady` PBO contrast.
- the broader all-vignette governance parking was committed separately as
  `2742f9d` before the Batch 9 commit.

## Batch 10 - Release Surfaces And Deferral Ledger

Status: Complete after review.

Tickets:

- LDG-2668

Scope:

- update NEWS, README/pkgdown, design index, roadmap, AGENTS, horizon, and docs;
- record conditional deferrals and non-scope boundaries.

Review focus:

- shipped surfaces are accurately described;
- no selection/promotion/profitability/identity overclaims;
- deferral ledger is complete and synchronized.

Planning note:

- LDG-2668 release-surface pointer updates partially landed early in the
  governance follow-up after the post-v0.1.9.6 API-footprint review. Verify the
  already-updated AGENTS, design-index, roadmap, horizon, and doc-contract pins
  at closeout, and complete the remaining release-surface updates in this batch.

Implementation notes:

- bumped `DESCRIPTION` to `0.1.9.7` and updated NEWS, README source/mirror,
  roadmap, design index, RFC index, AGENTS, horizon, and the packet deferral
  wording to describe the implemented release surface;
- recorded the evidence-only boundary for business objectives and filtering,
  the intraday M-1 warning-only guardrail, and the remaining D4, scored
  composition, broader robustness, public-extension, Triple Penance, M-2/L-1,
  and v0.2.x deferrals without selection, promotion, profitability, or
  execution-identity claims;
- verified `_pkgdown.yml` already indexes every new public v0.1.9.7 surface, so
  no reference-index edit was required;
- added non-vacuous release-surface and anti-overclaim documentation contracts.
  The documentation-contract target passed with 1,755 expectations,
  `tools::checkRd()` passed for all 142 Rd files, and release-surface, ASCII,
  diff-hygiene, and no-runtime-change checks passed.
- Review follow-up removed the inaccurate NEWS claim that the rebuilt Selection
  Integrity article contains plots, made the stale business-objective claim
  guard span wrapped lines under the Perl regex engine, added a synthetic
  positive control against vacuity, and added a negative guard against
  restoring the rejected teaching-plot language.
- Claude re-review verified all follow-up guards and release claims and returned
  the batch ready to commit.

## Batch 11 - Release Gate

Status: Complete after review.

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

Implementation notes:

- ran the release playbook on Windows: the full suite, installed-package
  README check, source build, package check, coverage, and full pkgdown build
  passed;
- accepted the existing package-check status of two missing-`inst/doc`
  vignette warnings and one long archival-path NOTE; coverage was 85.49%;
- ran the local Ubuntu gate on the playbook-minimum persistence tests plus the
  changed retention, objective, filter, and metric-context surfaces, then
  executed the Selection Integrity chunks through `knitr`; all passed;
- recorded and resolved a sandbox-only pkgdown `EPERM` rerun and a first WSL
  attempt contaminated by Windows object files; neither required source edits;
- removed this gate's generated v0.1.9.7 tarball, check directory, coverage
  report, test plot, and compiled `src/` artifacts. Only intended
  release-closeout records and tracked pkgdown site metadata remain in the
  working tree;
- recorded the review-confirmed local developer consequence of compiled
  artifact cleanup: source-tree `pkgload::load_all()` must rebuild and currently
  needs the locally absent `decor` helper, while standard build, check, install,
  and remote-CI compilation remain unaffected;
- Claude review found no blocking issue and accepted the release gate for
  commit and remote branch CI.

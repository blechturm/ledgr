# Current Contract And Decision-Bridge Reconciliation

**Role:** record
**Status:** working
**Authority:** Cut 15 tickets LDG-3043 and LDG-3044 in `tickets.yml`.
**Purpose:** Record the Workstream 33 consolidation pass pending its Type 1
close review.
**Baseline:** `1cbc5166` (accepted Workstreams 32 and 36).

This record compares changed contract prose with the baseline and disposes of
every row that existed in `decisions.md` at the baseline. It is migration and
review evidence, not another editable contract or obligation list.

## Contract rule-group inventory

The thirteen existing H2 contract routes are unchanged. The pass adds 81
explicit `contract-*` group IDs, one immediately before every H3 rule group.
All H3 groups have exactly one explicit ID; all IDs are unique. References use
those IDs rather than paragraph numbers, so adding or moving an unrelated
paragraph does not change an address.

The groups partition the standing bullets. They do not add a semantic layer:
the bullets remain the rules and `contracts.md` remains their sole current
authority.

## Clause reconciliation

`Unchanged meaning` removes release narration or adds navigation only. `Moved
history` removes chronology whose evidence remains in NEWS, the named packet,
or the Git record. `Consolidated` writes an already accepted pending rule into
the current contract. `Pending` preserves the shipped rule and links only to
the bridge.

| Baseline paragraph or span | Current rule group | Disposition | Meaning check and historical receiver |
| --- | --- | --- | --- |
| Public export and family bullets | `contract-public-name-shapes` | Unchanged meaning | Groups the same prefix, family-first, reopen and evidence-accessor rules. |
| Closed v0.1.9.5 verb-first allowlist | `contract-public-name-shapes` | Unchanged meaning | The five-name allowlist is byte-for-byte unchanged; release narration left the operative clause. History remains in the v0.1.9.5 packet and NEWS. |
| Indicator/rule and internal naming bullets | `contract-public-indicator-and-rule-names`; `contract-public-internal-names` | Unchanged meaning | Adds addresses only; removed public spellings remain absent. |
| v0.1.7 `ledgr_run()` entry paragraph | `contract-execution-entry-points` | Unchanged meaning | `ledgr_run()` remains the public single-run path and `ledgr_backtest()` remains dense-only. Version chronology remains in NEWS and the v0.1.7 packet. |
| Canonical path and adapter paragraphs | `contract-execution-entry-points` | Unchanged meaning | Adds one address; no entry-point or delegation rule changed. |
| v0.1.8 fold/output-handler paragraph and following parity rules | `contract-execution-fold-core` | Unchanged meaning | Removes the version prefix only. The fold/output separation and run/sweep parity are unchanged. |
| Scoring and temporary feature-start paragraphs | `contract-execution-window-start` | Unchanged meaning | Adds an address. The two-pulse minimum is the consolidated execution-window rule. |
| Walk-forward no-selection, carry, resume and boundary paragraphs | `contract-execution-walk-forward-folds` | Unchanged meaning | Adds an address; Cut 9-12 citations remain evidence locators. |
| Event staging and parallel-sweep paragraphs | `contract-execution-event-staging` | Unchanged meaning | Removes the v0.1.8.8 prefix from the still-current discard-all rule. |
| Snapshot guard paragraph | `contract-execution-snapshot-trust` | Unchanged meaning | Adds an address only. |
| Cost resolution, pulse-plan and disposition paragraphs | `contract-execution-accounting-events` | Unchanged meaning | Adds an address only; accepted equity-settlement behavior was already present. |
| v0.1.8.10 compiled-accounting paragraph | `contract-execution-compiled-accounting` | Unchanged meaning | Removes release chronology; the same model closure and refusal remain. The internal legacy option is retained because the current product still exposes that hook. |
| Decision/fill contexts and v0.1.9.1 timing paragraph | `contract-execution-decision-and-fill-contexts` | Unchanged meaning | Removes the version prefix; timing and context separation are unchanged. |
| Cost identity paragraph plus M-7 bridge | `contract-execution-cost-model` | Consolidated, corrected after review | States the shipped order exactly: price transforms precede fees, notional fees use the spread-adjusted unrounded price, and exposed fill price is rounded separately. Source history remains in the v0.1.9.5 packet. |
| v0.1.9.3 target-risk paragraphs | `contract-execution-target-risk` | Unchanged meaning | Removes the version prefix; public constructors, identity, exclusions and sweep provenance are unchanged. |
| Walk-forward and config/feature identity paragraphs | `contract-execution-identity` | Unchanged meaning plus consolidated | Removes Cut 15 narration while retaining current rule 3, schema-120 feature-retention deletion and capture identity. Adds the accepted walk-forward override match rule. |
| Strategy preflight paragraph | `contract-execution-preflight` | Unchanged meaning | Adds an address only. |
| v0.1.7 hard-reset history | `contract-execution-preflight` | Moved history | Removed from operative clauses. NEWS and the v0.1.6-to-v0.1.7 migration guide retain it. |
| Fill model and FIFO dust plus H-2 bridge | `contract-execution-fills-and-lots` | Consolidated | Existing rules remain and the accepted classed fill-transition validity rule is added. |
| v0.1.8 sweep-result and provenance paragraphs | `contract-promotion-candidate-evidence` | Unchanged meaning | Removes version narration without changing candidate fields or provenance version. |
| Promotion context and persistence chronology | `contract-promotion-commit` | Unchanged meaning / moved history | Current promotion audit and compact saved-sweep distinction remain; release sequence stays in NEWS and packets. |
| Selection status paragraphs | `contract-promotion-selection-status` | Unchanged meaning | Adds an address only. |
| v0.1.4 config helper and v0.1.7 workflow paragraphs | `contract-config-construction` | Unchanged meaning | Removes version prefixes; construction remains internal and experiment/run remain public. |
| Policy schema paragraphs | `contract-config-policies` | Unchanged meaning | Adds an address only. |
| Snapshot identity through verified-set paragraphs | `contract-snapshot-identity-and-verification` | Unchanged meaning | Adds an address; hash rule 3 remains the sole executable rule. |
| Off-session, bar-validation and fact paragraphs | three matching `contract-snapshot-*` groups | Unchanged meaning | Adds addresses only. |
| v0.1.7 open path and removed direct-bars helper paragraphs | `contract-snapshot-open-and-trust` | Unchanged meaning / moved history | Current snapshot-first and no-window-rehash rules remain; removed-surface chronology stays in NEWS and Cut 14. |
| Availability activation through status paragraphs | `contract-availability-activation-and-calendar`; `contract-availability-units-and-universe` | Unchanged meaning | Adds addresses and removes the superseded LDG-3012 narration; the assumed-default rule is unchanged. |
| Plan/result, fact inspection and provider paragraphs | three matching availability groups | Unchanged meaning | Adds addresses only. |
| Context/state and v0.2.0.0 canonical-R paragraph | `contract-availability-context-and-state`; `contract-availability-targets` | Unchanged meaning | Removes the version prefix; availability execution remains canonical R only. |
| Valuation, terminal, affordability and reason vocabulary | `contract-availability-valuation`; `contract-availability-affordability` | Unchanged meaning | Adds addresses; shipped corporate-action and terminal rules remain complete. |
| Connection, schema 120 and evidence paragraphs | first five persistence groups | Unchanged meaning | Adds addresses. Schema 120 remains sole current format and runtime features remain ephemeral. |
| CSV lifecycle and v0.1.7 snapshot-first paragraphs | `contract-persistence-snapshot-workflows` | Unchanged meaning / moved history | Removes a deleted-lifecycle note and version prefix; current create/seal and snapshot-first rules remain. |
| Run discovery and v0.1.5 telemetry paragraph | `contract-persistence-run-discovery`; `contract-persistence-telemetry-and-recovery` | Unchanged meaning | Removes version narration; current telemetry fields remain identical. |
| Hard-delete v0.1.x sentence | `contract-persistence-run-lifecycle` | Unchanged meaning | States the current absence directly; release chronology remains in NEWS. |
| Canonical JSON v0.1.8.9 chronology and former ordering | `contract-json-durable-bytes` | Unchanged meaning / moved history | Current byte format 2, radix order and rule marker remain. Earlier formats remain in NEWS and Cut 14 records. |
| Session-local keys and feature-map authoring | two matching JSON groups | Unchanged meaning | Adds addresses only. |
| v0.1.7.2 helper paragraphs | `contract-strategy-outputs` | Unchanged meaning | Removes version prefixes; the helper pipeline and outputs are unchanged. |
| Decision-axis acceptance and audit narrative | `contract-strategy-decision-axis` | Moved history | Keeps every operative axis rule and domain table; acceptance/review history remains in the Cut 22 packet and audit. |
| Feature maps | `contract-strategy-feature-maps` | Unchanged meaning | Adds an address only. |
| v0.1.x shorting and v0.1.7 functional-strategy paragraphs | `contract-strategy-supported-surface` | Unchanged meaning | States current unsupported shorting and functional signature directly. |
| Preflight v0.1.8.8 worker metadata | `contract-strategy-reproducibility` | Unchanged meaning | Removes the version prefix; fields remain unchanged. |
| Strategy provenance | `contract-strategy-provenance` | Unchanged meaning | Adds an address only. |
| Context pulse through explicit-map paragraphs | first two context groups | Unchanged meaning | Adds addresses and retained pending backlinks only. |
| Prepared views and feature-map v0.1.7.4 paragraph | `contract-context-prepared-views`; `contract-context-inspection` | Unchanged meaning | Removes the version prefix; the public wide surface remains `ledgr_pulse_wide()`. |
| Indicator, strict-window and TTR paragraphs | three matching context groups | Unchanged meaning | Adds addresses and retains the recursive-history bridge only where affected. |
| Fn-only v0.1.4 and `ctx$flat()`/`ctx$hold()` v0.1.7 paragraphs | `contract-context-feature-path` | Unchanged meaning | Removes version prefixes; the bounded fallback and intent constructors are unchanged. |
| Result reads through valuation | first three result groups | Unchanged meaning | Adds addresses; corporate-action and valuation behavior is now the standing receiver for the retired equity bridge. |
| Reconstruction and fill/sweep restoration | two matching result groups | Unchanged meaning | Adds addresses only. |
| v0.1.7.7 metric chronology and alternate v0.1.8 wording | `contract-result-standard-metrics` | Unchanged meaning / moved history | Keeps shipped Sharpe, scalar risk-free and formula rules; release chronology and obsolete alternate-path wording leave the operative clause. |
| Return panels, diagnostics, objectives and trade statistics | four matching result groups | Unchanged meaning | Adds addresses; objective-filtered identity remains a link-only pending change. |
| Documentation bullets | five documentation groups | Unchanged meaning | Adds addresses and changes `v0.2.2 release notes` to `current release notes`; the pinned claim sentence is unchanged. |
| Testing-architecture bridge and verification bullets | verification groups plus standing test-control artifacts | Corrected / transferred to exact owners | The Verification Contract owns shipped release gates; `tests/README.md`, `tests/test-gates.yml` and `tests/claims.yml` own the current runner, memberships and claim registry. The accepted synthesis remains design history. The contract does not claim to restate that whole process architecture. |

## Decision-bridge reconciliation

The pre-change bridge held fifteen rows. Each appears exactly once below.

| Pre-change row | Disposition | Resolvable destination and recovery |
| --- | --- | --- |
| Execution-window minimum | removed-to-contract | `contract-execution-window-start`; accepted source remains the v0.1.9.5 packet. |
| Fill-transition validity | removed-to-contract | `contract-execution-fills-and-lots`; accepted source remains the v0.1.9.5 packet. |
| Cost rounding and fees | removed-to-contract | `contract-execution-cost-model`; accepted source remains the v0.1.9.5 packet. |
| Walk-forward snapshot override | removed-to-contract | `contract-execution-identity`; accepted source remains the v0.1.9.5 packet. |
| Point-in-time historical projection | retained | Exact v11 sections, history-wave owner, four affected groups and pipeline row remain in `decisions.md`. |
| Recursive-indicator history boundary | retained | Exact feature-projection/v11 sections, history-wave/recursive owner, affected groups and pipeline row remain in `decisions.md`. |
| Objective-filtered walk-forward identity | retained | Exact validation sections, future completion owner, affected groups and pipeline row remain in `decisions.md`. |
| OMS order lifecycle | retained | Exact target-risk/OMS sections, future OMS owner, affected groups and pipeline row remain in `decisions.md`. |
| Equity corporate actions | removed-to-contract / transferred-to-pipeline | Current rules are in `contract-execution-accounting-events`, `contract-availability-valuation` and `contract-result-corporate-actions`; exact-quantity work remains only in the pipeline row `exact-equity-quantity-settlement`. |
| Testing architecture | corrected / transferred-to-standing-process-owners | Shipped release gates are under `contract-verification-release-gates`; the current runner, memberships, gate values and bounded claims registry are owned by `tests/README.md`, `tests/test-gates.yml` and `tests/claims.yml`. The accepted synthesis retains design history. |
| Accounting-core consolidation | corrected / transferred-to-current-internal-owners / transferred-to-pipeline | Current staging and compiled dispatch rules are under `contract-execution-event-staging` and `contract-execution-compiled-accounting`. The accepted synthesis remains authority for the internal carrier/preparer/replay architecture implemented by `R/accounting-replay.R` and `R/lot-accounting.R`; the future compiled envelope remains only in its pipeline row. |
| Feature-map read surface | removed-to-contract | Current alias, explicit-map, signal and inspection rules are under `contract-context-feature-resolution` and `contract-context-inspection`; synthesis history remains at its path. |
| Governance-document authority and lifecycle | transferred-to-ticket / transferred-to-pipeline | Cut 15 Workstreams 32-35 own implementation; check-mode activation and M1 closeout reassessment remain only in the governance-lifecycle pipeline row. |
| Snapshot verification policy | removed-to-contract | Current hash, read-class, verified-set and gate rules are under `contract-snapshot-identity-and-verification`, `contract-execution-snapshot-trust` and `contract-verification-terminal-and-snapshot-gates`; synthesis and Cut 13 retain history. |
| Pre-CRAN legacy removal | removed-to-contract | Current-only store, config, snapshot and API rules remain in their addressed groups; the synthesis, Cut 14 packet and NEWS retain removal history. |

Result: four bridge rows remain, eleven leave, and no accepted unimplemented
decision disappears. The remaining four rows have exact sources, one owner,
affected addressed groups and one pipeline route. No obligation prose is copied
into `contracts.md` or `decisions.md`.

Ordinary bridge exit still occurs at release closeout. Governance-lifecycle
synthesis Section 4 gives this governance workstream one-time authority to
close already-consolidated rows with the same receiver proof. The removed
locator stubs in `decisions.md` preserve every known inbound address without
continuing the row's authority.

### Exact retained-row backlink oracle

The correction check compares each retained row independently, rather than
comparing only the set of bridge IDs.

| Retained row | Exact addressed contract backlinks |
| --- | --- |
| `point-in-time-historical-projection` | `contract-snapshot-point-in-time-facts`; `contract-availability-provider-and-timing`; `contract-context-pulse-data`; `contract-result-read-surfaces` |
| `recursive-indicator-boundary` | `contract-context-indicator-computation`; `contract-context-strict-features` |
| `objective-filtered-walk-forward-identity` | `contract-execution-identity`; `contract-result-business-objectives` |
| `oms-order-lifecycle` | `contract-execution-entry-points`; `contract-execution-accounting-events`; `contract-execution-target-risk` |

## Source-derived scans

The implementation check derives H2, H3 and explicit-ID rows directly from
`contracts.md`; it does not compare a hand-written expected count to itself.
It also scans operative contract prose for version or legacy narration. The
five retained matches describe current executable surfaces or provenance: the
internal compiled-accounting legacy option, explicit refusal of legacy snapshot
roots and R6 strategies, the v0.2.2 terminal-gate evidence locator, and a
current format-oracle test that requires replacement constant names to
disappear.

The report-only governance guard remains report-only. Its reviewed fixtures
exercise bridge-shape failures, but it does not parse the current bridge table
and therefore does not validate this real-tree bridge. The reconciliation,
the exact per-row backlink comparison and independent close review establish
the real-tree result. Workstream 35 owns guard/table alignment.

## Verification

Input identity was accepted Cut 15 baseline `1cbc5166`; the structural
implementation source is `cfa7b969`. Verification ran on Windows x64 with R
4.6.1 ucrt and the user library at
`C:/Users/maxth/AppData/Local/R/win-library/4.6`.

- `testthat::test_file("tests/testthat/test-documentation-contracts.R")`
  passed 1,031 expectations in 10.2 seconds. The six focused metadata,
  availability-feature, feature-retention-removal, release-claim-boundary,
  control-plane and governance-report files passed 350 expectations in 30.7
  seconds. There were no failures, errors, warnings or skips.
- A source-derived R probe counted 13 H2 routes, 81 H3 rule groups and 81
  unique explicit group IDs. It compared the exact addressed backlink set for
  each of the four retained rows. Removing any one of the three OMS backlinks,
  or removing its bridge row, independently failed that comparison; prepending
  an unrelated paragraph left the sampled explicit address unchanged.
- `Rscript tools/governance-report.R` exited zero in 69.941 seconds over 319
  tracked sources. It reported 1,115 findings: 51 baseline structural, 883 new
  structural and 181 advisory. Neither `decisions.md` nor this reconciliation
  produced a finding. The three findings on `contracts.md` are its pre-existing
  missing Role, Status and Authority headers, owned by Workstream 35 rather
  than changed here. The tool remained report-only.
- `yaml::read_yaml("inst/design/ledgr_v0_2_2_spec_packet/tickets.yml")`, the
  local-target and fragment checks exercised by the documentation suite,
  ASCII checks on all four changed files and `git diff --check` passed.

Correction commit `2e87c6a9` was verified from the same environment:

- The exact per-row oracle reports four retained rows and eleven contract
  backlinks. Deleting each of the three OMS backlinks independently fails;
  deleting any of the four bridge rows also fails.
- The documentation-contract, governance-report, control-plane, cost-model,
  corporate-action-disposition and terminal-outcomes files pass 1,712
  expectations with no failures or errors. The cost-model block distinguishes
  an unrounded notional fee from its separately rounded fill price; the
  terminal blocks exercise zero-price write-off dispositions.
- The tracked real-tree report exits zero in 69.925 seconds over 320 sources.
  It reports 1,104 findings: 51 baseline structural, 872 new structural and
  181 advisory. The eleven WS33-introduced broken anchors are gone. The only
  finding on a changed semantic source is the unchanged three-header debt on
  `contracts.md`, still owned by Workstream 35; `decisions.md`, the review and
  this reconciliation produce none.
- YAML, ASCII, local-target and fragment checks and `git diff --check` pass.
  The correction touches no product source.

The independent Type 1 close review is preserved in `close_review_33.md` with
`CHANGES_REQUIRED`. Correction round 1 fixes the two semantic clauses, restores
removed-address locators and lifecycle wording, names exact durable owners and
replaces the set-only bridge witness with the per-row oracle above. No product
code, public behavior, claim registration or RFC decision changed. The
correction introduces no unresolved decision for the maintainer.

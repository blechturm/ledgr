# contracts.md Audit Report

**Ticket:** LDG-2528.
**Date:** 2026-06-03.
**Status:** Completed after Claude review.
**Scope:** Audit `inst/design/contracts.md` after v0.1.8.10 and before any
`contracts.md` edits. This report routes findings only; it does not change
contract semantics.

## Executive Summary

`contracts.md` is broadly aligned with the current post-v0.1.8.10 execution
shape. It already covers the most important current invariants:

- one shared fold core for `ledgr_run()` and `ledgr_sweep()`;
- B2 as an explicit memory-backed sweep spot-FIFO opt-in with default canonical
  R execution and durable compiled integration deferred;
- sealed snapshot trust boundaries;
- canonical event evidence versus derived result outputs;
- functional strategy validation, context helpers, feature contracts, run-store
  discovery, result access, documentation discovery, and release gates.

The audit found five fix-now contract-cleanup items for LDG-2531. They are
wording/structure fixes, not execution changes:

1. the active packet pointer is stale;
2. one fold-entry guard sentence is still written as a v0.1.8.7 future
   obligation;
3. R6/legacy strategy references no longer match the modern function-strategy
   contract;
4. removed context-helper wording is still written as if the reset has not
   landed;
5. one CI sentence is tied to the historical v0.1.2 gate instead of the current
   release gate.

No finding authorizes public API changes, execution-semantics changes, B2
scope expansion, durable compiled integration, target-risk implementation,
OMS/paper/live work, walk-forward work, or cost/liquidity public APIs.

## Audit Method

Reviewed source anchors:

- `inst/design/contracts.md:1-662`, all sections.
- `NAMESPACE:50-147`, exported public surface inventory.
- `R/backtest.R:277-404`, public `ledgr_run()` and
  `compiled_accounting_model` handling.
- `R/sweep.R:23-94` and `R/sweep.R:852-935`, public sweep selector and
  memory-backed candidate execution.
- `R/compiled-spot-fifo.R:1-88`, unsupported-model and memory-handler guards.
- `R/backtest-runner.R:581-585`, committed run entry into the shared fold.
- `R/experiment.R:324-344`, function-strategy validation.
- `R/strategy-provenance.R:1-105`, function-strategy signature and
  reproducibility classification.
- `R/pulse-context.R:432-438`, removed context helper stubs.
- `.github/workflows/R-CMD-check.yaml:18-19` and
  `.github/workflows/R-CMD-check.yaml:58-71`, current CI OS / check /
  coverage gates.

Commands used:

```powershell
rg -n "^##|^###" inst/design/contracts.md
rg -n "compiled_accounting_model|spot_fifo|ledgr_run\\(\\)|ledgr_sweep\\(\\)|canonical|derived|target risk|OMS|walk-forward|paper|live|data_hash|snapshot|ctx\\$vec|ctx\\$idx|pulse_seed|parallel|durable|run_info|replay|strategy_state" inst/design/contracts.md
rg -n "R6|strategy_type|function\\(ctx, params\\)|ledgr_strategy_preflight" R tests inst/design/contracts.md
rg -n -F 'ctx$targets' R tests inst/design/contracts.md man vignettes README.md
rg -n -F 'ctx$current_targets' R tests inst/design/contracts.md man vignettes README.md
rg -n "windows|ubuntu|R CMD check|coverage|release_ci_playbook|tag workflow|pkgdown" .github inst/design/contracts.md
```

## Section Coverage

`NAMESPACE:50-147` was cross-checked against contract surfaces. No public
export lacks a contract entry. New v0.1.8.10 public-surface additions,
including `compiled_accounting_model` on `ledgr_run()` / `ledgr_sweep()`,
`ctx$vec`, `ctx$idx()`, and `ctx$vec$feature(feature_id)`, are covered in the
Execution, Sweep, and Context contract sections.

| Contract section | Source anchor | Coverage result |
| --- | --- | --- |
| Execution Contract | `contracts.md:8-97` | Covers public single-run path, one fold core, output-handler boundary, parallel dispatch, sealed snapshot guard, fold-owned costs, B2 scope guard, preflight, and next-open fill timing. Needs two wording fixes: stale active packet pointer and stale v0.1.8.7 future-tense guard. |
| Sweep Promotion Contract | `contracts.md:98-130` | Covers compact sweep results, execution seed, row provenance, candidate extraction, promotion, durable promotion context, and no full sweep persistence. No immediate contract edit needed. |
| Config Contract | `contracts.md:132-141` | Covers internal config construction and public experiment-first workflow. No immediate contract edit needed. |
| Snapshot Contract | `contracts.md:143-173` | Covers sealed snapshots, artifact hashes, split snapshot/run DB guard, load/verify behavior, trusted normalized primitives, custom snapshot IDs, and retired `ledgr_data_hash()` direct-bars identity. No immediate contract edit needed. |
| Persistence Contract | `contracts.md:175-223` | Covers checkpointing, fresh-connection read-back, schema validation, durable run artifacts, metadata mutation visibility, low-level CSV snapshot workflows, run discovery, telemetry, `ledgr_run_open()`, labels, archives, tags, and no hard delete. No immediate contract edit needed. |
| Canonical JSON Contract | `contracts.md:225-248` | Covers yyjsonr canonical JSON v2 and persisted identity surfaces. No immediate contract edit needed. |
| Strategy Contract | `contracts.md:250-379` | Covers target validation, helper value types, helper composition, feature maps, signal wrapper, function signature, preflight tiers, worker dependencies, ambient RNG, provenance, extraction, and `NULL` / `NA` JSON caveat. Needs R6/legacy cleanup. |
| Context Contract | `contracts.md:381-483` | Covers `ctx$bars`, feature lookup, `ctx$idx()`, `ctx$vec`, `ctx$flat()`, `ctx$hold()`, bundled features, warmup, feature precomputation, TTR adapters, feature cache, removed helpers, and read-only inspection tools. Needs removed-helper tense cleanup only. |
| Result Contract | `contracts.md:485-590` | Covers derived result surfaces, result immutability, result read connections, fill/trade distinction, compare runs, tags, metrics, state reconstruction, fills/equity helpers, risk-free metric context, and standard metrics. No immediate contract edit needed. |
| Documentation Contract | `contracts.md:591-641` | Covers base-pipe examples, installed-documentation discovery, article placement, package help, indicator article consolidation, adapter positioning, pkgdown-only article boundaries, and visible-code helpers. No immediate contract edit needed from this audit; generated docs audit remains LDG-2536. |
| Verification Contract | `contracts.md:643-662` | Covers full tests, package check, coverage, WSL gate, release playbook, tag workflow, and fold-core trust-boundary regression coverage. Needs one historical v0.1.2 CI wording cleanup. |

## Structural Recommendation

The existing section ordering is already surface-first: Execution, Sweep,
Config, Snapshot, Persistence, Canonical JSON, Strategy, Context, Result,
Documentation, and Verification. LDG-2531 should not invert that organization.
Two structural choices remain open for LDG-2531: whether v0.1.8.10
fold-owned FIFO / lot-accounting language deserves a dedicated subsection or
stays bundled under Execution / Cost, and whether version-led bullets such as
"v0.1.7 makes ..." and "v0.1.8.8 ..." should be rewritten to lead with the
surface contract and demote the version to a parenthetical history note. Either
choice is acceptable; this audit does not force a broader restructuring.

## Findings

### C-001: Active Packet Pointer Is Stale

**Classification:** fix-now.
**Route:** LDG-2531.
**Source:** `contracts.md:3-6`.

The header says the active versioned spec packet is
`inst/design/ledgr_v0_1_8_spec_packet/`. The active design index now points to
v0.1.8.11 planning at `inst/design/ledgr_v0_1_8_11_spec_packet/`, and the
latest completed packet is v0.1.8.10.

**Recommended LDG-2531 action:** Replace the stale direct packet path with a
stable pointer to `inst/design/README.md` plus the active packet path, or update
the path to `inst/design/ledgr_v0_1_8_11_spec_packet/` if this index is meant
to name the active planning packet directly.

### C-002: Fold-Entry Guard Sentence Is Written As A Past Future Obligation

**Classification:** fix-now.
**Route:** LDG-2531.
**Source:** `contracts.md:56-62`.

The execution contract correctly says production fold entry must be guarded by
the sealed snapshot trust boundary, but it still says "v0.1.8.7 must make this
guard policy explicit". That release is complete; the sentence now reads like
an unclosed future task.

**Recommended LDG-2531 action:** Rewrite this as a current invariant, for
example: production run and sweep setup must enforce the accepted
sealed-snapshot guard before fold construction; primitive fold hot paths may
then rely on trusted normalized snapshot inputs.

### C-003: R6 / Legacy Strategy Language Is Stale

**Classification:** fix-now.
**Route:** LDG-2531.
**Source:** `contracts.md:300`, `contracts.md:366-369`.
**Evidence:** `R/experiment.R:324-344`, `R/strategy-provenance.R:1-105`,
`tests/testthat/test-strategy-provenance.R:206-224`.

The current modern experiment workflow validates strategy objects as functions
with signature `function(ctx, params)`. The tests explicitly reject legacy
strategy objects instead of storing them as R6 provenance. The contract still
says functional strategies and R6 strategies use the same target validator and
that R6 strategies are Tier 2 by default unless upgraded.

**Recommended LDG-2531 action:** Remove or qualify the R6 strategy bullets.
Preserve the current function-strategy contract, configured strategy-list
compatibility where still supported, and legacy metadata tolerance if needed.
Do not reauthorize R6 execution.

### C-004: Removed Context Helper Wording Is Stale

**Classification:** fix-now.
**Route:** LDG-2531.
**Source:** `contracts.md:479-481`.
**Evidence:** `R/pulse-context.R:432-438`,
`tests/testthat/test-pulse-context-accessors.R:66-69`.

The contract says `ctx$targets()` and `ctx$current_targets()` "should fail
loudly ... once the context reset ticket is implemented." The implementation
and tests show both removed helpers already fail with migration guidance.

**Recommended LDG-2531 action:** Rewrite the bullet in present tense: the
helpers are removed from the public workflow and fail loudly with migration
guidance to `ctx$flat()` and `ctx$hold()`.

### C-005: Verification Contract Has Historical v0.1.2 CI Wording

**Classification:** fix-now.
**Route:** LDG-2531.
**Source:** `contracts.md:649-650`.
**Evidence:** `.github/workflows/R-CMD-check.yaml:18-19`,
`.github/workflows/R-CMD-check.yaml:58-71`.

The verification contract says CI must include a Windows runner before the
v0.1.2 release. That gate is historical. The current workflow already includes
Ubuntu and Windows rows and runs package check / coverage gates.

**Recommended action:** Rewrite as a current release-gate invariant: CI must
include at least Ubuntu and Windows R CMD check coverage appropriate to the
release, with coverage threshold enforcement where configured.

## No-Action Findings

### N-001: B2 Scope Guard Is Present And Current

**Classification:** no-action.
**Source:** `contracts.md:66-77`.
**Evidence:** `R/backtest.R:290-294`, `R/backtest.R:356-368`,
`R/sweep.R:23-25`, `R/sweep.R:82-94`,
`R/compiled-spot-fifo.R:1-88`,
`tests/testthat/test-backtest-wrapper.R:93-108`,
`tests/testthat/test-sweep.R:312-337`.

The contract correctly states the closed selector:
`compiled_accounting_model = NULL | "spot_fifo"`. It names the default
canonical R path, the scoped memory-backed sweep opt-in, unsupported-accounting
fail-closed behavior, durable `ledgr_run()` fail-closed behavior, and the
internal legacy option not affecting public default execution.

### N-002: One-Fold-Core Language Is Present

**Classification:** no-action.
**Source:** `contracts.md:24-44`, `contracts.md:45-49`.
**Evidence:** `R/backtest-runner.R:581-585`, `R/sweep.R:852-935`.

The execution contract preserves the no-second-engine rule: `ledgr_run()` and
`ledgr_sweep()` must share the fold core, with output handlers differing only
after semantic fold results are produced.

### N-003: Canonical Evidence Versus Derived Output Language Is Present

**Classification:** no-action.
**Source:** `contracts.md:29-44`, `contracts.md:63-65`,
`contracts.md:487-528`.

The contract distinguishes canonical in-memory event streams and fold-owned
cost/fill events from derived result tables, reconstructed state, fills, equity,
and metrics helpers. It also blocks output handlers from computing or rewriting
fill prices, fees, cash deltas, or cost metadata.

### N-004: Snapshot Identity And Retired Direct-Bars Identity Are Covered

**Classification:** no-action.
**Source:** `contracts.md:143-173`, `contracts.md:237-243`.
**Evidence:** `tests/testthat/test-schema-snapshots.R:31-81`,
`tests/testthat/test-snapshot-adapters.R:19-20`.

The contract states snapshot-backed workflows use sealed `snapshot_hash`
values, not the retired direct-`bars` `ledgr_data_hash()` helper. Current tests
also guard removal of `runs.data_hash` and absence of `data_hash` from snapshot
metadata.

### N-005: Documentation Discovery Contract Is Still Useful

**Classification:** no-action.
**Source:** `contracts.md:591-641`.
**Evidence:** current article inventory includes `vignettes/indicators.qmd`,
`vignettes/strategy-development.qmd`, `vignettes/metrics-and-accounting.qmd`,
and `vignettes/experiment-store.qmd`; no current `vignettes/ttr-indicators.*`
file was found.

The documentation contract still names the right discovery spine and protects
against a stale parallel `ttr-indicators` installed teaching path. Generated
documentation and man-page conformance remain a separate LDG-2536 audit.
Cross-route: LDG-2536 should decide whether to retain the
parallel-teaching-path protection as preserved discipline or remove it as
no-longer-applicable. LDG-2531 should not edit this language until LDG-2536
routes it.

## Deferred / Later-RFC Items

### D-001: Target Risk Remains A Reserved Slot

**Classification:** later RFC.
**Source:** `contracts.md:27`, `R/backtest-runner.R:542`.

The current contract names a reserved future target-risk slot and current code
has a no-op placeholder. v0.1.8.11 must not implement or expand target risk.
Future target-risk work belongs to the accepted v0.1.9 risk-layer arc.

### D-002: Cost/Fill Context, Liquidity, OMS, Paper/Live, And Walk-Forward Stay Deferred

**Classification:** later RFC.
**Source:** `contracts.md:78-81`, `R/sweep.R:65-68`,
`vignettes/research-to-production.qmd:192-226`,
`vignettes/sweeps.qmd:485-488`.

The contracts keep strategy context separate from future execution-bar
cost/fill contexts. The current sweep docs explicitly defer automatic ranking,
walk-forward/PBO/CSCV helpers, risk-layer insertion, public cost-model
factories, paper/live adapters, intraday-specific support, and full sweep
artifact persistence. These are not v0.1.8.11 implementation scope.

### D-003: Full Sweep Artifact Persistence Remains Deferred

**Classification:** later RFC.
**Source:** `contracts.md:127-130`.

The contract still correctly states v0.1.8 does not add `ledgr_save_sweep()`,
`ledgr_load_sweep()`, or full sweep replay / verification helpers. No action in
v0.1.8.11 unless a later RFC scopes it.

## LDG-2531 Input Checklist

When LDG-2531 edits `contracts.md`, apply only these fix-now items from this
audit:

- C-001 active packet pointer;
- C-002 fold-entry guard tense;
- C-003 R6 / legacy strategy wording;
- C-004 removed context helper tense;
- C-005 historical CI wording.

Every edit should preserve these no-action/later-RFC boundaries:

- do not weaken the one-fold-core rule;
- do not broaden `compiled_accounting_model` beyond `NULL | "spot_fifo"`;
- do not make B2 default;
- do not authorize durable compiled integration;
- do not authorize non-spot accounting;
- do not reauthorize R6 strategy execution;
- do not implement target risk, cost/liquidity APIs, OMS, paper/live, or
  walk-forward features;
- do not convert generated documentation audit work into `contracts.md` edits
  before LDG-2536.

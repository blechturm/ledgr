# Proposed Amendment: Lean Core Pulse Plumbing (v0.2.3), Seed v2

- Status: **seed v2** of a proposed amendment to the accepted
  [lean core skeleton synthesis](rfc_lean_core_skeleton_v0_2_3_synthesis.md)
  ([pipeline](README.md#lean-core-pulse-plumbing)). Not binding. On
  acceptance, Section 4 is appended to the skeleton synthesis as a dated
  amendment and Section 5 is installed in one commit.
- Authors: maintainer with Claude, 2026-11-06.
- Inputs: [seed v1](rfc_lean_core_pulse_plumbing_v0_2_3_seed.md) (historical),
  the [Type 2 response](rfc_lean_core_pulse_plumbing_v0_2_3_response.md)
  (Codex, REVISE) and the
  [maintainer response review](rfc_lean_core_pulse_plumbing_v0_2_3_response_review.md)
  (D1-D8), whose decisions this seed writes out. Where this seed and the
  response review differ, the response review's decisions govern.
- Scope: the lean core under macro WS16. The old fold at pin `d5b3a151`
  stays the frozen oracle; nothing here changes it.
- Citation aliases: **C** = `inst/design/contracts.md`; **K** = the skeleton
  synthesis; **L** = the [lean fold core synthesis](rfc_lean_fold_core_v0_2_3_synthesis.md);
  **T** = the [typed fold carrier synthesis](rfc_typed_fold_carrier_v0_2_3_synthesis.md);
  **A** = the [typed accounting synthesis](rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md);
  **X** = the [core extension architecture synthesis](rfc_core_extension_architecture_v0_2_3_synthesis.md);
  **M** = `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md`;
  **S** = `inst/design/manual/optimization_coding_style.qmd`.

## 1. The Question

The lean core's stages are being designed now. Where does it check, copy and
write its per-pulse data, so that it keeps every guarantee users rely on and
spends as little as possible per pulse?

## 2. Evidence

All measurements ran the pinned reference `d5b3a151` on Windows 11, R 4.6.1,
High performance plan, P-core affinity, on the two reference workloads:
momentum 40 x 504 (scheduled monthly) and fill-heavy 500 x 1,260 (about 54
fills per pulse). Microseconds per pulse unless stated.

| Finding | Evidence |
| --- | --- |
| Every write lands on its pulse; one loop and the sequence counters guarantee it. Six skeleton variants reproduced the real events, diagnostics and equity exactly, and each gutted variant failed. | `dev/spikes/fold_plumbing/` |
| Five stage calls and the loop cost 3 to 6; `services` reads 2 to 20. The stage design is cheap. | `fold_plumbing/evidence/lean_timing.csv` |
| Today's plumbing alone costs 1,196 to 2,028, 32 to 62 percent of the real loop (1,954 and 5,988). | `fold_plumbing/evidence/timing.csv` |
| Removing the internal re-checks from today's real fold: 1,954 to 1,389 and 5,988 to 4,984, identical results, bad strategy output still refused. | `dev/spikes/edge_checks/` |
| The conditions that can fail on data cost 10 and 25 against 238 and 389 for the full carrier checks. | `fold_plumbing/checks.R` |
| The strategy target check, same rules restructured: 95 to 15 at 500 instruments in order, 30 shuffled. | `dev/spikes/strategy_check/` |
| The append validator, same rules restructured: 243 to 63 per 54-row block; compiled C++ 40. | `dev/spikes/append_validator/` |
| Building fresh outputs is cheaper in R than overwriting preallocated ones; passing references is cheaper than both. | `fold_plumbing/evidence/timing.csv`, `lean_timing.csv` |
| First lean shape: 77 and 225, about PMwR's whole published backtest (214). The cost is row writes (a 31-column ledger row per fill, 23-column diagnostic rows, text IDs) and N-wide copies. | `fold_plumbing/lean.R` |
| Compact lean shape (references, compact records, wide tables at the output boundary): 22 and 71 including the boundary, 6 and 33 in the loop, every output identical. | `fold_plumbing/lean.R` (`2885596e`) |
| FIFO lots: lean R about 2 us per fill, compiled core about 0.1 us per fill when the book stays in compiled form. Lean-core estimate per fill-heavy pulse: about 300 with R FIFO, about 185 compiled, against 6,000 today (sums of separate measurements). | `dev/spikes/lean_fifo/`, `dev/spikes/r_floor/` |
| `db_live` and `audit_log` write identical stores; `db_live` takes 195 against 9.4 s per fill-heavy run for 34 MB less R heap. | `dev/spikes/write_mode/` |
| A recorder holding references to reused buffers records the last pulse's values (500 of 504, 1,259 of 1,260). | `fold_plumbing/evidence/parity.csv` |

## 3. Rules

**R1. ledgr trusts its own modules (D1).** A value one ledgr module hands to
another is not checked again at runtime. Each module's unit tests prove its
output guarantees one property at a time, including empty, missing and
overflow inputs; the response's property census (finding 2) is their
checklist. An internal debug mode turns every internal check back on: the
test suite runs with it on, the parity harness with it on and off, and the
stage recorder and parity workers set it explicitly. It is not a public
option. A module defect that no test reaches is not refused in a user's run;
the maintainer accepted that trade-off.

**R2. Check where data or user code enters, as early as possible (D2, D5).**

| Phase | Checked |
| --- | --- |
| Preparation, once per run | snapshot bars, marks and prices, facts and provider codes; every feature's output matrix, including custom indicators, which run only in preparation (`R/history-features.R`) |
| E, once per fold | cost model and risk chain (ledgr constructors only), schedule, strategy parameters, state declaration, imported opening positions, prepared execution epochs |
| Per decided pulse | the strategy's return (targets, intent, state update); the history requests it makes; the contract refusals on what it asks for (a target that is not buyable, refused short exposure) |
| On read | the stored ledger (A Section 3.4 read boundary); deserialized state |

Skipped: every internal re-check, including today's post-risk quantity
check, because the risk chain is ledgr's own module.

**R3. Refusals the contract promises users stay (D3).** Lot-kernel overflow
and invariant refusals on data, unaffordable orders, staging and event-buffer
capacity (the capacity refusal stays at P5), and every refusal of R2's
boundaries keep their class and order. Section 6 lists what stops firing in
production.

**R4. No append check on write for ledgr's own producers (D4).** Every event
the fold publishes is built by ledgr's modules. The read check stays. The
validator restructure (append-validator spike) applies to the read path and
to debug mode.

**R5. The kept checks are restructured, rules unchanged.** The strategy
target check proves in-order names with one comparison and otherwise uses
one `match()`; it does not re-check the context axis the fold builds. A
signal strategy's targets are checked once, not in the wrapper and again in
P2. The accounting validator runs an event kind's section only when the
block holds that kind and builds no prepared object on paths that do not
use it.

**R6. Stages pass references or indexes, not copies.** A stage hands on
positions into prepared data and the values it newly computed. It does not
copy N-wide columns into a fresh packet each pulse. Stage outputs that are
computed stay fresh (no preallocated overwrite buffers).

**R7. Compact records per pulse, wide tables at the output boundary.** A
fill is written as one compact typed record (sequence, instrument position,
side, quantity, price, fee, execution time). The ledger's other columns,
event and run IDs, side text and the cash and position effects
(`ledgr_fill_publication_deltas()`) are built at the output boundary. A
pulse's diagnostic rows are one typed block holding only the columns that
vary per row; run ID, timestamp and sequence come from the pulse. The
boundary runs per bounded chunk and at the end of the run, so no buffer
grows with the run beyond a chunk (C Fold Core And Output Handlers, the
staging and chunk rules).

**R8. One write path (D6).** `db_live` is retired: the lean core runs in
memory and writes per bounded chunk and at the end, inside the run's one
transaction, as `audit_log` does now. The `execution_mode` argument and its
stored value go; before CRAN this takes a store-format version bump and no
compatibility path.

**R9. Reserved rows, committed at P5.** The response's protocol (finding 4)
binds, without the live-mode exception: a failed candidate mutates no
handler state; an append-boundary failure advances no committed count;
growth keeps outstanding ranges; every reserved row initializes all its
columns; readers, flushes and the recorder see only committed rows; sweep
workers stay candidate-local.

**R10. Diagnostics write residual rows only.** P2's deferred decision and
risk segments stay unexpanded until P3 certifies the clean forms; only
residual rows are written, directly into the pulse's typed block. Logical
offsets, keep gaps and the drain at P5 or at a stop are unchanged.

**R11. Floor v1 and budgets (D7).** The compact lean fold
(`dev/spikes/fold_plumbing/lean.R`, `fp_compact_fold()`) is floor v1, frozen
for WS16. Each family's stage is built and measured in a skeleton where
every other stage is a stub. Each family cut sets a microsecond budget as
cost above floor v1 on both reference workloads, from the family's own
probe plus a small margin; the same stage over its matched pinned boundary
must not get slower. Each close reports cost above the floor against its
budget, the pinned comparison and lines; an overrun is fixed or explicitly
accepted (L A2). Remaining floor items belong to their owning families
(event ID formatting, empty evidence columns and diagnostic binding to the
output family; the strategy check to P2). The floor is re-baselined at the
WS14 checkpoint after the switch, not during WS16.

**R12. Compiled FIFO via WS14 (D8).** The lean R FIFO is built first and
stays the executable oracle. A compiled kernel follows M WS14's route: once
ordinary R representation work no longer dominates, with a focused Type 2
decision before compiled execution becomes the default. The lot book then
stays in compiled form inside the fold and converts only at its edges.

**R13. The recorder copies.** A recorded value is copied at the stage
boundary, never held by reference.

## 4. Amendment Text For The Skeleton Synthesis

Appended as "Amendment (maintainer, date): pulse plumbing", with notices at
K Sections 2, 4 and 5.3:

> **Section 2.** For the lean core, validation placement is decided: ledgr
> trusts its own modules, and runtime checks run only where data or user
> code enters, as early as possible (rules R1-R3 of the pulse plumbing
> amendment). "Validation belongs at the boundary that establishes or
> changes a guarantee" applies to boundaries with data or user code; a
> group built by ledgr's own code is proven by its unit tests and checked
> only in the internal debug mode. Stages pass references or indexes into
> prepared data, not N-wide copies (R6).
>
> **Section 4.** The lean core has one write path (R8). P4 writes compact
> fill records into reserved rows; P5 commits the count (R9); ledger
> columns, IDs and effects are built at the output boundary per bounded
> chunk and at the end of the run (R7). "Buffer growth does not defer
> publication until run end" holds through the bounded chunk. The order
> book installed, events published, sequence advanced, legs recorded,
> positions and cash installed, and the failure prefix, are unchanged.
>
> **Section 5.3.** The recorder copies every captured value at the stage
> boundary (R13).

## 5. Installation At Acceptance

| Document | Change |
| --- | --- |
| K Sections 2, 4, 5.3 | the amendment and notices above |
| L Section 2 ("carrier construction and callback-output validation still apply", L:78-80) | notice: carrier construction checks are debug-only in the lean core (R1); callback-output validation stays (R2) |
| L Section 3 ("no compiled stage", L:102-106) and amendment A2 (L:413) | notice: R12 is the compiled route; A2 budgets are set against floor v1 with the pinned no-regression bar (R11) |
| T Sections 3.1 and 3.5 | notice: per-group validation at construction and the published event block are superseded for the lean core by R1, R7 and R9 |
| A Section 3.4 and its rejected item "validation only at append, or only in replay" | notice: for ledgr's own producers the read boundary alone guards the stored ledger (R4); the rejection's premise was producers that cannot be trusted |
| X Section 4 step 6 | notice: the microsecond budget is cost above floor v1 plus the pinned no-regression bar (R11) |
| M WS16 and rule 16 | floor v1 and stage isolation (R11); unit tests per module property and the debug mode in the suite (R1); the switch cut's obligations in Section 6 |
| S, "Clarity" item 3 ("Validate at construction", S:273) | reworded: validate where data or user code enters; ledgr's own constructors are proven by tests and checked in debug mode |
| S, new items | compact records and wide tables at the output boundary (R7); references or indexes instead of N-wide copies (R6) |
| `inst/design/manual/benchmark_methodology.qmd` | the floor skeleton and stage isolation as the family measurement method (R11) |
| `AGENTS.md` Core Rules | one line: in the lean core, check only where data or user code enters; internal hand-offs are checked only in debug mode. The file is at 149 lines, so the line replaces another; the maintainer names which |
| `inst/design/decisions.md` | rows for R4, R8 and R1-R2 as accepted decisions awaiting implementation |
| the first-checkpoint interface table (`ledgr_v0_2_3_spec_packet/lean_core_interface.md`) | Section 13 and the validator column follow R1-R3; Section 14 states R13 |
| `ledgr_v0_2_3_spec_packet/lean_core_rules_ledger.md` | the entries in Section 6 |
| `inst/design/contracts.md` | unchanged at acceptance; the switch cut rewrites Fold Core And Output Handlers (C:100-241), Typed Fold Carrier (C:242-342), Event Staging And Parallel Sweeps (C:468), Cost Resolution And Accounting Events (C:526) and the telemetry `execution_mode` field (C:1689) |

## 6. Rules Ledger Entries (Disposition: Change)

Each is a shipped behavior the lean core changes on purpose; the switch cut
records the oracle difference.

| Proposed ID | Change |
| --- | --- |
| LR-12 | `execution_mode` and `db_live` are removed; one write path (R8). |
| LR-13 | A malformed internal carrier group, publication block, leg block or applied-row set no longer raises `ledgr_internal_error`, `ledgr_invalid_pulse_plan` or `ledgr_lot_state_invariant` in production; the debug mode raises them (R1). |
| LR-14 | The P5 cash and gross-exposure reconciliations no longer refuse in production (`ledgr_affordability_reconciliation_failed`); the reconciliation diagnostic row stays (R1). |
| LR-15 | The fold's own events are not validated on write; the stored ledger is validated on read (R4). |
| LR-16 | The post-risk quantity check runs only in debug mode (R2). |

The response's precedence warning applies: an existing test that expects one
of these refusals from a production run becomes a debug-mode test, with its
reason in the switch cut's evidence.

## 7. Questions For The Synthesis

1. Is Section 6 complete, that is, does any other refusal stop firing in
   production under R1, R2 and R4? The response's census (finding 2) is the
   starting point.
2. Does R7's bounded chunk preserve every failure prefix of today's durable
   and memory sinks, including an INCOMPLETE stop mid-chunk?
3. Do sizing notes written through `ctx` (`ledgr_validate_sizing_evidence`)
   count as user output under R2, or as ledgr's own module?
4. Is the store-format bump for R8 the only identity impact, and does any
   config hash include `execution_mode`?

## 8. Routed Outside This Amendment

The pinned append and read check never refuses a fill row's `mark_age`
(`R/accounting-replay.R:258-274`; response finding 3; reproduced by the
append-validator spike). It is shipped behavior and goes to a separate
maintainer decision.

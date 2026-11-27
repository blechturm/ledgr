# Holistic review brief A (Codex): the integrated path before the switch

- Status: draft for the maintainer's approval (Cut 27 decision 9, LDG-3283).
  The review runs after Cut 27 closes. The maintainer dispositions its
  findings before Cut 28.
- Mode: **Type 2**. Challenge the design; do not verify a ticket.
- Reviewer: an independent Codex session with no prior context. A second
  brief (holistic_review_brief_claude.md) goes to a clean-context Claude
  session, which reads loop.R cold first. Do not read the other review.

## What you review

At the switch (Cut 28), the lean fold core in `dev/lean_core/` replaces the
package's fold and becomes part of `R/`. Review the whole integrated path a
run takes after that switch, as the code stands now:

| Part | Where it is today |
| --- | --- |
| Entry | `R/public-api.R`, `R/backtest-runner.R` (`ledgr_run()`), `R/sweep.R` (`ledgr_sweep()`), `R/run-prepare.R`, `R/execution-spec.R`, `R/walk-forward.R` |
| Preparation | `R/history-substrate.R`, `R/runtime-projection.R`, `R/features-engine.R`, `R/precompute-features.R`; `dev/lean_core/prepare.R` (lean hydration) |
| The lean fold | `dev/lean_core/loop.R` (envelope, stages E and P1 to P5), `plan.R`, `fifo.R`, `marks.R`, `facts.R`, `checks.R` |
| Publication | the terminal transfer in `loop.R` (`lean_loop_publish`), `facts.R`; `R/output-handler.R`, `R/ledger-writer.R`, `R/availability-diagnostic-writer.R` |
| Finalisation | `R/run-finalize.R`, `R/backtest-runner.R` after the fold |
| Readers | `R/backtest-results.R`, `R/accounting-replay.R`, `R/backtest-fills.R`, `R/diagnostic-decoder.R`, `R/result-table.R` |

Out of scope: `dev/lean_core/loop_harness.R` and `loop_workers.R` (harness
only, removed at the switch), the parity harness under
`dev/lean_core/parity/`, vignettes, and the old fold
(`R/fold-engine.R`, `R/fold-carrier.R`, `R/fold-phase-contract.R`), except
to see what the switch deletes.

## What to look for, in this order

1. **Deletion.** Code that can go at or after the switch: functions only
   the old fold reaches (`dev/spikes/switch_probe/c_reachability.csv` is
   a starting list, not the answer); parameters, branches and fields no
   caller uses; abstractions with one user; anything kept "for
   compatibility". There are no users before CRAN, so a compatibility
   reason does not count.
2. **Duplicated validation.** A rule checked in more than one place on the
   same path, such as entry and fold, fold and publication, or publication
   and reader. Give each rule one owner: say which check is the owner and
   which copies go. Production checks at external entry stay. Internal
   hand-offs are checked only in debug (pulse plumbing R3 and R4).
   Contracted refusals stay where they are.
3. **Code a cold reader cannot explain.** A name, a shape or a step whose
   purpose you cannot state from the code and its comments. Say what you
   could not explain and what would fix it: a rename, a removal, a
   comment, or a restructure.

For each part, also walk the seven shapes in
`inst/design/manual/optimization_coding_style.qmd` ("The Seven Shapes And
Their Replacements") where the code is on a fold, hydration, finalisation
or reader path.

## Context to read first

- `AGENTS.md` (repository rules).
- `inst/design/contracts.md`: the execution and persistence sections.
- `inst/design/ledgr_v0_2_3_spec_packet/lean_core_interface.md`, Section 19.
- `inst/design/ledgr_v0_2_3_spec_packet/lean_core_rules_ledger.md` (each
  rule the lean core keeps or changes, with its disposition).
- `inst/design/rfc/rfc_lean_core_deletion_readiness_v0_2_3_seed_v2.md`
  (what the switch already plans to delete or merge).
- `inst/design/rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md`
  (production versus debug checks).
- `dev/lean_core/parity/evidence/ldg3280/census/inventory.csv` (how the
  test suite depends on the code).

Findings the switch already plans (the deletion-readiness merges and
deletions, retiring the harness hooks, `checkpoint_every`, `db_live`)
are not new findings. Cite them only when you think the plan is wrong.

## Output

Write `inst/design/ledgr_v0_2_3_spec_packet/holistic_review_codex.md`:
- a verdict line: how much can go and how much is duplicated, in one or
  two sentences;
- the findings, numbered H1, H2, ..., most valuable first. Each finding
  gives:
  - its kind (deletion, duplicated validation, or unexplained code);
  - the exact `file:line` locations;
  - what to do;
  - what it would remove or simplify, in lines where you can count them;
  - the risk to behaviour, named against a contract section or rules-ledger
    entry where one applies;
- a short list of what you checked and found clean.

A finding that changes behaviour says so and names the contract text it
touches. Do not propose new features or compiled code.

## Rules

- Read only. Do not edit, commit, or push. You may run read-only probes
  from a scratch directory outside the repository, one `Rscript` per call
  with absolute paths. Do not start long parity gates.
- Do not touch `E:`, `C:/Users/maxth/ledgr-research`, or any vendor data.
- Write UTF-8 or ASCII, in plain English.

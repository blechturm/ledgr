# Holistic review brief B (Claude): loop.R cold, then the integrated path

- Status: draft for the maintainer's approval (Cut 27 decision 9, LDG-3283).
  The review runs after Cut 27 closes. The maintainer dispositions its
  findings before Cut 28.
- Mode: **Type 2**. Challenge the design; do not verify a ticket.
- Reviewer: a clean-context Claude session. A second brief
  (holistic_review_brief_codex.md) goes to an independent Codex session.
  Do not read the other review.

## Step 1: read loop.R cold

Before reading any design document, read
`dev/lean_core/loop.R` from top to bottom, with only the files it calls in
`dev/lean_core/` (`plan.R`, `fifo.R`, `marks.R`, `facts.R`, `checks.R`,
`prepare.R`). Skip `loop_harness.R` and `loop_workers.R`; they are harness
only and go at the switch.

As you read, write down, in order:
- what you think each stage (E, P1 to P5, the terminal transfer) does, in
  one or two sentences each;
- every place where you could not tell what a name, a variable, a branch
  or a step is for, with its line;
- every place where the stage headers (the "Shared envelope state" blocks)
  did not match what you saw the stage read or write.

Keep this list as written. It is the cold-read record, and the review's
first section reports it unchanged, even where later reading answers a
question.

## Step 2: the integrated path

At the switch (Cut 28), this fold replaces the package's fold and becomes
part of `R/`. Then review the whole path a run takes:

| Part | Where it is today |
| --- | --- |
| Entry | `R/public-api.R`, `R/backtest-runner.R` (`ledgr_run()`), `R/sweep.R` (`ledgr_sweep()`), `R/run-prepare.R`, `R/execution-spec.R`, `R/walk-forward.R` |
| Preparation | `R/history-substrate.R`, `R/runtime-projection.R`, `R/features-engine.R`, `R/precompute-features.R`; `dev/lean_core/prepare.R` |
| The lean fold | `dev/lean_core/loop.R` and the files it calls |
| Publication | the terminal transfer in `loop.R` (`lean_loop_publish`), `facts.R`; `R/output-handler.R`, `R/ledger-writer.R`, `R/availability-diagnostic-writer.R` |
| Finalisation | `R/run-finalize.R`, `R/backtest-runner.R` after the fold |
| Readers | `R/backtest-results.R`, `R/accounting-replay.R`, `R/backtest-fills.R`, `R/diagnostic-decoder.R`, `R/result-table.R` |

Out of scope: the parity harness (`dev/lean_core/parity/`), vignettes, and
the old fold (`R/fold-engine.R`, `R/fold-carrier.R`,
`R/fold-phase-contract.R`), except to see what the switch deletes.

Look for, in this order:
1. **Deletion.** Code that can go at or after the switch: functions only
   the old fold reaches (`dev/spikes/switch_probe/c_reachability.csv` is a
   starting list), and parameters, branches, fields and abstractions with
   no real user. There are no users before CRAN, so a compatibility reason
   does not count.
2. **Duplicated validation.** A rule checked in more than one place on one
   path. Name the owner and the copies that go. Production checks at
   external entry stay. Internal hand-offs are checked only in debug
   (pulse plumbing R3 and R4). Contracted refusals stay.
3. **Code a cold reader cannot explain.** Your Step 1 list, plus anything
   the integrated path adds. For each item, say whether the fix is a
   rename, a removal, a comment, or a restructure.

Where the code is on a fold, hydration, finalisation or reader path, also
walk the seven shapes in
`inst/design/manual/optimization_coding_style.qmd`.

## Context, read after Step 1

- `AGENTS.md`; `inst/design/contracts.md` (execution and persistence).
- `inst/design/ledgr_v0_2_3_spec_packet/lean_core_interface.md`, Section 19.
- `inst/design/ledgr_v0_2_3_spec_packet/lean_core_rules_ledger.md`.
- `inst/design/rfc/rfc_lean_core_deletion_readiness_v0_2_3_seed_v2.md`.
- `inst/design/rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md`.
- `dev/spikes/explicit_state/README.md`. That spike tried explicit
  per-stage state. It came out red on cost, and its finding about the stage
  headers is fixed. Do not re-propose that representation unless you
  answer its cost finding.

Changes the switch already plans (the deletion-readiness merges and
deletions, retiring the harness hooks, `checkpoint_every`, `db_live`) are
not new findings. Cite them only when you think the plan is wrong.

## Output

Write `inst/design/ledgr_v0_2_3_spec_packet/holistic_review_claude.md`:
1. **The cold read:** the Step 1 list, unchanged.
2. **The verdict:** how much can go, how much is duplicated, and how
   readable the fold is for a newcomer, in a few sentences.
3. **The findings**, numbered H1, H2, ..., most valuable first. Each
   finding gives:
   - its kind;
   - the exact `file:line` locations;
   - what to do;
   - what it removes or simplifies, in lines where you can count them;
   - the risk to behaviour, named against a contract section or
     rules-ledger entry where one applies.
4. **Checked and clean:** a short list.

A finding that changes behaviour says so and names the contract text it
touches. Do not propose new features or compiled code.

## Rules

- Read only. Do not edit, commit, or push. You may run read-only probes
  from a scratch directory outside the repository, one `Rscript` per call
  with absolute paths. Do not start long parity gates.
- Do not touch `E:`, `C:/Users/maxth/ledgr-research`, or any vendor data.
- Write UTF-8 or ASCII, in plain English.

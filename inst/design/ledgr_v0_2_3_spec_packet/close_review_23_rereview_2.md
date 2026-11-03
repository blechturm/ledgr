# Re-review 2: Cut 11 Workstream 23 (typed accounting reader)

Mode: Type 1, bounded final confirmation of correction commit `fbf90cb1`
against `close_review_23.md` and `close_review_23_rereview_1.md`. Host
boundary: no full suite, no package build/check, no worktree, no E:. Only
named test files, probes and mutations were run.

Verdict: **PASS_AFTER_PATCHES**. No design challenge, so not `NEEDS_TYPE_2`.
R1-R6 are closed in product and tests. Three small patches remain: one
codebase-census refusal that WS23 introduced, and two places where the
evidence claims more than it shows. Each patch below is exact, and applying
them needs no further review. The private Sharadar gate stays OPEN and
blocking (see the last section).

## Findings

N1. **Low-medium: the codebase census check fails at HEAD. WS23 left two
private helpers called only from tests, with no registered test-seam
contract.**
`tools/check-codebase-contracts.R --mode=check` stops with
`Test-seam contracts disagree. Missing: ledgr_write_fill_events,
ledgr_lot_dust_tolerance.` Run on archive extracts with `--root`:
- base `0d6c0b11`: `LEDGR_CODEBASE_CENSUS_OK`;
- `fbf90cb1~1`: missing `ledgr_lot_dust_tolerance`. Its last product callers
  in `R/backtest-results.R` were removed in `29b6dd1e`;
- HEAD: both helpers missing. `fbf90cb1` moved db_live onto
  `ledgr_write_fill_publication_row()`, so `ledgr_write_fill_events()`
  (`R/ledger-writer.R:91`) is now called only from tests.

LTB-0270 does not catch this, because it counts test references as callers.
*Exact patch:* append two entries to `test_seam_contracts` in
`tools/check-codebase-contracts.R`, after `ledgr_history_feature_planes`:

```r
  ledgr_write_fill_events = paste(
    "Publish one typed fill group directly to DuckDB for writer and derived-state fixtures."
  ),
  ledgr_lot_dust_tolerance = paste(
    "Pin the scalar dust-tolerance rule that the row-wise lot kernel applies."
  )
```

The reviewer applied this patch to a scratch copy of HEAD, and the check
then prints `LEDGR_CODEBASE_CENSUS_OK`. Deleting both helpers and moving
their tests to the surviving paths is also valid. It is a larger change.

N2. **Low: no detector covers the durable/resumed boundary seed in the
runner, but the evidence says one does.**
`R/backtest-runner.R:589-608` seeds the handler from the stored tail. A
probe confirmed it is correct: a durable run with an opening seeds
`(1, 2020-01-01 16:00:00)`, which equals the stored opening tail, and a
cash-only run does not seed. A namespace mutation that turns the runner's
`output_handler$seed_event_boundary(...)` call into a no-op still passes
`test-typed-accounting-boundary.R` and `test-run-continuity.R`, and no
other test references the call. Only the handler method is witnessed: a
no-op `seed_event_boundary` fails LTB-0550. The LDG-3201 evidence says
"Reverting each boundary fails its registered detector", which is false for
this call site.
*Exact patch:* in LDG-3201 evidence (`tickets.yml`, third bullet), replace
"Reverting each boundary fails its registered detector." with "Reverting the
handler carry, the seed method or db-live validation fails LTB-0550; the
runner's durable/resumed seed call is confirmed by review probe, not by a
registered detector."

N3. **Low: two evidence statements are stale after `fbf90cb1`.**
- `a0_successor/record_identities.csv` binds the candidate record to
  `7361951e` (R tree `e341ea96`). `a0_successor/README.md` says later
  commits "do not change its `R/` or `src/` trees". `fbf90cb1` changes `R/`
  (HEAD R tree `fcae0795`, src tree `b8e90af3` unchanged). The reviewer
  regenerated the candidate arm from HEAD with `record.R`: 281 files,
  byte-identical to the committed candidate record (`diff -r` empty), and
  `compare.R` passes. The record content is valid. Only its identity is
  stale.
  *Exact patch:* add the row
  `candidate_reproduced,fbf90cb157d81ac47b79c37d2d8f35833058d468,fcae0795d7fab29b033ec7c8165588442014c1e7,b8e90af3c4a5592f4e411e01c2cc7ccfc0699a1a,ws23_final_byte_identical`
  to `record_identities.csv`. In the README, replace the last sentence with
  "The record was regenerated at `7361951e`. Correction `fbf90cb1` changes
  `R/`, and regenerating at its tree reproduces all 281 files byte for
  byte."
- The closeout says "Walk-forward's former dead NULL-substrate branch now
  projects the one prepared timeline". `ledgr_walk_forward_opening_from_run()`
  is still unreachable: its only caller (`R/walk-forward.R:796`) runs when
  `history_substrate` is NULL, and `ledgr_history_substrate_for_experiment()`
  never returns NULL. A direct probe gives the right answer: cash 850,
  positions AAA 3 and BBB 1, cost basis 100 and 50.
  *Exact patch:* after that sentence, add "The branch remains unreachable
  from `ledgr_walk_forward()`; a direct review probe confirms its result."

## The seven confirmation items

| # | Item | Status | Basis |
| --- | --- | --- | --- |
| 1 | Fill-acquired terminal summary/print | CLOSED | LTB-0172 passes, including the new `FILL, DISPOSITION` arm. Two mutations each fail LTB-0172: the summary using the parent-only composition query (LTB-0175 also fails), and the pre-correction shape (all CASHFLOW/DISPOSITION plus parent fills only). The summary reads FILLs only for fact parents and instruments that have a CASHFLOW or DISPOSITION row, so fill-only instruments stay out. Composition keeps the parent-only query, and LTB-0068 passes unchanged. |
| 2 | Durable/resumed seed; db_live single payload | CLOSED in product; see N2 | The probe seed equals the stored tail. The seed runs after resume cleanup and opening publication (`R/run-resume.R:72-102`). db_live validates `block` and then writes that same `block` row by row (`R/output-handler.R:625-640`), so the payload is built once. |
| 3 | All-NA timestamp; D8 alias; oracle/fixture reasons | CLOSED | `.POSIXct(rep(NA_real_, n))`, and only disposition rows are parsed (`R/accounting-replay.R:298-300`). D8 lists `.ledgr_fill_publication_formula` and injects both the alias and the writer row. The runtime shift mocks both and covers all three paths. Fixture changes add the literal schema-124 effects and disposition fields. The LTB-0209/0216 oracle is now a test-local prefix query and replay, recorded in `claims.yml` LCL-0209/LCL-0216 and LDG-3202 evidence. The decreasing-timestamp arm now expects refusal, which is stronger than before. LTB-0515's 4 January date has a stated reason. |
| 4 | Deleted helper; dead branches | CLOSED; wording in N3 | `ledgr_availability_positions_asof` has no product or test reference. The unsorted fallback is gone. Walk-forward uses the timeline (correct by probe, unreachable). |
| 5 | Comparator re-hash | CLOSED; identity in N3 | 281 files per arm, PASS. Six mutations are refused: an extra byte, an extra file, a missing file, an off-field cell (once with a stale manifest, once with a consistent one), and a wrong accepted value with a consistent manifest. The HEAD regeneration is byte-identical. |
| 6 | Full-suite attribution | CLOSED | The named files, run at HEAD, give exactly eight failures: LTB-0408 (1 error), LTB-0416 (1 error), LTB-0247 (1 failure) and five in sweep-retention "wide return projections reversibly escape". WS23 did not change those test files, their inputs or the code under test. The only `R/sweep.R` change is the accepted INCOMPLETE line, and rereview 1 reproduced all four groups at base. The one optional skip is `quantstrat`, not installed. Every WS23-affected file is green. |
| 7 | No regression or antipattern in `fbf90cb1` | CLOSED except N1 | The summary adds one DISTINCT query per read. The seed adds one query per run. db_live's per-row insert loop and its per-row run check existed before (the old writer was called per row). It now builds its metadata once per block, not once per row. No new iteration over bars, events or instruments x pulses. |

## Private Sharadar aggregate gate

**OPEN. It blocks WS23 acceptance (LDG-3200 and LDG-3202 stay `pending`)
and WS24's first product commit**, as LDG-3202 evidence and the closeout
route it. Only an explicit maintainer amendment of LDG-3200/LDG-3202
acceptance, with its reason, can carve it out. The three patches above do
not change this.

What it requires:
- **Runner:** the registered private reference,
  `ledgr-research/experiments/v0_2_2-reference/` (master `3e3e175`:
  `worker.R`, `compare.R`, `collect.R`, `check.R`, with serialization in
  `common.R`).
- **Arms:** two library installs, immutable base `0d6c0b11` and the final
  WS23 candidate. The candidate is HEAD's R tree `fcae0795` if N1 is fixed
  by registration; if helpers are deleted, use the post-patch tree.
- **Data:** the dividend-v004 Sharadar snapshot (hash `e8cbb805...`). WS23
  does not change the store schema (124), so no W1 rebuild is needed.
- **Output:** committed aggregates only, no vendor rows. Per-table row
  counts and SHA-256 digests for full/filtered diagnostics, point/history
  explanations, D8/valuation summaries and economics, plus input identities,
  package/runtime versions, thread settings, repetitions, latency and peak
  memory (LDG-3200 acceptance 3 and 4).

Note for the maintainer: the registered worker records only `equity`,
`fills`, `ledger`, `sweep_candidates`, `wf_folds` and `wf_scores`. It does
not produce the diagnostics, explanation or summary tables that LDG-3200
names, and no in-repo record names the script that will. The gate therefore
needs either that recorder extension or a stated narrowing.

## What the reviewer ran

- Named files at HEAD:
  - terminal-reporting, typed-accounting-boundary, ledger-writer,
    research-cycle-scale, corporate-action-composition,
    accounting-consistency, fifo-torture, fills-streaming,
    position-facts-context, codebase-contracts, ws4a-carrier,
    accounting-reader-convergence, terminal-outcomes, run-continuity and
    walk-forward-orchestrator: all green;
  - history-integrated-proof, history-teaching, pit-consistency and
    sweep-retention: exactly the eight recorded failures.
- Mutations: two summary-query mutations, a no-op handler seed, and a no-op
  runner seed call.
- Comparator: the committed pair, six comparator mutations, and a HEAD
  `record.R` regeneration with `diff -r` against the committed record.
- Probes: the seed boundary, and the direct call to the walk-forward opening
  helper.
- Census: `check-codebase-contracts.R --mode=check` on archive extracts of
  `0d6c0b11`, `fbf90cb1~1`, HEAD and HEAD+N1.

Scratch files live in the session temp directory. The line-ending drift
that `load_all` wrote to `R/cpp11.R` and `src/cpp11.cpp` was reverted.
Nothing was committed, and no product or ticket file was edited.

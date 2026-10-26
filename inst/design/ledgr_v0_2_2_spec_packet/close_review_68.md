# Workstream 68 close review

Verdict: `CHANGES_REQUIRED` at `0c0feeaa`.

The independent Type 1 Claude Opus review confirmed the release blocker and
the durable-run correction, then found the same loss on in-memory sweep
candidates. `R/sweep.R` retained only decision rows, and
`ledgr_valuation_inputs_from_diagnostics()` likewise excluded the new
skip-only valuation rows. A public one-candidate probe returned `frozen` for
the manual sweep and `current` for the scheduled sweep at identical final
equity.

The review also found that LTB-0512 did not detect the grouped stale-count or
frozen-row predicates independently: run list and comparison shared one
reader, the frozen fixture did not isolate stale state, and the test did not
compare the two runs' maximum frozen weights. The ticket evidence and claim
therefore overstated their detector. Finally, the public raw-diagnostics shape
needed one contract sentence and two comments needed correction.

Required correction:

1. retain scheduled-skip `valuation` / `marked` rows in memory candidates and
   admit them to the in-memory valuation reader;
2. compare manual and scheduled grouped values directly, add a stale-only
   witness, and cover manual versus scheduled sweeps;
3. mutation-check every durable and sweep predicate separately;
4. describe the skip-only valuation row in the scheduler contract and correct
   the comments and evidence.

The reviewer found the single-run economics, reopen behavior, skip counts,
closed reason vocabulary, absence of current-mark rows, lack of double
counting, schema/identity boundary and seven-shape walk clean. The four focused
suites passed. The review was read-only on the owning worktree.

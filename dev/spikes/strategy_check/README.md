# Strategy-check spike, 2026-11-06

**Question.** In the lean floor probe (`dev/spikes/fold_plumbing/lean.R`)
the strategy target check, the one per-pulse check the response review
keeps, was the largest item on fill-heavy. Is there waste in
`ledgr_validate_strategy_targets()` (`R/strategy-contracts.R:34`)? **Kill
condition:** an arm that does not return an identical value, or raise the
same condition class and message, on every case measures nothing.

**Outcome: green.** The same rules restructured run 6x faster at 500
instruments with targets in universe order (95 to 15 us), 3x faster
shuffled (95 to 30 us), and match the pinned check on all ten cases.

## Where the waste is

- The check re-validates `universe` on every call: character, no missing or
  empty names, no duplicates. In the fold that is the context axis ledgr
  built itself (`R/fold-engine.R:868`), so under response review D1 it is a
  re-check of our own module.
- It hashes the names four times: `anyDuplicated(universe)`,
  `anyDuplicated(names(targets))`, two `setdiff()` calls and the final
  `targets[universe]` subset.
- The common case needs none of that. ledgr's helpers (`ctx$hold()`,
  `ledgr_target_rebalance()` and the rest) return targets named in universe
  order. Then one `identical(names(targets), universe)` proves the names are
  complete, unique and in order.
- `ledgr_signal_strategy()` checks its targets with the same function
  (`R/signal-strategy.R:100`, `:144`, `:163`), and P2 checks them again.

## What ran

- `arms.R`: `same_rules` keeps every rule and its order and message; when
  the names are identical to the universe it skips the name, missing and
  extra tests, otherwise it uses one `match()` and computes the missing and
  extra lists only to word the error. `trusted_universe` is the same
  without the universe re-check.
- `run.R`: ten parity cases (in order, shuffled, `ledgr_target` with an
  attribute, missing instrument, extra instrument, duplicate name, missing
  value, infinite value, non-numeric, invalid universe) through the pinned
  check and both arms, plus a gutted arm without the finiteness rule; then
  timing at 10, 40, 500 and 5,000 instruments, in order and shuffled, five
  repetitions, High performance plan, P-core affinity.
- `check.R` reruns into a scratch directory, diffs `parity.csv`, checks the
  timing rows, requires the expected outcomes and guards package scope.

## Result

Microseconds per call, median of 5 (`evidence/timing.csv`):

| instruments | order | pinned | same rules | trusted universe |
| ---: | --- | ---: | ---: | ---: |
| 10 | in order | 42 | 11 | 8 |
| 10 | shuffled | 42 | 14 | 11 |
| 40 | in order | 47 | 12 | 8 |
| 40 | shuffled | 47 | 16 | 12 |
| 500 | in order | 95 | 15 | 10 |
| 500 | shuffled | 95 | 30 | 25 |
| 5,000 | in order | 533 | 67 | 33 |
| 5,000 | shuffled | 567 | 200 | 167 |

Parity (`evidence/parity.csv`): both arms match the pinned outcome, class,
message and returned value on every case, except that the trusted-universe
arm accepts the invalid universe (by design: the fold builds it) and the
gutted arm accepts the missing and infinite values, so the comparison can
fail.

## What the lean core may take from this

Keep every rule on the strategy's return; restructure the check so the
in-order case costs one comparison, and do not re-check the context axis
the fold builds. Check a signal strategy's targets once, not in the wrapper
and again in P2. This changes no contract text.

The lean floor probe measured 141 us per fill-heavy pulse for this step;
that figure also includes building the named target vector in the
harness. The check itself is 95 us of it, and 10 to 15 us restructured.

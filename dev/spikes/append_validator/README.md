# Append-validator spike, 2026-11-06

**Question.** The fold plumbing spike's check-cost probe left the append
check (`ledgr_validate_accounting_append()`, `R/accounting-replay.R:88`) as
the largest per-pulse check on fill-heavy runs: about 250 us per fill block,
whatever its size. Can the same rules run much faster on the fill path, and
would compiling them help? **Kill condition:** an arm that does not accept
and refuse exactly what the pinned check does, with the same condition
class and message and the same returned values, measures nothing.

**Outcome: green.** The same rules restructured in R run 4x faster on a
54-row block (63 against 243 us) and match the pinned check on every case.
Compiled C++ is 40 us there: it saves another 22 us per fill block, which is
not worth a compiled stage.

## What ran

- `probe.R` timed the pinned check on real fill blocks of 1 to 500 rows and
  line-profiled a 54-row block. The cost was about 165 us fixed plus about
  1 us per row, spread over many statements: the check runs every rule
  section for all four event kinds (fill, opening, corporate cash,
  disposition) on every block, coerces columns already of their type, and
  builds a 37-field prepared object of which the handler reads only
  `event_seq` and `ts_utc` (`R/output-handler.R:466-478`).
- `blocks.R` builds blocks through the pinned payload builder
  (`ledgr_fill_event_payload`, `R/backtest-runner.R:92`), so every block is
  one P4 publishes.
- `arms.R` holds two candidates. Both take a fast path only for a typed
  all-FILL block in the pinned column order; anything else goes to the
  pinned check.
  - `r`: the pinned rules in the pinned order, skipping the sections whose
    masks are all FALSE, skipping coercions, building no prepared object.
  - `cpp`: the same fast path with the per-row rules in C++
    (`-ffp-contract=off`), one pass per rule in the pinned order. A
    reference measurement only.
- `run.R` runs ten parity cases through the pinned check and both arms,
  plus a gutted R arm without the forbidden-evidence rule, then times all
  three per block size, interleaved, five repetitions, High performance
  plan, P-core affinity.
- `check.R` reruns into a scratch directory, diffs `parity.csv`, checks the
  timing rows, requires the gutted arm to differ on `evidence_on_fill` only,
  and guards package scope.

Pinned tree `d5b3a151`, Windows 11, R 4.6.1, collapse 2.1.8, Rtools 4.5.

## Result

Microseconds per call, median of 5 (`evidence/timing.csv`). Each value
averages 4,000 calls; the 15.6 ms clock gives about 4 us resolution.

| rows per fill block | pinned | R, restructured | C++ |
| ---: | ---: | ---: | ---: |
| 1 | 165 | 38 | 35 |
| 10 | 178 | 45 | 40 |
| 54 (fill-heavy median) | 243 | 63 | 40 |
| 86 (fill-heavy maximum) | 278 | 70 | 43 |
| 500 | 640 | 178 | 60 |

Parity (`evidence/parity.csv`): one accepted block, eight single faults
(sequence not after the prior block, time before it, empty instrument,
infinite cash, invalid side, zero quantity, unreconciled cash, evidence on
a fill) and the accepted fill `mark_age` gap. Both arms match the pinned
outcome, class, message and returned values on all ten. The gutted arm
accepts the evidence fault, so the check can fail.

## What was learned about the package

- The append check's cost is its structure, not its rules: about 150
  vector operations on every block, most of them for event kinds the block
  does not contain. Guarding each kind's section by whether the block has
  rows of that kind, and dropping coercions and the prepared object on the
  append path, keeps one validator with the same rules and order.
- What stays in the R arm is about 35 us of fixed cost: the fast-path test
  (names and storage of 31 columns), the evidence test over 18 columns and
  the scalar boundary checks. C++ shares that cost, which is why it gains
  little below a few hundred rows.
- At 54 fills per pulse, the R arm takes the fill-heavy check from 243 to
  63 us per pulse, compiled from 243 to 40. The 22 us difference is under
  half a percent of today's 6 ms loop. Compiling is not needed for this
  check.
- The fill `mark_age` gap from the Type 2 response is real and is
  reproduced on purpose: a fill row's `mark_age` is never refused.
- The payload builder that makes the block costs about the same as the
  check (probe run, Balanced plan, not recorded as evidence). The pulse
  plumbing amendment's reserved-row write removes that block.

## What the lean core may take from this

Keep the one append validator and its rules; restructure it so that each
event kind's section runs only when the block has that kind, coercions run
only for columns not already of their storage type, and the append path
builds no prepared object. The read path keeps the prepared object. This
changes no contract text. A compiled validator is not needed.

## What the spike leaves out

Blocks of other event kinds (they take the pinned check unchanged), the
read path, data-frame input, and the reserved-row write itself. The C++ arm
is not a proposal.

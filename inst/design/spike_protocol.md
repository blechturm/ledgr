# ledgr Spike Protocol

**Status:** Binding for every spike, prototype, or comparative experiment
chartered inside an RFC cycle. Supersedes any stage plan a seed proposes.

**Why this exists:** the asset-availability spike (v0.1.9.8) spent about half
its effort on provenance machinery and pre-authored expected tables that
caught no defect, while every real finding came from running the package.
Its seed imported a proof-heavy working style from an unrelated project.
This protocol makes that shape impossible to charter again.

## 1. Probe before prose

Before a seed, response, or charter is written, the maintainer or an agent runs
the package against the open questions and records what it actually does in a
`dev/spikes/<topic>/probe.R` plus a one-page `probe_findings.md`. Design prose
may cite only behavior that was executed or is already in `contracts.md`.
A seed that reasons about package behavior nobody ran is returned.

## 2. One question, one kill condition

A charter names exactly one question, the cheaper prerequisite question it
depends on, and the condition under which the spike stops and recharters.
"Which storage shape?" needed "is the seam representation-neutral?" answered
first. Multi-stage plans are not written before the prerequisite is answered.

## 3. Runnable core before expected answers

No expected table, witness list, or checker is written before a fork exists
that can fail it. The order is:

1. smallest runnable fork with one seam;
2. run it; let its failures generate the test cases;
3. freeze the expected answers those cases need, in git, with the reviewer
   named in the commit message.

The initial test set is capped at ten cases. A case the fork cannot fail is a
policy sentence for the spec, not a test.

## 4. Size budgets are stop signals

| Artifact | Budget |
| --- | --- |
| Seed | 300 lines |
| Response | 300 lines |
| Charter | 150 lines |
| Spike harness (all R) | 1,500 lines |
| Any single correction diff | 500 lines |
| Review report | one page |

A diff or document over budget is a stop-and-talk with the maintainer, not a
review request. The size itself is the signal that the direction is wrong.

## 5. Provenance lives in the product

Git is the ledger for the build. Spike harnesses contain no hash ledgers,
registries, first-appearance records, ancestry or clean-workspace gates,
file-type tripwires, review/gate modes, or comprehension-key lifecycles.
Identity claims use ledgr's own primitives (`config_hash`, snapshot hash,
run-store identity) or are labelled `proto:` once.

## 6. Executor evidence

The executor delivers exactly three things:

- a runner that writes evidence CSVs;
- a checker that reruns into a scratch directory, diffs against the recorded
  CSVs, and guards package scope (`R`, `src`, `tests`, `NAMESPACE`,
  `DESCRIPTION`, `man`, `inst/design`);
- an inventory that shows one gutted path failing and lists what was demoted,
  deleted, and learned about the package.

Counts of passes are not evidence. A row is evidence only if the fork derived
it from provider facts; rows narrated as literals are labelled and excluded.

## 7. Review contract

A review is three actions: rerun, gut one path, diff the evidence. The brief
lists at most five verifiable items. Two rounds per artifact; a third round
means the ask was wrong and goes back to the maintainer. The reviewer never
executed the stage. Roles do not rotate within a stage.

## 8. Seed smell test

The maintainer returns a seed or charter without review if it:

- proposes more than ten witnesses or test cases before a runnable core;
- proposes more than one gate, any hash ledger, or any registry;
- plans more than two stages before the prerequisite question is answered;
- asks for a comparison of more than two alternatives at once;
- cites package behavior that no probe executed;
- exceeds its size budget.

## 9. Terminal outcome

The closeout is one page: what ran, what was learned about the package, what
the spec may consume, and what remains open. Green, red, or inconclusive is
stated in one sentence with the charter clause that decides it. Structural
numbers from small fixtures never appear in a ranking.

## Revision history

- **2026-09-08** -- initial version, written after the asset-availability
  spike closed inconclusive. Budgets are calibrated to the earlier spikes under
  `inst/design/spikes/`, which mostly fit them already.

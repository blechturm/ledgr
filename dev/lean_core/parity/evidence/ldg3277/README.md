# LDG-3277: the clarity pass on the lean core

Cut 27 decision 4 (maintainer, 2026-11-27). It covers the production files
`cut19_lines.R` counts: `loop.R`, `plan.R`, `checks.R`, `fifo.R`,
`prepare.R`, `loop_harness.R`, `marks.R` and `facts.R`. The base is
afaceaba (LDG-3276 complete); the clarity commit is bba035de.

## What changed

- **Names.** `s3` became `marks_state` and `s4` became `facts_state`: the
  marks run state and the facts run state, including the arguments of the
  `marks.R` and `facts.R` functions. The rename was made on parsed tokens
  (SYMBOL, SYMBOL_FORMALS and SYMBOL_SUB), so strings and names such as
  `s3_closes` were untouched. The counts: 62 in `loop.R`, 33 in `marks.R`,
  142 in `facts.R`.
- **Citations.** Code comments no longer cite pin line numbers, commits,
  cuts, tickets, workstreams or reviews. The explanation stays; "the pin's
  X" became "the package's X()" where it names package code. Interface
  sections and rules-ledger ids remain. The one trailing comment a variant
  anchors on (`decision_order = ...`, citing `R/fold-engine.R:1330`) was
  changed together with its anchor.
- **Stage headers.** Above each stage function (E, P1 to P5), a block names
  the envelope state the stage reads and writes. `stage_state.R` computes
  the block from the code, using codetools for the free variables and the
  `<<-` targets (`stage_state.csv`).
- **Variants.** 24 variants whose anchor or injected lines changed were
  re-anchored (`reanchored_variants.txt`). That adds 65 `reanchor` rows in
  `loop_variant_changes.csv`, one per manifest key.

The harness hook seams stay until the switch.

## Proofs

| check | result |
| --- | --- |
| `clarity_equiv.R --base=afaceaba --final=bba035de` (`clarity_equiv.txt`): per file, the parsed code with comments stripped equals the base's, renames applied | CLARITY EQUIVALENCE PASS, all eight files |
| `clarity_scan.R` (`clarity_scan_before.csv`: 331 findings, 111 citation lines and 220 symbol uses) | after: 0 findings (`clarity_scan_after.txt`, `.csv`) |
| `variant_anchor_check.R`: every registered variant's edits apply to the sources | 105 variants, VARIANT ANCHORS PASS (`variant_anchor_check.txt`, on the final code) |
| The variant driver on every variant over the 37 workloads the re-anchored variants use (`variants_debug0.log`, `_debug1.log`, `variants/`) | debug 0: 87 rows, 44 variants, 0 failures, the five negative controls failing closed; debug 1: 58 rows, 23 variants, 0 failures |
| A gate subset with the freeze, one workload per slice plus workers, walk-forward, the selector and overflow (`subset_debug0.csv`, `_debug1`) | 17 workloads, 283 tables, 0 different, PASS 17, every frozen path checked, debug off and on |

The scanner's pattern is deliberately broad: it also flags bare review
finding ids and any 8-hex-digit word. A comment that matched without being
a citation was rephrased; the scanner was not loosened.

## Lines

`lines.csv` (`cut19_lines.R --base=afaceaba --final=bba035de`): production
2,690 to 2,690 and debug 206 to 206. The pass adds no production lines;
comments are not counted.

Afterwards, LDG-3276's overflow check moved from `loop.R` into
`lean_lot_fill_checked()` in `fifo.R` (3e867f45). LDG-3276 had taken
`loop.R` to 1,003 production lines, over its 1,000 cap. After the move:
- `loop.R` is at 997, as at Cut 26's close;
- `fifo.R` is at 473;
- production since the cut base 9cfd7cd6 is 2,657 to 2,694 (+37, all of it
  the overflow refusal in `fifo.R`).

The LDG-3276 proofs reran on that code (`../ldg3276/after_move/`).

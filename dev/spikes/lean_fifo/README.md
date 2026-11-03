# Lean FIFO kernel spike, 2026-11-03

**Question.** Can a leaner implementation of ledgr's one FIFO lot kernel
produce bit-identical books and applied rows at materially lower cost per
call? Kill condition: any difference from `ledgr_lot_fill()` in the book or
any applied-row field, after any block, stops the spike.

**Outcome: green.** Identical on every block of every stream; 2.5 times
faster per call.

## Why this spike

The R-floor spike (`dev/spikes/r_floor/`, stage 3) found that 87 percent of
a lean P3 to P5 is the reused lot kernel, and `probe_lot.R` there split it:
book copies cost nothing (copy-on-modify is not the problem), input and
applied-row validation and the dust helper are about half, generic FIFO
arithmetic the rest.

## What ran

`kernel.R` reimplements `ledgr_lot_apply()` for fills with the same
floating-point operations in the same order: masked assignment instead of
`ifelse()`, the dust tolerance inlined, the Kahan-compensated realized-P&L
scan unchanged, compaction and growth unchanged, and no input or applied-row
validation (a trusted fold boundary would validate once). Anything unusual
(non-finite input or result, opening through an opposing lot) falls back to
the canonical kernel, so refusals stay exactly ledgr's.

`run.R` feeds each stream through both kernels and compares the full book
and all eight applied-row fields after every block:

| stream | blocks | fills | blocks differing | fallbacks |
| --- | ---: | ---: | ---: | ---: |
| recorded seam, 30 x 250 changing axis | 238 | 2,717 | 0 | 0 |
| recorded seam, 200 x 250 changing axis | 240 | 17,782 | 0 | 0 |
| random, 12 instruments, seeds 1 to 5 | 400 each | about 2,600 each | 0 | 0 |

The random streams mix integer, fractional, dust (1e-13) and large
quantities, both sides (so positions flip through zero), many lots per
instrument (so segments compact and grow) and fees on 40 percent of rows.

Cost on the recorded 200-instrument blocks, as the fold calls the kernel
(pinned, quiet host):

| kernel | us per block | us per fill |
| --- | ---: | ---: |
| canonical `ledgr_lot_fill()` | 392 | 5.3 |
| lean | 156 | 2.1 |

What remains is mostly the kernel's own arithmetic and the row-by-row Kahan
scan in event order (52 percent self time), then `pmax()` for the dust
tolerance (9 percent).

## Gutted path

`run.R <lib> <out> plain_sum` replaces the Kahan step with a plain sum. The
books then differ on 221 to 399 blocks per stream, and `check.R` requires
that failure.

## What the spec may consume, and what is open

One leaner FIFO kernel, bit-identical to today's, costs about 2.5 times less
per call by removing per-call validation, `ifelse()` and the dust helper;
copy-on-modify can stay. Not covered: openings and dispositions (only fills
were reimplemented), and refusal paths beyond the fallback. A further gain
would come from the Kahan scan, which must keep its event order.

Reproduce: `Rscript dev/spikes/lean_fifo/run.R <lib> <out dir>`, then
`Rscript dev/spikes/lean_fifo/check.R <lib> <scratch dir>`.

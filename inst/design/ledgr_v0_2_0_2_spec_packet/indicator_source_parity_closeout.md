# Cut 10 Closeout: Indicator Source Parity And Timing Attribution

**Status:** Agent-provisional; awaiting the one planned Type 1 close review.

**Implementation through LDG-2837:** `010049d..001ece3` on
`codex/ws16-v0.2.1.0`.

| Ticket | Commit | Claim and detector |
| --- | --- | --- |
| LDG-2833 | `633d207` | six-permutation attribution spike and checker |
| LDG-2834 | `13265fd` | LCL-0073 / LTB-0073 |
| LDG-2835 | `5547c3a` | LCL-0074 / LTB-0074 |
| LDG-2836 | `b47b83f`, `c7d936d`, `f4c0ba5` | LCL-0075 / LTB-0075 and the promoted peer record |
| LDG-2837 | `001ece3` | documentation checks added to LTB-0073 and LTB-0074 |

## Result In One Sentence

The old 9.57-second built-in-versus-TTR difference is order-confounded, not a
measured indicator-source cost: every pair changed direction by process
position, and none passed the preregistered structural threshold.

## Attribution Before Change

The spike ran native `ledgr_ind_sma()`, the private peer wrapper, and public
`ledgr_ind_ttr("SMA")` in all six orders. Each arm therefore occupied each
position twice in a fresh R process over a byte-copied store with the same
snapshot identity and an empty feature cache.

| Arm | Position 1 mean / spread | Position 2 mean / spread | Position 3 mean / spread |
| --- | ---: | ---: | ---: |
| built-in SMA | 50.635 / 0.210 s | 51.740 / 4.160 s | 46.955 / 1.510 s |
| private TTR wrapper | 51.050 / 0.520 s | 48.235 / 4.110 s | 45.535 / 0.310 s |
| public TTR SMA | 51.295 / 0.990 s | 46.700 / 0.020 s | 45.225 / 0.730 s |

Native minus public TTR was -0.660, +5.040 and +1.730 seconds by position.
The first-position built-in and public means differed by 0.660 seconds, not
9.57. No pair kept one direction, exceeded both one second and five percent,
and cleared the largest within-position spread. Rprof localized no material
source-specific lane. The spike therefore authorized no indicator
optimization.

All 18 runs produced the same 1,260,000-cell feature axis and 6,500-cell NA
mask, 1,260 equity rows, 68,201 fills and 33,948 realized trades. Native versus
TTR feature values differed by at most 7.56699591875076e-10, inside the
existing 1e-8 tolerance. Economic outputs were exact.

## Semantic Result

LTB-0073 carries one literal two-instrument, seven-date calendar through a
direct cold and warm run, single- and multi-candidate sequential sweep,
optional parallel sweep, and interrupted resume. It detects a closed date,
one missing observation on a declared open session, strict-window
contamination, recovery, late start, and the separation between stale
valuation and features. Its independent oracle is the declared calendar and
source bars. Dropping the gap declaration, compressing to observed rows,
admitting the closure as a pulse, using a stale mark as a feature, or losing
the projection slice on resume changes the literal matrix.

LTB-0074 compares built-in, public TTR, and custom arithmetic SMA against that
same oracle. The only external certification is the exact single-output
`ledgr_ind_ttr("SMA", input = "close", n = ...)` shape with matching bounded
warmup. Its independent predicate table rejects a changed function, input,
output, argument set, required history or stability horizon. Removing that
certification, widening it, certifying a bundle, or losing it across cache,
sweep, parameterization or resume fails the block.

Supported under availability:

- built-in SMA and simple returns;
- a truthful bounded custom indicator declaring `strict_window`; and
- the exact public TTR SMA shape above.

Deliberately unsupported under availability:

- built-in EMA and RSI;
- TTR EMA and RSI;
- TTR output bundles; and
- every other unassessed or recursive TTR shape.

Those unsupported declarations fail before strategy execution. Equal session
semantics are not a claim that different indicator formulas are numerically
equal.

## Corrected Peer Boundary

All six published TTR-labelled rows now construct features through exported
`ledgr_ind_ttr()`; built-in rows use exported `ledgr_ind_sma()`. The private
wrapper is absent from published claims. LTB-0075 guards that source boundary,
runs the durable built-in and public TTR rows in separate child processes in
both launch orders, requires equal R and library metadata, and compares their
feature and economic outputs.

The promoted record `peer_benchmark_record_20260926T080725Z` was produced from
`c7d936d` under R 4.6.1, TTR 0.24.4, DuckDB 1.5.2 and collapse 2.1.8. The
published warm research clocks are:

| Row | Warm total | Engine |
| --- | ---: | ---: |
| durable public TTR | 53.02 s | 47.44 s |
| durable built-in SMA | 68.33 s | 61.67 s |
| public canonical sweep | 32.31 s | 29.85 s |
| compiled spot-FIFO sweep | 17.60 s | 14.71 s |

The built-in-first companion recorded 65.50 seconds for built-in and 69.23
for public TTR; the second child was slower in both launch orders and the
source ranking reversed. These are corrected public boundaries, not evidence
that one source implementation is faster.

## Documentation And Failure Sensitivity

The source and rendered missing-data article now distinguishes the dense
implicit clock from a declared expected-session calendar and shows closure,
missing open observation, overlapping unavailability, recovery, late start,
stale valuation and a finite-value strategy guard. LTB-0073 parses its table
and compares it with the executable oracle.

The indicator article shows built-in, exported TTR, and custom SMA over that
gap and publishes the closed support matrix. LTB-0074 derives every matrix
status from the constructors. Mutating built-in EMA and RSI from Unsupported
to Supported caused the block to fail. The maintainer feature article records
the same source-neutral boundary. All qmd sources were rendered to their
tracked Markdown siblings, and documentation contracts passed.

## Seven-Shape Walk

No data-scale loop was added to feature hydration. The production changes
carry one scalar contract through precomputation, defer validation of an
unresolved declaration, slice an existing projection once before the
pre-existing finalization loops, and evaluate one constant-size certification
predicate at construction. They add none of the seven named anti-patterns.

The benchmark additions loop only over fixed arm, package, phase and output
sets at the orchestration or result boundary. The sampler's process-tree loop
is bounded by child lifetime and sample interval; it is not a collection-size
algorithm inside ledgr. Result frames manifest once at the benchmark boundary.
No rowwise timestamp formatting, repeated JSON decode, full-table subset per
id, quadratic validator or environment-held scalar buffer write was added.

## Gates, Boundaries And Declined Work

The exact LDG-2837 ordinary fast record in `.tmp/ws17-2837-fast` passed 453 of
453 blocks with no skip or failure in 76.50 seconds. The independent checker
accepted the one-run record against the unchanged 90-second bound. Focused
availability-feature, documentation-contract and control-plane files passed.

The workstream declined a TTR performance optimization because the attribution
threshold did not fire; certification of recursive indicators or bundles
without executable gap semantics; retention of a private wrapper in a peer
claim; treating boundary correction as package speedup; and numerical parity
claims across different formulas.

The independent cut review is the first invocation. The requested close
review is the second over six completed tickets, 2/6 = 0.333 against the 0.5
gate. One correction round would make the honest count 3/6 = 0.500.

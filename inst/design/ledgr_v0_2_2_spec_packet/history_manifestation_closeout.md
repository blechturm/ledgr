# Workstream 55 amendment closeout: ordinary history manifestation

## Outcome

LDG-3105 is implemented at `a22381d5` and corrected through `19e65491`. Ordinary
`ledgr_history_matrix()` and `ledgr_history_frame(..., layout = "wide")`
reads are direct sibling manifestations of one causal request. They retain
the values, ordered axis, included IDs, complete selection table, policy and
snapshot provenance, requirements and `used_before_window`; neither retains
cell evidence nor authenticates the transient numeric result. The explicit
long layout remains the cell-diagnostic request.

The verified snapshot and owner-prepared substrate are the trust boundary.
The ordinary result is a fresh R value. Registered ledgr transformations drop
its provenance, while an attribute-preserving base or third-party operation
may retain provenance about the originating read. No helper represents that
metadata as a seal over transformed values.

## Implementation shape

The initial least-machinery R implementation removed the evidence and digest
but its bounded value/count pass measured about 1.53 ms at 500 instruments by
252 sessions in development clocks, above the accepted 0.75 ms gate. The
implemented correction therefore fuses the bounded bar copy, permitted carry,
finite counts, carried counts and before-window flag in one compiled pass.

The context owner prepares immutable lifetime, terminal and late-knowledge
mask summaries before a public pulse context is exposed. Lifetime barriers and
non-finite bars are stored as sparse maximal runs. Their storage grows with
intervals and gaps rather than source cells, and the compiled reader queries
them without walking across an omitted interval. Only dependency columns
receive late-knowledge override state. The compiled pass reads requested cells
through one traceable source handle and, only for a missing price cell, the one
finite source named by a gap run when it falls inside the declared carry
horizon. It does not create a dense count plane, a prepared count index,
field-position evidence, an opposite-orientation plane, a result cache or a
second whole-history carry patch. The final matrix receives its dimensions and
names at allocation, avoiding an otherwise unnecessary full numeric copy. Wide
output allocates its final numeric columns directly.

Feature manifestation uses the prepared feature values and sparse projection
records over the requested rows and columns. It derives compact admission and
dependency disclosure without constructing the long layout's textual evidence
columns. The long bar and feature paths retain the existing diagnostic oracle.

## Binding resource record

The final registered installed-package record is
`dev/bench/v0_2_2_history_manifestation/evidence/19e65491/`. It ran on Windows
11, R 4.6.1, High performance power plan and process affinity `0xFFFF`.
`check_record.R` returns `LEDGR_HISTORY_MANIFESTATION_OK`.

| Gate | Matrix | Wide | Bound |
| --- | ---: | ---: | ---: |
| 500 x 252 median | 0.621 ms | 0.658 ms | <= 0.750 ms |
| returned-payload copies | 1 | 1 | <= 2.5 |
| digest calls | 0 | 0 | 0 |
| instrument exponent, 500/1,166/2,332 x 252 | 0.961 | 0.962 | 0.65-1.30 |
| session exponent, 500 x 252/504/1,260 | 0.946 | 0.817 | 0.65-1.30 |
| complete 252-versus-1,260-source delta | 0.0091 ms | 0.0058 ms | <= 0.100 ms |
| long-gap/restart source delta | 0.0010 ms | 0.0027 ms | <= 0.100 ms |

The focal steady-state allocation ratios are 1.264 numeric-payload equivalents
for matrix and 1.308 for wide after the first-read allocation witness. The
runner proves that owner mask summaries already exist before the first public
read and uses semantic deep copies to show that neither that read nor
subsequent clocks change the memo. It checks both complete and adversarial
long-gap/restart contexts. The instrument-growth
fixtures have matching decision
universe and requested widths, so the retained complete selection table is
part of each measured shape rather than an unlabelled larger axis.

The earlier GREEN spike recorded the replaced ordinary reader at 24.20 ms
for matrix construction at 500 by 252. The product record is not presented as
a paired speedup against that research harness; it binds the accepted absolute
resource and exactness gates.

## Semantic and detecting evidence

LCL-0479 / LTB-0488 now pins:

- matrix, wide and explicit-long value parity, including empty axes;
- one causal request-plan call and direct sibling construction;
- no ordinary evidence payload, transient hash or value-seal helper;
- ordinary bar and feature reads that do not call the eager evidence builders;
- owner preparation completed before the first public read, with no hidden
  memo growth on that read;
- exact requested source-value accesses at the fused manifestation boundary,
  including bounded carry dependencies;
- identical compact and explicit-long lifetime-restart classification when an
  inactive interval lies before the returned window, with and without carry
  and for a non-price field;
- sparse lifetime barriers, dependency-width late overlays and one auditable
  source handle rather than a direct compiled source bypass;
- structural provenance under registered ledgr transforms and the documented
  attribute-preserving base-operation boundary;
- absence of a finite-count or whole-history patch memo; and
- caller-mutation isolation from the substrate and later fresh reads.

LCL-0295, LCL-0397 and their existing integration blocks were migrated from
implicit wide evidence to explicit long diagnostics. They continue to pin
late-known restatements, vintage feature evidence, input and output carry,
lifetime and terminal barriers, run, sweep, walk-forward, explicit-precompute
and pulse-inspection parity. LTB-0391 additionally proves that ordinary bar
reads create neither whole-history carry-source nor patch caches.

The binding benchmark independently checks numeric, selection and
`used_before_window` parity across matrix, wide and long forms, absence of
ordinary evidence, presence of long evidence, zero digest calls, allocations,
two-axis growth and fixed-window source-length sensitivity.

## Optimization-shape walk

1. No R-level accumulator grows with returned cells or instruments. Sparse
   late-knowledge mask exceptions use fixed-size storage.
2. No row-wise data-frame append is introduced.
3. Bar manifestation is one compiled bounded pass; it does not rescan the
   completed result.
4. Estimator admission consumes counts and compact structural/expiry flags
   from that pass. Excluded ordinary reads never reacquire diagnostic planes.
5. Matrix and wide outputs are allocated in final orientation; neither is
   built through the other.
6. No per-cell environment mutation or lookup is introduced.
7. No candidate-, pulse- or instrument-invariant input is rebuilt inside a
   growing execution loop.

## Verification

The focused history API, frame, substrate, continuity, foundation, policy,
teaching, integration, integrated-proof, indicator-history, causality,
documentation-contract and control-plane suites pass. The codebase census and
its mode-branch self-test pass, as does the fold-phase contract checker. The
causal-history article was executed, regenerated and verified against its GFM
render.

The committed candidate passes the full package suite: 1,200 blocks, no
failure or error and one optional-package skip. That run exposed a pre-existing
LTB-0182 oracle mismatch: the current terminal-release record nests result
fields under `outputs`, while the block still read the former top-level shape.
Commit `d3a83cc6` repairs only that read; the focused block and the full suite
then pass.

The established fixture lane was first made runnable against both arms by
serializing the now-nested valuation summary through the recorder's existing
`s3list()` adapter. Against the accepted pre-implementation tree `a2375f41`,
the candidate has 50 of 50 gated families byte-identical and the informational
identity family identical. The checker self-test detects 51 of 51 isolated
family mutations. Full records remain local scratch evidence because their
diagnostic families are large.

A clean `git archive` source build compiles the new C++ path and builds every
vignette with the host Quarto executable. `R CMD check --no-manual
--no-build-vignettes` on that source tarball finishes `Status: OK`, including
installed tests, examples, code, Rd, installed vignette outputs and execution
of every vignette's R code.

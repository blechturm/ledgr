# Explicit-state spike (LDG-3278, Cut 27 decision 6)

**Question.** Can explicit stage state make the existing fold easier to
explain at an acceptable measured cost?

## The specified prerequisite: one stage takes and returns state

**Verdict: red, stopped before the extension.** One stage (P5) takes and
returns its state with exact outputs at debug 0 and 1, in sweep workers and
on all three large shapes. But that one stage already costs 1.18x, 1.40x
and 1.05x the lean core's pulse loop on 10x7200, 20x23400 and 500x1260, and
the cost grows with run length. Decision 6's stop clause ("reaches the spike
protocol's stop signals") applies, so the representation was not extended
to the other stages. This is a judgment at the boundary: 1.40x from one of
five stages is not small, and the mechanism below repeats in every stage
that writes a run-long record.

**Fork** (`take_return.R`, installed by `install_p5.R` through install.R and
the worker channel, as before). P5 (`lean_p5_commit`) gets a `state`
argument, the list `hd_recon, hd_has_recon, n_committed, strategy_state`.
Inside the stage the 4 reads and 6 `<<-` writes of those names become
`state$x` and `state$x <- v`, and the stage returns `state`. The call site
in run_loop:

    p5 <- lean_p5_commit(i, v1, v2, v3$batch, n_fill, list(hd_recon = hd_recon,
        hd_has_recon = hd_has_recon, n_committed = n_committed, strategy_state = strategy_state))
    hd_recon <<- p5$hd_recon
    hd_has_recon <<- p5$hd_has_recon
    n_committed <<- p5$n_committed
    strategy_state <<- p5$strategy_state

The stage is derived at load time from loop.R's own P5 by `es_transform`
(transform.R), so no economic rule is copied: the capacity refusal, both
reconciliation checks and the state update are the tracked code. The
installer refuses if any `<<-` to the four names is left in the stage, if
P5 has an early return, or if the call site is not found exactly once.
Retained views: `strategy_state` is only ever replaced, never written in
place, so a strategy's retained `ctx$state` stays frozen as before.

| debug | workloads | tables | different | forked workers |
| --- | --- | --- | --- | --- |
| 0 | crossover_3x40 s2_cost_chain s3_freeze_held s4_dividend s5_workers_sizing ovf_delta_then_lot | 92 | 0 | 2 |
| 1 | same | 92 | 0 | 2 |
| 0 | crossover_10x7200 crossover_20x23400 crossover_500x1260 | 48 | 0 | 0 |

All verdicts PASS; frozen paths match (`evidence/p5_*`, `evidence/p5large_*`).

**Gutted path** (`install_p5_gut.R`): P5 writes `hd_recon[i, ] <- recon` to
a local copy, so that one write is left out of the returned state. On
crossover_3x40 and s2_cost_chain, 26 of 32 tables differ and both workloads
FAIL. The fold itself does not notice: the pulses run, and the run fails at
finalisation when the NA reconciliation row reaches the result writer
(`ledgr_config_non_finite`, "canonical_json() does not allow non-finite
numeric values"). `check.R --phase=p5gut` reruns and diffs it; `check.R
--phase=p5` does the same for the prerequisite. Both pass.

**Timing** (`time_pairs.R --arm=p5`): debug off, each run a fresh process
with a warm-up run, P-cores (pcore.ps1 0xFFFF), High performance plan, 5
alternating pairs per shape, Balanced restored and confirmed afterwards.
Both arms produced the same fills and equity digests on every shape.

| shape | pulse loop as is / fork (median s) | ratio (min-max) | extra per pulse | whole run as is / fork | ratio (min-max) |
| --- | --- | --- | --- | --- | --- |
| 10x7200 | 2.06 / 2.42 | 1.18 (1.16-1.20) | 50 us | 3.23 / 3.62 | 1.12 (1.11-1.12) |
| 20x23400 | 8.06 / 11.28 | 1.40 (1.36-1.42) | 138 us | 11.36 / 14.57 | 1.28 (1.26-1.30) |
| 500x1260 | 0.74 / 0.78 | 1.05 (1.03-1.08) | 32 us | 3.54 / 3.64 | 1.02 (0.99-1.04) |

**Cause.** The extra cost per pulse grows with the number of pulses, not
with universe width. The envelope keeps its own binding of `hd_recon` (an
n_pulse x 6 matrix) and `hd_has_recon`, so the list passed in shares them,
and the stage's indexed write `state$hd_recon[i, ] <- recon` copies the whole
record on every pulse: quadratic in run length. `copy_probe.R`'s
`stage_take_return` form, the same shape without ledgr, takes 0.23 s for
5,000 pulses and 2.89 s for 20,000 (`evidence/copy_probe_p5.csv`), which
matches the 3.2 s seen on 20x23400. P1 (`eq`), P4 (`fl`, `hd_nrej`)
and the decision records write run-long buffers the same way, so the
extension would multiply this term.

**Readability.** P5 deparses to the same 61 lines (3,002 to 3,053
characters) and loses its 6 `<<-`; run_loop grows from 28 to 33 lines and
gains 4 `<<-` assign-backs. The stage's state covers only what it writes.
It still reads `cash`, `pos`, `nf`, `ctx_pos`, `ids` and `ids_attr` free
from the envelope (other stages write them) and writes `live` and
`facts_state` by reference. So the signature names P5's outputs but not its
inputs.

**Open.**
- A take-and-return form without the copy would return the pulse's row
  (`recon`) and let the envelope write it by index. That is a different
  state value (a per-pulse delta, not the record), so under decision 6 it
  is a new representation and was not built.
- Not measured: making P5's inputs from other stages explicit as well.
  Reads do not copy, so that would cost little but lengthen every call.

**What this informs.** The maintainer's decision on explicit stage state
for the switch. The specified representation keeps exact outputs and
retained-view behaviour, but passing run-long records by value costs a
measurable, run-length-dependent share at one stage. Funding the extension
would mean first choosing a representation that keeps run-long buffers
out of the state value.

## The shared-environment variant (earlier spike)

This variant moved each concern into one environment shared by several
stages. It is not the take-and-return form that decision 6 specified, and
its conclusion holds only for that representation (close review F2).

**Its verdict: red.** The shared-environment fork is bit-identical on every shape
decision 6 names, but its measured cost (pulse loop 1.8x, 4.6x and 3.0x the
lean core on 10x7200, 20x23400 and 500x1260) fails decision 6's "acceptable
measured cost" clause. The readability gain is small: every stage still
touches three or four of the five shared concerns.

**Fork.** `transform.R` rewrites `lean_fold_envelope_plain` (dev/lean_core/loop.R)
by AST transform, not by a hand-edited copy. Each concern's shared variables
move into one environment created at the top of the envelope
(`commit_state <- new.env(hash = TRUE, parent = emptyenv())`). Every read
becomes `commit_state$x` and every `<<-` write becomes `commit_state$x[i] <- v`.
Scope is respected: a nested function's formals and locals are left alone,
and a `<<-` is rewritten only when no enclosing nested function holds the
name. `install.R` rebinds the plain function and recompiles
`lean_envelope_code` from it exactly as loop.R does. It does this in the
parent and, through the harness's worker-edits channel (`worker_hook.R`), in
every sweep worker; each forked worker leaves a marker that the evidence
counts. `render.R` renders loop.R as transformed, comments kept, and proves
the rendering parses back to the transform's AST (`rendering_identical_to_ast`).

### Its prerequisite: one concern, P5's commit record

The concern is `hd_recon`, `hd_has_recon`, `n_committed` and `strategy_state`.
P5 and P1 write them; P1, P5, the context builders, the committed-prefix
hooks, layout and expand read them. The transform rewrote 21 reads, 7 `<<-`
writes and 5 envelope assignments, with no finding.

| debug | workloads | tables | different | forked workers |
| --- | --- | --- | --- | --- |
| 0 | crossover_3x40 s2_cost_chain s3_freeze_held s4_dividend s5_workers_sizing ovf_delta_then_lot | 92 | 0 | 2 |
| 1 | same | 92 | 0 | 2 |

**Gutted path** (`install_gut.R`): P5's `hd_recon[i, ] <<- recon` is left
unrewritten. On crossover_3x40 and s2_cost_chain: 32 tables, 26 different,
both FAIL (`object 'hd_recon' not found`). `check.R` reproduces both phases.

### Extension: every concern

There are five concerns, grouped by stage ownership:
- `book_state`: cash, pos, book, position_facts, event_seq, last_executed, last_fully_valued
- `fill_state`: fl, fcap, nf, hd_fill_start, hd_nfill, hd_nrej, rj
- `record_state`: dr, dcap, nd, szr, scap, nsz, hd_pre, hd_intent, hd_sizing, hd_all_explicit, hd_stop_detail, eq, n_eq
- `commit_state`: as in the prerequisite
- `run_state`: status, stop_reason, processed, full_run, n_done, ctx_pos

The transform rewrote 333 reads, 38 envelope assignments and 107 of the 108
`<<-` writes. The one left is `parts`, a local of `lean_loop_expand` written
by its own `add`.

| debug | workloads | tables | different |
| --- | --- | --- | --- |
| 0 | the prerequisite set + crossover_10x300 | 108 | 0 (2 forked workers) |
| 1 | same | 108 | 0 (2 forked workers) |
| 0 | crossover_10x7200 crossover_20x23400 crossover_500x1260 | 48 | 0 |

### Timing (lean as is vs the full shared-environment fork, debug off)

Each run is a fresh process with a warm-up run first, pinned to the P-cores
(pcore.ps1), on the High performance plan (restored to Balanced afterwards).
There are 5 alternating pairs per shape, and both arms produced the same
fills and equity digests.

| shape | pulse loop as is / fork (median s) | ratio fork/as-is (min-max) | whole run as is / fork | ratio |
| --- | --- | --- | --- | --- |
| 10x7200 | 2.14 / 3.77 | 1.77 (1.69-1.80) | 3.38 / 5.00 | 1.49 |
| 20x23400 | 8.22 / 38.04 | 4.62 (4.57-4.67) | 11.61 / 41.32 | 3.55 |
| 500x1260 | 0.75 / 2.26 | 3.01 (2.62-3.41) | 3.59 / 5.09 | 1.42 |

**Cause** (`copy_probe.R`, `evidence/copy_probe.csv`): an indexed write
through an environment field (`s$x[[i]] <- v`, `s$eq$ts[[i]] <- v`,
`s$m[i, ] <- v`) copies the whole object on every write. With 20,000 writes
into length-20,000 objects these forms take 0.55-3.1 s against at most 0.02 s
for the `<<-` forms. That is why the cost grows with run length (the
`hd_*`/`eq`/`fl` columns) and with universe width (`pos`). A
detach-modify-reattach form (`x <- s$x; s$x <- NULL; x[[i]] <- v; s$x <- x`)
stays in place. A list state passed in and returned also copies.

### Readability

Before (loop.R, P5):

    n_committed <<- nf
    ...
    hd_recon[i, ] <<- recon
    hd_has_recon[[i]] <<- TRUE

After (rendered, `render.R --set=all`):

    pos <- book_state$pos   # snapshot: a local assignment below shadows it on a marked run
    ...
    commit_state$n_committed <- fill_state$nf
    if (!is.null(batch) && !isTRUE(book_state$cash == batch$expected_final_cash) && ...
    commit_state$hd_recon[i, ] <- recon

Each mutable read now names its concern. Size effect of the full fork:
- loop.R grows from 1,460 to 1,469 lines and by 8% in characters (76,530 to 82,592)
- lines over 120 characters go from 23 to 64
- the deparsed envelope grows from 1,110 to 1,207 lines

Coupling is unchanged (`evidence/stage_concerns_all.csv`):
- P1 and P5 each touch 4 of the 5 concerns
- P2, P3 and P4 each touch 3
- `book_state` and `run_state` are read by almost every stage

So the objects label the state but do not give any stage an owned state to
take and return. The stage headers already listed that information, so the
explanation gain over them is small.

### What the transform could not handle, and a header finding

No concern name appears in `assign()`/`get()`/`environment()`/`quote()`, as
a call head, or as an envelope-level `for` variable.

One construct needed a rule beyond renaming: a **conditional shadow**. P2, P3
and P5 run `pos <- pos[ctx_pos]` (P2 also reassigns `ids`, `ids_attr`,
`ids_ok` and `n`) only on a marked run. So `pos` is the envelope's variable
on a complete run and a local otherwise. The transform inserts
`pos <- book_state$pos` as the stage's first statement, and only after
checking that neither the stage nor any envelope function it calls writes
`pos`.

The same construct hides reads from the stage headers. stage_state.R uses
codetools, which treats a conditionally assigned name as local. So the
ldg3277 header for P2 omits `pos`, `ids`, `ids_attr`, `ids_ok` and `n`; P3's
omits `pos`; and P5's omits `pos` and `ids`. All of these are read from the
envelope on an unmarked run.

### Open (shared-environment variant)

- Not measured: the detach-modify-reattach form inside the fork. Its writes
  would need a three-statement idiom at each of the 107 sites, which works
  against the readability goal.
- The ticket's "a stage takes and returns explicit state" shape was not
  forked here; it is the section above.
- The stage-header gap above was fixed under LDG-3277 (268bcd90):
  stage_state.R now counts these reads and the environment field writes.

### What this variant informs

Its red verdict holds for the shared-environment representation only. It
supports keeping the stages' `<<-` writes into the envelope frame over
concern environments, with the generated stage headers as the explanation
of shared state. It is not a measurement of the stage take-and-return form.

## Files

- `take_return.R`: the stage take-and-return fork (set `p5`; `es_install()` in transform.R dispatches to it).
- `transform.R`: the shared-environment transform and installer.
- `install.R` with `install_p5.R`, `install_p5_gut.R`, `install_commit.R`, `install_all.R` and `install_gut.R`: the `--witness=` files.
- `worker_hook.R`: installs the fork in sweep workers.
- `run.R`: the runner (`--phase=p5|p5gut|p5large|prereq|gut|extend|large`). It writes
  `evidence/<phase>_summary.csv` and `<phase>_d<debug>_tables.csv`.
- `check.R`: reruns a phase into scratch, diffs every CSV, and checks R,
  src, tests, NAMESPACE, DESCRIPTION, man, inst/design and dev/lean_core
  against HEAD.
- `render.R`: writes `render_<set>.csv` and `stage_concerns_<set>.csv` (shared-environment variant).
- `time_one.R` and `time_pairs.R`: the paired timing (`--arm=p5`: `timing_p5_raw.csv`,
  `timing_p5_summary.csv`, `timing_p5_host.txt`; `--arm=fork`: `timing_*`).
- `copy_probe.R`: the write-form probe (`copy_probe.csv`; with `stage_take_return`, `copy_probe_p5.csv`).
- `probe.R`: prints the findings and one stage before and after (shared-environment variant).

The harness is 925 lines of R (768 before the take-and-return fork).

    Rscript run.R --lib=C:/Users/maxth/ledgr-wt/pin-lib-7f65733f --phase=p5 --scratch=<dir>
    Rscript check.R --lib=C:/Users/maxth/ledgr-wt/pin-lib-7f65733f --phase=p5 --scratch=<dir>
    Rscript check.R --lib=C:/Users/maxth/ledgr-wt/pin-lib-7f65733f --phase=p5gut --scratch=<dir>
    Rscript run.R --lib=C:/Users/maxth/ledgr-wt/pin-lib-7f65733f --phase=p5large --scratch=<dir>
    Rscript time_pairs.R --lib=C:/Users/maxth/ledgr-wt/pin-lib-7f65733f --pairs=5 --arm=p5 --scratch=<dir>
    Rscript copy_probe.R --out=evidence/copy_probe_p5.csv

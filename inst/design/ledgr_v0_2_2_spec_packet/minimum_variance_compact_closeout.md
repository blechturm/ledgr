# Workstream 58 closeout: compact minimum-variance research path

## Outcome

LDG-3104 is implemented in `15b81736`, with the active peer-benchmark cleanup
in `202ee532`. The executed minimum-variance article now teaches the path Cut
19 set out to make ordinary:

```text
causal return matrix -> readiness -> ordinary R estimator
                     -> aligned weights -> explicit target intent
```

The strategy reads `return_1` once through the direct classed matrix surface,
uses the requirements recorded on that result, checks them with
`ledgr_passed_warmup()`, estimates and solves in ordinary R, restores the
history identity with `ledgr_align_weights()`, and hands an explicit keep or
liquidate choice to `ledgr_target_rebalance()`. Its structured return may add
one optional durable `intent_reason` without changing targets or economics.

All eight choices are visible experiment parameters: lookback, minimum
observations, minimum instruments, carry threshold, covariance shrinkage,
eigenvalue floor, invested equity fraction and whether held estimation
exclusions are kept. The callback has no hidden `%||%` defaults, manual name
reconstruction, second return read, retired history helper or transient
outcome attribute.

## Teaching boundary

The article separates three decisions that were previously easy to conflate.
An instrument may be excluded from estimation, the solver allocates only over
the retained columns, and the strategy must separately decide what execution
should do with a held excluded instrument or a leaver. The code makes the
choice visible through `keep_excluded`; leavers are explicitly assigned zero.

The current two-session close read used to recognize the first venue session
of a month remains a clearly labelled scheduling workaround. It is not a
second return read and does not claim a new context or portable scheduling
API. The scheduler remains with its RFC owner. The article also keeps durable
factor, prediction, rank, selection and weight evidence with LFB-028 rather
than treating the optional intent reason as that system.

Covariance shrinkage, eigenvalue flooring and solver failures are explained
after the compact research path. They remain ordinary strategy-side R, not a
new ledgr estimator or optimizer catalogue.

## Detecting evidence

The registered minimum-variance source oracle requires exactly one direct
`return_1` matrix read, all eight visible parameters, the readiness check,
alignment and target conversion. It rejects `%||%`, `colnames()`,
`rownames()`, `names<-`, `setNames()`, `ledgr_history_sufficient()`,
`na_action`, raw history attributes and `structure(..., outcome = ...)` in the
shown strategy.

The behavioral blocks retain the accepted synthetic economic oracle and cover
the readiness boundary, partially observed instruments, keeping a held
estimation exclusion, selling a leaver and the optional intent reason both
live and after reopening. The article, its GFM output, the Why R article,
causal-history teaching, help, contracts and NEWS use the same compact path.

The broad suite found one stale live source left by Workstream 57: the active
peer-benchmark harness still constructed its three empty candidates with the
removed `ledgr_param_grid()`. Commit `202ee532` moves those sites to the
accepted one-row, zero-column rectangular data frame. LTB-0496 now includes
that active harness in its removal census; the peer-boundary, parameter-grid
and control-plane tests pass. Historical audits, archived benchmarks and
spikes retain their old calls as records.

## Current private estimator arm

Research commits `293d13d` and `937f580` add the minimal
`experiments/minimum-variance-current-v001` runner, checker and aggregate
record. The runner loads the strategy and full visible parameter object from
the current article and uses the already sealed dividend-v004 Sharadar
snapshot. It delegates snapshot integrity, run identity, execution,
accounting and persistence to ledgr and exports no vendor row or private path.
The generated CSV remains ignored; the committed README and checker retain the
permitted aggregate pins.

At ledgr product-source commit `15b81736`, the run completed 7,213 pulses in
191.93 seconds, with 28,609 fills, 7,213 equity rows and final equity
8,590,156.302350. These economics equal the accepted Cut 17 record but were
measured again rather than carried forward. The current strategy hash is
`2555a03dee869f373c0ae00c44e7d94321fcab09480f68e43f13a511486d468e`.
The run persisted 7,213 intent reasons: 333 solved, 12 insufficient history
and 6,868 non-decision pulses, with every other failure count zero. `check.R`
returns `LEDGR_MINIMUM_VARIANCE_CURRENT_CHECK_OK` on the local record.

## Seven-shape walk

WS58 changes no production hot-path function. The article performs one causal
return read and one bounded covariance operation per scheduled decision; it
adds no per-instrument frame construction, full-table subset loop,
per-element parser or formatter, per-row JSON, discarded recomputation,
quadratic validator or environment-held scalar write. The peer-harness repair
constructs one tiny empty rectangular candidate at the experiment boundary,
outside pulse and candidate loops.

## Verification

- Focused minimum-variance, history, intent-evidence, documentation-contract,
  API, control-plane, parameter-grid and peer-boundary suites pass.
- The ordinary fast profile executes 577/577 blocks in 113.08 seconds. The
  unchanged 112-second timing hint is exceeded, not passed. The ordinary
  review profile passes 436/436 blocks with one established optional-path
  skip.
- The all-block suite passes 1,205 blocks and 21,531 expectations with no
  failure or warning and the same optional skip.
- The codebase checker passes with 74 connection sites, 159 version sites, 80
  run-config sites, 1,877 helpers, 2,426 conditions and 72 recorded findings;
  the mode census has 161 branch and 59 flow sites. The fold-phase checker and
  both YAML parses pass.
- The fixture record at pre-WS58 `25631b55` and candidate `202ee532` compares
  50/50 gated families plus the informational identity family byte-identical;
  its self-test detects all 51 single-family mutations.
- A clean archive source build executes every vignette and produces a
  cache-clean 11,251,412-byte tarball. `R CMD check --no-manual
  --no-build-vignettes` exits successfully with no error or warning. It records
  one pre-existing NOTE for unqualified `head()` in
  `ledgr_history_bar_mask_view()`; the same source is present at `25631b55`
  and WS58 does not widen into unrelated code cleanup.


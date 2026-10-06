# Audited Antipattern Repairs Closeout

**Status:** Agent-provisional; awaiting the Workstream 17 Type 1 close review.
**Range:** `a8669a3..16e660b`
**Tickets:** LDG-2966 and LDG-2967

## Result

All three shapes named by the Cut 8 audit are removed. Public behavior stays
exact on the registered writer, availability, sweep and result-reader
witnesses. This closeout uses the seven shape names from
`optimization_coding_style.qmd` verbatim rather than a local substitute.

LDG-2966 moves pulse fill rows and memory fill legs out of handler state and
into closure-owned reusable lists. LTB-0188 records zero allocation for the
final production write at capacities 256 and 8,192. Restoring the
environment-held writes fails its structural detector. At three 5,000-fill
pulses, the paired candidate/pre-cut median ratio is 0.319, a 68.1% reduction
for that deliberately wide shape. This is shape evidence, not an ordinary-run
effect estimate.

LDG-2967 prepares the physical-axis feature lookup once per availability
fold. The pulse's changing decision axis is still enforced through the pulse
lookup. It also replaces two queries and one output scan per frozen run with
one table check and three grouped queries independent of the frozen-run count,
then splits the returned rows once. Dense runs retain the existing typed
missing flags on run-list and comparison surfaces.

## Failure Sensitivity

| Block | Mutation | Observed failure |
| --- | --- | --- |
| LTB-0188 | move the three staged lists back into handler state | source guard fails; the large-capacity write regains the old copy allocation |
| LTB-0189 | add the old hashed lookup build to every availability pulse | four assertions fail; direct and sweep folds each prepare six times instead of once |
| LTB-0190 | restore the pre-cut per-frozen-run query loop | two assertions fail; two frozen runs use six DBI reads against four for one run |

## Exactness And Gates

- The writer, risk-fold, sweep, availability-economics and runner suites pass
  for LDG-2966. Its checked-in wide-pulse record preserves exact event and
  fill hashes.
- Feature-accessor scaling, selection visibility, pulse-context accessors,
  strategy-context entrances, availability parity, run store, run comparison,
  documentation contracts and the test control plane pass for LDG-2967.
- LTB-0189 compares the public durable and one-candidate sweep paths at the
  same resolved feature parameters and obtains identical final equity.
- LTB-0190 compares both frozen runs with their individual public
  `ledgr_valuation_summary()` values, preserves repeated IDs, and checks dense
  typed-missing behavior.
- The ordinary Workstream 11 record compares `a8669a3` with `16e660b` in five
  alternating fresh-process pairs per shape. It completed in 624.90 seconds.
  Cold ratios are 0.9844, 0.9853 and 1.0029; warm ratios are 1.0036, 0.9950
  and 0.9917. Every ratio is below 1.10, no retry ran, semantic hashes and the
  757-pulse orientation match, and the checker self-test passes. The durable
  summary is under
  `dev/bench/v0_2_2_antipattern_repairs/evidence/ldg2967_long_window/`.
- The ordinary fast profile at `16e660b` passed 531 of 531 blocks in 104.51
  seconds against 112, with zero failures, errors or skips. The record is
  `C:/tmp/ledgr-ws17-fast`.

## The Seven Shapes And Their Replacements

The changed production functions are `ledgr_persistent_output_handler()`,
`ledgr_memory_output_handler()`, `ledgr_execute_fold()`,
`ledgr_attach_feature_helpers()`, `ledgr_update_pulse_context_helpers()`,
`ledgr_filter_pulse_context_features()` and
`ledgr_run_assumption_flags_many()`.

### 1. One-row frame per element, bound at the end.

Neither output handler creates a frame per staged fill; each manifests its
existing bounded block only at flush. The fold and three context helpers add
no frame construction. The multi-run reader constructs one small `zero_stale`
frame per call, not per event or run, and consumes the two grouped query
frames directly.

### 2. Full-table subset inside a loop over ids.

The two handlers, fold and context helpers add no table subset. The multi-run
reader splits frozen and equity rows once by `run_id`; its loop reads the
resulting groups by name. It no longer scans `out$run_id == run_id` or queries
full tables once per frozen run.

### 3. Per-element parsing or formatting where a vectorised call exists.

The handlers stage already-normalized scalars. The fold and context helpers
perform no timestamp parsing or formatting. The multi-run reader passes each
run's timestamp columns to the existing vectorized valuation arithmetic; it
adds no per-element parser or formatter.

### 4. Per-row JSON on repetitive strings.

None of the seven changed functions adds JSON work. The handlers retain their
existing boundary serialization, while the fold, context helpers and grouped
reader do not parse or encode JSON.

### 5. Work computed and discarded, or recomputed on every call.

The handlers retain staged rows only until their existing flush. The fold now
prepares availability lookup state once and no longer creates a dense fast
context that availability execution discards. `ledgr_attach_feature_helpers()`
accepts that prepared state, and `ledgr_update_pulse_context_helpers()` only
forwards it. The filter reads the current pulse lookup. The multi-run reader
issues each grouped query once and computes each frozen run's valuation once.

### 6. Quadratic validators.

No changed handler, fold or context function introduces a validator. The
multi-run reader performs no pairwise validation; query membership is setwise,
and output placement uses `match()` plus grouped splits.

### 7. Scalar writes into an environment-held vector.

The persistent and memory handlers remove the audited shape: staged lists are
closure locals, and LTB-0188 detects their return to handler state. The fold
and context helpers add no environment-held scalar buffer writes. The
multi-run reader writes ordinary local output columns in vectorized batches,
not one element at a time through an environment.

## Review Accounting

Cut 8 had no separate cut review. The requested Type 1 close review is its
first review invocation: one invocation over two completed tickets, 0.500.

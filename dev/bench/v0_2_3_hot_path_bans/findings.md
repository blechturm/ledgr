# Hot-path ban probe (macro rule 17), 2026-11-02

Measurement step for the rule-17 chore cut, on Cut 7 head `e04786ef`. It
answers three questions:

- Can a static walk find the functions the fold reaches per pulse or per fill?
- How large is the starting baseline?
- What does a static walk miss that a runtime trace sees?

No product code is changed.

## Method

`probe_static.R <pkg_dir> <out_dir> <ring>` parses `R/` and builds call edges
from every top-level function and every closure defined inside one. Closures
are keyed `owner$name`. Edges come from:

- direct calls;
- function symbols passed as arguments;
- `x$m()` calls, resolved to every closure bound to member `m`. A closure is
  bound by a named list element, `x$m <- function`, `x$m <- f` or `m = x$y`;
- owner-local calls by name;
- three declared edges for function-valued arguments and factory returns that
  the walker cannot resolve:
  - `ledgr_plan_resolve` to the cost resolver closure;
  - the availability `decision_view` to the two prepared-membership closures.

It then walks breadth-first from the roots of one ring:

- `stages`: the five `ledgr_fold_stage_*` functions.
- `ctx`: `stages`, plus:
  - the strategy-facing per-pulse surface: `$`, `[[` and `names` on
    `ledgr_pulse_context`, and `$` on `ledgr_strategy_state_view`;
  - the `ledgr_pulse_context_helper_bundle` closures;
  - `ledgr_strategy_result()`.
- `helpers`: `ctx` plus the exported authoring helpers in
  `strategy-helpers.R` and `sizing-evidence.R`.

It counts banned calls in each reached function:

- the rule-17 list (`match`, `%in%`, `setdiff`, `setNames`, `unique`,
  `data.frame`, `as.data.frame`, `rbind`, `all.equal`), as call heads or as
  apply-family function arguments;
- canonical JSON encode or parse, as call heads or argument symbols. JSON
  wrappers are leaves: they are flagged at the call site and not traversed.

Calls inside the arguments of condition signalling (`abort`, `stop`, `warn`,
`ledgr_*abort` and similar) are exempt, because message building runs only on
the failure path. Conditions guarding a signal are not exempt.

`probe_dynamic.R <lib> <pkg_dir> <out_dir>` traces every namespace closure of
the installed build. It records each function that executes while a fold stage
is on the stack, across the nine dense peer recipes (`ledgr_run()` plus a
one-candidate `ledgr_sweep()` each). Tracing 2,004 functions takes 1.1 s; the
nine workloads take about 25 s.

## Results

| Ring | Roots | Reached | Functions with hits | Banned calls | Runtime functions missed |
| --- | ---: | ---: | ---: | ---: | ---: |
| stages | 5 | 295 | 85 | 184 | 8 |
| ctx | 14 | 310 | 95 | 203 | 0 |
| helpers | 22 | 344 | 112 | 251 | 0 |

The runtime trace saw 112 package functions under a stage, excluding the JSON
leaves. The `stages` ring misses the context S3 methods and lazy fields, which
user strategy code reaches; the `ctx` ring misses none. The `helpers` ring
adds 29 rows (48 calls) in the exported selection, signal, target and weight
helpers.

`ctx` baseline by banned call: `setNames` 47, `%in%` 40, `match` 26,
`unique` 18, `setdiff` 16, `data.frame` 9, `all.equal` 7, `canonical_json` 6,
`as.data.frame` 4, `ledgr_canonical_json_encode` 2, `ledgr_json_read_nested` 2,
`rbind` 1. By file it is led by `pulse-context.R` 57, `fold-engine.R` 18, and
`accounting-replay.R`, `availability-provider-prepared.R` and
`fold-carrier.R` at 14 each.

The JSON rows include the targets owned by WS7/WS8: per-fill metadata in
`ledgr_fill_event_payload` and `ledgr_write_fill_events`, the strategy-state
checkpoint encode, `ledgr_lot_parse_meta` and the canonical-JSON calls in the
decide and plan stages. The per-pulse strategy-state `data.frame()` in the
output handler is also in the baseline.

The static walk over-approximates. Some reached functions run once per run, or
only on rare branches, such as corporate-action posting or recovery. A
baseline row on such a path costs one recorded line, not a false failure.

## Limits

The runtime witness covers only the exercised workloads, and both walks miss
an unexercised indirection that is not declared. The probe parses source; the
test must walk the installed namespace so that CRAN mode, which has no `R/`
sources, can run it. The static probe takes 5.1 s including R start-up and
parsing; an in-process namespace walk is the test's budget item.

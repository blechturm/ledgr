# Workstream 56 closeout: optional strategy intent evidence

## Outcome

LDG-3101 is implemented in `13d91b03`, with the mode-neutral flush correction
in `d4c3d1bf`. A structured strategy result may add `intent_reason = NULL` or
one non-empty character scalar. A supplied value becomes one portfolio-level
diagnostic for that invoked pulse in dense and availability-aware execution.
Omitting the field preserves the existing result and writes no row.

This is deliberately smaller than durable research-factor evidence. It records
why the strategy submitted the portfolio intent, not the signal, prediction,
rank, selection, weight vector or estimator inputs that produced it. LFB-028
therefore remains open.

## One existing persistence path

The fold validates `intent_reason` beside `targets` and `state_update`, before
risk or economic application. A valid supplied value adds one segment to the
existing per-pulse pending diagnostic block. The established bounded columnar
writer, transaction, run store, resume path and walk-forward test-run path own
the rest of its lifecycle. There is no new table, schema version, writer,
identity field or reason-vocabulary extension.

The physical row is fixed:

- `instrument_id = ""`;
- `stage = "decision"`;
- `outcome = "recorded"`;
- `reason_code = reasons = "strategy_intent"`; and
- `detail_json` contains exactly the `intent_reason` key.

The user text stays inside `detail_json`; it does not become a diagnostic
reason code. Short snake-case values are teaching guidance, not validation.

Dense execution now flushes a non-empty pending diagnostic block through the
same writer. The availability-specific block already empties that list, so the
final flush condition is mode-neutral and does not add a new execution-mode
branch. A fast-lane run initially caught and rejected the redundant branch;
`d4c3d1bf` removed it, and the mode-branch census then passed.

## Public reads

`ledgr_results(run, "diagnostics")` is the durable reader in both modes. It
returns the supplied scalar exactly, live and after `ledgr_run_open()`.

Availability-aware `ledgr_run_explain()` includes the portfolio row in its
bounded diagnostic query, matches it to instrument decision rows by decision
timestamp and returns `intent_reason` as character. An explanation row with no
supplied reason receives `NA_character_`. Dense explanation behavior is
unchanged; no synthetic dense per-instrument trace was introduced.

## Detecting evidence

Four review-profile claims own the boundary:

- LCL-0481 / LTB-0490 pins the row count, all physical literals, one-key JSON,
  omitted zero-row result, live/reopen bytes, equal economics and state, and
  equal config and derived run identity when only the returned note differs.
- LCL-0482 / LTB-0491 places a deliberate missing note between two distinct
  notes, so an instrument join or compact-row-position join gives the wrong
  literal explanation vector.
- LCL-0483 / LTB-0492 rejects length-two, missing, empty and non-character
  values and proves a public failed run commits neither an economic event nor
  a `strategy_intent` row.
- LCL-0484 / LTB-0493 labels every invocation from durable strategy state. An
  interrupted eight-pulse run resumes with exactly `pulse_1` through
  `pulse_8`, and the committed test run of a one-fold walk-forward keeps one
  value for each of its three test pulses.

The focused intent suite has 40 passing expectations. Existing strategy
contract, availability parity, availability provider, experiment-run,
walk-forward, documentation-contract, codebase-contract and test-control-plane
suites also pass.

## Identity and economics

The result field is observed only after strategy invocation. It never enters
configuration construction, strategy fingerprinting, target validation, risk,
execution, accounting or strategy state. The registered dense witness runs the
same strategy and parameters with and without the returned note, then compares
fills, equity, metrics, serialized state, config hash and the config-derived
run identity. Only the diagnostic rows differ.

## Seven-shape walk

1. No row-wise store write was added. One supplied scalar joins the existing
   per-pulse segment list and bounded columnar writer.
2. No per-instrument duplication was added; the portfolio row has an empty
   instrument ID.
3. The omitted path builds no segment or JSON and writes no row.
4. The filtered explanation query retrieves at most one additional portfolio
   row per requested decision pulse.
5. Explanation parses each returned reason once in a linear vector pass; it
   does not rescan instruments or the full run store.
6. Validation is one scalar check outside all instrument work.
7. No environment-held strategy value, target, state vector or table is
   mutated or cached.

## Registered verification

- ordinary fast profile: 578/578 blocks, no skips or failures, 111.02 seconds;
  `check-test-gate.R` returns `LEDGR_TEST_GATE_OK` against 112 seconds;
- ordinary review profile: 434/434 blocks, one established optional-package
  skip, no failures, 451.86 seconds;
- source tarball build: succeeds;
- `R CMD check --no-manual --no-build-vignettes`: package installation,
  namespace, Rd, examples, tests and every executed vignette pass. The check
  reports the existing no-built-vignette warnings and existing `utils::head`
  note; the local untracked test-record directory also produced a packaging
  note and is removed after recording these results.

The package and claims YAML parse, generated help matches its roxygen source,
and `git diff --check` is clean. No private vendor data is used.

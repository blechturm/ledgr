Verdict: PASS_AFTER_PATCHES

Role: record; independent clean-context review of WS1 Phase B.
Status: accepted; review recorded 2026-10-28, P1 applied in 697f32ee.
Authority: review evidence against the accepted cut; this file grants no new implementation scope.

Independent code review of Phase B, 2026-10-28. Reviewed `0c6ac93a..d9047e02`,
including all six LDG-3129/3130/3131 implementation/evidence commits. HEAD was
`d9047e02bb8c4423d65c905b95ac364c53860dc8` on `claude/ws1-output-handler`.
This is a review of those tickets, not LDG-3132 closeout or its timing gate.

Phase B implements the accepted handler boundary and R3 scope correctly. Apply
P1 below before accepting the no-weakened-gate claim. The exact patch needs no
further independent review; record its reason and rerun the named checks.
No product or test patch was applied by this reviewer.

## Required finding, ranked by severity

### P1 - P2: the development NEWS heading disables the release-boundary presence pin

**Evidence:** `NEWS.md:1`; `tests/testthat/test-release-claim-boundary.R:88-93`;
cut decision (5), its prohibition on weakened oracles, and `AGENTS.md`'s
registered-test rule. The new first heading makes the `first_heading` condition
false. LTB-0181 still runs its other assertions; this is a bypassed assertion,
not a reported testthat skip.

**Failure scenario:** remove the four-line Sharadar boundary paragraph from
the v0.2.2 NEWS section. The presence pin no longer executes, and the forbidden-
claim scanner cannot detect missing prose. I evaluated the actual registered
block with only NEWS reads substituted in memory: missing paragraph plus the
development heading produced **0 failures**; the same missing paragraph with
the former first heading produced **1 failure**. No file or oracle was edited.
The actual current paragraph remains present; this finding concerns the gate.

**Exact required patch:** in `test-release-claim-boundary.R`, replace lines
88-93 (the comment, `news`, `first_heading`, and conditional) with:

```r
  # The published v0.2.2 NEWS boundary remains pinned under later headings.
  testthat::expect_true(grepl(boundary, squish(file.path(root, "NEWS.md")), fixed = TRUE))
```

Keep the development heading and the one-handler NEWS entry. Keep all other
LTB-0181 assertions, fixtures and predicates unchanged. Record the test-change
reason in LDG-3130 evidence: restoring the existing published-NEWS presence
claim after adding a development heading, rather than migrating or relaxing an
oracle. Rerun `test-release-claim-boundary.R` and the missing-paragraph probe
under the development heading. I tested this exact unconditional assertion in
memory: current NEWS gives 0 failures; missing paragraph gives 1. The patch
does not alter execution, records, identity or the performance candidate.

## Review results

**R3.** `R/ledger-writer.R:9-17` is the sole canonical-R fill-row publication
delta formula. `ledgr_fill_event_payload()` at `R/backtest-runner.R:132` feeds
both buffered DuckDB and memory; `ledgr_write_fill_events()` at
`R/ledger-writer.R:83` feeds db_live. The extraction preserves casts and
arithmetic order. Validation, NO_OP short circuits, sequence selection and
transaction boundaries remain at their former sites. Planner, fold-state,
compiled code and `ledgr_fill_leg_fees()` are unchanged. The accounting-events
contract at `contracts.md:349-363` matches the design note's accepted sentence,
including its canonical-R limitation and compiled-delta exception. The RFC
pipeline closes only R3, leaving its other obligations open. LTB-0515 and
LTB-0516 pass normally and each fails under both demonstrated perturbations:
39 and 1 failed expectations respectively for cash +1e-9, and again for the
position sign change.

**One handler and sink behavior.** The buffer allocation/growth, pulse row
staging, status/completion bookkeeping and diagnostic numbering each have one
implementation in `R/output-handler.R:393-655`. The sinks contain storage
policy and storage-specific projections, not second copies of those mechanisms.
LTB-0518 verifies exactly 21 methods for DuckDB in both modes and 27 for memory.
DuckDB has no compiled-append binding. LTB-0517 checks both direct dispatch and
fold refusal for buffered DuckDB, admits memory under the same buffered spec,
and the existing live refusal/compiled parity tests still pass.

I traced Section 4/4.1's returns and side effects through the implementation:
the two non-WROTE `buffer_event()` return policies; required initialization on
DuckDB; retained memory opening rows before initialization; live writes;
transaction return/interrupt behavior; strict/non-strict telemetry; diagnostic
seed, numbering of discarded rows and fresh exception seed after failure;
pending counts and drains; empty and populated typed/event/summary readers;
and close-before-open fee/leg projection. Existing fault, growth, interruption,
recovery and equivalence tests remain intact and passed. The memory abort's
new telemetry call reaches its unconditional discard closure inside `try()`;
its failure condition class/message and production side effects are unchanged.
It is explicitly recorded in the design note, not a hidden recovery path.

**Seven optimization shapes, including moved helpers.**

| Shape | Walk result |
| --- | --- |
| 1: one-row frames bound later | DuckDB strategy-state staging now uses two character columns (`:128-163`); equity uses five numeric columns (`:287-352`). Frames manifest at flush/summary boundaries. Pulse rows/legs remain the existing closure-local staged lists with block column writes. |
| 2: full-table subsets inside ID loops | No new such loop in the handler, either sink, or moved event/leg/projection helpers. Diagnostic retention applies one vector predicate to the emitted block. |
| 3: per-element parse/format with a vector operation available | No added loop of this kind. Equity retains epochs until summary materialization. State strings come from the fold's existing `ts_iso` publication boundary. Existing row conversion/column gathering is preserved. |
| 4: repetitive per-row JSON | Existing memory `append_event_rows()` parsing (`:724`) and `events()` serialization (`:818-843`) remain the explicitly recorded debt in design Section 12. They are not new loops or copies in each sink. Typed fill/compiled paths continue using typed values. |
| 5: discarded/repeated work | Memory avoids durable telemetry/state/JSON representations; DuckDB avoids typed/inline projections. Compiled deltas are copied, not recalculated. R3 and leg-fee publication have the declared owners. |
| 6: quadratic validators | None introduced or relocated into the new handler/sinks. No pairwise event, fill, diagnostic or pulse validator. |
| 7: environment-held scalar subassignment | Event/state/equity atomic columns use indexed `setv`; growth copies existing prefixes once. Row/leg staging and retained diagnostic chunks use closure-local lists and `<<-`. Fixed loops over 5, 11 or 16 columns do not grow with data. |

LTB-0521 passes: 300 equity facts cross 256; 70 retained chunks cross 64;
2,500 state rows cross 1,000 and 2,000. Values, classes, UTC timestamps and order
match the stated references. Existing event growth/allocation-bound tests pass
without changed bounds. There is no added R-level per-element loop over events,
fills, diagnostics or pulses; inherited loops are identified above rather than
claimed to have disappeared.

**Migrations and A0 owners.** Every edit to an existing registered test is a
constructor/argument, captured or mocked factory, inspected-owner, or private-
export migration within decision (5). Added LTB-0515 through LTB-0521 blocks
are additional witnesses. Existing assertions, fixtures, fault locations,
numeric oracles and allocation bounds are unchanged. The structural demo passes
its three controls and detects all six appropriate source violations, including
the sink owners of leg staging and diagnostic seeding. The peer benchmark's
only source edit is its constructor call.

The A0 diff changes only the permitted memory observer/state adapter and the
two persistent corruption attachments. Canonicalization, fixtures, corruption
identities/injected changes/expectations, and recorded bytes are unchanged.
`guts.R:12-33` uses active bindings to the memory sink's closure frame for kept
diagnostic chunks and the actual shared handler environment for event columns.
Independent direct probes of both memory corruptions changed subsequent
`events()`/`diagnostics()` output. The telemetry and warning wrappers restrict
their changes to DuckDB handlers and retain their original path restrictions.
The independent final check is byte-identical, and the full gut run exits 0:
control passes; all 17 corruptions exit 1 and name their expected table or
missing-observer message.

**LDG-3131.** The map accounts for all 26 blocks (6 + 5 + 15), and the three
parity files have an empty diff. Retiring none is consistent with the ticket:
retirement is conditional on equivalent matching-input coverage, not a quota.
Promotion, reproduction, metric-context, feature/warmup, retention, recovery
and growth claims remain covered. Both required recovery blocks passed.
LTB-0519 really installs the observer after package loading inside mirai
workers, verifies different process IDs, and compares complete native event
tables plus all five attributes, retained diagnostics/numbering and completion.
Its daemon-side event-ID change produces differing native events while public
status, completion JSON and final equity stay equal. LTB-0520 executes nonzero
fills for both candidates and compares timestamps, sequence, economic event
columns and cash/position deltas against persisted rows. Both blocks passed
without skips.

**Identity and other flags.** The 27 scalar bindings returned by
`ledgr_store_format_bindings()` match `07dbbc87` exactly. For that comparison I
evaluated all matching top-level base-source assignments in a private
environment and called the unchanged binding collector; I did not substitute
current constants for base constants. LTB-0331 passes the committed mode-branch
census. No execution-mode branch, store-format change, old-constructor alias or
compatibility layer was introduced. `R/accounting-replay.R:95` and its related
fallback are unchanged reconstruction code, not fill-row publication; widening
R3 into that reader would exceed this accepted scope.

The peer smoke command still fails at the exact trade-summary comparison.
I also replayed the same 5-instrument/40-day/20260530 smoke inputs with the
unmodified `07dbbc87` memory constructor substituted in both public sweep and
internal oracle: zero-cost passes in both versions; realistic cost with and
without risk fails with the same message in both. This corroborates the
pre-existing classification; it is not a claim that I independently loaded an
entire base checkout. No benchmark oracle or tolerance was relaxed.

## Optional

The LDG-3130 deleted-reference evidence at `tickets.yml:110` would be more
precise as "no executable references". The frozen A0 `inventory.md:4-6` still
names both former constructors, and the missing-observer corruption intentionally
names a nonexistent removed factory. Neither is an alias or a callable consumer;
preserve the historical evidence and qualify the inventory wording.

## Commands and results

Environment: Windows x64, R 4.6.1 ucrt; duckdb 2.0.0, collapse 2.1.8,
mirai 2.7.2, testthat 3.3.2, pkgload 1.5.3. R emits startup locale warnings;
the required worker/recovery witnesses did not skip.

Paths below abbreviate `P = C:/Users/maxth/ledgr-wt/ws1-output-handler`.
All R test commands used the absolute package/test paths. `G` means
`git -C P --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler --work-tree=P`.
The explicit git directory avoids this environment's ownership refusal without
editing global Git configuration.

| Command / invocation | Exit | Result |
| --- | ---: | --- |
| `Rscript P/dev/bench/v0_2_3_output_freeze/check.R --out=C:/Users/maxth/AppData/Local/Temp/ws1-phase-b-a0-check --agreement=C:/Users/maxth/AppData/Local/Temp/ws1-phase-b-a0-agreement.csv` | 0 | Every frozen record byte-identical; 213 agreement checks, four documented differences. |
| `gut.R` evaluated by `Rscript -e` as detailed below | 0 | Control exit 0; all 17 corruptions exit 1 and name their expected surface. |
| `Rscript P/dev/ws1/r3_perturbation_demo.R P` | 0 | Both controls pass; both blocks detect each delta mutant. |
| `Rscript P/dev/ws1/structural_relocation_demo.R P` | 0 | Three controls pass; all six structural mutants fail their own predicates. |
| `Rscript -e "pkgload::load_all(P, quiet=TRUE); testthat::test_file(..., reporter='summary', stop_on_failure=TRUE)"`, output-handler-sinks | 0 | Worker native surfaces, corruption and cross-sink events; no skips. |
| Same test command, one process over ledger-writer, execution-spec, codebase-contracts, release-claim-boundary | 0 | Includes LTB-0515/16/17/18/21 and mode census; NEWS bypass separately demonstrated. |
| Same test command, one process over sweep-parity, sweep-persistence-parity, availability-parity, risk-fold, corporate-action-recovery, backtest-audit-log-equivalence | 0 | All pass, including the required recovery/parallel blocks. |
| Same test command, one process over api-exports, availability-economics, research-cycle-scale, sweep, release-coverage-branches, terminal-outcomes | 0 | All pass; the coverage retry messages are the test's deliberate failure fixtures. |
| In-memory NEWS read-substitution probe evaluating actual LTB-0181 with a ListReporter | 0 | Missing paragraph: development heading 0 failures, release heading 1. |
| In-memory unconditional-pin AST probe | 0 | Proposed repair: current prose 0 failures, missing paragraph 1. |
| In-memory base-source binding comparison | 0 | `identical()` TRUE, 27 names and values. |
| In-memory direct memory-corruption and abort/return-policy probes | 0 | Mutations reach actual owners; discard/condition/return policies preserved. |
| `Rscript P/dev/bench/peer_benchmark/peer_benchmark.R --preset smoke --engine-set ledgr-cost --out-dir C:/Users/maxth/AppData/Local/Temp/ws1-phase-b-peer-review` | 1 | Known exact trade-summary mismatch. |
| In-memory peer smoke matrix, current versus original `07dbbc87` memory constructor | 0 | Matching pass/fail outcomes for zero cost, cost, cost+risk. |
| `G diff --exit-code 0c6ac93a d9047e02 --` the three parity files and fold/compiled/planner/replay/lot sources | 0 | Empty diff. |
| `G diff --exit-code 07dbbc87 d9047e02 -- R/accounting-replay.R R/store-gate.R R/lot-accounting.R` | 0 | Empty diff. |
| `G diff --exit-code 0c6ac93a d9047e02 -- DESCRIPTION NAMESPACE src dev/bench/v0_2_3_output_freeze/records dev/bench/v0_2_3_output_freeze/fixtures.R dev/bench/v0_2_3_output_freeze/check.R dev/bench/v0_2_3_output_freeze/gut.R dev/bench/v0_2_3_output_freeze/agreement.R` | 0 | No dependency, export, compiled arithmetic, frozen record, fixture or checker change. |
| `G diff --exit-code HEAD -- . ':!inst/design/ledgr_v0_2_3_spec_packet/ws1_phase_b_review.md'` | 0 | No tracked content change from verification. |
| `G diff --check 0c6ac93a d9047e02` | 1 | Only extra blank line at design note EOF, line 332. |
| `rg -n 'ledgr_(persistent|memory)_output_handler'` over R, tests, A0 and active peer source | 0 | Historical A0 inventory and intentional missing-factory strings only; no executable old binding. |

The initial checker invocation with `--help` (which this script ignores) also
executed the complete A0 check and exited 0, with 213 agreement checks and the
four documented differences. Its default agreement output is content-identical
to HEAD. Exploratory shell/R probe setup failures were corrected; an initial
old-handler reproduction probe also exited 1 because its assumption that the
zero-cost row would fail was false. The corrected cost matrix above records the
actual distinction rather than treating that probe as product failure.

For the gut invocation, the working directory was
`P/dev/bench/v0_2_3_output_freeze`. The command evaluated the original script
with only its final CSV destination redirected in memory to `tempdir()`, so
`gut_results.csv` in the repository was not rewritten:

```powershell
Rscript -e "x <- readLines('C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_output_freeze/gut.R'); i <- grep('a0_write_table', x, fixed=TRUE); x[i] <- sub('here', 'tempdir()', x[i], fixed=TRUE); eval(parse(text=x))"
```

Every `names_table` check was TRUE:

| Corruption | Expected named surface |
| --- | --- |
| fill_qty | dense_cost / ledger_events |
| equity_ulp | dense_risk_features / equity_curve |
| drop_diagnostic | avail_terminal_resume / run_diagnostics |
| swap_events | dense_dividend_state / ledger_events |
| null_to_text | avail_terminal_resume / runs |
| sweep_return_ulp | dense_cost / sweep_returns |
| struct_alias | dense_cost / sweep_attrs |
| interrupted_telemetry | avail_terminal_resume / run_telemetry |
| memory_event | dense_cost / memory_events |
| memory_diagnostic | avail_terminal_resume / memory_diagnostics |
| memory_observer_missing | no memory-sink observation point |
| wf_warning | walk_forward / run_conditions |
| fail_error_msg | failures / runs |
| fail_exception_diagnostic | failures / run_diagnostics |
| fail_rollback | failures / ledger_events |
| fail_sweep_error | failures / sweep |
| abort_status | failures / runs |

Verification regenerated LF line endings in `R/cpp11.R`, `src/cpp11.cpp` and
the initial check's `agreement.csv`; Git's stat report marks these modified,
but its normalized content diff against HEAD is empty. I made no manual edits
to those files. The review file is the only intentional repository change.

Full package tests, R CMD check and the quiet-machine timing gate remain
LDG-3132 work. The prohibited WS1 timing runner was not executed.

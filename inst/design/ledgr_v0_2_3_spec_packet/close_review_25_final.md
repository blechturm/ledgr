# Close review 25, final: WS25 / LDG-3209 / Cut 11 close (cad309f4, 1debb248)

Mode: independent clean-context Type 1 close review, ordered by the
maintainer. Scope: the joint WS25 claim (`tickets.yml` WS25 `review.reason`),
the final bounded correction `659c40de..cad309f4` (`a18c7957`, `189fa6b4`,
`f64d5711`, `cad309f4`), the rule-16 milestone record `1debb248`, and the
ledgr-research records `8f86376` (ws25c private aggregate rerun) and
`a09c604`/`d56f951`/`4b49566` (H1). Nothing on `E:` was read. No product
code, test, fixture, oracle or `tickets.yml` was edited; this file is the only
write.

Maintainer dispositions taken as given and not reopened: (1) the cold
full-trace validation/decode memory and time exception under LDG-3209, routed
to LDG-3210, with the H1 rule "excess attributable to cold validation/decode is
covered, any other cause is a finding"; (2) rule-16 timing cells over 1.10 are
accepted in this version and checked only for honest, complete reporting.

## Verdict: PASS_AFTER_PATCHES

The product is correct as claimed. The final correction round is sound, no
registered test, fixture or oracle was weakened, and every committed checker
reproduces its record. The H1 exceedance is genuinely attributable to cold
validation and is covered by the exception. Four evidence patches are
required. None changes product code or tests. One record states a false
explanation, one disclosure understates where the covered cost is paid, and
two records omit exact-candidate results that now exist.

## Required patches (evidence only)

### P1. False "shape-dependent compaction" explanation and misleading "physical rows" phrase

`dev/bench/v0_2_3_cut11_milestone/README.md:140-146` says the compact trace
"is not compact" on the fixed-basket quiet run and that "the compact form
evidently depends on the universe shape", contrasting it with "3.6 million
logical rows in 7,201 physical rows" on the declared-universe record. The
contrast is false. The writer (`R/availability-diagnostic-writer.R:35-48,
155-177`; `R/diagnostic-codec.R:84-148`) stores one typed
`run_diagnostic_implicit` row per certified clean decision on every universe
shape. The public record's own build CSV shows this:
`dev/bench/v0_2_3_diagnostic_reader_reuse/records/post_review_correction/availability-build-summary.csv`
has `implicit_rows = 3600000` and `physical_rows = 7201`. The builder counts
only `run_diagnostics` as "physical" (`build_availability_run.R:117-121`). The
quiet probe has the same structure per run: 72,000 implicit rows plus 7,201
residual rows equals 79,201 logical rows (`evidence/quiet_stored_rows_cad309f4.csv`).
Both shapes store physical rows equal to logical rows. The codec replaces wide
JSON-bearing residual rows with narrow typed rows; it does not omit rows.

Exact patch:

- Replace milestone README lines 140-146 with this statement: on both shapes,
  codec rule 1 stores one typed implicit row per clean decision, so physical
  rows equal logical rows. Here the store is 34 percent larger than at
  `0d6c0b11` on a hold-dominated trace. The public record's 7,201 counts only
  residual `run_diagnostics` rows beside 3,600,000 implicit rows.
- In `tickets.yml:3873` (LDG-3209 F5-F6 evidence) and
  `dev/bench/v0_2_3_diagnostic_reader_reuse/README.md:126-127`, replace
  "represented by 7,201 physical rows" with "stored as 3,600,000 typed
  implicit rows plus 7,201 residual `run_diagnostics` rows".

This contradicts no accepted claim, contract or acceptance item; see
Observation O1.

### P2. The exception's stated user-visible limit understates where H1's covered cost is paid

The exception text (`tickets.yml:3878`,
`per_pulse_restart_decoder_closeout.md:243-246`, mirrored in
`macro_plan.md:565-572`) gives the user-visible limit as "one cold full-trace
validation and decode per opened run handle". The H1 excess is not paid on an
opened handle. It is paid inside `ledgr_run()`. A call-chain probe on
`cad309f4` (5 x 30 hold run, wrapper around
`ledgr_diagnostic_decision_order_bad`) shows three store-wide validations per
`ledgr_run()`, plus one more on the first public read:

1. `ledgr_run_registration` -> `ledgr_diagnostic_initialize_run` ->
   `ledgr_diagnostic_summary_from_store` -> `ledgr_diagnostic_require_coverage`
   (`R/run-registration.R:88`, `R/diagnostic-codec.R:19,154`), over an empty
   trace;
2. `ledgr_run_restart_nonterminal` -> `ledgr_diagnostic_initialize_run`
   (`R/run-resume.R:44`), over an empty trace;
3. `diagnostic_writer$drain` -> `output_handler$write_diagnostic_summary` ->
   `ledgr_diagnostic_summary_from_store` (`R/output-handler.R:143-144`), over
   the full trace, inside the run transaction, so it publishes no handle proof;
4. the first public read (`ledgr_results(bt, "diagnostics")`) then validates
   cold again.

`data/h1/attribution_candidate-traced.csv` places the peak private-commit rise
in call 1 (1,515 to 2,004 MiB, on an empty trace, from the membership CTEs)
and in call 3 (2,004 to 4,685 MiB). This is cold validation, so the
maintainer's H1 rule covers it. The research README already discloses the
three-call count. The ticket-side exception and the LDG-3210 input do not.

Exact patch: do not reword the maintainer's disposition. Add an LDG-3209 H1
evidence line (see P4) stating that the covered excess is paid inside
`ledgr_run()`'s publication-time summary validation, and that `ledgr_run()`
performs three store-wide validations (two over an empty trace) before the
handle's own cold validation. Add the same sentence to the LDG-3210 measured
input at `macro_plan.md:565-572`.

### P3. No recorded full verification on the exact final candidate

LDG-3209 acceptance item 3 requires full tests, profiles, A0/frozen
references, fixture lanes, source census, build and R CMD check "on the exact
final candidate". The recorded full verification stops at `1e5030bf`.
`a18c7957` and `f64d5711` then changed `R/diagnostic-decoder.R` and
`R/diagnostic-codec.R`, and their evidence lines record only focused decoder,
split-store and documentation-contract suites.

This review ran the full source suite on `cad309f4` (result below). The ws25c
rerun shows that every `cad309f4` table digest on the private workloads equals
its `1e6ae7b5` digest. That is direct output-equivalence evidence for the
wrapper-only change.

Exact patch: add an LDG-3209 evidence line recording a full suite and a
supported-locale R CMD check on `cad309f4` (this review's suite run may be
cited). For A0, typed-accounting and the censuses, add one stated reason
citing the wrapper-only diff and ws25c digest equality, or rerun them.

### P4. LDG-3209 evidence and the closeout still say the three gates are open

`per_pulse_restart_decoder_closeout.md:253-266` ("Gates still open under
LDG-3209") and the last LDG-3209 evidence line (`tickets.yml:3878`, "The
corrected-head private rerun, milestone and H1 execution remain OPEN") predate
`8f86376`, `1debb248` and `4b49566`.

Exact patch: when reconciling, which the ticket assigns to after review and
acceptance, add three evidence lines with pointers and one-line results:

- ws25c: `WS25C_PRIVATE_GATE_CHECK_OK`; 14 runs exit 0; 195 tables
  IDENTICAL and 12 `ACCEPTED_TYPED_LEDGER`; snapshot `e8cbb805`.
- Milestone: `dev/bench/v0_2_3_cut11_milestone/README.md` and three timing
  records.
- H1: four of five ratios pass. Single-run parent private commit is 2.066x,
  attributed to cold validation and covered; `H1_GATE_EXCEEDED` is the
  checker's literal output.

Replace the closeout's open-gates list with those pointers.

## Joint WS25 claim, part by part

| Part | Status | Evidence checked |
| --- | --- | --- |
| Cursors/checkpoints/restore and `ledgr.interrupt` gone | Holds | No `strategy_state` table, restore helper, `ledgr_run_resume` or `ledgr.interrupt` in `R/`. `strategy_state` remains only as the declared in-memory state that LDG-3206 preserves (`R/backtest-config.R:110`, `R/backtest-runner.R:764-771`). |
| Nonterminal restart atomic from pulse one; terminal idempotence and publication recovery | Holds | `R/run-resume.R:6-56`: one `dbWithTransaction` deletes all eight derived tables, posts openings once and re-initializes empty coverage; returns `start_idx = 1L`. Registered witnesses run in the full suite. |
| Consumers behind an exact logical decoder first | Holds | Every read of `run_diagnostics`/`run_diagnostic_implicit` in `R/` goes through `ledgr_diagnostic_logical_sql()`/`ledgr_diagnostic_decode()`, except the always-physical stopped-row read at `R/availability-results.R:118`, which LDG-3207 classifies. |
| Certified implicit form or typed residual before row expansion | Holds | `#contract-execution-fold-carrier` and fold-phase text (`contracts.md:220-236`); writer appends implicit columns by index into bounded chunk buffers (`R/availability-diagnostic-writer.R:155-177`). |
| Full/filtered diagnostics, explanations, summaries, sequence and economics exact, without strategy code or writes | Holds | Private ws25c: 207 tables, 195 IDENTICAL plus 12 typed-ledger accepted, including `diagnostics_full`, `diagnostics_filtered`, `diagnostics_d8`, `explain_point`, `explain_history` and summaries; every digest equals `1e6ae7b5`. Decoder path performs reads only (`duckdb_register` is a connection-local view, unregistered on exit). |
| Scheduled skips and irreducible sizing remain | Holds | `#contract-persistence-fold-evidence`: skips, stops and errors always physical; sizing rows are physical `run_diagnostics` rows (`R/diagnostic-codec.R:172-176` reads them there). D8 table identical on real data. |
| Retention and association non-circular and no-lookahead | Holds (unchanged this round) | Association query `R/diagnostic-decoder.R:373-407` ties implicit fills to typed `ledger_events` and snapshot closes; no fills-to-diagnostics edge was added. |
| Proof families and H1 pass or have explicit disposition | Holds after P2/P4 | ws25c PASS; H1 one ratio exceeded, attributed and covered (below). |
| One final schema-125 plus codec fingerprint | Holds | `ledgr_diagnostic_codec_rule_version` enters the fingerprint through the `^ledgr_[a-z_]+_(schema|rule)_version$` binding scan (`R/store-gate.R:3-12`); `test-store-gate-contracts.R:9,188-196` pins it and refuses the WS24-close fingerprint. `#contract-persistence-current-format` names the binding. |

## Final correction round (659c40de..cad309f4)

- **Classed OOM boundary.** One wrapper,
  `ledgr_diagnostic_db_get_query()` (`R/diagnostic-decoder.R:68-70`), routes
  every query of the eight validation/decode/summary functions through
  `ledgr_diagnostic_query()` (`:41-63`). That function reclasses only
  out-of-memory, pin and allocation failures as
  `ledgr_diagnostic_resource_exhausted` (with the parent kept) and re-raises
  everything else unchanged. No raw `DBI::dbGetQuery` remains in either file.
  Only `duckdb_register` and writer-side `dbExecute` sit outside it, and
  neither is a read. No product path sets `memory_limit`. LTB-0565 exercises
  a real DuckDB refusal both cold and after a warm proof.
- **Per-handle reuse and invalidation.** The cache lives on the handle state
  (`R/backtest-handle.R:21-22,142-143`), so a fresh handle starts empty. It is
  reachable only while a public validation scope is open (`:262-277`), so
  direct internal calls stay cold. The cache key is the sorted run-id set.
  The token (`R/diagnostic-decoder.R:88-130`) is the coverage rows, summary
  hashes, and size and mtime of the main and WAL files of every attached user
  database. It covers the attached snapshot store, and returns NULL (no reuse)
  for in-memory or missing paths. A hit additionally requires that no explicit
  transaction be open (`:313-321`). Publication happens only after a complete,
  unfiltered validation, the token is recomputed afterwards, and nothing is
  published inside a transaction (`:447-459`). The fresh-handle, checkpoint,
  split-store, attached-store, transaction-local-repair and in-memory cases
  each have a registered witness (LTB-0561 to LTB-0564).
- **No weakened test.** The only removed test line is LTB-0558's
  `expect_match(validator_source, "ledgr_diagnostic_query")`, replaced by the
  wrapper symbol. The old pattern no longer matches the new call, the bounded
  SQL assertions around it are unchanged, and the stated reason is recorded
  (`tickets.yml:3877`). `claims.yml` LCL-0547 widens its oracle class and
  mutation list. LTB-0190's constant went 9, then 10 (memory-cap read added at
  `21310963`), then back to 9 (cap removed at `1e5030bf`). Its
  one-run-versus-many scale assertion is unchanged, so the reason holds.
  LTB-0562 to LTB-0564 are the four new blocks that `f4ead35d` had all
  labelled LTB-0561, given unique IDs at `432fe67c`; no pre-existing block
  was relabelled.
- **Seven shapes over the changed functions.** No added iteration, one-row
  frame, per-element parse, per-row JSON, quadratic validator or scalar
  environment write. A cache hit costs a constant five small queries plus one
  `file.info` over at most four paths. Shape 5 (recomputation) exists only in
  the pre-existing in-run validation (P2), which is covered and routed to
  LDG-3210.

## LDG-3209 acceptance items

| Item | Result |
| --- | --- |
| Schema-125 plus codec fingerprint; earlier stores refuse; WS24-close fingerprint refuses | Met (store-gate test in the full suite; no migration or fallback found). |
| Seven proof families with exact parity and refusal witnesses | Met by ws25c (rerun below) plus the public A0/gut records already accepted. The rebuild reproduces snapshot hash `e8cbb805`, which the checker enforces on every run. Fact digests are stated only in README prose, but hash rule 4 includes "the exact fact projection" (`#contract-snapshot-identity-and-verification`), so the checked hash subsumes them. |
| Full tests, profiles, A0, fixtures, census, build and check on the exact candidate | Not recorded; P3. |
| Milestone completeness | Both bases, four WS8 hotspots, three shape cells and quiet per-function counts (`quiet_prof_self_*.csv`) are present. Physical and logical rows are present but misexplained (P1). Store bytes are present. Helper-sizing rows and bytes are in ws25c `diagnostics_d8` (151,324 rows, 39,602,780 bytes, identical to base). Read, decode and memory figures come from the quiet reads, ws25c and H1. Timing cells over 1.10 are all disclosed. |
| H1 | Exceeded on one ratio and covered by the recorded exception: user-visible limit plus LDG-3210 routing, with the disclosure correction in P2. |

## H1 attribution judgement

The attribution supports "covered". In the traced candidate run, the lifetime
peak private commit is unchanged outside the validator. It reaches only
2,004 MiB before the publication-time validation, below the base run's
2,536 MiB peak. It rises to 4,685 MiB only inside
`ledgr_diagnostic_decision_order_bad()`. Reads of fills and equity add
nothing on either arm. Peak working set is equal on both arms (2,482 and
2,484 MiB), consistent with committed but untouched DuckDB working memory. The
single-run parent working-set ratio (1.098) passes, but only narrowly.

## Non-blocking observations

- **O1. Storage does not shrink on hold-dominated traces.** The accepted
  synthesis (`rfc_per_pulse_durable_records_v0_2_3_synthesis.md`, Sections 1
  and 7) treats savings as "hypotheses, not accepted bounds". It promotes the
  physical typed layout to the spec cut. The contracts describe implicit clean
  pairs and holds as stored typed rows without a row-count promise. One
  implicit row per hold therefore breaches nothing. The maintainer may still
  want to park a per-pulse run-length form of clean holds beside LDG-3210.
- **O2.** The classed message reads "Diagnostic integrity validation exhausted
  DuckDB's available memory" even when the final decode or summary read
  refuses. The class is right; only the wording is narrow.
- **O3.** `ledgr_diagnostic_decision_order_bad()` builds one axis frame per
  run with `lapply` plus `rbind` (`R/diagnostic-decoder.R:160-181`). It
  iterates runs, not rows, and predates this round.
- **O4.** In the milestone, the sentence "Three cells exceed the protocol's
  1.10 disposition trigger" counts only the `0d6c0b11` comparison. The
  v0.2.2 comparison's two 2.5x fixed-basket cells are disclosed in prose
  rather than counted. The checker output matches both tables.

## Checker reruns (no private data)

- `check.R data/ws25c ws25c` -> `WS25C_PRIVATE_GATE_CHECK_OK`.
- `h1/h1_check.R check data/h1`: four of five gated ratios pass. Single-run
  parent private commit is 1,648.2 -> 3,404.9 MiB (2.066), FAIL, printing
  `H1_GATE_EXCEEDED`. Elapsed (1.123 and 1.045) and summed working set (0.955)
  are disclosed only. No other R processes were seen.
- `dev/bench/timing/check.R`:
  - `cut11-accounting-1/cut11-milestone-ldg3200/attempt-1`: 1.224, 1.265 and
    1.123, all within bound 10. "work differs" appears on two cells, from the
    ledger digest only; the milestone explains this.
  - `ws5-timing-1/cut11-milestone-v022/attempt-1`: fixed no-fill 2.539 and
    fixed sparse 2.512 are over 1.1; the other four are 0.38-0.97.
  - `ws5-timing-1/cut11-milestone-ldg3200/attempt-1`: declared no-fill 1.127,
    fixed sparse 1.109 and declared sparse 1.163 are over 1.1; the other three
    are 0.91-1.05.
  - Every ratio equals the milestone tables. Over-bound cells fall under
    maintainer disposition 2.

## Full test suite on cad309f4

`pkgload::load_all()` plus `testthat::test_local(reporter = "summary")` on
the clean `release/v0.2.3` checkout at `1debb248` (product `cad309f4`), with
the default Windows R 4.6.1 locale, exits 0. Of 229 test files, about 23,293
expectations pass, with 0 failures, 0 errors and 0 warnings. One skip is
expected: `test-snapshot-adapters.R:343` exercises the missing-quantmod path,
and quantmod is installed. The "coverage attempt 1/3 failed" line in
`release-coverage-branches` is that test's own simulated shard retry.
LTB-0561 to LTB-0565, LTB-0190, LTB-0558 and the store-gate contracts all pass
in this run. The ws25c digest recount also confirms 195 IDENTICAL plus 12
`ACCEPTED_TYPED_LEDGER`, and all 207 `cad309f4` candidate table digests equal
the `1e6ae7b5` digests. R CMD build and check were not run in this review.

## Not verified

- The private rebuild itself, its fact digests and the H1 and milestone runs
  (they need `E:` data or host time). Only their committed aggregates and
  checkers were verified.
- A0, typed-accounting, the censuses, R CMD build and R CMD check on
  `cad309f4` were not rerun (P3).

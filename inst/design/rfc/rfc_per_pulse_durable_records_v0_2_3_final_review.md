# Per-Pulse Durable Records: Type 1 Final Review

- Mode: Type 1, RFC cycle stage 8; independent Codex session, 2026-11-03.
- Authority: maintainer-instructed brief supplied for this review. This session
  authored none of the seed, response, response review or synthesis.
- Reviewed head: `release/v0.2.3`,
  `0ad8477b173890c2b35c1c6f442c797a767b8c96`.
- Verdict: **PASS**. No corrective findings or patches required. No design
  problem requiring `NEEDS_TYPE_2` was found.

The synthesis faithfully settles the operative inputs, including explicitly
correcting v2 where its proposed physical omissions would violate its own exact
logical-trace guarantee. This verdict verifies the synthesis and its evidence;
it does not accept the pending RFC on the maintainer's behalf or certify an
unimplemented codec. Scope follows `inst/design/rfc_cycle.md:238` and
`inst/design/rfc_cycle.md:274`.

All file:line citations below resolve at the reviewed head. In this review,
`S`, `V2`, `R` and `RR` mean, respectively:

- `inst/design/rfc/rfc_per_pulse_durable_records_v0_2_3_synthesis.md`
- `inst/design/rfc/rfc_per_pulse_durable_records_v0_2_3_seed_v2.md`
- `inst/design/rfc/rfc_per_pulse_durable_records_v0_2_3_response.md`
- `inst/design/rfc/rfc_per_pulse_durable_records_v0_2_3_response_review.md`

1. **Verified: these are the right inputs, independently of their authors.**
   The RFC pipeline identifies this cycle and these operative artifacts
   (`inst/design/rfc/README.md:108`). I independently searched production
   references to `run_diagnostics`, `strategy_state` and `run_completion`, read
   their writers and consumers, and checked the governing contracts and pending
   release work. The actual boundary is the one the cycle addresses: cursor
   continuation reads the state table (`R/run-resume.R:28`,
   `R/strategy-state.R:427`), diagnostics feed public reads and summaries
   (`R/availability-results.R:35`, `R/sizing-evidence.R:130`), and committed
   completion has a separate recovery path (`R/backtest-runner.R:513`).
   Existing tests independently preserve raw versus no-instruction sizing
   (`tests/testthat/test-strategy-sizing-evidence.R:224`) and scheduled-skip
   evidence (`tests/testthat/test-strategy-schedule.R:850`). These tests were
   read, not changed or reported as rerun.

   The authority check did not stop at the cycle's bibliography. The design
   index distinguishes shipped contracts, pending accepted scope and horizon
   ideas (`inst/design/README.md:38`); the macro plan places reader and storage
   changes together before behavior-frozen subtraction
   (`inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md:429`, `:448`, `:602`).
   The earlier trace-scale/read-cost record independently establishes why the
   private reference is relevant
   (`inst/design/rfc/rfc_history_wave_v0_2_2_decisions.md:498`;
   `inst/design/ledgr_v0_2_2_spec_packet/history_proof_phase_b_closeout.md:118`).
   V1 supplies history and measurement limits, not the operative replay proposal
   (`inst/design/rfc/rfc_per_pulse_durable_records_v0_2_3_seed.md:49`, `V2:11`).
   I found no omitted controlling input that changes the synthesis's settlement.

2. **Verified: the prior decisions survive, and departures are explicit.**
   Section 9.4 requires the same reopened diagnostics and explanation without
   strategy execution
   (`inst/design/rfc/rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md:717`).
   E9 preserves the full logical trace and conditions physical compression on
   exact reconstruction
   (`inst/design/rfc/rfc_history_wave_v0_2_2_decisions.md:468`). `S:18`, `S:45`
   and `S:61` preserve both. `S:36` explicitly supersedes only the pending
   physical full-row requirement from
   `inst/design/ledgr_v0_2_0_0_spec_packet/v0_2_0_0_spec.md:431`.
   Keeping the non-weakening release gate (`S:39`) is consistent with its actual
   wording at `inst/design/contracts.md:3370`; exact compression does not weaken
   the trace. This expressly rejects the broader replacement proposed at
   `V2:51` and `R:216`, rather than silently overlooking it.

   The response-review dispositions (`RR:51`) are accounted for: recovery,
   summary evidence, consumers, early selection and placement survive; replay,
   replay commitments and RNG certification are withdrawn (`S:179`, `S:241`,
   `S:255`). The synthesis separately records why the outcome-only predicate
   and summary-only exact-sizing retention are insufficient (`S:90`, `S:257`).

3. **Verified: Q1-Q4 are settled and the public logical contract is preserved.**
   Q1 chooses the full logical trace by default (`S:45`); the actual wrapper
   delegates to `tibble::as_tibble()` (`R/backtest-results.R:1392`, `:1290`).
   History mode, point refusal and no-action defaults exist as cited
   (`R/availability-results.R:730`, `:755`, `:713`). The sizing empty-sentinel
   projection is real (`R/availability-results.R:44`). Durable writes renumber
   contiguously (`R/output-handler.R:645`), while candidates preserve logical
   sequence positions across discarded rows (`R/output-handler.R:360`).
   `S:54` and `S:175` correctly distinguish those obligations.

   Q2 permits physical omission of an otherwise exactly reconstructible clean
   trade; it does not erase its actual price or informational reasons (`S:126`).
   Q3 keeps physical scheduled-skip rows and valuation evidence (`S:151`), matching
   `inst/design/contracts.md:147`. Q4 makes the private reference mandatory
   alongside portable evidence (`S:209`, `S:216`). Its absence cannot be called
   a passed implementation gate (`S:232`). These choices resolve `V2:226`
   through `V2:235`; none is left to an accidental reader default.

4. **Verified by execution: the new sizing witness establishes its claimed limit.**
   I ran the complete embedded block at `S:293` unchanged on the reviewed head.
   It returned `tier_2`, identical normalized ledger and equity tables, identical
   complete D8 summaries, and identical stored configuration hashes. Both runs
   emitted the raw-sizing notice on 2020-01-01. The only instrument sizing
   instruction was `sizing_rounded`, target 50 and quantity 50, on 2020-01-02
   for caller seed 14 and 2020-01-03 for caller seed 47.

   An additional assertion pass confirmed that normalized full diagnostics
   differ, both have 14 rows numbered contiguously, and January 2's decision and
   reconciliation have sequences 5/6 versus 4/5. Both summaries have one
   evidenced decision, five unavailable decisions, zero no-instruction decisions,
   pooled/minimum/last coverage 1, requested/post-guard/rounded values USD 500,
   rounding difference 0 and final actual invested exposure 0.5. Thus a complete
   summary cannot identify the original instruction's placement or downstream
   sequence, as claimed at `S:103` and `S:108`.

   The code emits sizing rows for every nonempty validated helper instruction,
   including unchanged integer instructions (`R/fold-engine.R:889`, `:896`).
   D8 reads both their values and decision times (`R/sizing-evidence.R:139`,
   `:169`, `:187`). Ordinary sequential ambient RNG is expressly supported as
   Tier 2 (`inst/design/contracts.md:2100`). The witness therefore does not
   depend on a forbidden strategy or on replay certification. Closing and
   reopening the first run also preserved its diagnostics and history
   explanation exactly with `ledgr_execute_fold()` mocked to refuse execution.

5. **Verified: timing, association and reconciliation citations are accurate.**
   P1 constructs the private next-bar execution packet in the same fold step
   (`R/fold-engine.R:619`); P3 stages execution evidence and P4 applies the plan
   (`R/fold-engine.R:1204`, `:1271`). The decision row's position is the
   decision-time holding (`R/fold-engine.R:960`), while the execution row carries
   its planned outcome (`R/fold-engine.R:1219`). `S:132` preserves this ordering
   and keeps the next bar private from strategy/risk decisions.

   The fills reader really queries execution diagnostics
   (`R/execution-timing.R:224`), so the circular dependency identified at `S:139`
   must be removed before those physical rows disappear. For declared sessions,
   recording-pulse association maps to the execution session's close
   (`R/execution-timing.R:189`, `:201`); bar-native alignment remains the fill
   timestamp (`R/execution-timing.R:217`). The synthesis preserves association
   evidence rather than assuming economic execution time equals decision time.

   P5's three exposure reductions and its cash subtraction are as described
   (`R/fold-engine.R:1457`). Both reconciliation checks exist
   (`R/fold-engine.R:1159`, `:1444`). The sub-tolerance actionability threshold
   also exists (`R/fold-engine.R:1071`). Requiring exact residuals when arithmetic
   cannot be reproduced (`S:116`) and forbidding that threshold as a compression
   tolerance (`S:81`) faithfully preserve current evidence.

6. **Verified: recovery retirement and consumer coverage fit current code.**
   The response's complete runnable block (`R:229`) also passed unchanged:
   six-pulse quiet run DONE with six cursors and 25 diagnostics; strategy failure
   FAILED with zero cursors and one error diagnostic, then six calls on retry;
   soft stop RUNNING with three cursors and 13 diagnostics, then three calls on
   continuation; DONE retry zero calls; injected post-fold publication failure
   FAILED with six cursors, then recovery with zero strategy calls. Its sizing
   comparison reproduced 0.9980431 versus 0.9090909; its shortened-window result
   reproduced filled versus no_fill. These support the recovery and evidence
   distinctions carried into `S:179` through `S:205`.

   Registration checks identity before DONE's early return
   (`R/run-registration.R:115`, `R/backtest-runner.R:396`). INCOMPLETE validates
   completion, and publication recovery bypasses cursor continuation
   (`R/backtest-runner.R:513`, `:530`, `:560`, `:757`). The synthesis correctly
   avoids claiming DONE currently performs the same terminal checks (`S:198`).
   Interrupt rollback is explicit (`R/output-handler.R:104`), in-memory state
   updates remain separate (`R/fold-engine.R:1495`), and `checkpoint_every` still
   flushes buffers (`R/fold-engine.R:1565`). Walk-forward skips DONE/INCOMPLETE
   test runs (`R/walk-forward.R:1155`).

   The independently checked SQL consumers include valuation counts/exposure
   (`R/valuation-summary.R:105`), batched decision existence (`:636`, `:645`),
   completion-stop validation (`R/run-finalize.R:129`), corporate-action bounds
   (`R/corporate-action-results.R:159`) and fill associations. `S:160` through
   `S:177` covers them through logical decoding or exact summaries, while
   preserving candidate retention rather than granting candidates D8 coverage.

7. **Verified: implementation gates and routing stay within the chosen scope.**
   Selection currently happens at pulse flush after segment expansion
   (`R/fold-engine.R:277`, `R/fold-carrier.R:795`, `:842`); `S:71` moves only
   storage selection earlier and retains economic validation/state transitions.
   The field/presence/order map, frozen canonical baseline and exact public
   parity gates (`S:225`) make compression conditional on proof. Performance is
   to be measured, not inferred from the seed's estimates (`S:235`). The shared
   harness exists at `dev/bench/timing/runner.R`; no alternate engine or execution
   mode is authorized (`S:66`). Current-format refusal is consistent with the
   existing class at `R/store-gate.R:77`; coordinated format work remains pending
   (`S:244`).

   Horizon routing also checks out: the progress/state split is a non-binding
   proposal (`inst/design/horizon.md:97`), the authoring synthesis's storage
   obligation is conditional
   (`inst/design/rfc/rfc_strategy_authoring_api_v0_2_3_synthesis.md:515`), and the
   explanation showcase already depends on settled storage and measured read
   repair (`inst/design/horizon.md:49`). `S:264` preserves these distinctions.

Execution environment: Windows x86_64, R 4.6.1 (2026-06-24 ucrt), DuckDB 2.0.0,
collapse 2.1.8, pkgload 1.5.3. All probes used
`pkgload::load_all(..., compile = FALSE)`, disposable stores, and TMP, TEMP and
TMPDIR set to `C:/Users/maxth/ledgr-wt/final-review-tmp` before starting R.
R confirmed its session temp directory was inside that directory. Both embedded
blocks exited successfully; R printed locale startup warnings.

To reproduce either embedded block from PowerShell, set `$artifact` to `S` or
`R`'s absolute file path and run:

```powershell
$env:TMP = 'C:/Users/maxth/ledgr-wt/final-review-tmp'
$env:TEMP = $env:TMP
$env:TMPDIR = $env:TMP
$source = Get-Content -LiteralPath $artifact -Raw
$block = [regex]::Match($source, '(?s)```r\r?\n(.*?)\r?\n```').Groups[1].Value
$block | & 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' -
```

The synthesis baseline `04fac1bfff9055c440d09c0d98b6e6da652303b8` and reviewed
head differ only in five RFC documents; product code and cited contracts are
unchanged. No codec prototype, timing ranking, private Sharadar run, full test
suite or package check was run for this document review. Those future parity and
resource gates are not claimed passed. Only this requested review file was
written; no tracked file was changed, and no commit or implementation was made.

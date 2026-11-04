# Close review 25: Cut 11 Workstream 25 product surface (LDG-3206..LDG-3208)

Mode: independent clean-context Type 1 code review.
Reviewed commits: `453806e4` (retire pulse resume, centralize diagnostic reads)
and `aadd2fc3` (exact compact diagnostic encoding). The base is accepted WS24
`622ff3a4`. The concurrent lean-core commit `29d6ad40` was ignored.

## Verdict: CHANGES_REQUIRED

The design is sound. Certification runs in P3 on typed segments, after
strategy and risk have run. Only exact current-close clean fills and holds
become implicit. Risk, stale, restriction, rejection, sizing, skip, stop and
error rows stay physical. One SQL union decoder serves the logical trace, and
coverage and association checks run before every read. Restart is ordered
correctly: identity, snapshot guard and terminal-evidence validation all run
before the atomic delete-and-reopen transaction. Terminal recovery bypasses the
fold.

The candidate still cannot close:

- The package suite is red. Four tests break on removed seams or stale
  literal censuses, and the WS23 source-census check is stale.
- Crash-orphan runs make store-wide listing refuse.
- An accepted WS23 boundary seed was deleted without a replacement.
- Several acceptance witnesses are missing.

None of these needs a Type 2 review. F2 and F7 contain small maintainer choices.

## Evidence boundary

Bash `Rscript` and PowerShell were denied in this session (don't-ask mode).
Because of that, no test, census or mutation was executed. Every finding below
comes from reading the code and tracing call graphs. The red-suite claims in F1
are deterministic name and literal mismatches, so they need no run to confirm.
Rerun the focused suites before acting on the other findings. As instructed, E:,
private Sharadar data, the private rebuild, milestone clocks and the H1 gate were
not touched. They remain OPEN.

## Findings

### F1. High: the full suite and the registered censuses are red at `aadd2fc3`

Four tests fail deterministically:

- `tests/testthat/test-store-gate-contracts.R:3-33,77` (LTB-0259). The literal
  binding list has 30 entries and lacks `ledgr_diagnostic_codec_rule_version`.
  `ledgr_store_format_bindings()` auto-discovers the new binding through the
  `_rule_version$` pattern, so there are now 31 and `expect_identical` fails.
- `tests/testthat/test-ledger-writer.R:1124-1148,1160` (LTB-0518). The durable
  handler method set now also has `write_run_diagnostic_implicit`,
  `write_diagnostic_coverage` and `write_diagnostic_summary`
  (`R/output-handler.R:634-645`). The census still expects 20 methods.
- `tests/testthat/test-typed-accounting-boundary.R:119` (LTB-0550). The test
  calls `get("ledgr_run_resume", asNamespace("ledgr"))` on a deleted function.
- `tests/testthat/test-strategy-preflight.R:286-303`. The test calls the deleted
  `ledgr_abort_strategy_ambient_rng_for_resume()`.

One registered census is also stale. The patterns in
`dev/bench/v0_2_3_typed_accounting/check.R:5-17` still count `strategy_state`,
`ledgr.interrupt`, `ledgr_run_resume` and `run_diagnostics`.
`source_census.csv` was not regenerated, so the check stops.

Smallest fix:

1. Add the binding to LTB-0259 (type `integer`, length 31).
2. Add the three methods to LTB-0518 (23 durable methods; the intersection
   stays 18).
3. Point LTB-0550's boundary entry at `ledgr_run_restart_nonterminal`.
4. Retire the preflight resume-helper test, with its retired-resume reason
   listed in the ticket evidence.
5. Regenerate `source_census.csv`.

Then run the full suite on the exact candidate. Each change is a literal-census
update for a new or removed seam, not an oracle change.

### F2. High: crash-orphan nonterminal rows make `ledgr_run_list()` and `ledgr_run_info()` refuse the whole store

`R/diagnostic-decoder.R:48-67` exempts only one case from missing coverage:
`RUNNING` with no rows. Two orphan cases still break:

- **CREATED orphan.** The run row is inserted as `CREATED`
  (`R/run-registration.R:83`). It becomes `RUNNING` only after feature
  precompute and preflight (`R/backtest-runner.R:785`). If the process is
  killed in that window, the row stays `CREATED` with no coverage.
  `ledgr_run_completion_info_many()` (`R/availability-results.R:115`) decodes
  every listed run, so `ledgr_run_list()` (`R/run-store.R:880`) aborts with
  `ledgr_diagnostic_corrupt`. The message does not name the run.
- **RUNNING orphan.** A process killed mid-fold commits nothing inside the fold
  transaction. The row stays `RUNNING` with no coverage and no summary. The
  coverage check passes, but `ledgr_diagnostic_flag_counts()` calls
  `ledgr_diagnostic_summary_read()` (`R/diagnostic-codec.R:246-249`). That
  function requires a summary row for every run, so it refuses. The call path
  is `ledgr_run_assumption_flags_many()` (`R/valuation-summary.R:620`), reached
  from `R/run-store.R:905`.

Before WS25, both stores listed normally. LTB-0207 does not catch this: its
first attempt fails through the exit guard, which writes coverage 0 and a
summary.

Smallest fix: make every registered run carry coverage 0 and an empty-trace
summary from birth. Write them in the registration insert transaction for fresh
runs, and inside the restart transaction in `R/run-resume.R`. Then delete the
`RUNNING` exemption. Add one witness: an orphan `CREATED` row and an orphan
`RUNNING` row, then `ledgr_run_list()` and `ledgr_run_info()` succeed.

Maintainer choice: the alternative is to treat a nonterminal run with no
evidence as an empty trace at read time. That spreads a special case into two
readers, so the publish-at-birth fix is recommended.

### F3. Medium: the accepted opening-to-first-block boundary seed was deleted

WS23 rereview 2 (N2) accepted the runner call
`output_handler$seed_event_boundary(...)`. It seeds the handler from the
durable opening tail, so the first fold block is checked across that boundary.
`453806e4` deleted the call together with the resume code
(`R/backtest-runner.R`, old lines 589-608). The opening boundary still exists
on fresh runs and on every restart that posts openings. The handler method and
its comment (`R/output-handler.R:382-386`) remain, but nothing in production
calls it. This went unnoticed because N2 had already recorded that no detector
covers the call site.

Smallest fix: after `ledgr_run_restart_nonterminal()` returns
`next_event_seq > 1`, call
`output_handler$seed_event_boundary(next_event_seq - 1L, start_ts_utc)`. No
query is needed. Add the namespace no-op mutation detector that N2 noted is
missing.

### F4. Medium: fill recording-pulse derivation is an R loop over fills with an O(sessions) scan

`R/execution-timing.R:148-153` runs
`for (i in seq_along(fill_time)) which(session_open == fill_time[[i]])`. That is
O(fills x sessions) at R level on a public result-reader path, where the
removed code used vectorized `match()`. It hits shapes 1 and 7 of the
optimization manual: R-level iteration over fact rows, and pairwise work in
place of a grouped sweep. At published-benchmark scale it costs seconds; at
lake scale it costs minutes.

Smallest fix:

```r
hit <- match(fill_time, session_open, incomparables = NA)
dup <- session_open %in% session_open[duplicated(session_open, incomparables = NA)]
ok <- !is.na(hit) & hit >= 2L & !dup[hit]
recording[ok] <- session_close[hit[ok]]
```

Keep the existing ambiguous and missing cases in
`test-availability-execution-timing.R`.

### F5. Medium: acceptance witnesses named by LDG-3206 and LDG-3208 are absent; ticket evidence is empty

- **LDG-3208.** Three named witnesses are missing:
  - "writer counters prove retention/encoding precedes general
    row/data-frame/JSON expansion": no counter exists.
  - "a mutation exposing the next-bar outcome to P2 or risk before retention
    fails the registered no-lookahead witness": no such witness exists.
  - "exact-name searches detect a restored one-physical-row-per-axis claim":
    no documentation detector exists.
- **LDG-3206.** "exact-name documentation/condition searches detect stale
  continuation teaching" is unmet. LTB-0555 scans only `R/`.
- **Retired and migrated tests.** The closeout lists six behavioral witnesses.
  It does not list LTB-0490, 0493, 0532, 0533 or 0536, the economics,
  finalization-prefix and fold-witness migrations, or the WS4a W1 mutation that
  now accepts `ledgr_diagnostic_corrupt` as detection
  (`tests/testthat/test-ws4a-carrier.R:3115`).
- **Frozen provenance oracle.** The tier_1-to-tier_2 override in
  `tests/testthat/test-availability-fold-witnesses.R:162-176` is justified
  only by an inline comment, not in the ticket evidence (AGENTS.md test rule).
- **Ticket status.** LDG-3206..3208 are still `status: pending` with
  `evidence: []`.

Smallest fix: add the three LDG-3208 witnesses and a vignette/man/contract
exact-name detector. Then record every migrated or retired test with its reason
in `tickets.yml`.

### F6. Low: stale continuation teaching and dead resume residue

Stale teaching:

- `R/walk-forward.R:58` (`man/ledgr_walk_forward.Rd:89`): "resumes a test run
  that an interruption left unfinished".
- `R/strategy-preflight.R:59` (`man/ledgr_strategy_preflight.Rd:78`): "resume
  or parallel equivalence".
- `vignettes/strategy-development.qmd:320`: "axis and resume rules".
- `inst/design/contracts.md:1691-1695`: "preserves committed ledger and
  strategy-state evidence. Resuming the same run identity ...".
- The comment at `R/walk-forward.R:1156`.

Dead residue:

- `R/fold-engine.R:1770-1779` has a dead `start_idx > 1L` branch. The
  `frozen_at_resume` and `last_executed_at_resume` names survive with
  `last_executed_at_resume = NULL`.
- `raw_sizing_notice_written` (`R/backtest-runner.R:818`) is always FALSE after
  a restart, but it still runs a full decode with validation.

Fix: reword or delete these, and let the F5 detector pin the wording.

### F7. Low/Medium: summary and listing reads re-validate the full logical trace

`ledgr_diagnostic_flag_counts()` and `ledgr_run_sizing_summary()` call
`ledgr_diagnostic_require_coverage()` before reading the hashed summary row.
That runs a full-run `COUNT`/`DISTINCT` over the union plus a full association
join against `snapshot_bars` and `ledger_events`. `ledgr_run_list()` does this
twice for every run in the store: once via `completion_info_many`, once via
`flags_many`. Point explanations also run the full-run `COUNT`. Nothing is
expanded in R, so the filtered-read contract technically holds. But every
summary read costs time proportional to the whole store, which undercuts the
compact summary. LDG-3209's decode and summary costs will show this.

Maintainer choice: either keep the per-read revalidation and accept its cost,
or anchor validation at write time plus the `summary_hash` and scope read-time
checks to the decoded window.

### F8. Low: an unused implicit buffer is allocated on every fold, sweeps included

`R/availability-diagnostic-writer.R:93` allocates 65,536 rows x 16 columns
unconditionally, even when `can_encode` is FALSE (memory-sink sweep
candidates). Line 189 allocates it again on `release()`. `append_implicit`
(line 145) duplicates `append_block`'s chunk loop. This is the
"duplicated buffers" shape, and it affects the H1 peak-memory gate.

Fix: allocate lazily, only when `can_encode` is TRUE, and drop it on release
without reallocating.

### F9. Low: sequence permutations within a pulse are not refused

Two mutations decode silently in a different order:

- Swap `decision_seq` between two implicit holds of one pulse.
- Swap `execution_seq` between two implicit fills of one pulse.

Coverage stays contiguous and per-row association still holds, so neither
check fires. Physical rows have the same gap already. Maintainer choice: is
within-pulse order part of the "corrupt association" family? If so, add a
cheap window check that `diagnostic_seq` order agrees with run-axis order
within each `(run, ts, stage)`.

### F10. Low: on a split store, closed-handle reads now refuse

The decoder's association check needs the sealed `snapshot_bars` to be
visible. Two paths open a fresh temporary connection with no snapshot attach:

- `summary.ledgr_backtest()` attaches on one temporary connection
  (`R/backtest-results.R:840`), then reads through another
  (`ledgr_run_sizing_summary(object)`, line 861).
- `ledgr_backtest_terminal_evidence(bt)` with no `con`.

When the handle is closed, the association check then compares against the run
store's empty `snapshot_bars` and refuses. Only the internal `ledgr_config()`
path produces split stores, hence Low. Fix: attach the snapshot inside the
decoder's read-connection path, or pass one prepared connection through.

## Per-ticket acceptance

| Ticket | Assessment |
| --- | --- |
| LDG-3206 | **Not met.** The source and schema census for retired seams is clean in `R/`. The restart order is correct: identity, then snapshot, then terminal evidence, then one atomic delete-and-repost transaction. DONE and INCOMPLETE return early. Recovery invokes no strategy. A real interrupt rolls back and records FAILED. `checkpoint_every` only controls flushing. Blocking items: F1 (preflight test, LTB-0550), F3 (boundary seed), and the docs part of F5/F6. Configuration-hash equality with LDG-3200 could not be executed. |
| LDG-3207 | **Not met.** There is one decoder, and the consumers listed in the census route through it. The fills reader no longer reads diagnostics. Reads write nothing and call no user code. Ambiguous or missing sessions give NA. Blocking items: F2 (orphan listing) and F4 (fills loop). F7 and F10 are advisory. |
| LDG-3208 | **Not met.** Certification happens on typed P3 segments before expansion. Fills and holds are exact or explicit. Risk, stale, restriction, rejection, sizing, scheduled skip, stop and error rows stay physical. Coverage and association refuse missing, duplicated or corrupted pairs. The codec binding is fingerprint-only. Blocking items: F1 (LTB-0259, LTB-0518) and F5 (counters, no-lookahead witness, docs detector). F8 and F9 are minor. |
| LDG-3209 | **OPEN, and not ready.** The private rebuild, aggregates, milestone clocks and H1 gate are intentionally unrun. Public readiness is blocked by four items. First, the A0 harness: `a0_run_keys` (`dev/bench/v0_2_3_output_freeze/lib.R:215-221`) lists `strategy_state` and not the three new tables, and `a0_store_tables` "fails loudly" on unknown tables. Its `avail_terminal_resume` fixture (`fixtures.R:121-123`) still uses the now-ignored `ledgr.interrupt` option, and it records the physical `run_diagnostics` table instead of the logical trace. Second, `source_census.csv` is stale (F1). Third, no witness shows a schema-125 store carrying the WS24-close fingerprint refusing with `fingerprint_mismatch`. Fourth, the full suite is red. |

## Commands, mutations and clean areas

**Run:** `git log`, `git diff --stat`, `git show --stat`, and `git diff` over
`622ff3a4..aadd2fc3` for R, tests, contracts, NEWS and design. Source reads and
searches covered the codec, decoder, writer, fold P2/P3/E, runner, restart,
exit guard, output handler, store gate, results, valuation, sizing, run store,
walk-forward, tests, claims, contracts, man, vignettes and the A0/census
harnesses.

**Not run:** focused tests, the full suite, R CMD check and executable
mutations. Rscript and PowerShell were denied.

**Mutations evaluated by reading:**

| Mutation | Result |
| --- | --- |
| Restore `strategy_state`, `ledgr.interrupt` or `ledgr_run_resume` in R | Detected by LTB-0555 |
| Clear output before terminal validation | Ordering correct; INCOMPLETE corruption covered by LTB-0202 |
| Delete or duplicate a pair, mutate target or price | Detected (LTB-0554, split-store test) |
| Mutate the event or bar anchor | Caught by the association join (no registered test for the event side) |
| Swap seq within a pulse | **Not detected** (F9) |
| Implicit risk, sizing or skip | Structurally excluded |
| Next-bar exposure in P2 | Structurally impossible; **no witness** (F5) |
| Omit the codec binding | Would be caught by LTB-0259 once F1 updates it |

**Clean areas:**

- Restart transaction scope: it deletes exactly the derived tables and keeps
  `runs`, provenance, tags and promotion context.
- Interrupt and exception sequencing:
  - an interrupt during the fold rolls back, then gets coverage 0 and a summary;
  - an exception row gets its position from coverage.
- Terminal recovery bypasses the fold.
- UNION column order and types match `run_diagnostics`.
- Clean-fill and clean-hold predicates:
  - exact equality, NA treated as not clean;
  - rejected and sub-tolerance rows stay explicit.
- Implicit fill `event_seq` uses the same formula as the explicit fill row.
- Decision and risk segments are staged at P3 in the same emission order
  (intent, sizing, decision, risk, rejection, fill).
- Sweep and memory sinks (`can_encode` FALSE) keep the old numbering and
  retention.
- No migration, compatibility reader, second decoder or second execution path.
- Schema stays 125, and the codec version is not in run identity.

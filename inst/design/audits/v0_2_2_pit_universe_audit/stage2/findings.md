# Point-in-time universe audit, Stage 2: findings

**Status:** Stage 2 analyst output, 2026-10-10, for the challenger and then
Gate 2. Judges ledgr against itself (charter, Stage 2 checks a to g). No
finding has been challenged yet.
**Frozen commit:** 289d57c (worktree `C:/tmp/ws22-b`). Code is cited as
`R/file.R:function (lines)` at that commit. Contract headings are the `##`
headings of `inst/design/contracts.md` (no drift between 289d57c and the
current branch for `contracts.md`, `R/` or `tests/`).
**Probes:** `dev/audit/pit_universe/probes/S2_*.R` (new), plus re-runs of the
Stage 1 probes `I_paths.R`, `I_walk_forward.R`, `A_calendar_window.R` and
`B_helper_ties.R`. Every probe ran through `run_low.sh` at idle priority, each
under 20 seconds; quoted output is verbatim from those runs.
**Registers checked:** ledgr-research `docs/governance/ledgr-feedback.md`
(LFB-001 to LFB-028, read only), `inst/design/horizon.md`,
`inst/design/rfc/rfc_history_wave_v0_2_2_decisions.md`, `decisions.md`.

Classes: code defect, wrong contract, untested behavior, design question.
Severity: high (wrong results, unrecoverable runs, silent data loss), medium
(wrong but detectable, or inconsistent paths), low (wording, disclosure).

## Summary

| ID | Class | Sev | Claim | Rules | Check | Probe | Register |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S2-001 | code defect | high | A resumed run recounts dividend entitlement differently from the fresh run and the sweep, so an interruption changes cash (both posting choices) | PIT-10-007, PIT-10-008, PIT-10-021 | a, g | S2_entitlement | none |
| S2-002 | code defect | high | An invocation that values no pulse falls through to dense replay: NA equity over every pulse, run cannot be opened or rerun; a resume whose first pulse stops erases the valued prefix | PIT-11-003, PIT-12-011, PIT-13-013 | a, e | S2_stops O, R; I_walk_forward W4 | none |
| S2-003 | code defect | high | Sealed corporate-action rows with an unknown subtype or no knowledge time never act on a held position; strict passes and the summary reports fidelity `none`, 0 unsupported | PIT-10-001, PIT-10-006, PIT-01-018 | c, e, g | S2_ca_inert D1, D2 | LFB-014; LFB-013; history wave C (D1-F7) |
| S2-004 | code defect | high | `ledgr_backtest()` runs a dense fold on a point-in-time snapshot, trading a nonmember eight sessions before it joins | PIT-03-002 | a, d | S2_ca_inert B1; I_paths P13 | none |
| S2-005 | code defect | medium | A session calendar shorter than the bars silently truncates the run, which reports DONE with complete performance over a "requested" window taken from the calendar | PIT-04-008 | c, e | S2_calendar_short K1, K2 | none |
| S2-006 | design question | medium | Promotion verifies only the snapshot hash: another strategy, universe, valuation, corporate-action policy or opening promotes silently and gets promotion context | PIT-13-007 | a, f | S2_promote_config | none |
| S2-007 | design question | medium | `carry_test_state` boundaries are not state-continuous: last decision dropped, a `next_open` dividend lost, carried holdings lose mark history | PIT-04-007, PIT-09-005, PIT-10-003, PIT-13-011 | a, b | S2_wf_dividend; I_walk_forward W1, W4; S2_stops O | horizon 2026-10-08 (resolved, overlap only) |
| S2-008 | code defect | medium | An INCOMPLETE run keeps a fill after its achieved end; reconstruction then fails the cash identity the Result Contract promises to meet | PIT-11-011, PIT-11-012, PIT-11-013 | a, g | S2_stops P | related LFB-019 |
| S2-009 | design question | medium | A strict-preset cash refusal aborts FAILED and rolls back all evidence; a terminal refusal stops INCOMPLETE with its prefix | PIT-10-010 | e | S2_nonpositive N2 | none |
| S2-010 | design question | medium | A sealed zero close becomes a permissible current mark (`priced`, `tradable`, equity drops) while sizing treats it as unpriced and dense `tradable` excludes it | PIT-01-009 | c, d | S2_nonpositive N1 | none |
| S2-011 | design question | medium | Fact Dates and date-only windows are UTC days, not venue days: one Date fact blocks an open fill in New York but not in Sydney; Honolulu windows shift one session | PIT-01-019, PIT-04-012 | b, c | S2_venue | none |
| S2-012 | design question | medium | `ledgr_pulse_snapshot()` is dense on a point-in-time snapshot: BBB is member and admissible at s5, before it is knowable | PIT-05-009 | a, b, d | I_paths P12 | LFB-006, LFB-022 (partial) |
| S2-013 | code defect | medium | `ledgr_select_top_n()` breaks ties in the session collation locale, so selection differs between C and English locales | PIT-07-016 | a, g | B_helper_ties | none |
| S2-014 | design question | low | `ledgr_compute_metrics()` reports annualized metrics for an INCOMPLETE run that `summary()` withholds | PIT-12-007 | a, e | S2_stops P | none |
| S2-015 | code defect | low | `ledgr_run()` records an opening date earlier than the sealed start as the config start, against the Scoring start rule; config hashes differ for identical runs | PIT-04-011 | f, g | S2_calendar_short K3; I_paths P10 | none |
| S2-016 | code defect | low | `config_hash` binds the store-local `snapshot_id` | PIT-14-006 | f | A_calendar_window C6 | none |
| S2-017 | wrong contract | low | `ctx$vec$risk_mark` and `mark_source` are exposed but absent from the bound-field lists | PIT-05-003 | g | citation only | none |
| S2-018 | untested behavior | low | Partial trading-status coverage turns every uncovered instrument-time into `status_unknown`; no contract sentence or test pins it | PIT-03-015 | c, g | I_paths P7 (Stage 1) | history wave D1-F5 |

Counts: code defect 9 (4 high, 3 medium, 2 low); design question 7
(6 medium, 1 low); wrong contract 1 (low); untested behavior 1 (low).

## Carried open items from Gate 1

| Item | Result |
| --- | --- |
| Parallel sweep with corporate actions | Cleared. `S2_parallel_ca.R`: four candidates (dividend, dispositions, lifetime terminals, ex-date buyer and seller) under `effective_close` and `next_open`; `workers = 1` and `workers = 2` give identical `status`, `final_equity`, `total_return`, `n_trades`, `stop_reason` and `completion_json` for every row. Harness note: the probe replaces the worker load expression in its own process with one passing `compile = FALSE` (the product default would rebuild the frozen tree's DLL); no product file changed. |
| `next_open` posting with resume | Confirmed divergent: S2-001 (interrupts at s13 and s14 both diverge). |
| Promotion from a differently configured experiment | Confirmed: S2-006. |
| Valuation when the calendar is shorter than the bars | Confirmed: S2-005. Holdings are valued only through the last declared session; later bars are never read; the run is DONE and complete. |
| Non-Americas venue (UTC date against venue date) | Confirmed as a design question: S2-011. Window and sealed-date checks behave for Sydney (its close is on the same UTC date); fact Dates do not. |
| Facts reopen path in `ledgr_snapshot_open()` | Cleared. `S2_reopen.R`: after close and reopen (`verify = TRUE` and `FALSE`), data identity, availability activation, experiment plan, `ledgr_facts_history()` rows, `config_hash`, equity, ledger and diagnostics are identical to the original handle's run. Only the handle's `metadata` list differs, in field order (same names, no differing values). |

## S2-001 Resume recounts dividend entitlement (code defect, high)

**Claim.** For a dividend whose entitlement session has a fill at its open,
the fresh run and the sweep bind one entitled quantity and a resumed run binds
another, so cash and equity depend on whether the run was interrupted.

**Evidence.** Fresh fold: `R/fold-engine.R:ledgr_execute_fold (1103-1108)`
binds entitlements of pulse `i + 1` from positions before pulse `i`'s fills,
which execute at the open of `i + 1`; the plan-level test LTB-0035
(`test-corporate-action-cash.R:57`) pins exactly this (buyer bound 0, seller
keeps). Resume: `R/corporate-action-settlement.R:ledgr_corporate_action_plan
(263-277)` rebinds entitlements at or before the restart pulse through
`ledgr_corporate_action_past_quantities (58-102)`, which counts ordinary events
stamped strictly before `entitlement_time`, so it includes the fill at the
entitlement session's open. `ledgr_corporate_action_composition_report
(R/corporate-action-results.R, 203-214)` uses the same recount (read only).
`S2_entitlement.R` (HHH, entitlement s14 close, $1):

```
[effective_close BUY] fresh: no HHH CASHFLOW; final equity 99990.00
[effective_close BUY] interrupted at s13 (status RUNNING) then resumed: CASHFLOW at 2021-03-18T20:00:00Z entitled_quantity=10 cash=10; final equity 1e+05
[effective_close BUY] sweep final equity 99990.00
[effective_close SELL] fresh: CASHFLOW at 2021-03-18T20:00:00Z entitled_quantity=10 cash=10; final equity 100010.00
[effective_close SELL] interrupted at s13 (status RUNNING) then resumed: no HHH CASHFLOW; final equity 1e+05
[next_open BUY] interrupted at s14 (status RUNNING) then resumed: CASHFLOW at 2021-03-19T20:00:00Z entitled_quantity=10 cash=10; final equity 1e+05
[next_open SELL] interrupted at s14 (status RUNNING) then resumed: no HHH CASHFLOW; final equity 1e+05
```

**Why inconsistent.** Persistence Contract: "Memory, durable reopen and an
interrupted resume therefore agree on events, equity, diagnostics and summary
fields." The equity-settlement synthesis (3.4, rule 2) fixes the entitled
quantity "immediately before the ex-dividend boundary";
`vignettes/corporate-action-cash.qmd` calls `entitlement_time` that boundary,
and the synthesis says "a buyer on the ex-date does not receive one", which is
the fresh rule. The resume recount is the deviating path.

**Falsify.** Show a resumed run that matches its fresh run in the BUY or SELL
case, or a contract sentence that makes resume entitlement differ by design.
One-line fix direction: count only events strictly before the entitlement
session's open (the fresh boundary) in the recount.

## S2-002 A run that values no pulse is finalized as a dense run (code defect, high)

**Claim.** When an availability-aware invocation records no equity fact
(stop on its first pulse), finalization replays the ledger densely over every
calendar pulse, deletes any stored prefix and stores NA equity. The run can
then be neither opened nor rerun. A resumed run whose first resumed pulse
stops loses the prefix its first invocation valued.

**Evidence.** `R/run-finalize.R:ledgr_run_finalize (456-457)` sets
`use_fold_equity <- length(fold_equity) > 0L`; otherwise it takes the replay
branch (526-537) and `DELETE FROM equity_curve WHERE run_id = ?` then appends
the replay (592-599). The fold's equity facts cover only the current
invocation (`R/fold-engine.R:ledgr_execute_fold`, 366, 732). `S2_stops.R`:

```
[O] stored: status INCOMPLETE; completion INCOMPLETE achieved_end NA last_executed NA stop valuation_horizon_exhausted; equity rows 27 (NA 27) first..last 2021-03-18T20:00:00Z..2021-04-27T20:00:00Z
[O] ledgr_run_open: ledgr_run_terminal_evidence_invalid - Finalized terminal evidence does not contain its exact achieved equity prefix.
[O] rerun same run_id: ledgr_run_terminal_evidence_invalid - ...
[P] stored: status INCOMPLETE; completion INCOMPLETE achieved_end 2021-03-17T20:00:00Z ... equity rows 13 (NA 0)
[R] stored: status INCOMPLETE; completion INCOMPLETE achieved_end NA last_executed NA stop valuation_horizon_exhausted; equity rows 40 (NA 40) first..last 2021-03-01T21:00:00Z..2021-04-27T20:00:00Z
[R] equity rows identical to fresh P: FALSE
[R] ledgr_run_open: ledgr_run_terminal_evidence_invalid - ...
```

R is P interrupted at the s13 decision and resumed: P (fresh) keeps 13 valued
rows and achieved end s13; R reports no valued pulse at all. Walk-forward
(re-run of `I_walk_forward.R` W4): `[W4 gapbar] fold 3 test run ...: open
ERROR ledgr_run_terminal_evidence_invalid` and `[W4 rerun] ERROR
ledgr_run_terminal_evidence_invalid`, so the session cannot be rerun.

**Why inconsistent.** Persistence Contract: stops "finalize as `INCOMPLETE`,
preserving only accepted prefix economics"; `ledgr_run_open()` returns a
handle for availability-aware `INCOMPLETE` runs; repeating an `INCOMPLETE` run
ID "validates the exact stored equity timestamp prefix". Execution Contract,
Test-run resume: a rerun session opens an `INCOMPLETE` test run "as
recorded". The fresh P and resumed R of one run disagree (check a).

**Falsify.** A first-pulse stop that stores zero equity rows and reopens, or a
resumed R whose stored prefix equals P's. Fix direction: take the prefix
branch for every availability run, with an empty current frame.

## S2-003 Inert corporate-action rows are invisible to policy and summary (code defect, high)

**Claim.** A complete, sealed corporate-action row on a held instrument with
an unrecognized subtype (`cash_dividend`) or with no `knowledge_time` never
posts, disposes or refuses; the strict preset, which refuses the supported
version of the same dividend, completes DONE; the summary says the facts did
not affect held instruments.

**Evidence.** Ingest accepts any lower-snake-case subtype
(`R/availability-facts.R:ledgr_validate_equity_corporate_action_rows, 401-405`);
the plan acts only on five subtypes (`R/corporate-action-settlement.R:
ledgr_corporate_action_plan, 148-166`); an NA knowledge time gives an NA due
pulse (`ledgr_corporate_action_knowledge_index, 123-132`; plan 178-192);
fidelity becomes `none` when nothing posted (`R/corporate-action-results.R:
ledgr_corporate_action_summary, 434-445`; print text at 476 "NONE - supplied
facts did not affect held instruments"). `S2_ca_inert.R` (10 HHH held from s1):

```
[D0_control research] validate CA outcome accepted; status DONE; HHH CASHFLOW rows 1; summary: corporate_action_fidelity=modeled ... gross_cash_posted=10 ... unsupported_facts=0
[D0_control strict] run ERROR ledgr_corporate_action_unsupported - Corporate-action cash settlement is refused by the selected policy.
[D1_cash_dividend strict] validate CA outcome accepted; status DONE; HHH CASHFLOW rows 0; summary: corporate_action_fidelity=none ... affected_marked_exposure=0 gross_cash_posted=0 ... unsupported_facts=0
[D2_no_knowledge strict] validate CA outcome audit_only; status DONE; HHH CASHFLOW rows 0; summary: corporate_action_fidelity=none ... unsupported_facts=0
```

(Research-preset lines for D1 and D2 are the same as strict.)

**Why inconsistent.** Config Contract: the strict preset "refuses every
corporate-action settlement choice"; here strict refuses the supported row and
silently accepts the unsupported ones (check e).
`vignettes/corporate-action-adapter-authoring.qmd:58` says every row needs "a
closed `subtype`", but ingest keeps it open (check c). Row provenance records
`knowledge = evidenced` for the D2 row (PIT-01-018). The summary misreports a
held exposure as unaffected (check g).

**Register.** LFB-014 (held incomplete corporate-action facts are ignored and
misreported) is the same failure class for `complete = FALSE`; this finding
extends it to complete rows with an unknown subtype or no knowledge time.
LFB-013 and history-wave decision C (D1-F7, "known-when-effective, disclosed")
cover the missing knowledge mode and are accepted, not implemented.

**Falsify.** A run where D1 or D2 under strict refuses or stops, or a summary
field that counts them. Fix direction: refuse unknown subtypes at ingest and
count held never-due rows as unsupported.

## S2-004 `ledgr_backtest()` ignores declared facts (code defect, high)

**Claim.** On a snapshot that declares sessions, membership, status and
lifetime facts, `ledgr_backtest()` builds a config without the availability
block and runs a dense fold: every universe ID is a member at every pulse and
fills are stamped at bar time.

**Evidence.** `R/backtest.R:ledgr_backtest (241-262)` calls `ledgr_config()`
with no `availability`, `universe_rule` or `valuation_policy`;
`ledgr_run_experiment (462-497)` passes all three. Its roxygen (R/backtest.R,
40-41) calls it "a compatibility wrapper around the same canonical runner
path". `S2_ca_inert.R` B1 (full fixture; BBB joins at s10):

```
[B1] BBB fills: ledgr_run 2021-03-15T13:30:00Z .. 2021-03-15T13:30:00Z 1 fills | ledgr_backtest 2021-03-02T21:00:00Z .. 2021-03-02T21:00:00Z 1 fills
[B1] ledgr_backtest availability active: FALSE; diagnostics rows 0
```

Re-run of `I_paths.R` P13: `status DONE; availability active in config:
FALSE; pulses 40; first fill ts 2021-03-02T21:00:00Z; NNN member at every
pulse: TRUE`.

**Why inconsistent.** Availability Contract: activation follows declared
facts, "There is no mode flag". Execution Contract: "Public convenience APIs
must build canonical config and delegate to the existing runner; they must not
implement alternate pulse, fill ... semantics." The same snapshot gives a
survivorship-free run through `ledgr_run()` and a survivorship-biased one
through `ledgr_backtest()`, silently.

**Falsify.** A contract sentence scoping `ledgr_backtest()` to dense
semantics, or a refusal on an availability snapshot. Fix direction: refuse
availability-aware snapshots in `ledgr_backtest()`, or route them through the
experiment path.

## S2-005 A short session calendar truncates the run as complete (code defect, medium)

**Claim.** Nothing checks that the calendar covers the requested run range.
The run stops at the last declared session (or starts at the first), reports
DONE and `complete_performance = TRUE`, and its completion "requested" window
is taken from the calendar, not from the stored config window.

**Evidence.** `R/availability-policy.R:ledgr_availability_validate_experiment
(204-208)` only requires that a sessions family exists;
`R/availability-provider.R:ledgr_availability_calendar (311-317)` filters
declared sessions to the window. `S2_calendar_short.R` (bars s1..s40):

```
[K1_cal_to_s30] ... status DONE; completion DONE complete_performance TRUE; requested 2021-03-01T21:00:00Z..2021-04-13T17:00:00Z; achieved 2021-03-01T21:00:00Z..2021-04-13T17:00:00Z
[K1_cal_to_s30] config window 2021-03-01T21:00:00Z..2021-04-27T20:00:00Z; equity rows 30 ...
[K1_cal_to_s30] sweep status DONE final equity 10040.00; scoring_range 2021-03-01T21:00:00Z..2021-04-13T17:00:00Z
[K2_cal_from_s10] ... requested 2021-03-12T21:00:00Z..2021-04-27T20:00:00Z; ... config window 2021-03-01T21:00:00Z..2021-04-27T20:00:00Z; equity rows 31
```

**Why inconsistent.** Availability Contract: "Every availability-aware
experiment requires a complete declared session calendar". The asset
availability synthesis (s4.1, lines 142-149): "The session calendar must
establish complete coverage over the requested run range ... incomplete range
coverage ... fails `ledgr_sessions_incomplete`." The run's own config window
(s1..s40) and completion window (s1..s30) disagree while completion claims
completeness.

**Falsify.** A refusal or an INCOMPLETE completion for K1. Fix direction:
refuse when declared coverage does not span the requested range.

## S2-006 Promotion does not bind the candidate's configuration (design question, medium)

**Claim.** `ledgr_promote()` checks only the snapshot hash. A candidate from
experiment A promotes into an experiment with another strategy function,
universe rule, valuation policy, corporate-action policy or opening, with no
warning, and the run is stored with promotion context naming the candidate.

**Evidence.** `R/sweep.R:ledgr_promote (649-710)` validates status and
`ledgr_candidate_validate_same_snapshot (976-1001)`, replaces only cost and
risk, then calls `ledgr_run()` with the promoting experiment. Candidate
provenance carries `strategy_hash` and `feature_set_hash`; neither is checked.
`S2_promote_config.R` (candidate final equity 99923.00):

```
[same] promoted: status DONE final equity 99923.00 (candidate 99923.00); equal: TRUE
[basket_universe] promoted: status DONE final equity 99980.00 (candidate 99923.00); equal: FALSE
[stale0_refuse] promoted: status INCOMPLETE final equity 1e+05 (candidate 99923.00); equal: FALSE
[strict_ca] promoted: status INCOMPLETE final equity 1e+05 (candidate 99923.00); equal: FALSE
[cash_5e4] promoted: status DONE final equity 49923.00 (candidate 99923.00); equal: FALSE
[other_strategy] promoted: status DONE final equity 99846.00 (candidate 99923.00); equal: FALSE
[context] promotion context rows: promote_basket_universe,promote_cash_5e4,promote_other_strategy,promote_same,promote_stale0_refuse,promote_strict_ca
```

**Why inconsistent.** Sweep Promotion Contract: sweep rows carry "enough
compact candidate identity for deliberate promotion" and promotion "must
preserve the selected candidate's risk identity"; cost and risk are bound,
the strategy, universe, valuation and corporate-action policy are not, though
each changes the result. Promotion context is written for runs that ended
INCOMPLETE from a DONE candidate ("written only after the committed run
succeeds"). Owner of what promotion owes is `unclear` in Stage 1.

**Falsify.** A refusal for any non-`same` variant. Decision needed: which
experiment inputs promotion must match or record.

## S2-007 Carry-chain boundaries are not state-continuous (design question, medium)

**Claim.** Under `carry_test_state`, concatenated test runs differ from one
continuous run at every boundary in three ways: (i) each window's last
decision is dropped; (ii) a dividend with `next_open` posting whose
entitlement is a window's last pulse never posts; (iii) carried holdings have
no mark history, so one without a bar on the next window's first pulse stops
the test run at once.

**Evidence.** (i) `R/availability-facts.R:ledgr_session_execution_opportunities`
and `R/availability-economics.R:ledgr_fold_build_availability_pulse_plan
(424-427)`; re-run `I_walk_forward.R` W1: `final_pulse_no_execution 10` in each
test run. (ii) `R/corporate-action-settlement.R:ledgr_corporate_action_clock_index
(104-121)` maps an entitlement before the window to NA; posting index is
entitlement + 1 (182-186). `S2_wf_dividend.R`:

```
[next_open] fold 1 test 2021-03-08T21:00:00Z..2021-03-18T20:00:00Z opening none; HHH CASHFLOW none; ...
[next_open] fold 2 test 2021-03-19T20:00:00Z..2021-03-26T20:00:00Z opening HHH=20; HHH CASHFLOW none; first/last equity 99980.00 / 99980.00
[next_open] reference single run HHH CASHFLOW 2021-03-19T20:00:00Z
[effective_close] fold 1 test ... HHH CASHFLOW 2021-03-18T20:00:00Z; first/last equity 1e+05 / 100020.00
```

(iii) `R/backtest-runner.R:ledgr_run_fold_impl (976-1023)` and
`R/availability-economics.R:ledgr_availability_valuation_state (43-44)` start
mark history at the window's first pulse; W4: fold 3 opens with CCC carried
(last close s18) and stops `terminal_mark_unavailable` on its first pulse,
where a continuous run disposes CCC at its stale mark (I_paths P1: five
dispositions, DONE). `S2_stops.R` O shows the same for a dated opening.

**Why inconsistent.** Execution Contract, Contiguous carry, refuses gaps
because a pulse "would be carried across unvalued", i.e. it intends the chain
to be continuous; the Availability Contract values holdings at
"policy-permitted stale closes" which exist in the snapshot. Against that: the
Availability Contract says the terminal decision has no execution
opportunity, and the Execution Contract, Feature start, says no entry point
reads a bar before its scoring start (temporary, Cut 9). The rules are each
stated; their combination silently loses cash (ii) and makes walk-forward
stop (iii).

**Register.** horizon 2026-10-08 "Carried state over overlapping walk-forward
test windows" (resolved by Contiguous carry) covers overlap, not these.
History-wave decision A ("history reaches back to the start of the data")
addresses strategy reads, not marks or entitlements.

**Falsify.** A carry chain whose concatenated cash equals the continuous run
in (ii), or a carried holding that keeps a stale mark in (iii).

## S2-008 Fills after the achieved end break reconstruction (code defect, medium)

**Claim.** A valuation stop at pulse k keeps the fill decided at k-1 and
executed at k's open. That fill is in the ledger and the fills reader but in
no equity row, and `ledgr_state_reconstruct()` fails the cash identity.

**Evidence.** `R/fold-engine.R:ledgr_execute_fold` stops before the equity row
(655-662) after the previous pulse's fills were applied;
`R/derived-state.R:ledgr_rebuild_derived_state (187-191)` compares the last
rebuilt cash (at the achieved end) with all ledger cash deltas. `S2_stops.R` P:

```
[P] stored: status INCOMPLETE; completion INCOMPLETE achieved_end 2021-03-17T20:00:00Z last_executed 2021-03-18T13:30:00Z stop valuation_horizon_exhausted; equity rows 13 (NA 0) ...
[P] ledger: 2021-03-17T13:30:00Z FILL FFF 10 | 2021-03-18T13:30:00Z FILL AAA 10
[P] last equity row cash 99800 positions_value 200 ; ledger cash after all events 99400
[P] fills reader rows: 2 instruments FFF,AAA
[P] ledgr_state_reconstruct: ledgr_invariant_violation - Cash identity violated: cash != initial_cash + sum(cash_delta).
```

**Why inconsistent.** Result Contract (`ledgr_state_reconstruct()`): an
availability-aware run "is rebuilt on its open-session calendar through its
last fully valued pulse ... The rebuilt equity equals the stored equity
exactly." Readers disagree on the run's final state (fills include AAA,
equity excludes it; check a).

**Register.** LFB-019 (reconstruction fails on availability stores) is still
`open` in the register although LDG-2978 implemented availability
reconstruction (contracts.md, Result Contract); this is a different trigger.

**Falsify.** Reconstruct succeeding on P. Fix direction: check the identity
against events up to the achieved end, and decide whether post-prefix fills
belong to the INCOMPLETE run's evidence.

## S2-009 Two refusal kinds for declared policy refusals (design question, medium)

**Claim.** A corporate-action cash or quantity refusal declared by policy
(strict preset) aborts the fold: the run ends FAILED and its whole invocation
rolls back. A declared terminal refusal stops typed: INCOMPLETE with a
completion row and the accepted prefix.

**Evidence.** `R/corporate-action-settlement.R:ledgr_corporate_action_plan`
calls `rlang::abort` in `check_quantity_effects` (309) and `post_cash` (337);
terminal refusals go through `stop_valuation` (`R/fold-engine.R`, 594).
`S2_nonpositive.R` N2:

```
[N2 strict_dividend] call: ERROR ledgr_corporate_action_unsupported; runs.status FAILED; completion none; equity rows 0; ledger rows 0; diagnostics rows 1
[N2 terminal_refuse] call: returned; runs.status INCOMPLETE; completion INCOMPLETE terminal_settlement_unsupported 2021-03-24T20:00:00Z; equity rows 18; ledger rows 1; diagnostics rows 235
```

**Why inconsistent.** Persistence Contract separates expected stops (finalize
INCOMPLETE, keep the prefix) from "Unexpected fold exceptions" (FAILED, roll
back). A refusal the user declared is expected. The reason-token table has
no corporate-action refusal token. The equity-settlement synthesis (3.4) says
strict mode "stops".

**Falsify.** A contract sentence classing corporate-action refusals as fold
exceptions. Decision needed: typed stop or documented failure.

## S2-010 A non-positive close is a valid mark (design question, medium)

**Claim.** Ingest seals zero and negative prices (PIT-01-009). At runtime a
zero close becomes a permissible current mark: `priced` and `tradable()` are
TRUE, the holding is valued at 0 for that pulse, while the rebalance helper
treats the same member as unpriced and the dense `tradable()` would exclude it.

**Evidence.** `R/availability-economics.R:ledgr_availability_valuation_state`
(84: `observed <- is.finite(current_close)`; 124: `priced = is.finite(mark)`);
fills reject `open <= 0` (437-440). `S2_nonpositive.R` N1 (HHH close 0 at s20):

```
[N1] seal: accepted (HHH s20 close 0)
[N1] equity s19..s21: 2021-03-25T20:00:00Z 490 1e+05 | 2021-03-26T20:00:00Z 0 99510 | 2021-03-31T20:00:00Z 490 1e+05
[N1] ctx at 2021-03-26T20:00:00Z : close 0 priced TRUE risk_mark 0 mark_source current_close tradable TRUE rebalance_target 10
```

**Why inconsistent.** Context Contract: dense `ctx$tradable()` returns "IDs
with a finite positive close"; availability returns `admissible & priced`.
Availability Contract, Unpriced members: sizing needs a "positive accepted
current close". Three planes, three definitions of priced (check d); ingest
offers no positivity guarantee the runtime could rely on (check c).

**Falsify.** A contract sentence that a zero close is a valid mark. Decision
needed: positivity at ingest, or non-positive closes treated as missing.

## S2-011 Fact Dates and date-only windows are UTC days (design question, medium)

**Claim.** A fact given as a Date means UTC midnight, and a date-only window
boundary means UTC midnight, whatever the venue. The same Date therefore
lands at different points of the venue's session day.

**Evidence.** `R/availability-facts.R:ledgr_fact_time (1172-1176)` converts a
Date with `tz = "UTC"`; `R/walk-forward-folds.R:ledgr_experiment_window (529)`
resolves date strings to UTC midnight. Bars given as Dates are mapped to the
session close instead (PIT-02-001). `S2_venue.R` (BBB `known_inactive` from
the Date of d6; buy decided at d5):

```
[America/New_York] BBB non-decision diagnostics: 2021-03-05T21:00:00Z execution no_fill lifetime_inactive
[Australia/Sydney] BBB events: 2021-03-07T23:00:00Z FILL | 2021-03-08T05:00:00Z DISPOSITION
[Pacific/Honolulu] window '2021-03-03'..'2021-03-08' -> 2021-03-03T00:00:00Z..2021-03-08T00:00:00Z; pulses 2021-03-03T02:00:00Z,2021-03-04T02:00:00Z,2021-03-05T02:00:00Z,2021-03-06T02:00:00Z
[America/New_York] window ... pulses 2021-03-03T21:00:00Z,2021-03-04T21:00:00Z,2021-03-05T21:00:00Z
```

In New York the d6-open fill is refused (the fact applies from the previous
evening); in Sydney the d6 open is 23:00 UTC on the previous date, so the
fill executes and the holding is disposed at the d6 close. In Honolulu the
window "2021-03-03" starts with the 2021-03-02 civil session (close 02:00 UTC
on 03-03). Sydney windows resolve correctly because its close is on the same
UTC date.

**Why inconsistent.** Snapshot Contract maps "daily vendor labels ...
explicitly to declared session closes" for bars; facts and windows have no
such rule (contract heading for PIT-01-019: none). Execution Contract,
Sealed-date boundaries, states UTC dates for the range check only.

**Falsify.** A contract rule giving Dates a venue-independent meaning that
these outcomes satisfy. Decision needed: venue civil dates (session open) or
explicit UTC instants only.

## S2-012 Pulse inspection is dense on a point-in-time snapshot (design question, medium)

**Claim.** `ledgr_pulse_snapshot()` builds a dense context from a
point-in-time snapshot: membership, restrictions and knowledge clocks are
ignored.

**Evidence.** `R/pulse-snapshot.R:ledgr_pulse_snapshot (44-180)`. Re-run of
`I_paths.R` P12: `availability_active FALSE; members AAA,BBB; admissible
TRUE,TRUE` at s5, where BBB joins at s10 and is announced after the s5 close;
`FFF at s14 (halted, no bar): ERROR ledgr_invalid_args`.

**Why inconsistent.** Strategy Contract, Decision Axis And Eligibility:
`ctx$vec$admissible` is the eligibility plane "in every context: availability
folds, dense folds, `ledgr_pulse_snapshot()` and interactive contexts". On the
same snapshot the inspection shows a membership the run could not know at s5
(check b for inspection).

**Register.** LFB-022 (pulse snapshots refuse a member without a bar) and
LFB-006 (no mutation-free decision-context preview) are partial matches;
history-wave X-F4 covers feature hydration in inspection only.

**Falsify.** A contract sentence scoping pulse inspection to dense semantics.

## S2-013 Top-n ties depend on the collation locale (code defect, medium)

**Claim.** `ledgr_select_top_n()` orders ties with `order(-values, ids)`,
which follows `LC_COLLATE`; the provider orders IDs by C-locale radix.

**Evidence.** `R/strategy-helpers.R:ledgr_select_top_n (204)`;
`R/availability-provider.R:ledgr_availability_stable_ids (9-12)`. Re-run of
`B_helper_ties.R`:

```
LC_COLLATE=C (set=TRUE): selected=B1,A4 | provider stable order=A4,B1,a3,b2
LC_COLLATE=English_United States.1252 (set=TRUE): selected=a3,A4 | provider stable order=A4,B1,a3,b2
```

**Why inconsistent.** Strategy Contract: the helper "breaks ties by instrument
ID" with "its stable tie policy"; Availability Contract orders IDs by
"C-locale stable ID". The same strategy selects differently on a Windows
English session and a C-locale CI runner.

**Falsify.** Equal selections under both locales. Fix direction: radix order.

## S2-014 Metrics for INCOMPLETE runs differ by reader (design question, low)

**Claim.** `ledgr_compute_metrics()` returns annualized return and volatility
for an INCOMPLETE run that `summary()` withholds.

**Evidence.** `R/backtest-results.R:ledgr_compute_metrics (473)` and
`ledgr_compute_metrics_internal (231-290)` read equity rows only. `S2_stops.R`
P: `compute_metrics: total_return=0 annualized_return=0 volatility=0 ...`;
`summary lines: ... Annualized Return: withheld (achieved window is shorter
than requested) ... Volatility (annual): withheld ...`.

**Why inconsistent.** Persistence Contract binds `summary()` to completion
evidence; Result Contract defines public metrics from equity rows only. Each
is stated; the two public answers for one run disagree.

**Falsify.** A contract sentence exempting `ledgr_compute_metrics()`.

## S2-015 `ledgr_run()` records an unclamped scoring start (code defect, low)

**Claim.** With an opening dated before the sealed start, `ledgr_run()` and
promotion store the opening date as `start_ts_utc`; completion, sweep and
precompute use the sealed start.

**Evidence.** `R/backtest.R:ledgr_run_experiment (452)` calls
`ledgr_experiment_scoring_start(exp)` without `snapshot_start`, so the clamp
in `R/precompute-features.R:ledgr_experiment_scoring_start (307-315)` is
skipped. `S2_calendar_short.R` K3: `config window
2021-02-01T00:00:00Z..2021-04-27T20:00:00Z`, `requested
2021-03-01T21:00:00Z..`, sweep `scoring_range 2021-03-01T21:00:00Z..`.
Re-run `I_paths.R` P10: `run cfg start 2021-02-01T00:00:00Z; config_hash
equal to P1: FALSE; equity identical to P1: TRUE`.

**Why inconsistent.** Execution Contract, Scoring start: the scoring start is
"the snapshot start when the opening is undated or dated earlier".

**Falsify.** A stored config start equal to the sealed start.

## S2-016 `config_hash` binds a store-local name (code defect, low)

**Claim.** Identical bars sealed under two snapshot IDs have equal
`snapshot_hash` and different run `config_hash`.

**Evidence.** `R/config-hash.R:config_hash_payload (5)` keeps
`data.snapshot_id`. Re-run `A_calendar_window.R` C6: `[C6 snapshot hashes
equal] TRUE`, `[C6 config hashes equal] FALSE`. Walk-forward `session_id`
binds `snapshot_hash` (`R/walk-forward-identity.R`, 193).

**Why inconsistent.** Execution Contract: `config_hash` identifies the logical
config "after removing store-local and run-local fields"; Snapshot Contract
calls snapshot IDs store-local.

**Falsify.** A contract sentence making `snapshot_id` part of logical identity.

## S2-017 Context bound-field lists omit two planes (wrong contract, low)

**Claim.** Availability contexts expose `ctx$vec$risk_mark` and
`ctx$vec$mark_source` (`R/pulse-context.R:ledgr_pulse_context_vec, 932-970`),
used by `ledgr_target_rebalance()` sizing; neither the Context Contract's
bound fields ("`id`, `open`, ... `feature`" plus eligibility planes) nor the
Availability Contract's plane list (`member`, `held`, ..., `mark_age`) names
them. They appear only in frozen-holding and unpriced-member prose.

**Falsify.** A bound-field list that includes both.

## S2-018 Partial status coverage default is unstated and untested (untested behavior, low)

**Claim.** Once a trading-status family holds any row, every instrument-time
without an applicable row is `status_unknown` and target-restricted.

**Evidence.** `R/availability-provider-prepared.R:
ledgr_availability_provider_build_prepared (173, 188-209, 243-250)`; Stage 1
`I_paths.R` P7 on the default fixture: only FFF filled, 404 `status_unknown`
decisions. The only located test pins the empty family
(`test-availability-provider-witnesses.R:117`). The reason table lists
`status_unknown` but no contract sentence states the default.

**Register.** History-wave D1-F5 ("default keys on `has_status`", pending).

**Falsify.** A test that pins partial coverage, or the contract sentence.

## Flagged Stage 1 rules judged consistent or intended

Rules in a finding above are not repeated. One line each.

- PIT-01-005, PIT-04-010, PIT-02-003: runtime exclusion of off-session bars is
  the synthesis rule (s4.4, "excluded from that cutoff's runtime input"); the
  missing retrospective visibility is a disclosure question for Stage 3.
- PIT-01-010: opposing membership or lifetime revisions refused; decided as
  single-clock intervals (history wave D5-F1, D5-F2 deferred; LFB-012).
- PIT-01-012: duplicate corporate-action `fact_id` refused is identity
  protection; the asymmetry with other families is cosmetic.
- PIT-01-014: a label on a non-inactive lifetime row is never consulted
  (terminal resolution reads `known_inactive` rows only).
- PIT-02-004: undeclared price basis runs but is disclosed as `undeclared` in
  the corporate-action summary; refusal only of a declared conflicting basis.
- PIT-02-007: opposite session-constructor defaults are recorded in hashed
  metadata and the plan; no runtime inconsistency.
- PIT-03-004: the inactive-snapshot message states a requirement (membership
  and session facts), which is true; it does not claim the activation rule.
- PIT-03-009: interval precedence over sets is unreachable through public
  constructors (one membership family per universe).
- PIT-03-010: runtime two-valued membership versus resolver `NA` is a
  disclosure difference; both treat no evidence as not a member.
- PIT-03-014: superseded status revival is history-wave D2-F3 (pending).
- PIT-03-017: both reason tokens are in the closed table; naming only.
- PIT-03-021: the five operations exist as the contract says; two are unused.
- PIT-04-002, PIT-04-006: the runtime ignores session knowledge times, which
  is safe because ingest refuses any session not knowable by its opening
  (closure by local midnight); check c holds.
- PIT-04-003: POSIXct session times not checked against their date; not
  probed, no inconsistency observed (low, Stage 3 if wanted).
- PIT-04-004: two venues refused at validation, consistent with one calendar.
- PIT-04-013: a date-only end kept as given matches Execution Contract,
  Sealed-date boundaries ("boundaries already inside the range are kept").
- PIT-06-003: OHLC completeness for close-only indicators is unobservable
  because ingest rejects non-finite OHLC.
- PIT-07-004: raw-target stop versus helper skip are both stated
  (`risk_mark_unavailable` token; Unpriced members).
- PIT-07-014: `short_qty = -1` refused under availability is the stated short
  guard; a wrapper default question only.
- PIT-08-002: execution-time restriction blocking exits is today's documented
  behavior, parked in horizon 2026-09-29 "Design homework: where intent meets
  the universe and the market".
- PIT-10-002: dense runs cannot reach a disposition (dense requires full bar
  coverage; corporate actions alone never activate); stated activation rule.
- PIT-10-005: `effective_close` posting at the entitlement clock is the
  synthesis rule (3.4 rule 1) and the vignette's wording; the fixture places
  entitlement one session before its ex-date (fixture mapping, map.md).
- PIT-10-012: scheduled acquisitions dispose at the permissible mark, as the
  Availability Contract states.
- PIT-10-019: dispositions are not fills (Execution Contract: "It is not a
  fill").
- PIT-11-006: the resume event cut at the close after the restart pulse keeps
  the restart pulse's predecessor fills and removes later events; no committed
  path leaves restart-pulse events (soft interrupts commit whole pulses).
  Latent only.
- PIT-11-011: reconstruction rewriting `equity_curve` is stated in the Result
  Contract; identical rows on DONE runs (I_paths P5).
- PIT-12-005: recording pulse derived two ways; not probed beyond Stage 1,
  no divergence observed. Not judged.

Not flagged by Stage 1 but examined: corporate-action knowledge index uses the
first pulse at or after `knowledge_time` (`ledgr_corporate_action_knowledge_index`,
123-132), so no lookahead; sweep equals run (I_paths P2) and resume equals
fresh without dividends at the boundary (P4); parallel sweep equals sequential
(carried item). No observation bears on Workstream 22's byte identity; no
stop condition was met.

# Point-in-time universe audit, Stage 2: challenge

**Status:** Stage 2 challenger output, 2026-10-10, against `stage2/findings.md`
(S2-001 to S2-018), for Gate 2. Adversarial: each material finding was
reproduced, then attacked against contract text, accepted designs, tests and
counter-probes.
**Frozen commit:** 289d57c (worktree `C:/tmp/ws22-b`), unchanged.
**Reproduction:** every analyst probe behind a finding (`S2_entitlement`,
`S2_stops`, `S2_ca_inert`, `S2_calendar_short`, `S2_promote_config`,
`S2_wf_dividend`, `S2_nonpositive`, `S2_venue`) and the Stage 1 probes it cites
(`I_paths`, `I_walk_forward`, `A_calendar_window`, `B_helper_ties`) were rerun
through `run_low.sh`; every quoted line reproduced verbatim. Not rerun:
`S2_parallel_ca`, `S2_reopen` (Gate 1 carried items, no finding rests on them).
**Counter-probes:** `dev/audit/pit_universe/probes/S2C_*.R` (five).

## Verdicts

| ID | Verdict | Corrected class / severity | One-line reason | Counter-probe |
| --- | --- | --- | --- | --- |
| S2-001 | SURVIVES | - | Reproduced in all six cases; fresh = sweep = the vignette rule (entitlement pulse is the ex-date); the resume recount counts the ex-date-open fill | - |
| S2-002 | SURVIVES | - | `run-finalize.R:456` `use_fold_equity <- length(fold_equity) > 0L`; O, R and W4 reproduce; unrecoverable | - |
| S2-003 | SURVIVES WITH CHANGES | D1 code defect high; D2 disclosure, design question medium | D2 is `audit_only` by the documented missing-knowledge rule; the strict quote is roxygen, not the Config Contract | - |
| S2-004 | SURVIVES WITH CHANGES | code defect, high -> medium | Membership framing wrong (a character universe is a fixed basket); the defect is the activation that was skipped | S2C_backtest |
| S2-005 | SURVIVES | - | Synthesis s3 names `ledgr_sessions_incomplete`; no such class exists in R/ or tests | - |
| S2-006 | SURVIVES WITH CHANGES | - | Cross-snapshot promotion is designed (`require_same_snapshot = FALSE`); drop the context-write sub-claim | - |
| S2-007 | SURVIVES | - | (ii) and (iii) reproduce; (i) is a stated per-window rule, kept only as context | - |
| S2-008 | SURVIVES WITH CHANGES | - | The fill after the end is disclosed (`last_executed_ts_utc`); the defect is the reconstruct identity check | - |
| S2-009 | SURVIVES | - | Abort is test-pinned (deliberate), but predates the typed terminal refusals; still a design question | - |
| S2-010 | SURVIVES | - | No positivity check at seal (`snapshots-seal.R:340-372`); `priced = is.finite(mark)` | - |
| S2-011 | SURVIVES | - | Reproduced; the New York "control" also drops the end date's session (a date-only end is UTC midnight) | - |
| S2-012 | SURVIVES WITH CHANGES | - | Membership part refuted (fixed basket, documented); status and lifetime planes still differ from a run | S2C_pulse |
| S2-013 | SURVIVES | - | Reproduced; also hits uppercase IDs with `_` (not `.`/`-`) | S2C_ties |
| S2-014 | SURVIVES | - | Reproduced from `S2_stops` P | - |
| S2-015 | SURVIVES | - | K3 and P10 reproduce; scoring is correct, only the recorded start is unclamped | - |
| S2-016 | SURVIVES | - | C6 reproduces; the fix must substitute `snapshot_hash`, not just drop `snapshot_id` | - |
| S2-017 | SURVIVES | - | Both lists (contracts.md, Availability and Context) omit `risk_mark` and `mark_source` | citation |
| S2-018 | REFUTED | residual: wrong contract, low | Pinned by the frozen witness; stated in the synthesis and a vignette | citation |

Counts: SURVIVES 12, SURVIVES WITH CHANGES 5, REFUTED 1. Severity change: one
(S2-004 high -> medium). Register matches recorded by the analyst are right;
notes on S2-003 and S2-008 below.

## S2-001 (survives; citation note)

The cited Persistence sentence ("Memory, durable reopen and an interrupted
resume therefore agree ...") is scoped to freeze and terminal state. The general
guarantee is Strategy Contract, line ~1158: "Resume and parallel equivalence are
guaranteed only for strategies deterministic in `(ctx, params)`". The probe
strategy qualifies (the interrupt option does not change its targets). Which
side is wrong depends on the entitlement convention. The vignette
`corporate-action-cash.qmd:101-108` puts `entitlement_time` on the ex-date bar,
so the fresh fold (bind before that pulse's open fills; LTB-0035) is right and
the resume recount is the deviation. The fixture instead maps entitlement to
the last cum close (`fixture.R` `ca_row`); under that mapping a real-world
buyer at the s14 open would be entitled. That does not change the verdict:
fresh and resume must agree.

## S2-003 (survives with changes)

- **D1 (unknown subtype) stands, code defect, high.** `ledgr_corporate_action_plan`
  returns `NULL` when no row is cash, disposition or quantity eligible
  (`corporate-action-settlement.R:148-166`), so the row is inert. The
  equity-settlement synthesis s3.3 keeps a "cannot execute this" choice alive
  for unknown subtypes, and s3.5 defines `unsupported` as "a relevant supplied
  fact was reported without its effect". So the expected outcome is fidelity
  `unsupported` (research) or a stop (strict), not `none`. The analyst's fix
  direction ("refuse unknown subtypes at ingest") conflicts with that synthesis
  sentence. The policy route is the designed one; the vignette's "closed
  `subtype`" is the competing reading. That is a Gate 2 choice.
- **D2 (no knowledge time) reclassified as disclosure, design question, medium.**
  `ledgr_facts_validate()` already reports the row `audit_only` /
  `knowledge_time_missing` (`availability-ingest.R:270-273`). That is the
  package-wide rule for facts without knowledge (`availability-facts.R:8-9`;
  `point-in-time-inputs.qmd:251, 380`). A never-knowable fact has no settlement
  choice for strict to refuse, so "strict passes" is not itself wrong. What
  survives: the run summary drops the audit-only held row. History-wave decision C
  (known-when-effective, disclosed) and LFB-013 already route the missing
  knowledge mode.
- **Citation:** "refuses every corporate-action settlement choice" is
  `R/corporate-action-policy.R:5` (and its Rd), not the Config Contract.
- **Register:** LFB-014 is the right match (same failure class). Gate 2 should
  extend LFB-014 rather than allocate a new ID; M1 below belongs to the same
  family.

## S2-004 (survives with changes; high -> medium)

`ledgr_backtest()` accepts only a character universe. Availability Contract and
synthesis s3: "A character-vector universe is a fixed basket: it stays fixed
every pulse ... and it still consumes `sessions`, `trading_status`, and
`lifetime` facts". The analyst compared it against a *membership* universe.
S2C_backtest:

```
[K ledgr_run basket] availability active TRUE; BBB 2021-03-02T14:30:00Z 1 fills; NNN 2021-03-02T14:30:00Z 1 fills
[K2 experiment basket without valuation policy]: ledgr_valuation_policy_required - ...
[B ledgr_backtest basket] availability active FALSE; BBB 2021-03-02T21:00:00Z 1 fills; NNN 2021-03-02T21:00:00Z 1 fills
[B ledgr_backtest AAA,FFF]: LEDGR_SNAPSHOT_COVERAGE_ERROR ... (same for AAA,KKK and AAA,EEE)
```

`ledgr_run()` also buys BBB at s2, so "trading a nonmember eight sessions before
it joins" is not the defect. The defect: `ledgr_backtest()` skips availability
activation (fill clock, status, lifetime and the mandatory valuation policy)
that `ledgr_run()` enforces on the same basket. That breaks "There is no mode
flag" and "Public convenience APIs ... must not implement alternate pulse, fill
... semantics". Because the dense coverage check refuses any basket with
missing bars, silent economic harm needs status or lifetime restrictions on
fully-barred instruments. Example: vendor-carried bars through a halt (LFB-027).
B1 showed a timestamp difference, not a price difference. Hence medium.

## S2-005 (survives; note)

The analyst's synthesis quote is exact (s3, not s4.1: "incomplete range
coverage ... fails `ledgr_sessions_incomplete`"). That class appears nowhere in
`R/` or `tests/`, and `contracts.md` says only "complete declared session
calendar", with no "over the requested range". Gate 2 should fix the contract
wording together with the code.

## S2-006 (survives with changes)

`ledgr_promote()` roxygen documents deliberate train/test promotion across
snapshots (`require_same_snapshot = FALSE`). So promoting into a different
experiment is intended along at least one axis. The design question is which
inputs must match or be recorded, not whether `exp` may differ. Drop the
sub-claim that promotion context for an `INCOMPLETE` result breaks "written only
after the committed run succeeds": `INCOMPLETE` is a normal returned terminal
status, and the contract's contrast is with a failed run. The surviving signal is
that a `DONE` candidate can become an `INCOMPLETE` committed run purely through
a config mismatch.

## S2-007 (survives; note)

Part (i), the dropped last decision, follows from the stated
`final_pulse_no_execution` rule and is identical under `flat_test_state`
(I_walk_forward W2). It is context, not a continuity break. The material parts
are (ii), a `next_open` dividend lost across the boundary (reproduced: fold 2
starts at 99980.00 with no CASHFLOW), and (iii), carried holdings without mark
history (W4 fold 3 `terminal_mark_unavailable`, which then triggers S2-002).

## S2-008 (survives with changes)

The Persistence Contract completion projection lists `last_fully_valued_ts_utc`
and `last_executed_ts_utc` separately. Probe P records `last_executed
2021-03-18T13:30:00Z` after `achieved_end 2021-03-17T20:00:00Z`. Executions after
the achieved end are therefore an anticipated, disclosed state, and "readers
disagree on the final state" is weaker than stated. The defect stands where the
analyst located it: `derived-state.R:187-191` compares the last rebuilt pulse's
cash with *all* ledger cash deltas. The Result Contract requires the rebuild to
equal stored equity through the last fully valued pulse. LFB-019 as "related,
different trigger" is right.

## S2-009, S2-011, S2-013, S2-016 (survive; notes)

- **S2-009:** the abort is pinned at plan level (`test-corporate-action-cash.R:116-122`)
  and at run level (`test-sim-pit-inputs.R:490-493`, `expect_error(...,
  "ledgr_corporate_action_unsupported")`). It is deliberate, tested behavior
  from Cut 6 that the 2026-10-05 terminal-outcomes synthesis did not revisit.
  Changing it needs the decision the analyst names.
- **S2-011:** the New York line `window '2021-03-03'..'2021-03-08' -> pulses
  03-03,03-04,03-05` drops the 03-08 session too. A date-only end is UTC
  midnight for every venue that closes before midnight UTC, so New York is not a
  clean control. Honolulu adds a session at the start.
- **S2-013:** S2C_ties: `BRK.B`/`BRK-A`/`BRKA`/`BRKB` select identically
  under both locales, but `A10`/`A_1` differ (`C: A1,A10`; `English: A1,A_1`).
  The finding needs mixed case or underscores, both plausible in adapter IDs.
  Medium stands.
- **S2-016:** `config_hash` carries `data.snapshot_id` and no `snapshot_hash`
  (`backtest-config.R:269-274`). LTB `test-availability-causality.R:124-127`
  expects config hashes to differ across snapshots that differ only in facts.
  The fix therefore has to substitute `snapshot_hash`; simply dropping the ID
  would leave `config_hash` with no snapshot binding. The converse also holds
  today: one `snapshot_id` reused in two stores with different facts gives equal
  config hashes.

## S2-012 (survives with changes)

`ledgr_pulse_snapshot()` takes a character `universe`, which by contract is a
fixed basket. Its roxygen states the context has "every instrument a member"
and that "availability-aware state normalization is not simulated". Membership
TRUE for BBB at s5 is what a fixed-basket `ledgr_run()` shows too, so that part
is refuted. What survives (S2C_pulse, basket `c("AAA","EEE")` at s24):

```
[run basket s24] members AAA,EEE; EEE member TRUE target_restricted TRUE reason 'quotation_only' admissible FALSE; tradable AAA
[pulse s24] members AAA,EEE; EEE member TRUE target_restricted FALSE reason '' admissible TRUE; tradable AAA,EEE
```

Inspection ignores the status and lifetime facts a fixed basket still consumes,
against the Strategy Contract's single eligibility plane "in every context ...
`ledgr_pulse_snapshot()`". The class (design question) and medium severity stay.

## S2-018 (refuted)

The claims "no ... test pins it" and "no contract sentence" both fail.
`helper-availability-v0-2-0-1-witnesses.R` declares status rows for AAA, BBB
and CCC only. The frozen witness in `test-availability-provider-witnesses.R:84-89`
expects `DDD=unknown` at every cutoff (the next test pins the empty-family
default). Accepted availability synthesis s3, `trading_status` row: "missing
per-ID status is `status_unknown`, a typed no-fill". User documentation:
`missing-data-and-sessions.qmd:304` ("Declaring status is all or nothing").
Residual: `contracts.md` carries only the reason token, so this is optional
consolidation (wrong contract, low). History-wave D1-F5 remains the right
pending item.

## Missed findings (from the "judged consistent or intended" list)

**M1. A dense run ignores a held cash acquisition and misreports it (PIT-10-002;
code defect, medium-high; register: extend LFB-014).** The analyst dismissed it
because "dense runs cannot reach a disposition (dense requires full bar
coverage; corporate actions alone never activate)". Full coverage is reachable:
vendor-carried prints (LFB-027) or bars continuing past the effective time.
S2C_dense_acquisition (AAA and CCC bars s1-s40; complete `cash_acquisition` on
CCC effective s19 at $50; CCC held; corporate actions are the only facts):

```
[research] status DONE; availability active FALSE; CCC events 2021-03-02T21:00:00Z FILL; final equity 10008.00
[research] summary: corporate_action_fidelity=none ... affected_marked_exposure=498 gross_cash_posted=0 ... positions_disposed=0 ... unsupported_facts=0
[strict] (identical: DONE, no disposition, fidelity none)
```

No disposition, no strict refusal, and the summary reports `none` while
reporting a held affected exposure of 498. That breaks the synthesis s3.4
table (cash acquisition is a disposition at mark, `modeled`) and the s3.5
meaning of `none`. Dense CA-only snapshots are a documented mode
(`corporate-action-cash.qmd:34-36`), and nothing in `contracts.md` scopes
dispositions to availability runs.

**M2. Off-date POSIXct session times seal, then the run and the sweep diverge
(PIT-04-003, "not probed"; code defect, medium; checks a, c).** In
S2C_session_posix, the 2021-03-02 session row's POSIXct open and close are the
2021-03-03 instants:

```
[sessions] constructor accepted
[seal] accepted
[run] ERROR duckdb_error - TransactionContext Error: Current transaction is aborted (please ROLLBACK)
[run] stored status FAILED
[sweep] status DONE
```

Ingest does not guarantee unique, date-consistent session instants, which the
runtime assumes. The run fails with an unclassified store error, while the
sweep on the same experiment scores `DONE`. The cause is inferred from the
input (two sessions share one close); the failing statement was not traced.
Register: none.

**Note (not a finding):** PIT-12-005 (recording pulse derived from diagnostics
in durable runs and from the execution-opportunity index in sweeps) was
dismissed as "not probed ... Not judged". Neither side has evidence of agreement
or divergence. It stays an unexamined check-a item for Gate 2, not a cleared
one.

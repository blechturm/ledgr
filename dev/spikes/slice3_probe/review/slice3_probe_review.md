CHANGES_REQUIRED

Mode: Type 1 review of measurement input; independent session.

The parity holds, but coverage is incomplete. Supplement the cut input with these measurements. No scope decision requires Type 2.

Evidence: [review_probe.R](review_probe.R), arguments `0` or `1`. All 16 added cases match collected tables/conditions in both modes (13 tables/run, 10/sweep). Outputs: [debug 0](review_probe_debug0.txt), [debug 1](review_probe_debug1.txt), [closed-session debug 1](review_probe_debug1_extra.txt), [summary](evidence_summary.txt). Names below identify cases in this script.

**P1 - required: frozen-target refusal and liquidation are missing.** `frozen_increase` requests 20 while holding 10 frozen: `ledgr_restricted_target`. `frozen_liquidate` requests zero: Jan 10 rejects `execution_bar_missing`; Jan 14 sells at Jan 15's open; freeze-exit quantity becomes zero. Original `s3_freeze_exit` restores a mark while still holding 10. Cut/fix: include admissibility and liquidation measurements. Gutting validation changes FAILED to INCOMPLETE and ten tables ([output](review_probe_debug0_gut.txt)).

**P2 - required: a scheduled-skip valuation stop is missing.** `skip_stop` decides only Jan 2, then stops Jan 10 before emitting a skip row: processed=9, achieved end Jan 9, affected exposure=459.89358250000004. Horizon-zero case `skip_stop_first_missing` processes seven pulses. Cut/fix: include both measurements to preserve valuation-stop precedence and prefix accounting on skips.

**P3 - required: declared-session boundaries are undermeasured.** `declared_prefix`/`scheduled_prefix`: processed=11, `full_run=FALSE`, no completion row. `all_missing_session` retains an open pulse without any bars. `closed_sessions`: 14 pulses; frozen age advances from 3 on Friday Jan 10 to 4 on Monday Jan 13. Originals open every date and omit prefixes. Cut/fix: include these measurements to distinguish session, bar and civil-day axes.

**P4 - required: stale/frozen helper liquidation evidence is missing.** `sizing_stale`/`sizing_frozen` emit `sizing_liquidation`, quantity=0, price=NA, then `execution_bar_missing`; decisions retain separate valuation marks. Original sizing covers allocation skips. Cut/fix: include both cases so evidence preserves observed-close semantics while validation receives valuation marks (`R/strategy-helpers.R:413`, `:577`).

**P5 - required: feature history is missing.** Originals request only `bar="close"`. `history_feature` uses SMA matrix and long-frame history in targets, producing ten ledger events. This reaches separate feature branches (`R/history-frame.R:1123`, `:1130`). Cut/fix: incorporate this case before claiming feature-history coverage.

**P6 - required: schedule queries and scheduled sweeps are missing.** `schedule_query` uses Friday queries to change targets; `schedule_no_decisions` refuses `ledgr_schedule_no_decision`. `scheduled_sweep` resolves cadence per candidate: week-start DONE, month-end FAILED with the no-decision message. Original `s3_sweep` has no schedule. Cut/fix: include these cases to cover callback queries and candidate-specific resolution/refusal.

**P7 - required: unavailable marks without a reference are missing.** `risk_never_marked` requests C before its first bar: `risk_mark_unavailable`, source=`missing`, age=NA, exposure=0, processed=2. Original risk-stop coverage uses an expired reference. Cut/fix: include this case to preserve distinct missing-mark diagnostics.

**P8 - advisory: names overstate some observations.** `s3_stop_freeze` completes DONE; `s3_reduce_on_stale` has pass-through risk rows. Actual risk reduction occurs in `s3_stale_reduction` (200 to 66.002989298090881). Cut/fix: describe the observed branches to avoid overstating stop/risk coverage.

Checked: patch, relevant pin code, all original definitions/dumps; independently reran seven originals (112 identical tables). Recorded final files each contain 266 identical comparisons. The global missing-bar trigger suffices for the permitted fixed basket; fixed membership supports the axis assertion (`R/availability-provider-prepared.R:472`). Staging and clean-row rules agree with the pin (`R/fold-engine.R:1280`, `R/diagnostic-codec.R:36`). Completion exposure/counts match: valuation excludes its stopping pulse; risk includes it. No accidental parity found on checked paths.

Not checked: full 74-workload gate, timing, package tests/checks, exhaustive permutations, or slices 4-5. Worktree untouched.

# Probe Findings: Public Workflow Access For Selection And Promotion

**Question:** does the documented public workflow provide the access needed for
safe selection and promotion, or does it require new public surface?
**Answer:** it provides the access. No new public surface is needed. Four
defects sit beside the path, none of them a missing accessor.

**Ran:** `Rscript dev/spikes/api-representation-hardening/probe.R` on
2026-09-09, checkout `c78ab4f` loaded with `pkgload::load_all()`, R 4.5.2
(ucrt, Windows 11), ledgr 0.1.9.7, duckdb 1.4.3, dplyr 1.1.4. Ten cases on a
synthetic two-instrument, eight-bar sealed snapshot in a temporary DuckDB file,
`ledgr_risk_max_weight(0.4)` as the nondefault risk chain (executed evidence:
a qty 60 target fills 40 shares under the cap). One non-exported call, labelled
`proto:` in the script, reads candidate risk identity the way `ledgr_promote()`
does.

## Executed observations

1. Sweep rows carry `risk_chain_hash` as a column, a results attribute, and in
   row `provenance` with `risk_plan_json`; all match the experiment.
2. `filter()`, `arrange()`, `slice_head()`, and base `[` on in-memory results
   keep the class, the attribute, and a promotable risk identity. The same
   holds after `ledgr_sweep_save()` and `ledgr_sweep_open()`. The audit's T-3
   loss did not occur under any supported operation: dplyr and vctrs copy the
   attributes that `ledgr_sweep_results_restore()` omits.
3. Candidates built from a plain tibble, an `as.data.frame()` copy, and an
   attribute-stripped data frame all reconstruct the risk chain from row
   provenance, and the stripped one promotes successfully.
4. Promotion from a reopened, filtered candidate reproduces the sweep row's
   final equity exactly (10593.491941 both sides) and records the risk hash in
   `ledgr_promotion_context()` under `selected_candidate` and `source_sweep`.
5. `ledgr_run_info()` has no risk field. A committed run's risk identity is
   reachable only through `config_json` or `bt$config$risk_chain`.
6. `ledgr_sweep_review()$ranked` is a plain tibble. A candidate taken from it
   has zero `sweep_meta` fields, and promoting it stores `source_sweep$sweep_id`
   as `NULL`. This is the research-workflow vignette's documented path.
7. `ledgr_results(bt, what = "fills")` returns the `as_tibble()` table wrapped
   in `ledgr_result_fills` and a `ledgr_result_type` attribute; data identical.
8. Target extraction: `c(target)` gives a plain named numeric with no other
   attributes; `target[["AAA"]]` works on the classed object; `unclass()` keeps
   `origin`; `as.numeric()` and `as.vector()` drop names.
9. `stream_threshold`: on a run with fills, `Inf` raises an untyped base error
   after a coercion warning; `NA` and `"100"` raise `ledgr_invalid_args`;
   `-1`, `0`, and `1.5` are accepted and switch the return type to
   `ledgr_fills_cursor` with `lazy = FALSE`. On a run with no fills every one of
   those values returns an empty tibble without error, because the count
   shortcut runs before validation.
10. The cursor has no S3 methods, no exported consumer (tests use
    `DBI::dbFetch(cursor$res)`), and no vignette. With `lazy = TRUE` on a
    no-fill run the return is an empty tibble, so the return type depends on
    data, not arguments. The empty and nonempty tables share one class.
11. After `close(bt)`, `ledgr_run_fills()` and `summary()` reopen a temporary
    connection by path and succeed on populated and empty runs.
12. Reversal fee duplication (audit T-1) reproduced with
    `ledgr_cost_notional_bps_fee(10)` and a long/short flip: 7 fill events,
    13 derived rows, derived fee total 13.045 against source 6.775; six of
    seven events carry the full fee on both `CLOSE` and `OPEN` rows. The engine
    accepted the negative targets without a shorting contract.

## Unresolved

- Whether reads through a closed handle are a contract or an accident.
- Which fee allocation the split rows should carry (pro rata by quantity or
  whole fee on the closing row); both conserve, they differ for TCA.
- No case exercised no-lookahead, RNG hygiene, wide-name collisions, or
  interrupted persistence; those remain source deductions in the audit.

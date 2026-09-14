# Probe: does the documented public workflow provide the access needed for safe
# selection and promotion, or does it require new public surface?
#
# Spike protocol section 1 probe for the API / representation-boundary
# hardening RFC (seed v1, 2026-09-09). Ten cases, exported surface only,
# except one labelled internal identity check. Run from the package root:
#
#   Rscript dev/spikes/api-representation-hardening/probe.R
#
# The script never stops on a failing case; every case prints its own
# observations so the findings page can quote executed behavior.

suppressPackageStartupMessages({
  # Load the checkout, not the installed build, so observations match the SHA.
  pkgload::load_all(".", quiet = TRUE)
  library(dplyr)
})

say <- function(...) cat(sprintf(...), "\n", sep = "")
case <- function(label, expr) {
  say("\n== %s ==", label)
  tryCatch(expr, error = function(e) {
    say("  ERROR [%s]: %s", paste(class(e), collapse = "/"), conditionMessage(e))
    invisible(NULL)
  })
}
quiet <- function(expr) suppressMessages(suppressWarnings(expr))
classes <- function(x) paste(class(x), collapse = "/")
outcome <- function(expr) {
  tryCatch(
    {
      value <- withCallingHandlers(expr, warning = function(w) {
        say("    warning: %s", conditionMessage(w))
        invokeRestart("muffleWarning")
      })
      if (is.logical(value) && length(value) == 1L) {
        sprintf("value %s", value)
      } else {
        sprintf("value of class %s (%d rows)", classes(value), NROW(value))
      }
    },
    error = function(e) sprintf("error [%s]: %s", class(e)[[1]], conditionMessage(e))
  )
}

say("R %s; ledgr %s; duckdb %s; dplyr %s; git %s",
    R.version.string, as.character(packageVersion("ledgr")),
    as.character(packageVersion("duckdb")), as.character(packageVersion("dplyr")),
    tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) "n/a"))

# ---- fixture: two instruments, eight daily bars, sealed temp store ---------
ts <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:7
mk <- function(id, open, close) {
  data.frame(instrument_id = id, ts_utc = ts, open = open, high = pmax(open, close) + 1,
             low = pmin(open, close) - 1, close = close, volume = 1000)
}
bars <- rbind(
  mk("AAA", 100 + 0:7, c(100, 103, 101, 105, 104, 108, 107, 110)),
  mk("BBB", 50 + 0:7, c(50, 49, 52, 51, 54, 53, 56, 55))
)
store <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(bars, db_path = store, snapshot_id = "probe_snapshot")

strategy <- function(ctx, params) {
  targets <- ctx$flat()
  targets["AAA"] <- params$qty
  targets["BBB"] <- params$qty
  targets
}
risk <- ledgr_risk_max_weight(0.4)
expected_hash <- ledgr_risk_chain_hash(risk)
exp <- ledgr_experiment(
  snapshot, strategy,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero(),
  risk_chain = risk
)
grid <- ledgr_param_grid(a = list(qty = 20), b = list(qty = 60))

risk_identity_of <- function(candidate) {
  # proto: internal reader used by ledgr_promote(); the only non-exported call.
  id <- ledgr:::ledgr_candidate_risk_identity(candidate)
  identical(id$risk_chain_hash, expected_hash)
}
report_view <- function(label, view) {
  cand <- quiet(ledgr_candidate(view, 1L))
  say("  %-22s class=%s attr(risk_chain_hash)=%s row col=%s candidate=%s risk_identity_matches=%s",
      label, classes(view),
      !is.null(attr(view, "risk_chain_hash", exact = TRUE)),
      "risk_chain_hash" %in% names(view),
      cand$candidate_id, risk_identity_of(cand))
}

# ---- case 1: sweep carries nondefault risk identity -------------------------
sweep <- case("1 sweep rows carry the nondefault risk chain", {
  s <- quiet(ledgr_sweep(exp, grid, seed = 7L,
                         retain = ledgr_sweep_retention("completed", trades = "closed")))
  say("  status=%s final_equity=%s", paste(s$status, collapse = ","),
      paste(round(s$final_equity, 2), collapse = ","))
  say("  row column risk_chain_hash present=%s; sweep attr risk_chain_hash=%s",
      "risk_chain_hash" %in% names(s), !is.null(attr(s, "risk_chain_hash", exact = TRUE)))
  say("  provenance$risk_chain_hash matches experiment=%s; provenance$risk_plan_json present=%s",
      identical(s$provenance[[1]]$risk_chain_hash, expected_hash),
      !is.null(s$provenance[[1]]$risk_plan_json))
  # Retained closed trades carry no quantity column, so show the cap through a
  # committed run of the same experiment: qty=60 AAA at ~100 exceeds 40% of cash.
  cap_bt <- quiet(ledgr_run(exp, params = list(qty = 60), run_id = "probe_cap"))
  cap_fills <- ledgr_run_fills(cap_bt)
  say("  risk bit: committed qty=60 run fills AAA=%s BBB=%s (cap 40%% of 10000 cash)",
      cap_fills$qty[cap_fills$instrument_id == "AAA"][[1]],
      cap_fills$qty[cap_fills$instrument_id == "BBB"][[1]])
  close(cap_bt)
  s
})

# ---- case 2: documented row operations, in memory ---------------------------
case("2 in-memory row operations keep candidate risk identity", {
  report_view("filter()", dplyr::filter(sweep, candidate_id == "b"))
  report_view("arrange(desc())", dplyr::arrange(sweep, dplyr::desc(final_equity)))
  report_view("slice_head(n = 1)", dplyr::slice_head(sweep, n = 1))
  report_view("base [2, ]", sweep[2L, ])
  review <- ledgr_sweep_review(sweep, rank_by = dplyr::desc(final_equity), n = 1L)
  report_view("sweep_review()$ranked", review$ranked)
  say("  sweep_meta fields on a candidate from sweep results=%d, from sweep_review()$ranked=%d",
      length(quiet(ledgr_candidate(sweep, 1L))$sweep_meta),
      length(quiet(ledgr_candidate(review$ranked, 1L))$sweep_meta))
  say("  plain tibble (as_tibble) candidate -> risk identity: %s",
      outcome(risk_identity_of(quiet(ledgr_candidate(tibble::as_tibble(sweep), 1L)))))
})

# ---- case 3: save, reopen, then the same row operations ---------------------
reopened <- case("3 saved sweep reopened, row operations keep identity", {
  ledgr_sweep_save(sweep, snapshot, sweep_id = "probe_saved", note = "probe")
  r <- ledgr_sweep_open(snapshot, "probe_saved")
  say("  reopened class=%s attr(risk_chain_hash) matches=%s risk_plan_json in provenance=%s",
      classes(r), identical(attr(r, "risk_chain_hash", exact = TRUE), expected_hash),
      !is.null(r$provenance[[1]]$risk_plan_json))
  report_view("filter()", dplyr::filter(r, candidate_id == "b"))
  report_view("arrange(desc())", dplyr::arrange(r, dplyr::desc(final_equity)))
  report_view("base [2, ]", r[2L, ])
  r
})

# ---- case 4: promote the subset candidate; parity with the sweep row ---------
promoted <- case("4 promotion from a reopened, filtered candidate", {
  cand <- quiet(ledgr_candidate(dplyr::filter(reopened, candidate_id == "b"), 1L))
  p <- quiet(ledgr_promote(exp, cand, run_id = "probe_promoted", note = "probe selection"))
  eq <- ledgr_results(p, what = "equity")
  say("  promoted run final equity=%s; sweep row final_equity=%s; equal=%s",
      round(tail(eq$equity, 1), 6), round(cand$row$final_equity, 6),
      isTRUE(all.equal(tail(eq$equity, 1), cand$row$final_equity)))
  info <- ledgr_run_info(snapshot, "probe_promoted")
  say("  run_info fields: %s", paste(names(info), collapse = ","))
  say("  run_info fields with 'risk': %s; promoted handle config risk_chain_hash matches=%s",
      paste(grep("risk", names(info), value = TRUE), collapse = ","),
      identical(p$config$risk_chain_hash, expected_hash))
  pc <- ledgr_promotion_context(p)
  say("  promotion context class=%s selected=%s source sweep_id=%s",
      classes(pc), pc$selected_candidate$candidate_id, pc$source_sweep$sweep_id)
  say("  risk_chain_hash readable from promotion context: selected_candidate=%s source_sweep=%s; config path=%s",
      identical(pc$selected_candidate$risk_chain_hash, expected_hash),
      identical(pc$source_sweep$risk_chain_hash, expected_hash),
      paste(names(which(rapply(p$config, function(v) identical(v, expected_hash), how = "unlist"))), collapse = ","))
  ranked_cand <- quiet(ledgr_candidate(
    ledgr_sweep_review(reopened, rank_by = dplyr::desc(final_equity), n = 1L)$ranked, 1L))
  ranked_p <- quiet(ledgr_promote(exp, ranked_cand, run_id = "probe_from_ranked", note = "vignette path"))
  say("  promotion from sweep_review()$ranked: source_sweep$sweep_id=%s (vignette research-workflow path)",
      ledgr_promotion_context(ranked_p)$source_sweep$sweep_id %||% "NULL")
  close(ranked_p)
  p
})

# ---- case 5: reopen the committed run --------------------------------------
case("5 reopen the promoted run and read the same evidence", {
  close(promoted)
  r <- ledgr_run_open(snapshot, "probe_promoted")
  say("  reopened class=%s", classes(r))
  say("  promotion_context(reopened) available=%s; run_promotion_context(exp, id) available=%s",
      !is.null(ledgr_promotion_context(r)),
      !is.null(ledgr_run_promotion_context(exp, "probe_promoted")))
  say("  results(what='fills') identical to run_fills(): %s; all.equal: %s",
      identical(ledgr_results(r, what = "fills"), ledgr_run_fills(r)),
      paste(all.equal(ledgr_results(r, what = "fills"), ledgr_run_fills(r)), collapse = " | "))
  say("  results(what='fills') attrs=%s; run_fills attrs=%s",
      paste(names(attributes(ledgr_results(r, what = "fills"))), collapse = ","),
      paste(names(attributes(ledgr_run_fills(r))), collapse = ","))
  say("  as_tibble(bt, what='fills') identical to run_fills(): %s",
      identical(tibble::as_tibble(r, what = "fills"), ledgr_run_fills(r)))
  close(r)
})

# ---- case 6: target extraction with base R ---------------------------------
case("6 target extraction: is a reader needed beyond base R?", {
  pulse <- tryCatch(
    ledgr_pulse_snapshot(snapshot, universe = c("AAA", "BBB"), ts_utc = ts[[4]],
                         features = list(ledgr_ind_returns(2))),
    error = function(e) { say("  pulse_snapshot failed: %s", conditionMessage(e)); NULL })
  target <- NULL
  if (!is.null(pulse)) {
    target <- tryCatch({
      sig <- ledgr_signal_return(pulse, lookback = 2)
      ledgr_target_rebalance(ledgr_weight_equal(ledgr_select_top_n(sig, n = 1)), pulse,
                             equity_fraction = 0.1)
    }, error = function(e) { say("  vignette pipeline failed: %s", conditionMessage(e)); NULL })
  }
  if (is.null(target)) target <- ledgr_target(c(AAA = 3, BBB = 0), origin = "fallback")
  say("  target class=%s names=%s attrs=%s", classes(target),
      paste(names(target), collapse = ","), paste(names(attributes(target)), collapse = ","))
  show <- function(label, v) say("  %-34s class=%-22s names=%-8s other attrs=%s", label, classes(v),
                                 paste(names(v), collapse = ","),
                                 paste(setdiff(names(attributes(v)), "names"), collapse = ","))
  show("unclass(target)", unclass(target))
  show("c(target)", c(target))
  show("as.numeric(target)", as.numeric(target))
  show("as.vector(target)", as.vector(target))
  show("target[c('AAA','BBB')]", target[c("AAA", "BBB")])
  show("setNames(as.numeric(t), names(t))", setNames(as.numeric(target), names(target)))
  say("  target[['AAA']] = %s; unclass(target)[['AAA']] = %s", target[["AAA"]], unclass(target)[["AAA"]])
})

# ---- case 7: stream_threshold validation order -----------------------------
bt <- quiet(ledgr_run(exp, params = list(qty = 20), run_id = "probe_direct", seed = 1L))
empty_exp <- ledgr_experiment(snapshot, function(ctx, params) ctx$flat(),
                              opening = ledgr_opening(cash = 10000), cost_model = ledgr_cost_zero())
bt_empty <- quiet(ledgr_run(empty_exp, params = list(), run_id = "probe_no_fills"))
case("7 stream_threshold validation on a run with fills vs. no fills", {
  say("  direct run has %d fill rows; no-fill run has %d",
      nrow(ledgr_run_fills(bt)), nrow(ledgr_run_fills(bt_empty)))
  for (thr in list(Inf, NA_real_, "100", -1, 0, 1.5, 100000L)) {
    say("  stream_threshold=%-8s with fills -> %s", deparse(thr),
        outcome(ledgr_run_fills(bt, stream_threshold = thr)))
    say("  stream_threshold=%-8s no fills   -> %s", deparse(thr),
        outcome(ledgr_run_fills(bt_empty, stream_threshold = thr)))
  }
  say("  lazy='yes' with fills -> %s", outcome(ledgr_run_fills(bt, lazy = "yes")))
})

# ---- case 8: cursor ownership and empty-result class ------------------------
case("8 fills cursor ownership and empty result class", {
  cur <- ledgr_run_fills(bt, lazy = TRUE)
  say("  lazy=TRUE class=%s; exported names containing 'fills': %s", classes(cur),
      paste(sort(grep("fills", getNamespaceExports("ledgr"), value = TRUE)), collapse = ", "))
  say("  S3 methods for the cursor: %s",
      paste(format(utils::methods(class = "ledgr_fills_cursor")), collapse = ", "))
  say("  threshold-triggered switch: stream_threshold=0, lazy=FALSE -> %s",
      outcome(ledgr_run_fills(bt, stream_threshold = 0)))
  say("  no-fill run, lazy=TRUE -> %s", outcome(ledgr_run_fills(bt_empty, lazy = TRUE)))
  say("  empty table class=%s; nonempty table class=%s",
      classes(ledgr_run_fills(bt_empty)), classes(ledgr_run_fills(bt)))
  close(bt_empty)
  say("  reading a no-fill run through a closed handle -> %s", outcome(ledgr_run_fills(bt_empty)))
  closed_bt <- quiet(ledgr_run(exp, params = list(qty = 20), run_id = "probe_closed", seed = 1L))
  close(closed_bt)
  say("  reading a 2-fill run through a closed handle -> %s", outcome(ledgr_run_fills(closed_bt)))
  say("  summary() through a closed handle -> %s", outcome(summary(closed_bt)))
})

# ---- case 9: reversal fee conservation (audit T-1) -------------------------
case("9 reversal fee conservation in derived fills (audit T-1)", {
  flip <- function(ctx, params) {
    t <- ctx$flat()
    t["AAA"] <- if (ctx$vec$positions[[ctx$idx("AAA")]] > 0) -5 else 5
    t
  }
  fee_exp <- ledgr_experiment(snapshot, flip, opening = ledgr_opening(cash = 10000),
                              cost_model = ledgr_cost_notional_bps_fee(10))
  fee_bt <- tryCatch(quiet(ledgr_run(fee_exp, params = list(), run_id = "probe_reversal")),
                     error = function(e) {
                       say("  reversal run refused [%s]: %s", class(e)[[1]], conditionMessage(e))
                       NULL
                     })
  if (is.null(fee_bt)) {
    flat_flip <- function(ctx, params) {
      t <- ctx$flat()
      t["AAA"] <- if (ctx$vec$positions[[ctx$idx("AAA")]] > 0) 0 else 5
      t
    }
    fee_exp <- ledgr_experiment(snapshot, flat_flip, opening = ledgr_opening(cash = 10000),
                                cost_model = ledgr_cost_notional_bps_fee(10))
    fee_bt <- quiet(ledgr_run(fee_exp, params = list(), run_id = "probe_flip_flat"))
    say("  fallback: long/flat alternation (no reversal inside one fill)")
  }
  fills <- ledgr_run_fills(fee_bt)
  ledger <- ledgr_results(fee_bt, what = "ledger")
  fee_col <- grep("fee", names(ledger), value = TRUE)
  say("  ledger fee columns: %s; derived fill rows=%d; ledger fill events=%d",
      paste(fee_col, collapse = ","), nrow(fills),
      sum(ledger$event_type %in% c("FILL", "FILL_PARTIAL")))
  by_seq <- fills |>
    group_by(event_seq) |>
    summarise(rows = n(), fee_sum = sum(fee), actions = paste(action, collapse = "+"), .groups = "drop")
  print(as.data.frame(by_seq))
  if (length(fee_col) > 0L) {
    src <- ledger |>
      filter(event_type %in% c("FILL", "FILL_PARTIAL")) |>
      select(event_seq, source_fee = all_of(fee_col[[1]]))
    cmp <- inner_join(by_seq, src, by = "event_seq")
    say("  total derived fee=%s; total source fee=%s; events where derived != source: %d",
        sum(cmp$fee_sum), sum(cmp$source_fee), sum(abs(cmp$fee_sum - cmp$source_fee) > 1e-9))
  }
  close(fee_bt)
})

# ---- case 10: candidate from an arbitrary external coercion ----------------
case("10 external coercion: what survives as.data.frame() and attribute stripping", {
  df <- as.data.frame(sweep)
  say("  as.data.frame class=%s; candidate risk identity -> %s", classes(df),
      outcome(risk_identity_of(quiet(ledgr_candidate(df, 1L)))))
  bare <- sweep
  attributes(bare) <- attributes(bare)[c("names", "row.names", "class")]
  class(bare) <- setdiff(class(bare), c("ledgr_sweep_results", "ledgr_saved_sweep_results"))
  say("  attributes stripped: candidate risk identity -> %s",
      outcome(risk_identity_of(quiet(ledgr_candidate(bare, 1L)))))
  say("  promote from the stripped candidate -> %s",
      outcome(quiet(ledgr_promote(exp, quiet(ledgr_candidate(bare, 1L)), run_id = "probe_stripped"))))
})

close(bt)
ledgr_snapshot_close(snapshot)
say("\nprobe finished")

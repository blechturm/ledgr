# Cut 10 real-data continuity checker (LDG-2972).
#
# Usage:
#   Rscript dev/bench/v0_2_2_real_data_continuity/check_record.R <record.csv> --expect pre|post
#
# Groups: lfb017 (LDG-2973), lfb023 (LDG-2974), lfb018 (LDG-2975) and
# invariance. Expected values are fixture arithmetic (see README.md), not
# another engine path. `--expect pre` requires every LFB group to fail and the
# invariance group to pass; `--expect post` requires every group to pass. A
# missing observation is a failure, never a pass.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L || args[[2L]] != "--expect" || !args[[3L]] %in% c("pre", "post")) {
  stop("usage: check_record.R <record.csv> --expect pre|post", call. = FALSE)
}
rec <- utils::read.csv(args[[1L]], stringsAsFactors = FALSE, na.strings = character())
expect <- args[[3L]]

get <- function(arm, observable) {
  v <- rec$value[rec$arm == arm & rec$observable == observable]
  if (length(v) != 1L) NA_character_ else v
}
split_list <- function(x) if (is.na(x) || !nzchar(x)) character() else strsplit(x, ",", fixed = TRUE)[[1L]]
results <- list()
check <- function(group, name, ok) {
  ok <- isTRUE(ok)
  results[[length(results) + 1L]] <<- data.frame(group = group, check = name, pass = ok, stringsAsFactors = FALSE)
}
ran <- function(arm) identical(get(arm, "condition_class"), "")
days <- c("2020-01-06", "2020-01-07", "2020-01-08", "2020-01-09", "2020-01-10")
rows_for <- function(aaa, bbb, bbb_reason) {
  as.vector(rbind(sprintf("%s:AAA:decision_recorded:%s", days, aaa), sprintf("%s:BBB:%s:%s", days, bbb_reason, bbb)))
}

# ---- LFB-017 ------------------------------------------------------------------
# f = 0.9, equal weight, equity 1000, AAA close 10, BBB close 20. AAA is sized
# floor(0.5 * 0.9 * 1000 / 10) = 45 on every pulse. BBB has no bar on day 1
# (unheld: skipped at 0) and day 4 (held 22: E = 440, V = 450, V + E <= 1000,
# so the cap does not bind and AAA stays 45). Otherwise floor(450 / 20) = 22.
skip_reason <- c("sizing_unavailable", "decision_recorded", "decision_recorded", "sizing_unavailable", "decision_recorded")
expected_default <- rows_for(rep(45, 5), c(0, 22, 22, 22, 22), skip_reason)
for (arm in c("lfb017_default", "lfb017_concat", "lfb017_subset")) {
  check("lfb017", paste(arm, "completes"), ran(arm) && identical(get(arm, "status"), "DONE"))
  check("lfb017", paste(arm, "fills: buy AAA 45 day 2, BBB 22 day 3, no round trip"),
        identical(split_list(get(arm, "fills")), c("2020-01-07:AAA:BUY:45", "2020-01-08:BBB:BUY:22")))
  check("lfb017", paste(arm, "decision targets and sizing_unavailable rows"),
        identical(split_list(get(arm, "decision_rows")), expected_default))
}
# Cap: day 2 and 3 weights 0.1/0.9 at f = 1 buy AAA 10 and BBB 45. Day 4, BBB
# unpriced and held 45 at mark 20: E = 900, V = 0.5 * 1000 = 500, V + E > 1000,
# s = (1000 - 900) / 500 = 0.2, AAA = floor(0.2 * 500 / 10) = 10. Day 5 both
# priced at 0.5/0.5: AAA 50, BBB 25 (no later bar to fill).
check("lfb017", "cap fixture completes", ran("lfb017_cap") && identical(get("lfb017_cap", "status"), "DONE"))
check("lfb017", "cap fixture fills", identical(split_list(get("lfb017_cap", "fills")),
                                               c("2020-01-08:AAA:BUY:10", "2020-01-08:BBB:BUY:45")))
check("lfb017", "cap binds at s = 0.2 and BBB is recorded as skipped",
      identical(split_list(get("lfb017_cap", "decision_rows")),
                rows_for(c(0, 10, 10, 10, 50), c(0, 45, 45, 45, 25),
                         c("decision_recorded", "decision_recorded", "decision_recorded", "sizing_unavailable", "decision_recorded"))))

# ---- LFB-023 ------------------------------------------------------------------
# trade_until_may trades through May; train windows that start in June or later
# hold cash throughout and have no finite Sharpe ratio, so those folds reuse the
# previous training selection and still run their test window.
folds_prev <- split_list(get("lfb023_later_empty", "folds"))
fold_part <- function(x, k) vapply(strsplit(x, ":", fixed = TRUE), `[[`, "", k)
check("lfb023", "later-empty session completes DONE", ran("lfb023_later_empty") &&
        identical(get("lfb023_later_empty", "session_status"), "DONE") && length(folds_prev) >= 6L)
if (length(folds_prev)) {
  expected_source <- ifelse(fold_part(folds_prev, 2L) > "2020-05-31", "previous", "train")
  check("lfb023", "sources: train through May, previous after",
        identical(fold_part(folds_prev, 4L), expected_source) && any(expected_source == "previous") &&
          any(expected_source == "train"))
  check("lfb023", "every later-empty fold is DONE and ran its test window",
        all(fold_part(folds_prev, 3L) == "DONE") && all(fold_part(folds_prev, 5L) == "test"))
}
folds_none <- split_list(get("lfb023_never", "folds"))
check("lfb023", "never-select session completes DONE with no test runs", ran("lfb023_never") &&
        identical(get("lfb023_never", "session_status"), "DONE") && length(folds_none) >= 6L &&
        all(fold_part(folds_none, 3L) == "DONE") && all(fold_part(folds_none, 4L) == "none") &&
        all(fold_part(folds_none, 5L) == "no_test"))
check("lfb023", "print flags folds without a test window",
      grepl("no test window", get("lfb023_never", "print"), fixed = TRUE))
check("lfb023", "candidate on a none fold refuses",
      grepl("ledgr_walk_forward_candidate_not_found", get("lfb023_candidate_none", "condition_class"), fixed = TRUE))
check("lfb023", "candidate on a previous fold says so in provenance",
      identical(get("lfb023_candidate_previous", "provenance_source"), "previous"))
check("lfb023", "no_selection = fail keeps the refusal",
      grepl("ledgr_walk_forward_no_selection", get("lfb023_fail", "condition_class"), fixed = TRUE))
check("lfb023", "no_selection = fail stores a FAILED first fold with NULL source",
      identical(split_list(get("lfb023_fail", "stored_folds"))[1L], "1:FAILED:NULL"))
check("lfb023", "policy changes the session ID",
      ran("lfb023_all_select_fail") && !identical(get("lfb023_all_select_fail", "session_id"), get("inv_wf_all_select", "session_id")))
check("lfb023", "an all-train session has identical test results under both policies",
      identical(get("lfb023_all_select_fail", "same_test_equity_as_previous"), "TRUE"))

# ---- LFB-018 ------------------------------------------------------------------
for (arm in c("lfb018_timelimit", "lfb018_interrupt", "lfb018_resumed")) {
  check("lfb018", paste(arm, "is FAILED with an error message"),
        identical(get(arm, "status"), "FAILED") && identical(get(arm, "error_msg_nonempty"), "TRUE"))
}
check("lfb018", "time limit still reaches the caller",
      grepl("error", get("lfb018_timelimit", "condition_class"), fixed = TRUE))
check("lfb018", "interrupt still reaches the caller",
      grepl("interrupt", get("lfb018_interrupt", "condition_class"), fixed = TRUE))
check("lfb018", "a resumed FAILED row takes the new attempt's message",
      grepl("second attempt failed", get("lfb018_resumed", "error_msg"), fixed = TRUE) &&
        grepl("error", get("lfb018_resumed", "condition_class"), fixed = TRUE))
# An interrupt inside the pulse loop (strategy on 2020-01-08). The reference
# must trade, so the resume comparison has power.
for (mode in c("dense", "availability")) {
  arm <- paste0("lfb018_midloop_", mode)
  ref_fills <- split_list(get(paste0(arm, "_reference"), "fills"))
  check("lfb018", paste(mode, "mid-loop interrupt: FAILED, named message, caller sees the interrupt"),
        identical(get(arm, "status"), "FAILED") &&
          identical(get(arm, "error_msg"), "Run interrupted before completion.") &&
          grepl("interrupt", get(arm, "condition_class"), fixed = TRUE))
  check("lfb018", paste(mode, "mid-loop resume reaches the uninterrupted result"),
        length(ref_fills) >= 2L && ran(paste0(arm, "_resume")) &&
          identical(get(paste0(arm, "_resume"), "status"), "DONE") &&
          identical(get(paste0(arm, "_resume"), "fills"), get(paste0(arm, "_reference"), "fills")) &&
          identical(get(paste0(arm, "_resume"), "equity"), get(paste0(arm, "_reference"), "equity")))
}

# ---- Invariance ---------------------------------------------------------------
check("invariance", "close-filter pipeline unchanged", ran("inv_where") && identical(get("inv_where", "status"), "DONE") &&
        identical(split_list(get("inv_where", "fills")),
                  c("2020-01-07:AAA:BUY:90", "2020-01-08:AAA:SELL:45", "2020-01-08:BBB:BUY:22",
                    "2020-01-10:AAA:BUY:45", "2020-01-10:BBB:SELL:22")))
check("invariance", "gap-free run unchanged", ran("inv_nogap") &&
        identical(split_list(get("inv_nogap", "fills")), c("2020-01-07:AAA:BUY:45", "2020-01-07:BBB:BUY:22")) &&
        identical(split_list(get("inv_nogap", "decision_rows")), rows_for(rep(45, 5), rep(22, 5), rep("decision_recorded", 5))))
check("invariance", "dense warn-and-zero unchanged",
      identical(get("inv_dense", "target"), "AAA=50,BBB=0") && identical(get("inv_dense", "warning"), "ledgr_invalid_target_price"))
folds_all <- split_list(get("inv_wf_all_select", "folds"))
check("invariance", "all-select walk-forward unchanged", ran("inv_wf_all_select") &&
        identical(get("inv_wf_all_select", "session_status"), "DONE") && length(folds_all) >= 6L &&
        all(fold_part(folds_all, 3L) == "DONE") && all(fold_part(folds_all, 4L) %in% c("train", "<absent>")) &&
        all(fold_part(folds_all, 5L) == "test"))
# Moving prices: the uninterrupted run trades and its equity moves, so the
# soft-stop resume comparison below cannot pass on a flat curve.
inv_equity <- as.numeric(split_list(get("inv_uninterrupted", "equity")))
check("invariance", "uninterrupted run trades with moving equity",
      ran("inv_uninterrupted") && identical(get("inv_uninterrupted", "status"), "DONE") &&
        length(split_list(get("inv_uninterrupted", "fills"))) >= 2L && length(unique(inv_equity)) > 1L)
check("invariance", "soft stop keeps RUNNING without an error message",
      identical(get("inv_soft_stop", "status"), "RUNNING") && identical(get("inv_soft_stop", "error_msg_nonempty"), "FALSE"))
check("invariance", "soft-stop resume reaches the uninterrupted result",
      identical(get("inv_soft_stop_resume", "status"), "DONE") &&
        identical(get("inv_soft_stop_resume", "fills"), get("inv_uninterrupted", "fills")) &&
        identical(get("inv_soft_stop_resume", "equity"), get("inv_uninterrupted", "equity")) &&
        !is.na(get("inv_uninterrupted", "fills")))

out <- do.call(rbind, results)
summary <- stats::aggregate(pass ~ group, data = out, FUN = function(p) sprintf("%d/%d", sum(p), length(p)))
group_pass <- tapply(out$pass, out$group, all)
for (i in seq_len(nrow(out))) if (!out$pass[[i]]) cat(sprintf("FAIL [%s] %s\n", out$group[[i]], out$check[[i]]))
print(summary, row.names = FALSE)
ok <- if (identical(expect, "post")) {
  all(group_pass)
} else {
  isTRUE(group_pass[["invariance"]]) && !any(group_pass[c("lfb017", "lfb023", "lfb018")])
}
cat(sprintf("%s: expectation '%s' %s\n", if (ok) "OK" else "MISMATCH", expect, if (ok) "met" else "not met"))
quit(status = if (ok) 0L else 1L)

# Real-data continuity checker (Cut 10 LDG-2972, Cut 11 LDG-2977).
#
# Usage:
#   Rscript dev/bench/v0_2_2_real_data_continuity/check_record.R <record.csv>
#     --expect pre|post10|pre11|post [--against <earlier record.csv>]
#
# Cut 10 groups: lfb017 (LDG-2973), lfb023 (LDG-2974), lfb018 (LDG-2975) and
# invariance. Cut 11 groups: lfb019 (LDG-2978), wfgap (LDG-2979), wfresume
# (LDG-2980), bounds (LDG-2991), invariance11, and reason11, which pins each
# Cut 11 group's pre-cut failure to its source-table reason. Expected values
# are fixture arithmetic (see README.md), not another engine path.
#
#   pre     Cut 10 groups fail, invariance passes (Cut 10 pre-cut record).
#   post10  Cut 10 groups and invariance pass (Cut 10 post record).
#   pre11   Cut 10 groups, invariance, invariance11 and reason11 pass; every
#           Cut 11 group fails.
#   post    every group except reason11 passes.
#
# `--against` compares every observable of the invariance arms (inv_*) and the
# lfb017 arms with an earlier record, except telemetry stamps and session IDs
# (a session ID hashes the temporary store path): the cut must
# not change them. A missing observation is a failure, never a pass.

args <- commandArgs(trailingOnly = TRUE)
modes <- c("pre", "post10", "pre11", "post")
if (length(args) < 3L || args[[2L]] != "--expect" || !args[[3L]] %in% modes) {
  stop("usage: check_record.R <record.csv> --expect pre|post10|pre11|post [--against <record.csv>]", call. = FALSE)
}
rec <- utils::read.csv(args[[1L]], stringsAsFactors = FALSE, na.strings = character())
expect <- args[[3L]]
against <- if (length(args) >= 5L && args[[4L]] == "--against") {
  utils::read.csv(args[[5L]], stringsAsFactors = FALSE, na.strings = character())
}

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

# ==== Cut 11 ===================================================================
msg <- function(arm) get(arm, "condition_message")
has <- function(x, pattern) !is.na(x) && grepl(pattern, x, fixed = TRUE)

# ---- LFB-019 (LDG-2978) --------------------------------------------------------
# Rows are cash/positions_value/equity/realized/unrealized per pulse.
# Gap, stale(2): AAA 10 flat; BBB 20, 21, 23 on days 2, 3, 5. Day 1 buys AAA
# 45 only (BBB unpriced), filled day 2 at 10: cash 550. Day 2 buys BBB 22,
# filled day 3 at 21: cash 88. Day 4 has no BBB bar: its stale mark 21 gives
# 450 + 462 = 912. Day 5: 450 + 22 * 23 = 956, unrealized 956 - 912 = 44.
gap_rows <- c("1000/0/1000/0/0", "550/450/1000/0/0", "88/912/1000/0/0", "88/912/1000/0/0", "88/956/1044/0/44")
# Freeze, stale(1): BBB's last bar is day 2 at 22, so from day 4 (age 2) the
# held 22 shares are frozen at 22. Day 4: AAA 39 at 13 plus 22 * 22 is
# 507 + 484 = 991; day 5: AAA 41 at 14 plus 484 is 1058.
freeze_rows <- c("1000/0/1000/0/0", "21/979/1000/0/0", "81/964/1045/5/40", "94/991/1085/7/78", "66/1058/1124/7/117")
for (case in list(list(arm = "lfb019_gap", rows = gap_rows, pos = c("AAA:45", "BBB:22"), skips = "2", frozen = "0"),
                  list(arm = "lfb019_freeze", rows = freeze_rows, pos = c("AAA:41", "BBB:22"), skips = "1", frozen = "3"))) {
  a <- case$arm
  check("lfb019", paste(a, "run completes with its skip and freeze rows"),
        ran(paste0(a, "_run")) && identical(get(a, "status"), "DONE") &&
          identical(get(a, "skips"), case$skips) && identical(get(a, "frozen"), case$frozen))
  check("lfb019", paste(a, "stored equity matches the fixture arithmetic"),
        identical(split_list(get(a, "stored_equity")), case$rows))
  check("lfb019", paste(a, "reconstruction succeeds and reproduces every pulse"),
        ran(a) && identical(split_list(get(a, "rebuilt_equity")), case$rows))
  check("lfb019", paste(a, "reconstructed positions"), identical(split_list(get(a, "rebuilt_positions")), case$pos))
}

# ---- Gapped carry (LDG-2979) ---------------------------------------------------
# Test windows 2020-03-02..04-01 and 2020-05-02..06-01: the 22 weekdays from
# 2020-04-02 to 2020-05-01 lie between them.
check("wfgap", "carry across the gap refuses with the gapped-carry class",
      has(get("wfgap_carry", "condition_class"), "ledgr_walk_forward_gapped_carry"))
check("wfgap", "the refusal names the first gap and both remedies",
      has(msg("wfgap_carry"), "22 unobserved pulse(s) between test window 1 (ends 2020-04-01T23:59:59Z)") &&
        has(msg("wfgap_carry"), "test window 2 (starts 2020-05-02T00:00:00Z)") &&
        has(msg("wfgap_carry"), "`step` equal to `test_window`") && has(msg("wfgap_carry"), "flat_test_state"))
check("wfgap", "nothing is written before the refusal",
      identical(get("wfgap_carry", "store_before"), "sessions=0,runs=0") &&
        identical(get("wfgap_carry", "store_after"), "sessions=0,runs=0"))

# ---- Walk-forward resume (LDG-2980) --------------------------------------------
ref_digest <- split_list(get("wfresume_reference", "digest"))
ref_equity <- unique(unlist(strsplit(vapply(strsplit(ref_digest, ":", fixed = TRUE), `[[`, "", 5L), "/", fixed = TRUE)))
check("wfresume", "the reference session completes, trades and moves",
      identical(get("wfresume_reference", "session_status"), "DONE") && length(ref_digest) >= 6L &&
        length(ref_equity) > 1L)
check("wfresume", "the interrupted attempt reaches the caller and stores a PARTIAL session",
      has(get("wfresume_interrupted", "condition_class"), "interrupt") &&
        identical(get("wfresume_interrupted", "stored_session_status"), "PARTIAL"))
check("wfresume", "rerunning completes with the uninterrupted folds, selections and test equity",
      ran("wfresume_rerun") && identical(get("wfresume_rerun", "session_status"), "DONE") &&
        identical(get("wfresume_rerun", "digest"), get("wfresume_reference", "digest")))

# ---- Fold boundaries (LDG-2991) ------------------------------------------------
check("bounds", "folds starting on the first sealed date run",
      ran("bounds_first_date") && identical(get("bounds_first_date", "session_status"), "DONE"))
check("bounds", "a start before the first date refuses and names the range",
      has(get("bounds_before_first", "condition_class"), "ledgr_walk_forward_invalid_fold_window") &&
        has(msg("bounds_before_first"), "2019-12-02") &&
        has(msg("bounds_before_first"), "sealed snapshot range 2020-01-01 to 2020-12-31"))
check("bounds", "an end after the last date refuses and names the range",
      has(get("bounds_after_last", "condition_class"), "ledgr_walk_forward_invalid_fold_window") &&
        has(msg("bounds_after_last"), "sealed snapshot range 2020-01-01 to 2020-12-31"))

# ---- Cut 11 invariance ------------------------------------------------------------
check("invariance11", "flat_test_state over the gapped folds completes",
      identical(get("inv_wfgap_flat", "session_status"), "DONE"))
stamp <- get("inv_wfresume_reopen", "stamp_before")
check("invariance11", "rerunning a finished session reopens its test runs without executing them",
      ran("inv_wfresume_reopen") && !is.na(stamp) && nzchar(stamp) && !identical(stamp, "no_telemetry_table") &&
        identical(stamp, get("inv_wfresume_reopen", "stamp_after")) &&
        identical(get("inv_wfresume_reopen", "digest_matches"), "TRUE"))
check("invariance11", "folds inside the sealed range run",
      ran("inv_bounds_inside") && identical(get("inv_bounds_inside", "session_status"), "DONE"))

# ---- Pre-cut source-table reasons (pre11 only) -----------------------------------
check("reason11", "LFB-019: reconstruction refuses with ledgr_missing_bars",
      has(get("lfb019_gap", "condition_class"), "ledgr_missing_bars") &&
        has(get("lfb019_freeze", "condition_class"), "ledgr_missing_bars"))
check("reason11", "gapped carry: the session is PARTIAL with an INCOMPLETE test run",
      identical(get("wfgap_carry", "session_status"), "PARTIAL") &&
        "INCOMPLETE" %in% split_list(get("wfgap_carry", "test_status")))
check("reason11", "resume: the rerun stops on the FAILED test run (ledgr_run_not_complete)",
      has(get("wfresume_rerun", "condition_class"), "ledgr_run_not_complete"))
check("reason11", "boundaries: the first sealed date is refused as outside the range",
      has(msg("bounds_first_date"), "inside the sealed snapshot range"))

# ---- Against an earlier record --------------------------------------------------
if (!is.null(against)) {
  key <- function(r) paste(r$arm, r$observable, sep = "|")
  pick <- function(r) r[grepl("^(inv_|lfb017_)", r$arm) & !grepl("^stamp|^session_id$", r$observable), , drop = FALSE]
  now <- pick(rec)
  then <- pick(against)
  shared <- intersect(key(now), key(then))
  same <- now$value[match(shared, key(now))] == then$value[match(shared, key(then))]
  check("against", sprintf("%d shared invariance observables unchanged", length(shared)),
        length(shared) > 0L && all(same))
  for (k in shared[!same]) cat("CHANGED", k, "\n")
}

cut10 <- c("lfb017", "lfb023", "lfb018")
cut11 <- c("lfb019", "wfgap", "wfresume", "bounds")
if (expect %in% c("pre", "post10")) results <- Filter(function(r) !r$group %in% c(cut11, "invariance11", "reason11"), results)
if (identical(expect, "post")) results <- Filter(function(r) !identical(r$group, "reason11"), results)
out <- do.call(rbind, results)
summary <- stats::aggregate(pass ~ group, data = out, FUN = function(p) sprintf("%d/%d", sum(p), length(p)))
group_pass <- tapply(out$pass, out$group, all)
for (i in seq_len(nrow(out))) if (!out$pass[[i]]) cat(sprintf("FAIL [%s] %s\n", out$group[[i]], out$check[[i]]))
print(summary, row.names = FALSE)
ok <- isTRUE(switch(expect,
  pre = isTRUE(group_pass[["invariance"]]) && !any(group_pass[cut10]),
  post10 = all(group_pass),
  pre11 = all(group_pass[c(cut10, "invariance", "invariance11", "reason11", if (!is.null(against)) "against")]) &&
    !any(group_pass[cut11]),
  post = all(group_pass)
))
cat(sprintf("%s: expectation '%s' %s\n", if (ok) "OK" else "MISMATCH", expect, if (ok) "met" else "not met"))
quit(status = if (ok) 0L else 1L)

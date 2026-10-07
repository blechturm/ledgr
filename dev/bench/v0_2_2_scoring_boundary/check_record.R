# Cut 9 scoring-boundary checker (LDG-2968).
#
# Usage:
#   Rscript check_record.R <record_dir> [--expect=boundary:pass,value:fail]
#                          [--self-test=<pre_cut_record_dir>]
#
# Every assertion belongs to one group. `boundary` asserts that no arm
# evaluates, trades, records equity or contributes metric input before its
# scoring start, and that a distinct execution start refuses. `value` asserts
# exact cross-path values, which also depend on where feature state starts and
# therefore stay red until Workstream 19. Expected values are derived from the
# fixture alone: day d has open = close = d, SMA(3), next-open fills, one
# share once SMA is finite, initial equity 1000.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) stop("usage: check_record.R <record_dir> [--expect=...] [--self-test=<dir>]", call. = FALSE)
record_dir <- args[[1L]]
flag <- function(name) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else NULL
}

day_iso <- function(d) format(as.Date("2020-01-01") + d - 1L, "%Y-%m-%dT00:00:00Z")
initial <- 1000
price <- function(d) d
scoring_start <- 6L
scoring_end <- 10L
train <- c(6L, 8L)
test <- c(9L, 10L)
execution_start_class <- "ledgr_unsupported_execution_start"
hydration_class <- "ledgr_unsupported_hydration_start"

# EMA fixture: closes 30 on days 1-5, then 6..10, opening on day 6. Restarted
# at day 6, TTR's EMA(3) seeds with the mean of the first three closes and then
# recurses with alpha 0.5; ledgr_ind_ema(3) is the four-bar filter with weights
# 0.5, 0.25, 0.125, 0.125. The strategy holds one share while the recursive EMA
# is below 9, so it buys on day 8 (7 < 9), fills at the day-9 open of 9 and is
# valued at the day-10 close of 10; the day-10 exit cannot fill.
ema_restart <- local({
  closes <- 6:10
  recursive <- rep(NA_real_, 5L)
  recursive[[3L]] <- mean(closes[1:3])
  for (i in 4:5) recursive[[i]] <- 0.5 * closes[[i]] + 0.5 * recursive[[i - 1L]]
  weights <- c(0.5, 0.25, 0.125, 0.125)
  bounded <- rep(NA_real_, 5L)
  for (i in 4:5) bounded[[i]] <- sum(weights * closes[i:(i - 3L)])
  list(recursive = recursive, bounded = bounded, final = initial - 9 + 10)
})

# Final equity when SMA(3) state starts at `feature_start` and the strategy is
# evaluated over [start, end]: first finite SMA on max(start, feature_start + 2),
# one share filled at the next open if that open is inside the window.
final_equity <- function(start, end, feature_start) {
  decision <- max(start, feature_start + 2L)
  fill <- decision + 1L
  if (fill > end) initial else initial - price(fill) + price(end)
}
# Upper bound on final equity for any fill that respects the boundary: the
# earliest permitted fill is the open after the scoring start.
boundary_bound <- function(start, end) initial - price(start + 1L) + price(end)

read_record <- function(dir) {
  utils::read.csv(file.path(dir, "observations.csv"), stringsAsFactors = FALSE,
                  colClasses = "character")
}

assertions <- function(obs) {
  key <- paste(obs$arm, obs$observable, sep = "/")
  v <- function(arm, observable) {
    hit <- match(paste(arm, observable, sep = "/"), key)
    if (is.na(hit)) NA_character_ else obs$value[[hit]]
  }
  num <- function(arm, observable) as.numeric(v(arm, observable))
  out <- list()
  add <- function(group, arm, observable, ok, detail) {
    out[[length(out) + 1L]] <<- data.frame(
      group = group, arm = arm, observable = observable,
      pass = isTRUE(ok), detail = detail, stringsAsFactors = FALSE
    )
  }
  integral <- function(x, n) is.finite(x) && abs(x * n - round(x * n)) < 1e-9

  durable <- list(run = c(6L, 10L), backtest = c(6L, 10L), promote = c(6L, 10L),
                  run_window = c(6L, 10L), walk_forward_test = test)
  for (arm in names(durable)) {
    w <- durable[[arm]]
    n <- w[[2L]] - w[[1L]] + 1L
    fills <- strsplit(v(arm, "fill_ts"), ",", fixed = TRUE)[[1L]]
    ledger_first <- v(arm, "ledger_first_ts")
    add("boundary", arm, "equity_first_ts", identical(v(arm, "equity_first_ts"), day_iso(w[[1L]])),
        sprintf("expected %s, got %s", day_iso(w[[1L]]), v(arm, "equity_first_ts")))
    add("boundary", arm, "equity_n", identical(num(arm, "equity_n"), as.numeric(n)),
        sprintf("expected %d, got %s", n, v(arm, "equity_n")))
    add("boundary", arm, "state_first_ts", identical(v(arm, "state_first_ts"), day_iso(w[[1L]])),
        sprintf("expected %s, got %s", day_iso(w[[1L]]), v(arm, "state_first_ts")))
    add("boundary", arm, "state_n", identical(num(arm, "state_n"), as.numeric(n)),
        sprintf("expected %d, got %s", n, v(arm, "state_n")))
    add("boundary", arm, "fill_ts", all(fills > day_iso(w[[1L]])),
        sprintf("fills after %s: %s", day_iso(w[[1L]]), v(arm, "fill_ts")))
    add("boundary", arm, "ledger_first_ts",
        !nzchar(ledger_first) || ledger_first >= day_iso(w[[1L]]),
        sprintf("first ledger event %s", ledger_first))
  }
  for (arm in c("sweep", "sweep_window")) {
    n <- scoring_end - scoring_start + 1L
    add("boundary", arm, "scoring_start", identical(v(arm, "scoring_start"), day_iso(scoring_start)),
        sprintf("expected %s, got %s", day_iso(scoring_start), v(arm, "scoring_start")))
    add("boundary", arm, "returns_first_ts", identical(v(arm, "returns_first_ts"), day_iso(scoring_start)),
        sprintf("expected %s, got %s", day_iso(scoring_start), v(arm, "returns_first_ts")))
    add("boundary", arm, "returns_n", identical(num(arm, "returns_n"), as.numeric(n)),
        sprintf("expected %d, got %s", n, v(arm, "returns_n")))
    add("boundary", arm, "final_equity", num(arm, "final_equity") <= boundary_bound(scoring_start, scoring_end),
        sprintf("bound %g, got %s", boundary_bound(scoring_start, scoring_end), v(arm, "final_equity")))
    add("boundary", arm, "time_in_market", integral(num(arm, "time_in_market"), n),
        sprintf("%s over %d scoring pulses", v(arm, "time_in_market"), n))
  }
  n_train <- train[[2L]] - train[[1L]] + 1L
  add("boundary", "walk_forward", "train_scoring_start", identical(v("walk_forward", "train_scoring_start"), day_iso(train[[1L]])),
      sprintf("got %s", v("walk_forward", "train_scoring_start")))
  add("boundary", "walk_forward", "test_scoring_start", identical(v("walk_forward", "test_scoring_start"), day_iso(test[[1L]])),
      sprintf("got %s", v("walk_forward", "test_scoring_start")))
  add("boundary", "walk_forward", "train_final_equity",
      num("walk_forward", "train_final_equity") <= boundary_bound(train[[1L]], train[[2L]]),
      sprintf("bound %g, got %s", boundary_bound(train[[1L]], train[[2L]]), v("walk_forward", "train_final_equity")))
  add("boundary", "walk_forward", "train_time_in_market", integral(num("walk_forward", "train_time_in_market"), n_train),
      sprintf("%s over %d training pulses", v("walk_forward", "train_time_in_market"), n_train))
  add("boundary", "execution_start", "outcome", identical(v("execution_start", "outcome"), execution_start_class),
      sprintf("expected %s, got %s", execution_start_class, v("execution_start", "outcome")))

  restart_full <- final_equity(scoring_start, scoring_end, scoring_start)
  add("value", "run", "sma_seen", identical(v("run", "sma_seen"), "NA,NA,7,8,9"),
      sprintf("got %s", v("run", "sma_seen")))
  add("value", "run", "final_equity", identical(num("run", "final_equity"), restart_full),
      sprintf("expected %g, got %s", restart_full, v("run", "final_equity")))
  add("value", "sweep", "final_equity", identical(num("sweep", "final_equity"), num("promote", "final_equity")),
      sprintf("sweep %s, promoted run %s", v("sweep", "final_equity"), v("promote", "final_equity")))
  add("value", "sweep_window", "final_equity", identical(num("sweep_window", "final_equity"), num("run_window", "final_equity")),
      sprintf("window sweep %s, window run %s", v("sweep_window", "final_equity"), v("run_window", "final_equity")))
  restart_train <- final_equity(train[[1L]], train[[2L]], train[[1L]])
  restart_test <- final_equity(test[[1L]], test[[2L]], test[[1L]])
  add("value", "walk_forward", "train_final_equity", identical(num("walk_forward", "train_final_equity"), restart_train),
      sprintf("training uses the test rule: expected %g, got %s", restart_train, v("walk_forward", "train_final_equity")))
  add("value", "walk_forward_test", "final_equity", identical(num("walk_forward_test", "final_equity"), restart_test),
      sprintf("expected %g, got %s", restart_test, v("walk_forward_test", "final_equity")))

  # Workstream 19 feature-start contract (LDG-2970).
  add("value", "backtest", "final_equity", identical(num("backtest", "final_equity"), num("run", "final_equity")),
      sprintf("backtest %s, run %s", v("backtest", "final_equity"), v("run", "final_equity")))
  add("value", "precompute", "warmup_start", identical(v("precompute", "warmup_start"), day_iso(scoring_start)),
      sprintf("default precompute warmup starts %s", v("precompute", "warmup_start")))
  add("value", "precompute", "scoring_start", identical(v("precompute", "scoring_start"), day_iso(scoring_start)),
      sprintf("default precompute scoring starts %s", v("precompute", "scoring_start")))
  add("value", "precompute_explicit", "warmup_start", identical(v("precompute_explicit", "warmup_start"), day_iso(scoring_start)),
      sprintf("explicit start precompute warmup starts %s", v("precompute_explicit", "warmup_start")))
  add("value", "precompute_sweep", "final_equity", identical(num("precompute_sweep", "final_equity"), restart_full),
      sprintf("expected %g, got %s", restart_full, v("precompute_sweep", "final_equity")))
  add("value", "hydration", "window_hydration_start", identical(v("hydration", "window_hydration_start"), day_iso(scoring_start)),
      sprintf("omitted hydration stored as %s", v("hydration", "window_hydration_start")))
  add("value", "walk_forward", "hydration_start", identical(v("walk_forward", "hydration_start"), day_iso(train[[1L]])),
      sprintf("fold hydration stored as %s", v("walk_forward", "hydration_start")))
  add("value", "hydration", "earlier_outcome", identical(v("hydration", "earlier_outcome"), hydration_class),
      sprintf("expected %s, got %s", hydration_class, v("hydration", "earlier_outcome")))

  seen <- function(arm, observable) suppressWarnings(as.numeric(strsplit(v(arm, observable), ",", fixed = TRUE)[[1L]]))
  same <- function(x, y) length(x) == length(y) && identical(is.na(x), is.na(y)) && all(x[!is.na(x)] == y[!is.na(y)])
  add("value", "ema_run", "recursive_seen", same(seen("ema_run", "recursive_seen"), ema_restart$recursive),
      sprintf("expected %s, got %s", paste(ema_restart$recursive, collapse = ","), v("ema_run", "recursive_seen")))
  add("value", "ema_run", "bounded_seen", same(seen("ema_run", "bounded_seen"), ema_restart$bounded),
      sprintf("expected %s, got %s", paste(ema_restart$bounded, collapse = ","), v("ema_run", "bounded_seen")))
  add("value", "ema_run", "final_equity", identical(num("ema_run", "final_equity"), ema_restart$final),
      sprintf("expected %g, got %s", ema_restart$final, v("ema_run", "final_equity")))
  for (arm in c("ema_sweep", "ema_promote")) {
    add("value", arm, "final_equity", identical(num(arm, "final_equity"), ema_restart$final),
        sprintf("expected %g, got %s", ema_restart$final, v(arm, "final_equity")))
  }
  do.call(rbind, out)
}

group_pass <- function(table, group) all(table$pass[table$group == group])

# A boundary-correct record under Workstream 18 semantics: durable arms restart
# feature state at their window start, sweeps keep hydrated features but act
# only from the scoring start, and a distinct execution start refuses. Used as
# the self-test base before a boundary-correct record exists.
reference_record <- function() {
  rows <- list()
  put <- function(arm, observable, value) {
    rows[[length(rows) + 1L]] <<- data.frame(arm = arm, observable = observable,
                                             value = as.character(value), stringsAsFactors = FALSE)
  }
  durable <- list(run = c(6L, 10L), backtest = c(6L, 10L), promote = c(6L, 10L),
                  run_window = c(6L, 10L), walk_forward_test = test)
  for (arm in names(durable)) {
    w <- durable[[arm]]
    fill <- w[[1L]] + 3L
    put(arm, "equity_first_ts", day_iso(w[[1L]]))
    put(arm, "equity_n", w[[2L]] - w[[1L]] + 1L)
    put(arm, "state_first_ts", day_iso(w[[1L]]))
    put(arm, "state_n", w[[2L]] - w[[1L]] + 1L)
    put(arm, "fill_ts", if (fill <= w[[2L]]) day_iso(fill) else "")
    put(arm, "ledger_first_ts", if (fill <= w[[2L]]) day_iso(fill) else "")
    put(arm, "final_equity", final_equity(w[[1L]], w[[2L]], w[[1L]]))
  }
  put("run", "sma_seen", "NA,NA,7,8,9")
  for (arm in c("sweep", "sweep_window")) {
    put(arm, "scoring_start", day_iso(scoring_start))
    put(arm, "returns_first_ts", day_iso(scoring_start))
    put(arm, "returns_n", scoring_end - scoring_start + 1L)
    put(arm, "final_equity", final_equity(scoring_start, scoring_end, 1L))
    put(arm, "time_in_market", (scoring_end - scoring_start - 1L) / (scoring_end - scoring_start + 1L))
  }
  put("walk_forward", "train_scoring_start", day_iso(train[[1L]]))
  put("walk_forward", "test_scoring_start", day_iso(test[[1L]]))
  put("walk_forward", "train_final_equity", final_equity(train[[1L]], train[[2L]], 1L))
  put("walk_forward", "train_time_in_market", 2 / 3)
  put("execution_start", "outcome", execution_start_class)
  do.call(rbind, rows)
}

self_test <- function(record, pre_cut_dir) {
  pre_cut <- read_record(pre_cut_dir)
  base <- record
  base_label <- "candidate record"
  if (!group_pass(assertions(base), "boundary")) {
    base <- reference_record()
    base_label <- "fixture-derived reference"
  }
  if (!group_pass(assertions(base), "boundary")) stop("self-test base fails its boundary group", call. = FALSE)
  guts <- c(ordinary_sweep = "sweep", window_sweep = "sweep_window", walk_forward = "walk_forward")
  for (gut in names(guts)) {
    arm <- guts[[gut]]
    spliced <- rbind(base[base$arm != arm, c("arm", "observable", "value")],
                     pre_cut[pre_cut$arm == arm, c("arm", "observable", "value")])
    table <- assertions(spliced)
    failed <- table[table$group == "boundary" & !table$pass, , drop = FALSE]
    if (nrow(failed) == 0L || any(failed$arm != arm)) {
      stop(sprintf("gut %s did not fail the boundary group on arm %s alone", gut, arm), call. = FALSE)
    }
    cat(sprintf("GUT %-15s fails boundary on %s: %s\n", gut, arm,
                paste(unique(failed$observable), collapse = ", ")))
  }
  cat(sprintf("SELF-TEST OK (base: %s)\n", base_label))
}

record <- read_record(record_dir)
table <- assertions(record)
for (i in seq_len(nrow(table))) {
  cat(sprintf("%-8s %-5s %-18s %-22s %s\n", table$group[[i]], if (table$pass[[i]]) "PASS" else "FAIL",
              table$arm[[i]], table$observable[[i]], table$detail[[i]]))
}
status <- c(boundary = group_pass(table, "boundary"), value = group_pass(table, "value"))
cat(sprintf("GROUPS boundary=%s value=%s\n",
            if (status[["boundary"]]) "pass" else "fail", if (status[["value"]]) "pass" else "fail"))

pre_cut_dir <- flag("self-test")
if (!is.null(pre_cut_dir)) self_test(record, pre_cut_dir)

expect <- flag("expect")
if (!is.null(expect)) {
  pairs <- strsplit(strsplit(expect, ",", fixed = TRUE)[[1L]], ":", fixed = TRUE)
  wanted <- stats::setNames(vapply(pairs, `[[`, character(1), 2L) == "pass", vapply(pairs, `[[`, character(1), 1L))
  if (!identical(unname(status[names(wanted)]), unname(wanted))) {
    stop(sprintf("group status differs from --expect=%s", expect), call. = FALSE)
  }
  cat("LEDGR_SCORING_BOUNDARY_EXPECTATION_MET", expect, "\n")
}

# Cut 18 (LDG-3234): statement clocks for the census's statements.
#
#   Rscript dev/lean_core/parity/cut18_clocks.R --lib=<pinned library> --out=<dir> [--rounds=3]
#     [--shapes=10x7200,slice2_10x7200]
# Internal: --mode=arm --arm=plain|clocked --shape=<id> --rds=<file>
#
# The clocked arm parses loop.R and plan.R, wraps every top-level statement
# of every census function in a clock (nanotime reads into one environment,
# a count beside), evaluates the result into the lean environment and runs
# the descriptor's committed run with the lean loop installed; the plain arm
# runs the unmodified sources. Both must produce the same fills and equity.
# Clocks are gross: a statement that calls another census function includes
# that function's statements and their clocks. A statement left by return()
# or an error is not counted for that evaluation; such statements are marked.
# Writes statement_cost.csv (us per pulse and evaluations per pulse, median
# of the rounds) and clock_runs.csv (loop seconds per arm and round).

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
source(file.path(here, "cut18_census.R"))

# Small or per-read helpers are not clocked: their clocks would cost more
# than their work. Their time is inside the clocked statement that calls
# them (statement_cost.csv leaves them NA).
cut18_unclocked <- c("lean_ctx_dollar", "lean_strategy_view", "feature_fn", "schedule_fn", "lean_ctx_helpers", "lean_gross",
                     "check_uncovered", "lean_not_covered", "grow", "lean_plan_segments", "lean_plan_empty_segments",
                     "lean_plan_segment_rows", "lean_plan_id_rank", "lean_exec_view", "plan")

# Compound statements whose block statements are clocked as well (the
# inventory's line-range rows sit inside them).
cut18_inner <- c("loop.R|lean_p4_apply|8", "loop.R|lean_p3_plan|8")
cut18_inner_text <- list()

# Statement ids of each clocked census function, in body order.
cut18_statement_ids <- function(census) {
  s <- attr(census, "statements")
  s <- s[!s$fn %in% cut18_unclocked & !s$debug_fn, ]
  lapply(split(s, s$fn), function(x) x$statement[order(as.integer(sub(".*\\|", "", x$statement)))])
}

cut18_wrap <- function(stmt, key) {
  bquote({
    .c18_t0 <- .c18_now()
    .c18_v <- .(stmt)
    .c18[[.(key)]] <- .c18[[.(key)]] + (.c18_now() - .c18_t0)
    .c18[[.(paste0("n_", key))]] <- .c18[[.(paste0("n_", key))]] + 1
    .c18_v
  })
}

# Wraps the statements of every named census function inside `x`.
cut18_instrument <- function(x, ids, keys) {
  if (!is.call(x)) return(x)
  if (identical(x[[1L]], as.name("<-")) && is.name(x[[2L]]) && as.character(x[[2L]]) %in% names(ids) &&
      is.call(x[[3L]]) && identical(x[[3L]][[1L]], as.name("function"))) {
    nm <- as.character(x[[2L]]); f <- x[[3L]]
    body <- cut18_instrument(f[[3L]], ids, keys)
    st <- ids[[nm]]
    if (is.call(body) && identical(body[[1L]], as.name("{"))) {
      if (length(body) - 1L != length(st)) stop("cut18: statement count differs for ", nm)
      for (k in seq_along(st)) {
        s <- body[[k + 1L]]
        # Inner clocks: the statements of an `if (...) { ... }` block, keyed <key>_<j>.
        if (st[[k]] %in% cut18_inner && is.call(s) && identical(s[[1L]], as.name("if")) && is.call(s[[3L]]) &&
            identical(s[[3L]][[1L]], as.name("{"))) {
          for (j in seq_len(length(s[[3L]]) - 1L)) {
            cut18_inner_text[[paste0(st[[k]], "@", j)]] <<- paste(deparse(s[[3L]][[j + 1L]]), collapse = " ")
            s[[3L]][[j + 1L]] <- cut18_wrap(s[[3L]][[j + 1L]], paste0(keys[[st[[k]]]], "_", j))
          }
        }
        body[[k + 1L]] <- cut18_wrap(s, keys[[st[[k]]]])
      }
    } else {
      if (length(st) != 1L) stop("cut18: statement count differs for ", nm)
      body <- cut18_wrap(body, keys[[st[[1L]]]])
    }
    f[[3L]] <- body
    if (length(f) >= 4L) f[[4L]] <- NULL   # drop the srcref
    x[[3L]] <- f
    return(x)
  }
  for (i in seq_along(x)) if (!is.null(x[[i]]) && !(is.name(x[[i]]) && !nzchar(as.character(x[[i]])))) x[[i]] <- cut18_instrument(x[[i]], ids, keys)
  x
}

cut18_lean_env <- function(clocked) {
  suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
  ns <- asNamespace("ledgr")
  defs <- new.env(parent = ns)
  sys.source(file.path(repo, "dev/spikes/r_floor/fixture.R"), envir = defs, keep.source = FALSE)
  sys.source(file.path(repo, "dev/bench/v0_2_3_lean_tuning_profile/descriptors.R"), envir = defs, keep.source = FALSE)
  lean <- new.env(parent = ns)
  lean$.lean_debug <- FALSE
  sys.source(file.path(repo, "dev/lean_core/fifo.R"), envir = lean, keep.source = FALSE)
  keys <- NULL
  if (clocked) {
    census <- cut18_census(readLines(file.path(repo, "dev/lean_core/loop.R")), readLines(file.path(repo, "dev/lean_core/plan.R")))
    ids <- cut18_statement_ids(census)
    st <- unlist(ids, use.names = FALSE)
    keys <- stats::setNames(sprintf("s%03d", seq_along(st)), st)
    lean$.c18 <- new.env(parent = emptyenv())
    for (k in keys) { assign(k, 0, envir = lean$.c18); assign(paste0("n_", k), 0, envir = lean$.c18) }
    for (s in intersect(cut18_inner, names(keys))) for (j in 1:80) {
      assign(paste0(keys[[s]], "_", j), 0, envir = lean$.c18); assign(paste0("n_", keys[[s]], "_", j), 0, envir = lean$.c18)
    }
    lean$.c18_now <- microbenchmark::get_nanotime
    for (f in c("plan.R", "loop.R")) {
      ex <- parse(file.path(repo, "dev/lean_core", f), keep.source = FALSE)
      for (e in ex) eval(cut18_instrument(e, ids, keys), envir = lean)
    }
  } else {
    for (f in c("plan.R", "loop.R")) sys.source(file.path(repo, "dev/lean_core", f), envir = lean, keep.source = FALSE)
  }
  sys.source(file.path(repo, "dev/lean_core/loop_harness.R"), envir = lean, keep.source = FALSE)
  for (f in ls(lean, all.names = TRUE)) if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
  list(ns = ns, defs = defs, lean = lean, keys = keys)
}

if (identical(opt("mode"), "arm")) {
  env <- cut18_lean_env(identical(opt("arm"), "clocked"))
  desc <- env$defs$bench_descriptor(opt("shape"))
  store <- tempfile(fileext = ".duckdb")
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "c18", price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(store, "c18", verify = TRUE)
  exp <- desc$experiment(snapshot)
  restore <- env$lean$lean_loop_install()
  folds0 <- env$lean$lean_entry$lean_folds %||% 0L
  invisible(gc(FALSE))
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "c18", seed = 20260530L))
  if (env$lean$lean_entry$lean_folds - folds0 != 1L) stop("the lean loop did not run once")
  fills <- as.data.frame(ledgr::ledgr_results(bt, "fills")); equity <- as.data.frame(ledgr::ledgr_results(bt, "equity"))
  close(bt); restore(); ledgr::ledgr_snapshot_close(snapshot)
  cost <- if (!is.null(env$keys)) {
    # inner clocks: <statement>@<block statement number> for those that ran
    inner <- grep("^s[0-9]+_[0-9]+$", ls(env$lean$.c18), value = TRUE)
    inner <- inner[vapply(inner, function(k) get(paste0("n_", k), envir = env$lean$.c18) > 0, TRUE)]
    owner <- names(env$keys)[match(sub("_[0-9]+$", "", inner), env$keys)]
    allk <- c(env$keys, stats::setNames(inner, paste0(owner, "@", sub("^s[0-9]+_", "", inner))))
    data.frame(statement = names(allk), ns = vapply(allk, function(k) get(k, envir = env$lean$.c18), 0),
               n = vapply(allk, function(k) get(paste0("n_", k), envir = env$lean$.c18), 0), stringsAsFactors = FALSE)
  }
  cal <- NULL
  if (!is.null(env$keys)) {
    # Tick calibration: 1,000 clocked empty statements, compiled like the loop.
    assign("cal", 0, envir = env$lean$.c18); assign("n_cal", 0, envir = env$lean$.c18)
    f <- function() NULL
    body(f) <- as.call(c(as.name("{"), replicate(1000L, cut18_wrap(quote(NULL), "cal"), simplify = FALSE)))
    environment(f) <- env$lean; f <- compiler::cmpfun(f)
    f(); assign("cal", 0, envir = env$lean$.c18); assign("n_cal", 0, envir = env$lean$.c18)
    t0 <- env$lean$.c18_now(); for (r in 1:50) f(); full <- env$lean$.c18_now() - t0
    n <- get("n_cal", envir = env$lean$.c18)
    cal <- c(full_ns = full / n, inner_ns = get("cal", envir = env$lean$.c18) / n)
  }
  saveRDS(list(loop_s = env$lean$lean_loop_last_times$pulses, pulses = nrow(equity), cal = cal, inner_text = cut18_inner_text,
               signature = digest::digest(list(fills[setdiff(names(fills), "recording_pulse_ts_utc")], equity)), cost = cost), opt("rds"))
  quit(status = 0L)
}

out <- opt("out"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
rounds <- as.integer(opt("rounds", "3"))
shapes <- strsplit(opt("shapes", "10x7200,slice2_10x7200"), ",")[[1L]]
rscript <- file.path(R.home("bin"), "Rscript.exe")
runs <- list(); costs <- list(); inner_text <- list()
for (s in shapes) for (k in seq_len(rounds)) for (arm in if (k %% 2L) c("plain", "clocked") else c("clocked", "plain")) {
  rds <- tempfile(fileext = ".rds")
  st <- system2(rscript, c(file.path(here, "cut18_clocks.R"), paste0("--lib=", lib), "--mode=arm", paste0("--arm=", arm),
                           paste0("--shape=", s), paste0("--rds=", rds)))
  if (st != 0L) stop("arm ", arm, " on ", s, " failed")
  r <- readRDS(rds)
  runs[[length(runs) + 1L]] <- data.frame(shape = s, round = k, arm = arm, loop_s = r$loop_s, pulses = r$pulses, signature = r$signature)
  if (!is.null(r$cost)) costs[[length(costs) + 1L]] <- cbind(shape = s, round = k, r$cost, full_ns = r$cal[["full_ns"]],
                                                             inner_ns = r$cal[["inner_ns"]])
  if (length(r$inner_text)) inner_text <- r$inner_text
  cat(sprintf("%-15s round %d %-7s loop %.2f s\n", s, k, arm, r$loop_s))
}
runs <- do.call(rbind, runs); costs <- do.call(rbind, costs)
utils::write.csv(runs, file.path(out, "clock_runs.csv"), row.names = FALSE)
same <- tapply(runs$signature, runs$shape, function(v) length(unique(v)) == 1L)
# Net cost: the gross clock less the statement's own inner tick and the full
# ticks of the clocked statements it runs through calls (the census call
# graph; a function called from several statements charges each of them its
# whole count, flagged in `shared_callee`).
census <- cut18_census(readLines(file.path(repo, "dev/lean_core/loop.R")), readLines(file.path(repo, "dev/lean_core/plan.R")))
clocked_fns <- names(cut18_statement_ids(census))
calls <- unique(census[census$token == "SYMBOL_FUNCTION_CALL" & census$text %in% clocked_fns & !census$debug, c("statement", "text")])
callers <- table(calls$text)
# An inner block statement calls what its text calls; its outer statement
# also carries the inner clocks' own ticks.
for (nm in names(inner_text)) for (f in clocked_fns) {
  if (grepl(paste0("(^|[^A-Za-z0-9_.])", f, "\\("), inner_text[[nm]])) calls <- rbind(calls, data.frame(statement = nm, text = f))
}
summ <- do.call(rbind, lapply(split(costs, list(costs$shape, costs$statement), drop = TRUE), function(x) {
  p <- runs$pulses[runs$shape == x$shape[[1L]]][[1L]]
  data.frame(shape = x$shape[[1L]], statement = x$statement[[1L]], fn = strsplit(x$statement[[1L]], "|", fixed = TRUE)[[1L]][[2L]],
             gross_us = stats::median(x$ns) / 1e3 / p, evals = stats::median(x$n) / p,
             full_ns = stats::median(x$full_ns), inner_ns = stats::median(x$inner_ns))
}))
nested <- function(fn_evals, st, seen = character()) {     # clocked evaluations reached through calls of statement st
  callee <- setdiff(calls$text[calls$statement == st], seen)
  sum(vapply(callee, function(f) {
    own <- fn_evals[[f]]
    own + sum(vapply(summ_s$statement[summ_s$fn == f], function(s2) nested(fn_evals, s2, c(seen, f)), 0))
  }, 0))
}
# The empty-statement calibration understates a tick inside the loop (deeper
# variable lookups), so the effective full tick is the measured loop
# overhead over the clocked evaluations per pulse, split into its inner part
# by the calibrated ratio. The pulse statement then reconciles with the
# plain loop by construction; a statement's net figure is good to about one
# tick (about 1.5 us) per evaluation, its own and nested.
loop_us <- function(s, a) 1e6 * stats::median(runs$loop_s[runs$shape == s & runs$arm == a]) / 7200
summ <- do.call(rbind, lapply(split(summ, summ$shape), function(summ_s) {
  summ_s <<- summ_s
  s <- summ_s$shape[[1L]]
  full_eff <- 1e3 * (loop_us(s, "clocked") - loop_us(s, "plain")) / sum(summ_s$evals)
  inner_eff <- full_eff * summ_s$inner_ns[[1L]] / summ_s$full_ns[[1L]]
  fn_evals <- tapply(summ_s$evals, summ_s$fn, sum)
  summ_s$nested_evals <- vapply(summ_s$statement, function(s) nested(fn_evals, s) +
    sum(summ_s$evals[startsWith(summ_s$statement, paste0(s, "@"))]), 0)
  summ_s$tick_ns <- full_eff
  summ_s$net_us <- summ_s$gross_us - (summ_s$evals * inner_eff + summ_s$nested_evals * full_eff) / 1e3
  summ_s$shared_callee <- vapply(summ_s$statement, function(s) any(callers[calls$text[calls$statement == s]] > 1L), TRUE)
  summ_s
}))
utils::write.csv(summ[order(summ$shape, summ$statement), ], file.path(out, "statement_cost.csv"), row.names = FALSE)
loops <- aggregate(loop_s ~ shape + arm, runs, stats::median)
loops$us_per_pulse <- 1e6 * loops$loop_s / 7200
# Reconciliation: run_loop's pulse statement, net, against the plain loop.
recon <- summ[summ$fn == "run_loop" & summ$evals > 0.0001 & summ$evals < 0.01, c("shape", "statement", "gross_us", "net_us")]
print(loops); print(recon); print(same)
utils::write.csv(loops, file.path(out, "clock_loops.csv"), row.names = FALSE)
quit(status = if (all(same)) 0L else 1L)

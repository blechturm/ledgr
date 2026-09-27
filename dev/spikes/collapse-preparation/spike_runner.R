# Runner for the collapse::rsplit() preparation spike.
#
# Question: can collapse::rsplit() materially reduce the time or allocation
# cost of ledgr's bars-by-instrument preparation while preserving what is
# consumed downstream? Two alternatives only: production base split() and
# collapse::rsplit(x, f, sort = TRUE, simplify = FALSE).
#
# The seam is in memory: each production function body is copied, its single
# split() call is replaced, and the copy is bound in the loaded namespace for
# one call. Split inputs are captured from real production calls (DuckDB query
# included); containing steps evaluate the production statements verbatim.
#
# Usage, from the repository root:
#   Rscript dev/spikes/collapse-preparation/spike_runner.R \
#       [--phase parity|all] [--out <dir>] [--reps <n>] [--gut none|misgroup]
# parity writes fixture.csv, parity.csv, downstream.csv and environment.csv;
# all adds timing.csv, timing_summary.csv and memory.csv.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
script_path <- local({
  f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  normalizePath(sub("^--file=", "", f[[1L]]), winslash = "/")
})
spike_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
phase <- arg_value("--phase", "all")
out_dir <- arg_value("--out", file.path(spike_dir, "evidence"))
reps <- as.integer(arg_value("--reps", "15"))
gut <- arg_value("--gut", "none")
stopifnot(phase %in% c("parity", "all"), gut %in% c("none", "misgroup"), reps >= 3L)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

dll <- file.path(repo_root, "src", paste0("ledgr", .Platform$dynlib.ext))
if (!file.exists(dll)) {
  stop("Compile the package once before running: load_all(compile = FALSE) never compiles. ",
    "A first compile rewrites R/cpp11.R and src/cpp11.cpp line endings; restore them with git checkout.")
}
suppressMessages(pkgload::load_all(repo_root, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
write_ev <- function(x, name) utils::write.csv(x, file.path(out_dir, name), row.names = FALSE)
log_line <- function(...) cat(sprintf("[%s] ", format(Sys.time(), "%H:%M:%S")), ..., "\n", sep = "")

# ---- seam -------------------------------------------------------------------
PRECOMPUTE_SPLIT <- quote(split(rows, rows$instrument_id))
RUNNER_SPLIT <- quote(split(bars_all, as.character(bars_all$instrument_id)))

replace_call <- function(expr, target, replacement) {
  hits <- 0L
  walk <- function(e) {
    if (is.call(e)) {
      if (identical(e, target)) { hits <<- hits + 1L; return(replacement) }
      for (i in seq_along(e)) if (!is.null(e[[i]])) e[[i]] <- walk(e[[i]])
    }
    e
  }
  out <- walk(expr)
  if (hits != 1L) stop(sprintf("expected exactly one production split() site, found %d", hits))
  out
}
splice <- function(target, splitter) as.call(c(list(splitter), as.list(target)[-1L]))
seam <- function(name, target, splitter) {
  f <- get(name, envir = ns)
  body(f) <- replace_call(body(f), target, splice(target, splitter))
  f
}
with_binding <- function(name, value, code) {
  old <- get(name, envir = ns)
  unlockBinding(name, ns); assign(name, value, envir = ns)
  on.exit({ assign(name, old, envir = ns); lockBinding(name, ns) }, add = TRUE)
  force(code)
}

split_base <- function(x, f) split(x, f)
split_rsplit <- if (identical(gut, "misgroup")) {
  function(x, f) collapse::rsplit(x, c(f[-1L], f[1L]), sort = TRUE, simplify = FALSE) # deliberate gut
} else {
  function(x, f) collapse::rsplit(x, f, sort = TRUE, simplify = FALSE)
}
split_rsplit_unpinned <- function(x, f) collapse::rsplit(x, f, simplify = FALSE)

# Production statements around each split site, extracted from the loaded code.
statements <- function(block) as.list(block)[-1L]
is_assign_to <- function(s, name) is.call(s) && identical(s[[1L]], as.name("<-")) && identical(s[[2L]], as.name(name))
find_call <- function(e, pred) {
  if (pred(e)) return(e)
  if (is.call(e)) for (i in seq_along(e)) if (!is.null(e[[i]])) { r <- find_call(e[[i]], pred); if (!is.null(r)) return(r) }
  NULL
}
fold_body <- body(get("ledgr_run_fold", envir = ns))
cache_block <- find_call(fold_body, function(e) is.call(e) && identical(e[[1L]], as.name("if")) &&
  identical(e[[2L]], quote(isTRUE(use_bars_cache))))[[3L]]
cache_stmts <- statements(cache_block)
k_bars <- which(vapply(cache_stmts, is_assign_to, logical(1), name = "bars_all"))
RUNNER_BLOCK <- replace_call(as.call(c(as.name("{"), cache_stmts[(k_bars + 1L):length(cache_stmts)])),
  RUNNER_SPLIT, quote(.spike_split(bars_all, as.character(bars_all$instrument_id))))
BAR_COL_MAP <- find_call(fold_body, function(e) is_assign_to(e, "bar_col_map"))
fetch_stmts <- statements(body(get("ledgr_precompute_fetch_bars", envir = ns)))
k_rows <- which(vapply(fetch_stmts, is_assign_to, logical(1), name = "rows"))
FETCH_PRE <- as.call(c(as.name("{"), fetch_stmts[seq_len(k_rows)]))
FETCH_POST <- replace_call(as.call(c(as.name("{"), fetch_stmts[(k_rows + 1L):length(fetch_stmts)])),
  PRECOMPUTE_SPLIT, quote(.spike_split(rows, rows$instrument_id)))
stopifnot(length(k_bars) == 1L, length(k_rows) == 1L, !is.null(BAR_COL_MAP))

eval_runner_block <- function(bars_all, instrument_ids, pulses_posix, availability_active, splitter) {
  env <- new.env(parent = ns)
  env$bars_all <- bars_all
  env$instrument_ids <- instrument_ids
  env$pulses <- pulses_posix
  env$pulses_posix <- pulses_posix
  env$availability_active <- availability_active
  env$fail_run <- function(msg, class = NULL, ...) stop(msg, call. = FALSE)
  env$.spike_split <- splitter
  eval(BAR_COL_MAP, env)
  eval(RUNNER_BLOCK, env)
  env
}
query_rows <- function(snapshot, universe, start, end) {
  env <- new.env(parent = ns)
  env$snapshot <- snapshot; env$universe <- universe; env$start <- start; env$end <- end
  eval(FETCH_PRE, env)
  env$rows
}
run_fetch_post <- function(rows, splitter) {
  env <- new.env(parent = ns)
  env$rows <- rows
  env$.spike_split <- splitter
  eval(FETCH_POST, env)
}

# ---- capture real split inputs ----------------------------------------------
capture_precompute <- function(snapshot, universe, start, end) {
  holder <- new.env()
  f <- seam("ledgr_precompute_fetch_bars", PRECOMPUTE_SPLIT, function(x, g) { holder$x <- x; holder$g <- g; split(x, g) })
  invisible(f(snapshot, universe, start, end))
  list(x = holder$x, f = holder$g)
}
capture_runner <- function(exp, run_id) {
  holder <- new.env()
  stopper <- function(x, g) {
    holder$x <- x; holder$g <- g
    stop(structure(class = c("spike_captured", "error", "condition"), list(message = "captured", call = NULL)))
  }
  fold <- seam("ledgr_run_fold", RUNNER_SPLIT, stopper)
  tryCatch(
    suppressWarnings(suppressMessages(with_binding("ledgr_run_fold", fold, ledgr_run(exp, run_id = run_id)))),
    error = function(e) if (is.null(holder$x)) stop(e)
  )
  if (is.null(holder$x)) stop("runner split was not reached")
  list(x = holder$x, f = holder$g)
}
derive <- function(x, keep) { x <- x[keep, , drop = FALSE]; attr(x, "row.names") <- .set_row_names(nrow(x)); x }

# ---- fixtures -----------------------------------------------------------------
small_bars <- function(ids, n_days, drop = NULL) {
  ts <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (seq_len(n_days) - 1L)
  b <- data.frame(
    ts_utc = rep(ts, times = length(ids)), instrument_id = rep(ids, each = n_days),
    stringsAsFactors = FALSE
  )
  i <- seq_len(nrow(b))
  b$close <- 100 + 3 * sin(i / 2) + match(b$instrument_id, ids)
  b$open <- b$close - 0.25; b$high <- b$close + 1; b$low <- b$close - 1
  b$volume <- 1000 + i
  b$volume[[2L]] <- NA_real_
  if (!is.null(drop)) b <- b[!drop(b, match(b$instrument_id, ids), match(b$ts_utc, ts)), , drop = FALSE]
  rownames(b) <- NULL
  b
}
iso <- function(x) format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
seal <- function(bars, id, sessions = FALSE, weekdays_only = FALSE) {
  path <- tempfile(fileext = ".duckdb")
  facts <- NULL
  if (sessions) {
    # Uneven histories reach the runner only through the availability path, which needs a
    # declared calendar. Daily Date labels are mapped by the snapshot to the declared close.
    bars$ts_utc <- as.Date(bars$ts_utc, tz = "UTC")
    dates <- seq(min(bars$ts_utc), max(bars$ts_utc), by = "day")
    open <- if (weekdays_only) !format(dates, "%u") %in% c("6", "7") else rep(TRUE, length(dates))
    facts <- ledgr_facts(ledgr_facts_sessions(data.frame(session_date = dates,
      status = ifelse(open, "open", "closed"), session_open = ifelse(open, "14:30:00", NA_character_),
      session_close = ifelse(open, "21:00:00", NA_character_),
      knowledge_time = as.POSIXct(min(dates) - 1L, tz = "UTC")), venue_id = "SPIKE", timezone = "UTC"))
  }
  list(snapshot = ledgr_snapshot_from_df(bars, db_path = path, snapshot_id = id, facts = facts), path = path,
    availability = sessions)
}
capture_exp <- function(fx) {
  if (isTRUE(fx$availability)) {
    ledgr_experiment(fx$snapshot, flat, cost_model = ledgr_cost_zero(), valuation_policy = ledgr_valuation_stale(2L))
  } else {
    ledgr_experiment(fx$snapshot, flat, cost_model = ledgr_cost_zero())
  }
}
close_fixture <- function(fx) { try(ledgr_snapshot_close(fx$snapshot), silent = TRUE); unlink(fx$path) }
uneven_drop <- function(b, k, d) {
  n <- max(d)
  (k %% 4L == 1L & d <= (k * 37L) %% (n %/% 3L)) |
    (k %% 4L == 2L & d > n - (k * 53L) %% (n %/% 4L)) |
    (k %% 4L == 3L & d %% 97L == k %% 97L)
}
flat <- function(ctx, params) ctx$flat()

# ---- evidence builders --------------------------------------------------------
fixture_row <- function(case, site, source, x, f) {
  sizes <- tabulate(match(f, unique(f)))
  data.frame(case = case, site = site, source = source, rows = nrow(x), groups = length(unique(f)),
    min_group_rows = min(sizes), max_group_rows = max(sizes),
    columns = paste(sprintf("%s<%s>", names(x), vapply(x, function(v) class(v)[[1L]], "")), collapse = " "),
    ts_tzone = attr(x$ts_utc, "tzone") %||% "", compact_row_names = .row_names_info(x) < 0L,
    na_cells = sum(is.na(x)), key_sorted_c_locale = identical(order(f, method = "radix"), seq_along(f)))
}
parity_row <- function(case, site, arm, x, f, splitter) {
  base <- split(x, f)
  cand <- splitter(x, f)
  common <- intersect(names(base), names(cand))
  per <- vapply(common, function(g) {
    b <- base[[g]]; r <- cand[[g]]
    ab <- attributes(b); ar <- attributes(r)
    ab <- ab[order(names(ab))]; ar <- ar[order(names(ar))]
    c(identical = identical(b, r),
      columns_identical = identical(as.list(b), as.list(r)),
      rows_equal = nrow(b) == nrow(r) && identical(b$instrument_id, r$instrument_id) &&
        identical(as.numeric(b$ts_utc), as.numeric(r$ts_utc)),
      column_attrs_equal = identical(lapply(b, attributes), lapply(r, attributes)),
      chronological = !is.unsorted(as.numeric(r$ts_utc)),
      row_names_differ = !identical(ab$row.names, ar$row.names),
      other_frame_attrs_differ = !identical(ab[setdiff(names(ab), "row.names")], ar[setdiff(names(ar), "row.names")]))
  }, logical(7))
  per <- matrix(per, nrow = 7L, dimnames = list(c("identical", "columns_identical", "rows_equal",
    "column_attrs_equal", "chronological", "row_names_differ", "other_frame_attrs_differ"), NULL))
  first_diff <- which(names(base)[seq_len(min(length(base), length(cand)))] != names(cand)[seq_len(min(length(base), length(cand)))])
  data.frame(case = case, site = site, arm = arm,
    groups_base = length(base), groups_cand = length(cand),
    names_same_set = setequal(names(base), names(cand)), names_same_order = identical(names(base), names(cand)),
    first_order_difference = if (length(first_diff)) first_diff[[1L]] else NA_integer_,
    base_order_head = paste(utils::head(names(base), 6L), collapse = "|"),
    cand_order_head = paste(utils::head(names(cand), 6L), collapse = "|"),
    total_rows_base = sum(vapply(base, nrow, 1L)), total_rows_cand = sum(vapply(cand, nrow, 1L)),
    na_cells_base = sum(vapply(base, function(d) sum(is.na(d)), 1L)),
    na_cells_cand = sum(vapply(cand, function(d) sum(is.na(d)), 1L)),
    groups_identical = sum(per["identical", ]), groups_columns_identical = sum(per["columns_identical", ]),
    groups_rows_equal = sum(per["rows_equal", ]), groups_column_attrs_equal = sum(per["column_attrs_equal", ]),
    groups_chronological = sum(per["chronological", ]), groups_row_names_differ = sum(per["row_names_differ", ]),
    groups_other_frame_attrs_differ = sum(per["other_frame_attrs_differ", ]),
    differing_frame_attributes = paste(sort(unique(unlist(lapply(common, function(g) {
      ab <- attributes(base[[g]]); ar <- attributes(cand[[g]])
      Filter(function(a) !identical(ab[[a]], ar[[a]]), union(names(ab), names(ar)))
    })))), collapse = "|"))
}
downstream_row <- function(case, product, a, b, detail = "") {
  data.frame(case = case, product = product, identical = identical(a, b),
    equal_ignoring_attributes = isTRUE(all.equal(a, b, check.attributes = FALSE)), detail = detail)
}
stopped_row <- function(case, product, e) {
  data.frame(case = case, product = product, identical = FALSE, equal_ignoring_attributes = FALSE,
    detail = paste("rsplit arm stopped:", conditionMessage(e)))
}
compare_runner_block <- function(case, bars_all, ids, pulses_posix, availability_active) {
  path <- if (availability_active) "availability path" else "dense path"
  eb <- eval_runner_block(bars_all, ids, pulses_posix, availability_active, split_base)
  er <- tryCatch(eval_runner_block(bars_all, ids, pulses_posix, availability_active, split_rsplit), error = identity)
  if (inherits(er, "error")) return(stopped_row(case, paste0("runner:hydration (", path, ")"), er))
  do.call(rbind, lapply(c("bars_by_id", "bars_cols_by_id", "bars_mat", "static_bars_views"), function(p) {
    diffs <- if (p == "bars_by_id") sum(!mapply(function(u, v) identical(attr(u, "row.names"), attr(v, "row.names")), eb[[p]], er[[p]])) else NA
    downstream_row(case, paste0("runner:", p), eb[[p]], er[[p]],
      paste0(path, if (!is.na(diffs)) sprintf("; frames with differing row.names: %d", diffs) else ""))
  }))
}
precompute_with <- function(exp, grid, splitter) {
  f <- seam("ledgr_precompute_fetch_bars", PRECOMPUTE_SPLIT, splitter)
  with_binding("ledgr_precompute_fetch_bars", f, ledgr_precompute_features(exp, grid))
}
compare_precompute <- function(case, exp, grid, sweep = FALSE) {
  pb <- precompute_with(exp, grid, split_base)
  pr <- tryCatch(precompute_with(exp, grid, split_rsplit), error = identity)
  if (inherits(pr, "error")) return(stopped_row(case, "precompute:object", pr))
  differing <- names(pb)[!mapply(identical, unclass(pb), unclass(pr))]
  order_note <- sprintf("payload value order base=%s rsplit=%s", paste(names(pb$payload[[1L]]$values), collapse = "|"),
    paste(names(pr$payload[[1L]]$values), collapse = "|"))
  out <- downstream_row(case, "precompute:object", pb, pr,
    paste0("differing components: ", if (length(differing)) paste(differing, collapse = ",") else "none", "; ", order_note))
  if (sweep) {
    metrics <- function(pc) {
      s <- suppressWarnings(suppressMessages(ledgr_sweep(exp, grid, precomputed_features = pc, seed = 1L)))
      keep <- names(s)[vapply(s, is.atomic, logical(1)) & !grepl("^t_|elapsed|seconds|duration", names(s))]
      stats::setNames(lapply(keep, function(n) s[[n]]), keep) # plain columns; result-object attributes excluded
    }
    mb <- metrics(pb); mr <- metrics(pr)
    differ <- names(mb)[!mapply(identical, mb, mr)]
    out <- rbind(out, downstream_row(case, "sweep:metrics", mb, mr, sprintf("%d candidates; %d atomic non-timing columns; differing: %s",
      length(mb[[1L]]), length(mb), if (length(differ)) paste(differ, collapse = ",") else "none")))
  }
  out
}
compare_run <- function(case, fx) {
  one <- function(splitter, run_id) {
    exp <- ledgr_experiment(fx$snapshot, ledgr_demo_sma_crossover_strategy(),
      features = ledgr_feature_map(fast = ledgr_ind_sma(ledgr_param("fast_n")), slow = ledgr_ind_sma(ledgr_param("slow_n"))),
      opening = ledgr_opening(cash = 10000), cost_model = ledgr_cost_zero())
    fold <- seam("ledgr_run_fold", RUNNER_SPLIT, splitter)
    run <- with_binding("ledgr_run_fold", fold, ledgr_run(exp, params = list(qty = 1, threshold = 0),
      feature_params = list(fast_n = 2L, slow_n = 3L), run_id = run_id, seed = 1L))
    on.exit(close(run), add = TRUE)
    drop_id <- function(d) as.data.frame(d[setdiff(names(d), "run_id")])
    list(fills = drop_id(ledgr_results(run, what = "fills")), equity = drop_id(ledgr_results(run, what = "equity")))
  }
  rb <- one(split_base, "parity-base")
  rr <- tryCatch(one(split_rsplit, "parity-rsplit"), error = identity)
  if (inherits(rr, "error")) return(stopped_row(case, "run:fills+equity", rr))
  rbind(downstream_row(case, "run:fills", rb$fills, rr$fills, sprintf("%d fill rows", nrow(rb$fills))),
    downstream_row(case, "run:equity", rb$equity, rr$equity, sprintf("%d equity rows", nrow(rb$equity))))
}

# ---- parity phase ---------------------------------------------------------------
fixture <- list(); parity <- list(); downstream <- list(); scale <- list()
add <- function(lst, row) c(lst, list(row))

log_line("small cases")
fx1 <- seal(small_bars(c("DEMO_01", "DEMO_02", "DEMO_03"), 10L), "c1")
fx2 <- seal(small_bars(c("aaa", "BBB", "b_1", "B2"), 10L), "c2")
fx3 <- seal(small_bars(c("U1", "U2", "U3", "U4"), 10L, drop = function(b, k, d) (k == 2L & d <= 3L) |
  (k == 3L & d > 6L) | (k == 4L & d == 5L)), "c3", sessions = TRUE)
small <- list(
  list(case = "c1_baseline", fx = fx1, ids = c("DEMO_01", "DEMO_02", "DEMO_03")),
  list(case = "c2_collation", fx = fx2, ids = c("aaa", "BBB", "b_1", "B2")),
  list(case = "c3_uneven", fx = fx3, ids = c("U1", "U2", "U3", "U4"))
)
start_all <- "2020-01-01T00:00:00Z"; end_all <- "2020-01-10T23:59:59Z"
for (s in small) {
  pc <- capture_precompute(s$fx$snapshot, s$ids, start_all, end_all)
  rn <- capture_runner(capture_exp(s$fx), paste0(s$case, "-capture"))
  s$pc <- pc; s$rn <- rn
  fixture <- add(fixture, fixture_row(s$case, "precompute", "production capture", pc$x, pc$f))
  fixture <- add(fixture, fixture_row(s$case, "runner", "production capture", rn$x, rn$f))
  parity <- add(parity, parity_row(s$case, "precompute", "rsplit", pc$x, pc$f, split_rsplit))
  parity <- add(parity, parity_row(s$case, "runner", "rsplit", rn$x, rn$f, split_rsplit))
  pulses <- sort(unique(rn$x$ts_utc))
  downstream <- add(downstream, compare_runner_block(s$case, rn$x, s$ids, pulses, availability_active = isTRUE(s$fx$availability)))
  assign(s$case, s)
}
# c1: consumed downstream through a feature-using run and a precomputed payload.
grid <- ledgr_grid_cross(features = ledgr_feature_grid(fast_n = 2L, slow_n = 3L),
  strategy = ledgr_strategy_grid(qty = 1, threshold = c(0, 0.01)))
sma_exp <- function(fx) ledgr_experiment(fx$snapshot, ledgr_demo_sma_crossover_strategy(),
  features = ledgr_feature_map(fast = ledgr_ind_sma(ledgr_param("fast_n")), slow = ledgr_ind_sma(ledgr_param("slow_n"))),
  opening = ledgr_opening(cash = 10000), cost_model = ledgr_cost_zero())
downstream <- add(downstream, compare_run("c1_baseline", fx1))
downstream <- add(downstream, compare_precompute("c1_baseline", sma_exp(fx1), grid, sweep = TRUE))
# c2: group order under the session collation locale, and whether it is consumed.
downstream <- add(downstream, compare_precompute("c2_collation", sma_exp(fx2), grid, sweep = TRUE))
# c4: an instrument absent from the requested range (applicable empty-group behaviour).
pc4 <- capture_precompute(fx3$snapshot, c3_uneven$ids, "2020-01-08T00:00:00Z", end_all)
fixture <- add(fixture, fixture_row("c4_absent", "precompute", "production capture", pc4$x, pc4$f))
parity <- add(parity, parity_row("c4_absent", "precompute", "rsplit", pc4$x, pc4$f, split_rsplit))
late <- c3_uneven$rn$x$ts_utc >= as.POSIXct("2020-01-08", tz = "UTC")
rn4 <- derive(c3_uneven$rn$x, late)
fixture <- add(fixture, fixture_row("c4_absent", "runner", "derived row subset of c3 capture", rn4, as.character(rn4$instrument_id)))
parity <- add(parity, parity_row("c4_absent", "runner", "rsplit", rn4, as.character(rn4$instrument_id), split_rsplit))
downstream <- add(downstream, compare_runner_block("c4_absent", rn4, c3_uneven$ids, sort(unique(rn4$ts_utc)), TRUE))
# c5: one instrument.
pc5 <- capture_precompute(fx1$snapshot, "DEMO_02", start_all, end_all)
fixture <- add(fixture, fixture_row("c5_single", "precompute", "production capture", pc5$x, pc5$f))
parity <- add(parity, parity_row("c5_single", "precompute", "rsplit", pc5$x, pc5$f, split_rsplit))
# c6: user-set collapse options must not change the configured candidate.
local({
  old <- collapse::set_collapse()
  on.exit(do.call(collapse::set_collapse, old), add = TRUE)
  collapse::set_collapse(sort = FALSE, stable.algo = FALSE, nthreads = 2L, na.rm = TRUE)
  x <- c2_collation$pc$x; f <- c2_collation$pc$f
  parity <<- add(parity, parity_row("c6_options", "precompute", "rsplit", x, f, split_rsplit))
  parity <<- add(parity, parity_row("c6_options", "precompute", "rsplit_unpinned", x, f, split_rsplit_unpinned))
  old_collate <- Sys.getlocale("LC_COLLATE")
  Sys.setlocale("LC_COLLATE", "C") # base split() group order follows the session collation
  row_c <- tryCatch(parity_row("c6_options", "precompute_under_C_collation", "rsplit", x, f, split_rsplit),
    finally = Sys.setlocale("LC_COLLATE", old_collate))
  parity <<- add(parity, row_c)
  shuffled <- derive(x, order(-seq_len(nrow(x))))
  parity <<- add(parity, parity_row("c6_options", "precompute_reversed_input", "rsplit", shuffled, shuffled$instrument_id, split_rsplit))
  parity <<- add(parity, parity_row("c6_options", "precompute_reversed_input", "rsplit_unpinned", shuffled, shuffled$instrument_id, split_rsplit_unpinned))
})
# c7: a user indicator callback that reads the row names it receives.
rowname_ind <- ledgr_indicator("rowname_probe", fn = function(window) as.numeric(rownames(window))[nrow(window)],
  requires_bars = 1L, series_fn = function(bars) as.numeric(rownames(bars)))
downstream <- add(downstream, compare_precompute("c7_rowname_callback",
  ledgr_experiment(fx1$snapshot, flat, features = list(rowname_ind), cost_model = ledgr_cost_zero()),
  ledgr_param_grid(list(qty = 1))))
# How often each site executes per public workflow, counted by execution on c1.
call_counts <- local({
  counts <- new.env()
  counter <- function(site) function(x, g) { counts[[site]] <- counts[[site]] + 1L; split(x, g) }
  pre <- seam("ledgr_precompute_fetch_bars", PRECOMPUTE_SPLIT, counter("precompute"))
  fold <- seam("ledgr_run_fold", RUNNER_SPLIT, counter("runner"))
  grid4 <- ledgr_grid_cross(features = ledgr_feature_grid(fast_n = 2L, slow_n = 3L),
    strategy = ledgr_strategy_grid(qty = 1, threshold = c(0, 0.01, 0.02, 0.03)))
  exp <- sma_exp(fx1)
  count <- function(workflow, expr) {
    counts$precompute <- 0L; counts$runner <- 0L
    value <- suppressWarnings(suppressMessages(with_binding("ledgr_precompute_fetch_bars", pre,
      with_binding("ledgr_run_fold", fold, force(expr)))))
    list(value = value, row = data.frame(workflow = workflow, candidates = length(grid4$labels),
      precompute_site_calls = counts$precompute, runner_site_calls = counts$runner))
  }
  r1 <- count("ledgr_run", { run <- ledgr_run(exp, params = list(qty = 1, threshold = 0),
    feature_params = list(fast_n = 2L, slow_n = 3L), run_id = "count-run", seed = 1L); close(run); NULL })
  r2 <- count("ledgr_precompute_features", ledgr_precompute_features(exp, grid4))
  r3 <- count("ledgr_sweep with precomputed features", ledgr_sweep(exp, grid4, precomputed_features = r2$value, seed = 1L))
  r4 <- count("ledgr_sweep without precomputed features", ledgr_sweep(exp, grid4, seed = 1L))
  rbind(r1$row, r2$row, r3$row, r4$row)
})
for (fx in list(fx1, fx2, fx3)) close_fixture(fx)

log_line("research-scale fixtures")
sim <- as.data.frame(ledgr_sim_bars(n_instruments = 500L, n_days = 2500L, seed = 1L))
sim_ids <- unique(sim$instrument_id); sim_ts <- sort(unique(sim$ts_utc))
drop_sim <- uneven_drop(sim, match(sim$instrument_id, sim_ids), match(sim$ts_utc, sim_ts))
for (case in c("scale_even", "scale_uneven")) {
  uneven <- case == "scale_uneven"
  bars <- if (uneven) derive(sim, !drop_sim) else sim
  fx <- seal(bars, case, sessions = uneven, weekdays_only = TRUE)
  window <- c(iso(min(sim_ts)), iso(max(sim_ts) + 86399))
  pc <- capture_precompute(fx$snapshot, sim_ids, window[[1L]], window[[2L]])
  raw <- query_rows(fx$snapshot, sim_ids, window[[1L]], window[[2L]])
  fixture <- add(fixture, fixture_row(case, "precompute", "production capture", pc$x, pc$f))
  parity <- add(parity, parity_row(case, "precompute", "rsplit", pc$x, pc$f, split_rsplit))
  scale[[case]] <- list(fx = fx, pc = pc, raw = raw, window = window)
}
for (case in names(scale)) {
  fx <- scale[[case]]$fx
  rn <- capture_runner(capture_exp(fx), paste0(case, "-capture"))
  fixture <- add(fixture, fixture_row(case, "runner", "production capture", rn$x, rn$f))
  parity <- add(parity, parity_row(case, "runner", "rsplit", rn$x, rn$f, split_rsplit))
  scale[[case]]$rn <- rn
  scale[[case]]$avail <- isTRUE(fx$availability)
  scale[[case]]$pulses <- sort(unique(rn$x$ts_utc))
  downstream <- add(downstream, compare_runner_block(case, rn$x, sim_ids, scale[[case]]$pulses, scale[[case]]$avail))
}
write_ev(do.call(rbind, fixture), "fixture.csv")
write_ev(do.call(rbind, parity), "parity.csv")
write_ev(do.call(rbind, downstream), "downstream.csv")
write_ev(call_counts, "call_counts.csv")

git1 <- function(...) {
  old <- Sys.getenv("HOME"); on.exit(Sys.setenv(HOME = old), add = TRUE)
  if (nzchar(Sys.getenv("USERPROFILE"))) Sys.setenv(HOME = Sys.getenv("USERPROFILE"))
  out <- suppressWarnings(system2("git", c("-C", shQuote(repo_root), ...), stdout = TRUE, stderr = FALSE))
  if (length(out)) out[[1L]] else NA_character_
}
timer_res <- local({ x <- vapply(1:20000, function(i) as.numeric(Sys.time()), 1); d <- diff(x); min(d[d > 0]) })
write_ev(data.frame(key = c("r_version", "platform", "os", "collate_locale", "collapse", "duckdb", "DBI", "pkgload",
  "git_head", "blob_precompute_features", "blob_backtest_runner", "collapse_options", "timer_resolution_s", "cpu", "gut"),
  value = c(R.version.string, R.version$platform, paste(Sys.info()[c("sysname", "release")], collapse = " "),
    Sys.getlocale("LC_COLLATE"), as.character(packageVersion("collapse")), as.character(packageVersion("duckdb")),
    as.character(packageVersion("DBI")), as.character(packageVersion("pkgload")), git1("rev-parse", "HEAD"),
    git1("rev-parse", "HEAD:R/precompute-features.R"), git1("rev-parse", "HEAD:R/backtest-runner.R"),
    paste(deparse(collapse::set_collapse()), collapse = ""), format(timer_res, digits = 3),
    Sys.getenv("PROCESSOR_IDENTIFIER"), gut)), "environment.csv")
log_line("parity evidence written")
if (identical(phase, "parity")) for (sc in scale) close_fixture(sc$fx)

if (identical(phase, "all")) {
  # ---- timing and allocation phase ------------------------------------------------
  invisible(gc.time(TRUE))
  time_pair <- function(case, site, op, f_base, f_rsplit, n, warm = 2L) {
    for (w in seq_len(warm)) { invisible(f_base()); invisible(f_rsplit()) }
    rows <- vector("list", 2L * n)
    for (r in seq_len(n)) {
      arms <- if (r %% 2L == 1L) c("base", "rsplit") else c("rsplit", "base")
      for (pos in 1:2) {
        fun <- if (arms[[pos]] == "base") f_base else f_rsplit
        invisible(gc())
        g0 <- gc.time()[[3L]]; t0 <- Sys.time()
        res <- fun()
        t1 <- Sys.time(); g1 <- gc.time()[[3L]]
        rm(res)
        rows[[2L * (r - 1L) + pos]] <- data.frame(case = case, site = site, op = op, rep = r, position = pos,
          arm = arms[[pos]], elapsed_s = as.numeric(t1 - t0, units = "secs"), gc_s = g1 - g0)
      }
    }
    do.call(rbind, rows)
  }
  alloc <- function(case, site, op, arm, fun, retained) {
    invisible(gc()); tf <- tempfile()
    utils::Rprofmem(tf, threshold = 0)
    res <- fun()
    utils::Rprofmem(NULL)
    lines <- readLines(tf); unlink(tf)
    big <- grep("^[0-9]+ :", lines, value = TRUE)
    data.frame(case = case, site = site, op = op, arm = arm,
      allocated_bytes = sum(as.numeric(sub(" :.*$", "", big))), allocation_events = length(big),
      small_vector_pages = sum(grepl("^new page", lines)),
      retained_output_bytes = if (retained) as.numeric(utils::object.size(res)) else NA_real_)
  }
  timing <- list(); memory <- list()
  for (case in names(scale)) {
    sc <- scale[[case]]
    ops <- list(
      list(site = "precompute", op = "split", retained = TRUE, n = reps,
        make = function(sp) function() sp(sc$pc$x, sc$pc$f)),
      list(site = "precompute", op = "post_query_convert_and_split", retained = TRUE, n = reps,
        make = function(sp) function() run_fetch_post(sc$raw, sp)),
      list(site = "precompute", op = "fetch_bars_including_duckdb_query", retained = TRUE, n = reps,
        make = function(sp) { f <- seam("ledgr_precompute_fetch_bars", PRECOMPUTE_SPLIT, sp)
          function() f(sc$fx$snapshot, sim_ids, sc$window[[1L]], sc$window[[2L]]) }),
      list(site = "runner", op = "split", retained = TRUE, n = reps,
        make = function(sp) function() sp(sc$rn$x, sc$rn$f)),
      list(site = "runner", op = if (sc$avail) "hydration_block_availability_path" else "hydration_block_dense_path",
        retained = FALSE, n = max(5L, reps %/% 2L),
        make = function(sp) function() eval_runner_block(sc$rn$x, sim_ids, sc$pulses, sc$avail, sp))
    )
    if (!sc$avail) {
      # Workflow context only: these include DuckDB, feature computation, fold execution and
      # run-store writes. No allocation trace is taken for them.
      run_no <- 0L
      ops <- c(ops, list(
        list(site = "runner", op = "ledgr_run_flat_end_to_end_context", retained = FALSE, n = 3L, alloc = FALSE,
          make = function(sp) { fold <- seam("ledgr_run_fold", RUNNER_SPLIT, sp)
            function() { run_no <<- run_no + 1L
              run <- suppressWarnings(with_binding("ledgr_run_fold", fold,
                ledgr_run(capture_exp(sc$fx), run_id = sprintf("context-%03d", run_no))))
              close(run); NULL } }),
        list(site = "precompute", op = "ledgr_precompute_features_sma_end_to_end_context", retained = FALSE, n = 3L,
          alloc = FALSE, make = function(sp) { f <- seam("ledgr_precompute_fetch_bars", PRECOMPUTE_SPLIT, sp)
            function() with_binding("ledgr_precompute_fetch_bars", f, ledgr_precompute_features(sma_exp(sc$fx), grid)) })
      ))
    }
    for (o in ops) {
      log_line(case, " ", o$site, " ", o$op)
      fb <- o$make(split_base); fr <- o$make(split_rsplit)
      timing <- add(timing, time_pair(case, o$site, o$op, fb, fr, o$n, warm = if (identical(o$alloc, FALSE)) 1L else 2L))
      if (!identical(o$alloc, FALSE)) {
        memory <- add(memory, alloc(case, o$site, o$op, "base", fb, o$retained))
        memory <- add(memory, alloc(case, o$site, o$op, "rsplit", fr, o$retained))
      }
    }
    memory <- add(memory, data.frame(case = case, site = c("precompute", "runner"), op = "input_frame", arm = "shared",
      allocated_bytes = NA_real_, allocation_events = NA_integer_, small_vector_pages = NA_integer_,
      retained_output_bytes = c(as.numeric(utils::object.size(sc$pc$x)), as.numeric(utils::object.size(sc$rn$x)))))
    close_fixture(sc$fx)
  }
  write_ev(do.call(rbind, timing), "timing.csv")
  write_ev(do.call(rbind, memory), "memory.csv")
  source(file.path(spike_dir, "summarise_timing.R"), local = TRUE)
  timing_read <- utils::read.csv(file.path(out_dir, "timing.csv"), stringsAsFactors = FALSE)
  write_ev(summarise_timing(timing_read), "timing_summary.csv")
  log_line("timing and allocation evidence written")
}

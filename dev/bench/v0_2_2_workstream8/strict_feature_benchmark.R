# Current-tree gate for LDG-2941. Each candidate changes only the strict
# availability-aware series computation for one canonical ledgr built-in.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
repo <- normalizePath(
  arg_value("--repo", file.path(dirname(script), "..", "..", "..")),
  winslash = "/"
)
out <- arg_value("--out", file.path(dirname(script), "evidence"))
reps <- as.integer(arg_value("--reps", "3"))
stopifnot(reps >= 3L)
probe_only <- "--probe-only" %in% args
native_only <- "--native-only" %in% args
dir.create(out, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")

with_bindings <- function(bindings, code) {
  if (is.null(bindings)) return(force(code))
  old <- lapply(names(bindings), get, envir = ns)
  names(old) <- names(bindings)
  for (name in names(bindings)) {
    unlockBinding(name, ns)
    assign(name, bindings[[name]], envir = ns)
    lockBinding(name, ns)
  }
  on.exit(for (name in names(old)) {
    unlockBinding(name, ns)
    assign(name, old[[name]], envir = ns)
    lockBinding(name, ns)
  }, add = TRUE)
  force(code)
}

scalar_strict <- ns$ledgr_compute_feature_series_strict
scalar_dense <- ns$ledgr_compute_feature_series
candidate_calls <- new.env(parent = emptyenv())
candidate_calls$n <- 0L
dense_calls <- new.env(parent = emptyenv())
dense_calls$n <- 0L
candidate_kind <- function(feature_def) {
  params <- feature_def$params
  n <- if (is.list(params)) params$n else NULL
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || !is.finite(n) ||
      n < 1 || n %% 1 != 0) return(NULL)
  n <- as.integer(n)
  fingerprint <- ledgr_feature_def_fingerprint(feature_def)
  if (identical(fingerprint, ledgr_indicator_fingerprint(ledgr_ind_sma(n)))) {
    return("sma")
  }
  if (identical(
    fingerprint,
    ledgr_indicator_fingerprint(ledgr_ind_returns(n))
  )) return("returns")
  NULL
}
environment(candidate_kind) <- ns

exact_sma_series <- function(values, width) {
  values <- as.numeric(values)
  width <- as.integer(width)
  out <- rep(NA_real_, length(values))
  if (length(values) < width) return(out)
  ends <- seq.int(width, length(values))
  out[ends] <- vapply(ends, function(i) {
    mean(values[seq.int(i - width + 1L, i)])
  }, numeric(1))
  out
}

complete_mask <- function(bars_df, width) {
  columns <- intersect(c("open", "high", "low", "close"), names(bars_df))
  values <- do.call(cbind, lapply(bars_df[columns], function(x) {
    suppressWarnings(as.numeric(x))
  }))
  if (is.null(dim(values))) values <- matrix(values, ncol = 1L)
  complete <- stats::complete.cases(values) &
    rowSums(is.finite(values)) == ncol(values)
  cumulative <- cumsum(!complete)
  previous <- c(rep(0, width), cumulative)[seq_along(cumulative)]
  seq_along(cumulative) >= width & cumulative - previous == 0
}

candidate_series <- function(bars_df, feature_def, enabled) {
  kind <- candidate_kind(feature_def)
  if (is.null(kind) || !identical(kind, enabled)) {
    return(scalar_strict(bars_df, feature_def))
  }
  candidate_calls$n <- candidate_calls$n + 1L
  ledgr_validate_feature_def(feature_def)
  if (!identical(feature_def$gap_contract, "strict_window") ||
      !is.data.frame(bars_df) ||
      !all(c("ts_utc", "close") %in% names(bars_df))) {
    return(scalar_strict(bars_df, feature_def))
  }
  width <- as.integer(feature_def$stable_after)
  n <- nrow(bars_df)
  if (n < width) return(rep(NA_real_, n))
  value <- if (identical(kind, "sma")) {
    exact_sma_series(bars_df$close, width)
  } else {
    ledgr_call_feature_series_fn(
      feature_def$series_fn,
      bars_df,
      feature_def$params %||% list()
    )
  }
  if (!is.numeric(value) || !is.atomic(value) || !is.null(dim(value))) {
    rlang::abort(
      sprintf(
        "Feature %s returned a non-numeric or non-vector series.",
        feature_def$id
      ),
      class = "ledgr_invalid_feature_output"
    )
  }
  if (length(value) != n) {
    rlang::abort(
      sprintf(
        "Feature %s returned %d values; expected %d.",
        feature_def$id,
        length(value),
        n
      ),
      class = "ledgr_invalid_feature_output"
    )
  }
  value <- as.numeric(value)
  complete <- complete_mask(bars_df, width)
  if (any(is.nan(value[complete])) || any(is.infinite(value[complete]))) {
    rlang::abort(
      sprintf("Feature %s returned a non-finite value.", feature_def$id),
      class = "ledgr_invalid_feature_output"
    )
  }
  value[!complete] <- NA_real_
  value
}

make_candidate <- function(enabled) {
  force(enabled)
  function(bars_df, feature_def) candidate_series(
    bars_df, feature_def, enabled
  )
}
candidates <- list(
  sma = make_candidate("sma"),
  returns = make_candidate("returns")
)

bars <- as.data.frame(ledgr_sim_bars(
  n_instruments = 50L,
  n_days = 500L,
  seed = 20261004L
))
bars$ts_utc <- as.POSIXct(
  paste(as.Date(bars$ts_utc, tz = "UTC"), "21:00:00"),
  tz = "UTC"
)
dates <- sort(unique(as.Date(bars$ts_utc, tz = "UTC")))
civil_dates <- seq(min(dates), max(dates), by = "day")
is_open <- civil_dates %in% dates
ids <- unique(bars$instrument_id)
knowledge <- as.POSIXct(min(dates) - 2, tz = "UTC")
sessions <- ledgr_facts_sessions(
  data.frame(
    session_date = civil_dates,
    status = ifelse(is_open, "open", "closed"),
    session_open = ifelse(is_open, "14:30:00", NA_character_),
    session_close = ifelse(is_open, "21:00:00", NA_character_),
    knowledge_time = knowledge,
    stringsAsFactors = FALSE
  ),
  venue_id = "WS8",
  timezone = "UTC"
)
membership <- ledgr_facts_membership_snapshots(
  data.frame(
    instrument_id = ids,
    effective_from = as.POSIXct(min(dates), tz = "UTC"),
    knowledge_time = knowledge,
    stringsAsFactors = FALSE
  ),
  universe_id = "ws8_members",
  complete = TRUE
)
source_path <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(
  bars,
  instruments_df = data.frame(instrument_id = ids),
  facts = ledgr_facts(sessions, membership),
  db_path = source_path,
  snapshot_id = "ws8-strict"
)
ledgr_snapshot_close(snapshot)
rm(bars)

copy_store <- function() {
  path <- tempfile(fileext = ".duckdb")
  stopifnot(file.copy(source_path, path))
  path
}
strategy_for <- function(feature_id) {
  force(feature_id)
  function(ctx, params) {
    values <- ctx$vec$feature(feature_id)
    targets <- ctx$flat()
    targets[is.finite(values) & values > params$threshold] <- 1
    targets
  }
}
make_experiment <- function(snapshot, indicator) {
  feature_id <- ledgr_feature_id(indicator)
  ledgr_experiment(
    snapshot,
    strategy_for(feature_id),
    features = list(indicator),
    universe = ledgr_universe_members("ws8_members"),
    valuation_policy = ledgr_valuation_stale(1L),
    opening = ledgr_opening(cash = 1e7),
    cost_model = ledgr_cost_zero(),
    persist_features = FALSE
  )
}
grid <- ledgr_param_grid(list(threshold = 0))

semantic <- function(x) {
  if (inherits(x, "ledgr_backtest")) {
    out <- list(
      fills = ledgr_results(x, what = "fills"),
      equity = ledgr_results(x, what = "equity"),
      trades = ledgr_results(x, what = "trades")
    )
    close(x)
    return(out)
  }
  attrs <- attributes(x)
  drop_sweep_id <- function(value) {
    if (is.data.frame(value)) return(value[setdiff(names(value), "sweep_id")])
    value
  }
  keep <- names(x)[!grepl("^t_", names(x))]
  list(
    columns = stats::setNames(lapply(keep, function(name) x[[name]]), keep),
    returns = drop_sweep_id(attrs$sweep_returns),
    trades = drop_sweep_id(attrs$sweep_trades),
    attributes = attrs[setdiff(
      names(attrs),
      c(
        "names", "row.names", "class", "sweep_id", "sweep_returns",
        "sweep_trades", "feature_engine_version", "t_prepare", "t_engine",
        "t_results"
      )
    )]
  )
}

run_arm <- function(feature, workflow, candidate = NULL) {
  path <- copy_store()
  on.exit(unlink(path), add = TRUE)
  snapshot <- ledgr_snapshot_open(path, "ws8-strict")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  indicator <- if (identical(feature, "sma")) {
    ledgr_ind_sma(20L)
  } else {
    ledgr_ind_returns(20L)
  }
  ledgr_feature_cache_clear()
  candidate_calls$n <- 0L
  dense_calls$n <- 0L
  bindings <- if (is.null(candidate)) NULL else list(
    ledgr_compute_feature_series_strict = candidate
  )
  if (!is.null(bindings) && probe_only) {
    bindings$ledgr_compute_feature_series <- function(bars_df, feature_def) {
      dense_calls$n <- dense_calls$n + 1L
      scalar_dense(bars_df, feature_def)
    }
  }
  invisible(gc(full = TRUE))
  g0 <- gc.time()[[3L]]
  t0 <- Sys.time()
  value <- with_bindings(bindings, {
    experiment <- make_experiment(snapshot, indicator)
    if (identical(workflow, "run")) {
      ledgr_run(
        experiment,
        params = list(threshold = 0),
        run_id = paste0("ws8-", feature),
        seed = 1L
      )
    } else {
      ledgr_sweep(experiment, grid, seed = 1L, workers = 1L)
    }
  })
  cache <- if (inherits(value, "ledgr_backtest")) {
    info <- ledgr_run_info(snapshot, value$run_id)
    c(hits = info$feature_cache_hits, misses = info$feature_cache_misses)
  } else {
    c(hits = NA_integer_, misses = NA_integer_)
  }
  list(
    elapsed = as.numeric(Sys.time() - t0, units = "secs"),
    gc_s = gc.time()[[3L]] - g0,
    candidate_calls = candidate_calls$n,
    dense_calls = dense_calls$n,
    cache = cache,
    value = semantic(value)
  )
}

if (probe_only) {
  probe <- run_arm("sma", "run", candidates$sma)
  print(probe[c("elapsed", "candidate_calls", "dense_calls", "cache")])
  unlink(source_path)
  quit(save = "no", status = 0L)
}

other_r <- function() {
  if (!requireNamespace("ps", quietly = TRUE)) return(NA_integer_)
  tasks <- ps::ps()
  sum(
    tolower(tasks$name) %in% c("rscript.exe", "rterm.exe", "r.exe") &
      tasks$pid != Sys.getpid()
  )
}

if (native_only) {
  feature <- arg_value("--feature", "sma")
  workflow <- arg_value("--workflow", "run")
  result <- run_arm(feature, workflow)
  utils::write.csv(data.frame(
    feature = feature,
    workflow = workflow,
    elapsed_s = result$elapsed,
    gc_s = result$gc_s,
    other_r_processes = other_r()
  ), file.path(out, "native.csv"), row.names = FALSE)
  saveRDS(result$value, file.path(out, "semantic.rds"), version = 3L)
  unlink(source_path)
  quit(save = "no", status = 0L)
}

timing <- list()
parity <- list()
for (feature in names(candidates)) {
  for (workflow in c("run", "sweep")) {
    reference <- run_arm(feature, workflow)$value
    for (rep in seq_len(reps)) {
      order <- if (rep %% 2L) c("production", "candidate") else {
        c("candidate", "production")
      }
      for (position in seq_along(order)) {
        arm <- order[[position]]
        result <- run_arm(
          feature,
          workflow,
          if (identical(arm, "candidate")) candidates[[feature]] else NULL
        )
        timing[[length(timing) + 1L]] <- data.frame(
          feature = feature,
          workflow = workflow,
          rep = rep,
          position = position,
          arm = arm,
          elapsed_s = result$elapsed,
          gc_s = result$gc_s,
          candidate_calls = result$candidate_calls,
          other_r_processes = other_r()
        )
        parity[[length(parity) + 1L]] <- data.frame(
          feature = feature,
          workflow = workflow,
          rep = rep,
          arm = arm,
          identical = identical(result$value, reference)
        )
      }
    }
  }
}
timing <- do.call(rbind, timing)
parity <- do.call(rbind, parity)
groups <- interaction(timing$feature, timing$workflow, drop = TRUE)
summary <- do.call(rbind, lapply(split(timing, groups), function(x) {
  production <- stats::median(x$elapsed_s[x$arm == "production"])
  candidate <- stats::median(x$elapsed_s[x$arm == "candidate"])
  data.frame(
    feature = x$feature[[1L]],
    workflow = x$workflow[[1L]],
    production_median_s = production,
    candidate_median_s = candidate,
    gain_fraction = (production - candidate) / production
  )
}))

internal <- list()
set.seed(2L)
values <- 100 * exp(cumsum(stats::rnorm(3000L, 0, 0.02)))
internal_bars <- data.frame(
  ts_utc = as.POSIXct("2000-01-01", tz = "UTC") + 86400 * 0:2999,
  instrument_id = "AAA",
  open = values,
  high = values * 1.005,
  low = values * 0.995,
  close = values,
  volume = 1e5,
  stringsAsFactors = FALSE
)
internal_bars[c(1:400, 1200:1210), c("open", "high", "low", "close")] <- NA
for (feature in names(candidates)) {
  indicator <- if (identical(feature, "sma")) {
    ledgr_ind_sma(20L)
  } else {
    ledgr_ind_returns(20L)
  }
  definition <- ledgr_precompute_feature_def_from_indicator(indicator)
  clock <- function(fn, iterations = 10L) {
    times <- numeric(reps)
    value <- NULL
    for (rep in seq_len(reps)) {
      t0 <- proc.time()[["elapsed"]]
      for (iteration in seq_len(iterations)) value <- fn()
      times[[rep]] <- (proc.time()[["elapsed"]] - t0) / iterations
    }
    list(median = stats::median(times), value = value)
  }
  production <- clock(function() scalar_strict(internal_bars, definition))
  candidate <- clock(function() candidates[[feature]](
    internal_bars, definition
  ))
  internal[[feature]] <- data.frame(
    feature = feature,
    production_median_s = production$median,
    candidate_median_s = candidate$median,
    speedup = production$median / candidate$median,
    identical = identical(production$value, candidate$value),
    na_mask_identical = identical(
      is.na(production$value), is.na(candidate$value)
    )
  )
}
internal <- do.call(rbind, internal)

read_git_head <- function(path) {
  head <- trimws(readLines(file.path(path, ".git", "HEAD"), warn = FALSE))
  if (!startsWith(head, "ref: ")) return(head)
  ref <- sub("^ref: ", "", head)
  trimws(readLines(file.path(path, ".git", ref), warn = FALSE))
}

gates <- do.call(rbind, lapply(names(candidates), function(feature) {
  public <- summary[
    summary$feature == feature & summary$workflow == "run",
    ,
    drop = FALSE
  ]
  micro <- internal[internal$feature == feature, , drop = FALSE]
  eligible <- micro$speedup > 10 && public$gain_fraction > 0.05
  data.frame(
    feature = feature,
    internal_gate = micro$speedup > 10,
    public_run_gate = public$gain_fraction > 0.05,
    outcome = if (eligible) "eligible" else "rejected"
  )
}))

utils::write.csv(timing, file.path(out, "timing.csv"), row.names = FALSE)
utils::write.csv(summary, file.path(out, "timing_summary.csv"), row.names = FALSE)
utils::write.csv(parity, file.path(out, "parity.csv"), row.names = FALSE)
utils::write.csv(internal, file.path(out, "internal.csv"), row.names = FALSE)
utils::write.csv(gates, file.path(out, "gates.csv"), row.names = FALSE)
utils::write.csv(data.frame(
  key = c(
    "r_version", "collapse", "duckdb", "git_head", "instruments",
    "pulses", "internal_gate", "public_gate"
  ),
  value = c(
    R.version.string,
    as.character(packageVersion("collapse")),
    as.character(packageVersion("duckdb")),
    read_git_head(repo),
    "50", "500", "10x", "5%"
  )
), file.path(out, "environment.csv"), row.names = FALSE)
unlink(source_path)
print(summary, row.names = FALSE)
print(internal, row.names = FALSE)
print(gates, row.names = FALSE)
stopifnot(
  all(parity$identical),
  all(internal$identical),
  all(internal$na_mask_identical)
)

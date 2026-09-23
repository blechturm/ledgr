args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) {
  stop(
    paste(
      "Usage: measure_workstream8.R",
      "<repo-root> <operation> <arm> <repetition> <output.csv>"
    ),
    call. = FALSE
  )
}

repo_root <- normalizePath(args[[1L]], winslash = "/")
operation <- args[[2L]]
arm <- args[[3L]]
repetition <- as.integer(args[[4L]])
output_path <- normalizePath(args[[5L]], winslash = "/", mustWork = FALSE)
allowed <- c("sweep", "wide", "normalizer", "validation", "cold", "marks")
if (!operation %in% allowed || is.na(repetition) || repetition < 1L) {
  stop("Invalid operation or repetition.", call. = FALSE)
}

user_lib <- "C:/Users/maxth/Documents/R/win-library/4.6"
collapse_lib <- "C:/tmp/ledgr-collapse-218-lib"
libraries <- c(collapse_lib, user_lib)
libraries <- libraries[dir.exists(libraries)]
.libPaths(c(libraries, .libPaths()))
options(keep.source = TRUE, keep.source.pkgs = TRUE, warn = 1)
pkgload::load_all(repo_root, quiet = TRUE, export_all = TRUE)

elapsed <- function(fn) {
  invisible(gc(full = TRUE))
  started <- proc.time()[["elapsed"]]
  value <- fn()
  list(seconds = proc.time()[["elapsed"]] - started, value = value)
}

load_availability_fixture <- function() {
  runner <- file.path(
    repo_root,
    "dev",
    "spikes",
    "availability-hot-path-representation",
    "spike_runner.R"
  )
  fixture_env <- new.env(parent = globalenv())
  for (expr in parse(runner)) {
    if (is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
        is.name(expr[[2L]]) &&
        as.character(expr[[2L]]) %in% c("FIXTURES", "spike_fixture")) {
      eval(expr, fixture_env)
    }
  }
  fixture_env$spike_fixture(fixture_env$FIXTURES$envelope757)
}

measure_sweep <- function() {
  bars <- as.data.frame(ledgr_sim_bars(
    n_instruments = 40L,
    n_days = 756L,
    seed = 2744L,
    instrument_prefix = "W8_"
  ))
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  feature_map <- ledgr_feature_map(
    fast = ledgr_ind_sma(5L),
    slow = ledgr_ind_sma(20L)
  )
  strategy <- function(ctx, params) {
    target <- ctx$flat()
    for (id in ctx$universe) {
      values <- ctx$features(id)
      ready <- all(is.finite(unname(values[c("fast", "slow")])))
      target[[id]] <- if (ready && values[["fast"]] > values[["slow"]]) {
        params$quantity
      } else {
        0
      }
    }
    target
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    features = feature_map,
    cost_model = ledgr_cost_zero()
  )
  grid <- do.call(
    ledgr_param_grid,
    stats::setNames(
      lapply(seq_len(12L), function(i) list(quantity = i)),
      sprintf("quantity_%02d", seq_len(12L))
    )
  )
  result <- elapsed(function() ledgr_sweep(
    experiment,
    grid,
    seed = 2744L,
    workers = 1L
  ))
  if (!all(result$value$status == "DONE")) {
    stop("The registered sweep did not finish DONE.", call. = FALSE)
  }
  list(seconds = result$seconds, rows = nrow(bars), detail = "12 candidates")
}

measure_wide <- function() {
  shapes <- list(c(40L, 2L), c(200L, 5L), c(563L, 5L))
  measured <- lapply(shapes, function(shape) {
    instruments <- sprintf("I%04d", seq_len(shape[[1L]]))
    features <- sprintf("F%02d", seq_len(shape[[2L]]))
    input <- data.frame(
      instrument_id = rep(instruments, times = shape[[2L]]),
      ts_utc = as.POSIXct("2020-01-01", tz = "UTC"),
      feature_name = rep(features, each = shape[[1L]]),
      feature_value = seq_len(prod(shape)),
      stringsAsFactors = FALSE
    )
    invisible(ledgr:::ledgr_features_wide(input))
    timing <- elapsed(function() {
      for (i in seq_len(100L)) invisible(ledgr:::ledgr_features_wide(input))
    })
    data.frame(
      shape = paste(shape, collapse = "x"),
      cells = prod(shape),
      seconds = timing$seconds / 100,
      stringsAsFactors = FALSE
    )
  })
  measured <- do.call(rbind, measured)
  list(
    seconds = sum(measured$seconds),
    rows = sum(measured$cells),
    detail = paste(
      sprintf("%s=%.9f", measured$shape, measured$seconds),
      collapse = ";"
    )
  )
}

measure_availability <- function(operation) {
  fixture <- load_availability_fixture()
  if (identical(operation, "normalizer")) {
    result <- elapsed(function() {
      ledgr:::ledgr_availability_observation_times(
        fixture$bars$ts_utc,
        fixture$facts
      )
    })
    return(list(
      seconds = result$seconds,
      rows = nrow(fixture$bars),
      detail = "observation timestamps"
    ))
  }
  if (identical(operation, "validation")) {
    result <- elapsed(function() {
      ledgr:::ledgr_availability_validate_inputs(
        fixture$facts,
        fixture$bars,
        fixture$instruments,
        "quarantine"
      )
    })
    if (!isTRUE(result$value$can_seal)) {
      stop("The registered validation fixture cannot seal.", call. = FALSE)
    }
    return(list(
      seconds = result$seconds,
      rows = nrow(fixture$bars),
      detail = "complete validation"
    ))
  }

  db_path <- tempfile(fileext = ".duckdb")
  if (identical(operation, "cold")) {
    result <- elapsed(function() ledgr_snapshot_from_df(
      fixture$bars,
      instruments_df = fixture$instruments,
      facts = fixture$facts,
      invalid_observations = "quarantine",
      db_path = db_path,
      snapshot_id = paste0("workstream8-cold-", arm, "-", repetition)
    ))
    on.exit(ledgr_snapshot_close(result$value), add = TRUE)
    return(list(
      seconds = result$seconds,
      rows = nrow(fixture$bars),
      detail = "cold snapshot_from_df"
    ))
  }

  snapshot <- ledgr_snapshot_from_df(
    fixture$bars,
    instruments_df = fixture$instruments,
    facts = fixture$facts,
    invalid_observations = "quarantine",
    db_path = db_path,
    snapshot_id = paste0("workstream8-marks-", arm, "-", repetition)
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    valuation_policy = ledgr_valuation_stale(2L),
    cost_model = ledgr_cost_zero()
  )
  run <- ledgr_run(
    experiment,
    run_id = paste0("workstream8-marks-run-", arm, "-", repetition)
  )
  on.exit(close(run), add = TRUE)
  result <- elapsed(function() ledgr_results(run, "availability"))
  list(
    seconds = result$seconds,
    rows = nrow(result$value),
    detail = "availability result read"
  )
}

measurement <- switch(
  operation,
  sweep = measure_sweep(),
  wide = measure_wide(),
  measure_availability(operation)
)
row <- data.frame(
  measured_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  arm = arm,
  operation = operation,
  repetition = repetition,
  seconds = measurement$seconds,
  rows = measurement$rows,
  detail = measurement$detail,
  git_sha = Sys.getenv("LEDGR_MEASURE_GIT_SHA", unset = "unrecorded"),
  dirty = identical(Sys.getenv("LEDGR_MEASURE_DIRTY"), "true"),
  r = R.version.string,
  duckdb = as.character(utils::packageVersion("duckdb")),
  collapse = as.character(utils::packageVersion("collapse")),
  stringsAsFactors = FALSE
)
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(row, output_path, row.names = FALSE, na = "")
print(row)

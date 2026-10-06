args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("Usage: run_case.R <repo> <bundle|plane> <output.json>")
}
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
mode <- match.arg(args[[2L]], c("bundle", "plane"))
output <- normalizePath(args[[3L]], winslash = "/", mustWork = FALSE)

suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
bars <- as.data.frame(ledgr_sim_bars(
  n_instruments = 500L, n_days = 1260L, seed = 20261006L
))
store <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(
  bars, db_path = store, snapshot_id = "ws16_feature_map_read_surface"
)
on.exit({
  try(ledgr_snapshot_close(snapshot), silent = TRUE)
  unlink(store)
}, add = TRUE)
rm(bars)
invisible(gc(verbose = FALSE))

features <- ledgr_feature_map(
  fast = ledgr_ind_sma(5L), slow = ledgr_ind_sma(20L)
)
strategy <- if (identical(mode, "bundle")) {
  function(ctx, params) {
    targets <- ctx$flat()
    selected <- logical(length(ctx$universe))
    for (i in seq_along(ctx$universe)) {
      values <- ctx$features(ctx$universe[[i]])
      selected[[i]] <- all(is.finite(values)) &&
        values[["fast"]] > values[["slow"]]
    }
    targets[selected] <- 1
    pulses <- if (is.null(ctx$state_prev$pulses)) 0L else ctx$state_prev$pulses
    list(
      targets = targets,
      state_update = list(pulses = pulses + 1L, selected = sum(selected))
    )
  }
} else {
  function(ctx, params) {
    targets <- ctx$flat()
    fast <- ctx$vec$feature("fast")
    slow <- ctx$vec$feature("slow")
    selected <- is.finite(fast) & is.finite(slow) & fast > slow
    targets[selected] <- 1
    pulses <- if (is.null(ctx$state_prev$pulses)) 0L else ctx$state_prev$pulses
    list(
      targets = targets,
      state_update = list(pulses = pulses + 1L, selected = sum(selected))
    )
  }
}
experiment <- ledgr_experiment(
  snapshot, strategy, features = features,
  opening = ledgr_opening(cash = 1e8), cost_model = ledgr_cost_zero()
)

invisible(gc(verbose = FALSE))
started <- proc.time()[["elapsed"]]
run <- suppressWarnings(ledgr_run(
  experiment, run_id = "ws16_feature_map_read_surface", seed = 1L
))
elapsed <- proc.time()[["elapsed"]] - started
on.exit(close(run), add = TRUE)

normalize_frame <- function(x) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  drop <- intersect(
    c("run_id", "event_id", "created_at_utc", "recorded_at_utc"), names(x)
  )
  if (length(drop)) x[drop] <- NULL
  for (name in names(x)) {
    if (inherits(x[[name]], "POSIXt")) {
      x[[name]] <- format(x[[name]], "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
    }
  }
  rownames(x) <- NULL
  x
}
identity <- function(x) {
  x <- normalize_frame(x)
  list(
    rows = nrow(x),
    hash = digest::digest(serialize(x, NULL, version = 3L), algo = "sha256")
  )
}
fills <- identity(ledgr_results(run, "fills"))
equity <- identity(ledgr_results(run, "equity"))
con <- DBI::dbConnect(duckdb::duckdb(), run$db_path)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
state <- DBI::dbGetQuery(
  con,
  paste(
    "SELECT ts_utc, state_json FROM strategy_state",
    "WHERE run_id = ? ORDER BY ts_utc"
  ),
  params = list(run$run_id)
)

result <- list(
  repo_commit = system2(
    "git", c("-C", shQuote(repo), "rev-parse", "HEAD"), stdout = TRUE
  )[[1L]],
  mode = mode,
  elapsed_s = unname(elapsed),
  fills = fills,
  equity = equity,
  strategy_state = identity(state)
)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(result, output, auto_unbox = TRUE, pretty = TRUE)
cat("LEDGR_WS16_CASE_OK", mode, sprintf("%.3f", elapsed), "\n")

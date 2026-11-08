# LDG-3217 (W3, no whole-history long bar frame): every bar query a committed
# run makes through ledgr_precompute_fetch_bars_frame(), pinned against lean,
# with its row count against all bars of the run's universe in range.
#
#   Rscript fetch_probe.R --lib=<pinned library> --arm=pinned|lean
#     (--db=<sealed store> | --state=<private build-state.json>) --out=<csv, appended>
#
# Same workload as memory.R. Private runs write counts only.

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  ws16 <- file.path(here, "..", "v0_2_3_ws16_entry")
  source(file.path(ws16, "common.R"), local = globalenv())
  source(file.path(ws16, "workloads.R"), local = globalenv())
  source(file.path(here, "..", "..", "lean_core", "load.R"), local = globalenv())
})
arm <- match.arg(ws16_need("arm"), c("pinned", "lean"))
lean <- lean_core_load(ws16_need("lib"), debug = FALSE)
if (identical(arm, "lean")) lean$lean_prepare_install()
calls <- new.env()
calls$rows <- integer()
ws16_wrap("ledgr_precompute_fetch_bars_frame", function(orig) {
  force(orig)
  function(...) {
    res <- orig(...)
    calls$rows <- c(calls$rows, nrow(res))
    res
  }
})
work <- tempfile("fetch_probe_")
dir.create(work)
store <- file.path(work, "store.duckdb")
state_path <- ws16_arg("state")
if (!is.null(state_path)) {
  state <- jsonlite::read_json(state_path, simplifyVector = TRUE)
  if (!file.copy(state$snapshot_path, store)) stop("Could not copy the sealed snapshot.", call. = FALSE)
  snapshot <- ledgr::ledgr_snapshot_open(store, state$snapshot_id, verify = TRUE)
  exp <- ledgr::ledgr_experiment(snapshot, ws16_momentum_strategy, features = list(ledgr::ledgr_ind_returns(252L)),
                                 schedule = ledgr::ledgr_schedule_month_start(),
                                 universe = ledgr::ledgr_universe_members(state$universe_id),
                                 valuation_policy = ledgr::ledgr_valuation_stale(5L),
                                 cost_model = ledgr::ledgr_cost_zero(), opening = ledgr::ledgr_opening(cash = 1e6))
  shape <- "private_h1"
} else {
  db <- ws16_need("db")
  if (!file.copy(db, store)) stop("Could not copy the prepared store.", call. = FALSE)
  snapshot <- ledgr::ledgr_snapshot_open(store, sub("\\.duckdb$", "", basename(db)), verify = TRUE)
  exp <- ws16_momentum_experiment(snapshot, 252L)
  shape <- sub("\\.duckdb$", "", basename(db))
}
bt <- ledgr::ledgr_run(exp, params = list(lookback = 252L, n = 20L), run_id = "cut12-fetch", seed = 1L)
con <- ledgr:::get_connection(snapshot)
total <- DBI::dbGetQuery(con, "SELECT count(*) AS n FROM snapshot_bars WHERE snapshot_id = ?",
                         params = list(snapshot$snapshot_id))$n
close(bt)
ledgr::ledgr_snapshot_close(snapshot)
unlink(work, recursive = TRUE)
res <- data.frame(shape = shape, arm = arm, fetch_calls = length(calls$rows), largest_fetch_rows = max(calls$rows, 0L),
                  fetched_rows = sum(calls$rows), snapshot_bars = total,
                  largest_fetch_share = round(max(calls$rows, 0L) / total, 3))
print(res, row.names = FALSE)
path <- ws16_need("out")
utils::write.table(res, path, sep = ",", row.names = FALSE, col.names = !file.exists(path), append = file.exists(path))

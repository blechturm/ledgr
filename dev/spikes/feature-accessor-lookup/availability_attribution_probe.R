# Supplementary probe for the feature-accessor spike. uncovered_paths_probe.R showed
# the availability-path run (sessions, stale(2)) at 500 x 1,260 spending about 44 s of
# 175 sampled seconds inside ledgr_execute_fold(), with ctx$features at about 9 s.
# This probe names where the rest goes. It profiles one production ledgr_run of the
# SMA 5/10 alias strategy on the availability path and one on the dense path (same
# bars) and writes availability_attribution.csv: for each path, the 40 functions with
# the largest total time and the 25 with the largest self time. Production code only;
# sampled profiles, not clocks.
#
# Usage, from the repository root:
#   Rscript dev/spikes/feature-accessor-lookup/availability_attribution_probe.R [--out <dir>]

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
spike_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
out_dir <- arg_value("--out", file.path(spike_dir, "evidence"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo_root, quiet = TRUE, compile = FALSE))
quiet <- function(expr) suppressWarnings(suppressMessages(expr))

bars <- as.data.frame(ledgr_sim_bars(n_instruments = 500L, n_days = 1260L, seed = 20260530L))
seal <- function(b, sessions) {
  path <- tempfile(fileext = ".duckdb"); facts <- NULL
  if (sessions) {
    b$ts_utc <- as.Date(b$ts_utc, tz = "UTC")
    dates <- seq(min(b$ts_utc), max(b$ts_utc), by = "day"); open <- !format(dates, "%u") %in% c("6", "7")
    facts <- ledgr_facts(ledgr_facts_sessions(data.frame(session_date = dates, status = ifelse(open, "open", "closed"),
      session_open = ifelse(open, "14:30:00", NA_character_), session_close = ifelse(open, "21:00:00", NA_character_),
      knowledge_time = as.POSIXct(min(dates) - 1L, tz = "UTC")), venue_id = "SPIKE", timezone = "UTC"))
  }
  s <- ledgr_snapshot_from_df(b, db_path = path, snapshot_id = "a", facts = facts); ledgr_snapshot_close(s)
  path
}
alias_map <- ledgr_feature_map(fast = ledgr_ind_sma(ledgr_param("fast_n")), slow = ledgr_ind_sma(ledgr_param("slow_n")))
profile_path <- function(label, path, valuation) {
  snapshot <- ledgr_snapshot_open(path, "a"); on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot, ledgr_demo_sma_crossover_strategy(), features = alias_map,
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(), valuation_policy = valuation)
  prof <- tempfile(fileext = ".Rprof")
  t0 <- Sys.time(); utils::Rprof(prof, interval = 0.01)
  run <- quiet(ledgr_run(exp, params = list(qty = 1, threshold = 0), feature_params = list(fast_n = 5L, slow_n = 10L),
    run_id = label, seed = 1L))
  invisible(ledgr_results(run, what = "fills")); invisible(ledgr_results(run, what = "equity"))
  utils::Rprof(NULL); wall <- as.numeric(Sys.time() - t0, units = "secs"); close(run)
  s <- utils::summaryRprof(prof); unlink(prof)
  top <- function(tab, col, n, kind) {
    tab <- tab[order(-tab[[col]]), , drop = FALSE][seq_len(min(n, nrow(tab))), , drop = FALSE]
    data.frame(path = label, kind = kind, rank = seq_len(nrow(tab)), fn = gsub("\"", "", rownames(tab)),
      seconds = tab[[col]], pct_of_sampled = round(100 * tab[[col]] / s$sampling.time, 1),
      sampled_seconds = s$sampling.time, wall_seconds = round(wall, 2))
  }
  rbind(top(s$by.total, "total.time", 40L, "total"), top(s$by.self, "self.time", 25L, "self"))
}
dense <- seal(bars, FALSE); avail <- seal(bars, TRUE); rm(bars)
out <- rbind(profile_path("availability", avail, ledgr_valuation_stale(2L)), profile_path("dense", dense, NULL))
utils::write.csv(out, file.path(out_dir, "availability_attribution.csv"), row.names = FALSE)
unlink(c(dense, avail))
print(out[out$kind == "total" & out$rank <= 40, c("path", "rank", "fn", "seconds", "pct_of_sampled")], row.names = FALSE)
print(out[out$kind == "self", c("path", "rank", "fn", "seconds", "pct_of_sampled")], row.names = FALSE)

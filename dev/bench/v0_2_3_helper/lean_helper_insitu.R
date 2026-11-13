# Cut 17 (LDG-3233): where the sizing helper's time goes inside a real lean
# run of slice2_10x7200. The strategy is the descriptor's; on each rebalance
# pulse two clocks run: first a read of the context columns the helper uses
# (universe, equity, member, buyable, position, holding_value, close; the
# view materialises each column on its first read), then the
# ledgr_target_rebalance() call itself on the now-read view. Reading columns
# is read-only; the run's work string must equal lean_helper_compare.R's.
#
#   Rscript dev/bench/v0_2_3_helper/lean_helper_insitu.R --lib=<lib> --arm=<name> --row=<csv>
# Run under the host policy (pcore.ps1, High performance).

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), args, value = TRUE)[[1L]])
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
ns <- asNamespace("ledgr")
defs <- new.env(parent = ns)
sys.source(file.path(repo, "dev/spikes/r_floor/fixture.R"), envir = defs, keep.source = FALSE)
sys.source(file.path(repo, "dev/bench/v0_2_3_lean_tuning_profile/descriptors.R"), envir = defs, keep.source = FALSE)
acc <- new.env(); acc$read <- 0; acc$helper <- 0; acc$calls <- 0L
# The strategy is the descriptor's own, unchanged (strategy preflight refuses
# clocks or captured helpers in strategy code). The clocks wrap the
# namespace binding of ledgr_target_rebalance(), which the strategy resolves.
orig <- get("ledgr_target_rebalance", envir = ns)
clock <- function() as.numeric(Sys.time())
timed <- function(ctx, ...) {
  t0 <- clock()
  for (col in c("universe", "equity", "member", "buyable", "position", "holding_value", "close")) ctx[[col]]
  t1 <- clock()
  out <- orig(ctx, ...)
  t2 <- clock()
  acc$read <- acc$read + (t1 - t0); acc$helper <- acc$helper + (t2 - t1); acc$calls <- acc$calls + 1L
  out
}
unlockBinding("ledgr_target_rebalance", ns); assign("ledgr_target_rebalance", timed, envir = ns); lockBinding("ledgr_target_rebalance", ns)
desc <- defs$bench_descriptor("slice2_10x7200")
store <- tempfile(fileext = ".duckdb")
ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "lh", price_basis = "split_adjusted"))
snapshot <- ledgr::ledgr_snapshot_open(store, "lh", verify = TRUE)
exp <- desc$experiment(snapshot)
lean <- new.env(parent = ns)
lean$.lean_debug <- FALSE
for (f in c("fifo.R", "plan.R", "loop.R", "loop_harness.R")) sys.source(file.path(repo, "dev/lean_core", f), envir = lean, keep.source = FALSE)
for (f in ls(lean, all.names = TRUE)) if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
restore <- lean$lean_loop_install()
invisible(gc(FALSE))
t0 <- as.numeric(Sys.time())
bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "lh", seed = 20260530L))
run_s <- as.numeric(Sys.time()) - t0
if (lean$lean_entry$lean_folds != 1L) stop("the lean loop did not run")
fills <- as.data.frame(ledgr::ledgr_results(bt, "fills"))
eq <- ledgr::ledgr_results(bt, "equity")
close(bt); restore(); ledgr::ledgr_snapshot_close(snapshot)
utils::write.csv(data.frame(arm = opt("arm"), lib = lib, calls = acc$calls, run_s = run_s, read_s = acc$read, helper_s = acc$helper,
  read_us_per_call = 1e6 * acc$read / acc$calls, helper_us_per_call = 1e6 * acc$helper / acc$calls,
  helper_us_per_pulse = 1e6 * acc$helper / 7200, fills = nrow(fills), final_equity = format(eq$equity[nrow(eq)], digits = 17)),
  opt("row"), row.names = FALSE)

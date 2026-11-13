# Input for the next lean tuning cut (found in Cut 17, 2026-11-14): the cost
# of strategy reads of the pulse context's asset fields inside a real lean
# run of slice2_10x7200. On each rebalance pulse, before the helper runs,
# every field the sizing helper reads is read twice through `$` (the lean
# context's method while the lean loop is installed): the first read builds
# the value (asset fields go to the pin's $.ledgr_pulse_context and
# ledgr_pulse_context_lazy_field()), the second is the cached read. Reads
# are read-only; fills and final equity must equal an untimed run's.
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/asset_reads.R --lib=<pin library> --out=<csv>
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
sys.source(file.path(here, "descriptors.R"), envir = defs, keep.source = FALSE)
fields <- c("universe", "equity", "member", "buyable", "position", "holding_value", "close")
acc <- new.env()
acc$first <- stats::setNames(numeric(length(fields)), fields); acc$cached <- acc$first; acc$calls <- 0L
clock <- function() as.numeric(Sys.time())
orig <- get("ledgr_target_rebalance", envir = ns)
timed <- function(ctx, ...) {
  for (f in fields) {
    t0 <- clock(); eval(call("$", ctx, f)); t1 <- clock(); eval(call("$", ctx, f)); t2 <- clock()
    acc$first[[f]] <- acc$first[[f]] + (t1 - t0); acc$cached[[f]] <- acc$cached[[f]] + (t2 - t1)
  }
  acc$calls <- acc$calls + 1L
  orig(ctx, ...)
}
unlockBinding("ledgr_target_rebalance", ns); assign("ledgr_target_rebalance", timed, envir = ns); lockBinding("ledgr_target_rebalance", ns)
desc <- defs$bench_descriptor("slice2_10x7200")
store <- tempfile(fileext = ".duckdb")
ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "ar", price_basis = "split_adjusted"))
snapshot <- ledgr::ledgr_snapshot_open(store, "ar", verify = TRUE)
exp <- desc$experiment(snapshot)
lean <- new.env(parent = ns)
lean$.lean_debug <- FALSE
for (f in c("fifo.R", "plan.R", "loop.R", "loop_harness.R")) sys.source(file.path(repo, "dev/lean_core", f), envir = lean, keep.source = FALSE)
for (f in ls(lean, all.names = TRUE)) if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
restore <- lean$lean_loop_install()
bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "ar", seed = 20260530L))
if (lean$lean_entry$lean_folds != 1L) stop("the lean loop did not run")
fills <- as.data.frame(ledgr::ledgr_results(bt, "fills"))
eq <- ledgr::ledgr_results(bt, "equity")
close(bt); restore(); ledgr::ledgr_snapshot_close(snapshot)
res <- data.frame(field = fields, calls = acc$calls, first_read_us = 1e6 * acc$first / acc$calls,
                  cached_read_us = 1e6 * acc$cached / acc$calls, fills = nrow(fills),
                  final_equity = format(eq$equity[nrow(eq)], digits = 17), lib = lib)
utils::write.csv(res, opt("out"), row.names = FALSE)
print(res[, 1:4], row.names = FALSE, digits = 3)
cat(sprintf("sum: first reads %.1f us, cached reads %.1f us per helper call\n", sum(res$first_read_us), sum(res$cached_read_us)))

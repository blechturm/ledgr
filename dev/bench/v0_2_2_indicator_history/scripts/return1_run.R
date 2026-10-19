# Usage: Rscript return1_run.R <tree> <label> <days> <out.csv>
args <- commandArgs(TRUE)
tree <- args[[1]]; label <- args[[2]]; days <- as.integer(args[[3]]); out_csv <- args[[4]]
suppressMessages(pkgload::load_all(tree, quiet = TRUE))
source(file.path(tree, "tests/testthat/helper-availability-runtime.R"))
snap <- availability_runtime_fixture(days = days)
ns <- asNamespace("ledgr")
scalar_name <- if (exists("ledgr_compute_feature_series_strict_scalar", envir = ns)) {
  "ledgr_compute_feature_series_strict_scalar"
} else {
  NA_character_
}
fn_calls <- 0L
counter <- function(...) NULL
exp <- ledgr_experiment(
  snap,
  function(ctx, params) ctx$hold(),
  features = list(ledgr_ind_returns(1L)),
  cost_model = ledgr_cost_zero()
)
# Count calls of the indicator's own scalar fn (per-window work).
target <- if (!is.na(scalar_name)) "ledgr_call_feature_fn" else "ledgr_call_feature_fn"
trace(target, quote(fn_calls <<- fn_calls + 1L), where = ns, print = FALSE)
elapsed <- system.time(bt <- ledgr_run(exp, run_id = "return1"))[["elapsed"]]
close(bt)
row <- data.frame(tree = label, days = days, run_seconds = elapsed, scalar_fn_calls = fn_calls)
print(row)
utils::write.table(row, out_csv, sep = ",", row.names = FALSE,
  col.names = !file.exists(out_csv), append = file.exists(out_csv))

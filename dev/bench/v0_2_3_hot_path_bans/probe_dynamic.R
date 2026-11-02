# Probe: which package functions execute while a fold stage is on the stack.
# Usage: Rscript probe_dynamic.R <lib> <pkg_dir> <out_dir>
args <- commandArgs(trailingOnly = TRUE)
lib <- args[[1]]; pkg <- args[[2]]; out <- args[[3]]
suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
source(file.path(pkg, "dev/bench/peer_benchmark/dense/recipes.R"))
ns <- asNamespace("ledgr")
stages <- c("ledgr_fold_stage_observe_settle", "ledgr_fold_stage_decide",
  "ledgr_fold_stage_plan", "ledgr_fold_stage_apply", "ledgr_fold_stage_commit")

rec <- new.env()
rec$depth <- 0L
rec$seen <- character()
enter_stage <- function() rec$depth <- rec$depth + 1L
leave_stage <- function() rec$depth <- rec$depth - 1L
note <- function(name) if (rec$depth > 0L) rec$seen[[name]] <- name

fns <- Filter(function(n) is.function(get(n, ns)) && !is.primitive(get(n, ns)), ls(ns, all.names = TRUE))
t0 <- proc.time()[["elapsed"]]
for (n in stages) suppressMessages(trace(n, tracer = enter_stage, exit = leave_stage,
  where = ns, print = FALSE))
traced <- 0L
for (n in setdiff(fns, stages)) {
  ok <- tryCatch({
    suppressMessages(trace(n, tracer = bquote(note(.(n))), where = ns, print = FALSE))
    TRUE
  }, error = function(e) FALSE)
  traced <- traced + ok
}
cat(sprintf("traced %d of %d functions in %.1f s\n", traced, length(fns), proc.time()[["elapsed"]] - t0))

for (label in names(dense_cases())) {
  case <- dense_cases()[[label]]
  fixture <- dense_fixture(case)
  snapshot <- ledgr_snapshot_from_df(fixture$bars, snapshot_id = paste0("dyn_", label),
    facts = fixture$facts, price_basis = "split_adjusted")
  exp <- ledgr_experiment(snapshot, fixture$strategy, features = fixture$features,
    opening = fixture$opening, cost_model = fixture$cost, risk_chain = ledgr_risk_none(),
    asset_state = fixture$asset_state,
    universe = if (case$facts) ledgr_universe_members("u") else NULL)
  t1 <- proc.time()[["elapsed"]]
  bt <- suppressWarnings(ledgr_run(exp, run_id = paste0("dyn_", label), seed = 20260530L))
  close(bt)
  sw <- suppressWarnings(ledgr_sweep(exp, ledgr_grid_named(one = list()), workers = 1L,
    seed = 20260530L, stop_on_error = TRUE))
  cat(sprintf("%-24s run+sweep %.1f s, seen %d\n", label, proc.time()[["elapsed"]] - t1, length(rec$seen)))
  ledgr_snapshot_close(snapshot)
}
dir.create(out, showWarnings = FALSE, recursive = TRUE)
writeLines(sort(unname(rec$seen)), file.path(out, "dynamic_seen.txt"))

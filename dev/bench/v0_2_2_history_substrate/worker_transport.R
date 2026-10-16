args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args) > 0L) args[[1L]] else ".",
  winslash = "/", mustWork = TRUE
)
output <- if (length(args) > 1L) args[[2L]] else file.path(
  root, "dev", "bench", "v0_2_2_history_substrate", "evidence",
  "ws41_worker_transport", "transport.csv"
)

dot_git <- file.path(root, ".git")
git_dir <- if (isTRUE(file.info(dot_git)$isdir)) {
  dot_git
} else {
  sub("^gitdir: ", "", readLines(dot_git, warn = FALSE)[[1L]])
}
package_head <- system2(
  "git",
  c(
    paste0("--git-dir=", shQuote(git_dir)),
    paste0("--work-tree=", shQuote(root)),
    "rev-parse", "HEAD"
  ),
  stdout = TRUE
)[[1L]]

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(root, quiet = TRUE)
source(file.path(root, "tests", "testthat", "helper-availability-runtime.R"))

snapshot <- availability_runtime_fixture(days = 8L)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
strategy <- function(ctx, params) {
  target <- ctx$flat()
  target[["AAA"]] <- params$qty
  target
}
experiment <- ledgr_experiment(
  snapshot,
  strategy,
  cost_model = ledgr_cost_zero()
)
grid <- ledgr_param_grid(
  one = list(qty = 1), two = list(qty = 2), three = list(qty = 3),
  four = list(qty = 4), five = list(qty = 5), six = list(qty = 6)
)
sequential <- ledgr_sweep(experiment, grid, seed = 41L, workers = 1L)

captured <- new.env(parent = emptyenv())
original <- ledgr:::ledgr_sweep_stage_history_tasks
parallel <- testthat::with_mocked_bindings(
  ledgr_sweep(experiment, grid, seed = 41L, workers = 2L),
  ledgr_sweep_stage_history_tasks = function(tasks, owner_id) {
    captured$unstaged_task_bytes <- as.numeric(utils::object.size(tasks))
    staged <- original(tasks, owner_id)
    captured$compact_task_bytes <- as.numeric(
      utils::object.size(staged$tasks)
    )
    captured$invariant_bytes <- as.numeric(
      utils::object.size(staged$invariant)
    )
    staged
  },
  .package = "ledgr"
)

columns <- c(
  "candidate_id", "candidate_row", "status", "final_equity", "n_trades",
  "execution_seed", "risk_chain_hash", "error_class", "error_msg"
)
parity <- isTRUE(all.equal(
  as.data.frame(sequential[, columns, drop = FALSE]),
  as.data.frame(parallel[, columns, drop = FALSE]),
  tolerance = 0,
  check.attributes = FALSE
))
staged_total <- captured$compact_task_bytes + captured$invariant_bytes
record <- data.frame(
  recorded_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  package_head = package_head,
  r_version = R.version.string,
  platform = paste(Sys.info()[c("sysname", "release", "machine")], collapse = " "),
  candidate_count = nrow(parallel),
  worker_count = 2L,
  unstaged_task_bytes = captured$unstaged_task_bytes,
  staged_invariant_bytes = captured$invariant_bytes,
  compact_task_bytes = captured$compact_task_bytes,
  staged_total_bytes = staged_total,
  staged_to_unstaged_ratio = staged_total / captured$unstaged_task_bytes,
  history_worker_support = attr(parallel, "history_worker_support"),
  result_parity = parity,
  stringsAsFactors = FALSE
)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(record, output, row.names = FALSE)
if (!parity) stop("Staged and sequential sweep results differ.", call. = FALSE)
cat(sprintf(
  "LEDGR_WS41_WORKER_TRANSPORT_OK ratio=%.6f\n",
  record$staged_to_unstaged_ratio
))

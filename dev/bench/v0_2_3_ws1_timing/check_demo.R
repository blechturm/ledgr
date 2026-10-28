# WS1 timing protocol (LDG-3127): demonstrates that check.R can fail.
#
# Builds a synthetic, otherwise valid record for the full frozen matrix (eight
# pairs, base and candidate equal, so every ratio is 1), confirms it passes,
# then applies one corruption at a time and requires check.R to fail for the
# named reason. The two cut-required demonstrations (a missing row; a ratio
# above 1.03) also run through the command line and must exit 1. No product
# code runs; nothing outside tempdir() is written.
#
# Usage: Rscript dev/bench/v0_2_3_ws1_timing/check_demo.R

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  assign("ws1_here", normalizePath(here, winslash = "/"), envir = globalenv())
})
root <- normalizePath(file.path(ws1_here, "..", "..", ".."), winslash = "/")
source(file.path(ws1_here, "matrix.R"))
source(file.path(ws1_here, "check.R"))

synthetic <- function() {
  cells <- ws1_timing_cells()
  grid <- merge(merge(data.frame(pair = seq_len(ws1_timing_pairs)), cells), data.frame(arm = ws1_timing_arms))
  grid <- grid[order(grid$pair, match(grid$workload, ws1_timing_workloads$workload), grid$path, grid$arm), ]
  decl <- ws1_timing_workloads[match(grid$workload, ws1_timing_workloads$workload), ]
  # Base and candidate share each pair's seconds, so every ratio of medians is 1.
  secs <- 0.5 + 0.01 * grid$pair + 0.1 * match(grid$workload, ws1_timing_workloads$workload)
  raw <- data.frame(seq = seq_len(nrow(grid)), pair = grid$pair, arm = grid$arm, workload = grid$workload,
    path = grid$path, seconds = sprintf("%.17g", secs), outcome = "ok", error = NA_character_,
    candidates = decl$candidates, statuses = decl$statuses, n_trades = "7", pid = "1",
    affinity = sprintf("%.17g", ws1_timing_affinity), power_plan_guid = ws1_timing_power_plan_guid,
    ledgr_path = "synthetic", ledgr_version = "synthetic", started_utc = "synthetic", exit_status = "0",
    stringsAsFactors = FALSE)
  digests <- vapply(ws1_timing_protocol_files, function(f) ws1_timing_file_digest(file.path(root, f)),
    character(1L))
  meta <- c(protocol_version = ws1_timing_protocol_version, label = "synthetic", smoke = "FALSE",
    finished_utc = "synthetic", power_plan_guid = ws1_timing_power_plan_guid,
    runner_affinity = sprintf("%.0f", ws1_timing_affinity), runner_worktree_clean_protocol = "TRUE",
    pairs = as.character(ws1_timing_pairs),
    retain_sha256 = digest::digest(ws1_timing_retain_text(root), algo = "sha256", serialize = FALSE),
    stats::setNames(digests, paste0("sha256:", ws1_timing_protocol_files)))
  list(raw = raw, meta = meta)
}

write_record <- function(rec, dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data.frame(key = names(rec$meta), value = unname(rec$meta), stringsAsFactors = FALSE),
    file.path(dir, "meta.csv"), row.names = FALSE)
  utils::write.csv(rec$raw, file.path(dir, "raw.csv"), row.names = FALSE, na = "NA")
  dir
}

cell_rows <- function(raw, workload, path, arm = NULL) {
  raw$workload == workload & raw$path == path & (if (is.null(arm)) TRUE else raw$arm %in% arm)
}

cases <- list(
  clean = list(expect = NA, edit = function(r) r),
  missing_row = list(expect = "missing row", edit = function(r) {
    r$raw <- r$raw[-which(cell_rows(r$raw, "dense_cost", "run", "candidate"))[[1L]], ]; r }),
  ratio_above_bound = list(expect = "ratio above bound", edit = function(r) {
    i <- cell_rows(r$raw, "timing_scale", "sweep", "candidate")
    r$raw$seconds[i] <- sprintf("%.17g", as.numeric(r$raw$seconds[i]) * 1.031); r }),
  duplicate_row = list(expect = "duplicate row", edit = function(r) {
    r$raw <- rbind(r$raw, r$raw[1L, ]); r }),
  non_finite = list(expect = "invalid seconds", edit = function(r) { r$raw$seconds[[3L]] <- "NaN"; r }),
  non_positive = list(expect = "invalid seconds", edit = function(r) { r$raw$seconds[[4L]] <- "0"; r }),
  failed_execution = list(expect = "failed or skipped execution", edit = function(r) {
    r$raw$outcome[[5L]] <- "error"; r$raw$error[[5L]] <- "injected"; r }),
  skipped_execution = list(expect = "failed or skipped execution", edit = function(r) {
    r$raw$outcome[[6L]] <- "skipped"; r }),
  incomplete_where_done_expected = list(expect = "incomplete or unexpected status", edit = function(r) {
    i <- which(cell_rows(r$raw, "dense_cost", "sweep"))[[1L]]
    r$raw$statuses[[i]] <- "DONE;INCOMPLETE;DONE"; r }),
  unpinned_row = list(expect = "host not registered", edit = function(r) { r$raw$affinity[[7L]] <- "16777215"; r }),
  smoke_record = list(expect = "smoke record", edit = function(r) { r$meta[["smoke"]] <- "TRUE"; r }),
  five_pairs_only = list(expect = "pair count", edit = function(r) {
    r$meta[["pairs"]] <- "5"; r$raw <- r$raw[as.integer(r$raw$pair) <= 5L, ]; r }),
  protocol_changed = list(expect = "protocol changed", edit = function(r) {
    r$meta[["sha256:dev/bench/v0_2_3_ws1_timing/matrix.R"]] <- "0"; r }),
  work_differs = list(expect = "work differs between rows", edit = function(r) {
    r$raw$n_trades[[which(cell_rows(r$raw, "walk_forward", "run", "candidate"))[[1L]]]] <- "8"; r }),
  empty_record = list(expect = "missing row", edit = function(r) { r$raw <- r$raw[0L, ]; r })
)

tmp <- file.path(tempdir(), "ws1_check_demo")
results <- data.frame(case = names(cases), expected = NA_character_, verdict = NA_character_,
  reasons = NA_character_, ok = FALSE, stringsAsFactors = FALSE)
for (j in seq_along(cases)) {
  case <- cases[[j]]
  dir <- write_record(case$edit(synthetic()), file.path(tmp, names(cases)[[j]]))
  res <- ws1_check_record(dir, root)
  reasons <- unique(res$failures$reason)
  results$expected[[j]] <- if (is.na(case$expect)) "PASS" else case$expect
  results$verdict[[j]] <- if (res$ok) "PASS" else "FAIL"
  results$reasons[[j]] <- paste(reasons, collapse = "; ")
  results$ok[[j]] <- if (is.na(case$expect)) res$ok else (!res$ok && case$expect %in% reasons)
}

# An explicit, linked maintainer exception turns the over-bound cell into EXCEPTED.
exc_file <- file.path(tmp, "exceptions.csv")
utils::write.csv(data.frame(workload = "timing_scale", path = "sweep", link = "inst/design/example.md#exception"),
  exc_file, row.names = FALSE)
excepted <- ws1_check_record(file.path(tmp, "ratio_above_bound"), root, exceptions = exc_file)
results[nrow(results) + 1L, ] <- list("ratio_above_bound_with_exception", "PASS",
  if (excepted$ok) "PASS" else "FAIL", paste(unique(excepted$failures$reason), collapse = "; "),
  excepted$ok && excepted$cells$verdict[excepted$cells$workload == "timing_scale" & excepted$cells$path == "sweep"] == "EXCEPTED")

# Command-line exit codes for the clean record and the two required demonstrations.
rscript <- file.path(R.home("bin"), "Rscript")
cli <- vapply(c("clean", "missing_row", "ratio_above_bound"), function(case) {
  out <- suppressWarnings(system2(rscript, c("--no-init-file", shQuote(file.path(ws1_here, "check.R")),
    shQuote(paste0("--record=", file.path(tmp, case)))), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  if (is.null(status)) 0L else as.integer(status)
}, integer(1L))

old <- options(width = 200)
print(results, row.names = FALSE)
cat("\ncommand-line exit codes:", paste(names(cli), cli, sep = "=", collapse = " "), "\n")
options(old)
stopifnot(all(results$ok), identical(unname(cli), c(0L, 1L, 1L)))
cat("DEMO PASS: check.R passes the clean record and fails every corruption for its named reason\n")

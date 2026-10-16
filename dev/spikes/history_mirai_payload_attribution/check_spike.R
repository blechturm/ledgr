#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
source(file.path(dirname(script_path), "common.R"), local = globalenv())
opt <- e0_parse_args(commandArgs(trailingOnly = TRUE), list(
  against = file.path(dirname(script_path), "evidence", "smoke"),
  actual = "", `package-root` = ".", `scratch-dir` = tempdir()
))
.libPaths(e0_lib_paths())

against <- normalizePath(opt$against, winslash = "/", mustWork = TRUE)
package_root <- normalizePath(opt$`package-root`, winslash = "/", mustWork = TRUE)
preset <- utils::read.csv(
  file.path(against, "fixture_shape.csv"), stringsAsFactors = FALSE
)$preset[[1L]]
if (!preset %in% c("smoke", "record")) stop("Unknown recorded preset.", call. = FALSE)
if (!nzchar(opt$actual)) {
  actual <- file.path(
    normalizePath(opt$`scratch-dir`, winslash = "/", mustWork = TRUE),
    paste0("history-e0-check-", Sys.getpid())
  )
  status <- system2(
    e0_rscript(),
    c(
      file.path(dirname(script_path), "run_spike.R"),
      "--preset", preset, "--package-root", package_root,
      "--out-dir", actual, "--gut", "none"
    )
  )
  if (!identical(status, 0L)) stop("Smoke rerun failed.", call. = FALSE)
} else {
  actual <- normalizePath(opt$actual, winslash = "/", mustWork = TRUE)
}

failures <- character()
check <- function(ok, message) {
  if (!isTRUE(ok)) failures <<- c(failures, message)
  invisible(ok)
}
read_csv <- function(root, file, col_classes = NA) {
  utils::read.csv(
    file.path(root, file), stringsAsFactors = FALSE,
    colClasses = col_classes, check.names = FALSE
  )
}
exact_files <- c(
  "fixture_shape.csv", "payload_map.csv", "payload_summary.csv",
  "result_identity.csv"
)
for (file in exact_files) {
  expected <- read_csv(against, file, "character")
  observed <- read_csv(actual, file, "character")
  check(identical(observed, expected), paste(file, "differs from recorded evidence"))
}

summary <- read_csv(actual, "arm_summary.csv")
check(identical(summary$arm, c("A", "B", "C")), "arm order must be A, B, C")
check(all(summary$status == "DONE"), "all three arms must finish DONE")
check(all(summary$exit_status == 0L), "all three worker processes must exit zero")
check(all(summary$sweep_wall_sec > 0), "all sweep clocks must be positive")
check(all(summary$sample_count >= 2L), "each arm needs at least two process samples")
always_memory <- c(
  "sweep_parent_peak_wset", "sweep_parent_peak_private_commit",
  "sweep_tree_peak_wset_sum", "sweep_tree_peak_private_commit_sum",
  "whole_tree_peak_wset_sum", "whole_tree_peak_private_commit_sum"
)
check(all(vapply(summary[always_memory], function(x) all(is.finite(x) & x > 0), logical(1))),
      "parent and process-tree memory observations must be finite and positive")
check(all(is.finite(summary$max_sample_gap_sec) & summary$max_sample_gap_sec > 0),
      "each arm must disclose its maximum sampling gap")
check(all(is.finite(summary$sweep_max_blackout_sec) &
            summary$sweep_max_blackout_sec > 0),
      "each arm must disclose its maximum in-sweep blackout")

identity <- read_csv(actual, "result_identity.csv", "character")
identity$arm <- NULL
by_arm <- split(identity, read_csv(actual, "result_identity.csv", "character")$arm)
by_arm <- lapply(by_arm, function(x) {
  x$arm <- NULL
  x <- x[order(x$candidate_id, method = "radix"), , drop = FALSE]
  rownames(x) <- NULL
  x
})
check(length(by_arm) == 3L && identical(by_arm$A, by_arm$B) && identical(by_arm$B, by_arm$C),
      "candidate results and reproduction identities must match across arms")

payload <- read_csv(actual, "payload_map.csv")
expected_fields <- c(
  "exp", "bars_by_id", "bars_mat", "static_bars_views", "pulses_posix",
  "pulses_iso", "metric_kernel", "retain", "precomputed_features",
  "runtime_projection", "snapshot_hash", "strategy_hash", "master_seed",
  "compiled_accounting_model", "availability_data", "availability_config",
  "execution_opportunities_posix", "corporate_action_rows", "index", "run_id",
  "candidate_id", "candidate_row", "raw_params", "params", "feature_params",
  "execution_seed", "candidate", "candidate_feature_row"
)
check(identical(sort(payload$field, method = "radix"), sort(expected_fields, method = "radix")),
      "task-field inventory changed")
expected_invariant <- expected_fields[seq_len(18L)]
check(setequal(payload$field[payload$invariant], expected_invariant),
      "candidate-invariant task fields changed")
expected_mori <- c(
  "bars_by_id", "bars_mat", "static_bars_views", "pulses_posix", "pulses_iso",
  "execution_opportunities_posix", "runtime_projection", "availability_data",
  "corporate_action_rows"
)
check(setequal(payload$field[payload$mori_candidate], expected_mori),
      "mori-candidate inventory changed")
check(
  identical(payload$staging_class[payload$field == "static_bars_views"],
            "derived_immutable"),
  "static_bars_views must remain classified as derived immutable data"
)

for (arm in "c") {
  reconstruction <- read_csv(actual, file.path(paste0("arm_", arm), "reconstruction.csv"))
  check(nrow(reconstruction) == 4L && all(reconstruction$exact) &&
          all(reconstruction$field_order_exact),
        paste0("arm ", toupper(arm), " must reconstruct all tasks exactly"))
}

proxy <- read_csv(actual, "payload_summary.csv")
value <- stats::setNames(proxy$value, proxy$measure)
check(value[["task_count"]] == 4, "record must contain four tasks")
check(value[["current_minus_staged_wire_proxy"]] > 0,
      "staging must reduce the base-R wire-size proxy")

allowed <- c(
  "dev/spikes/history_mirai_payload_attribution",
  "inst/design/spikes/history_mirai_payload_attribution"
)
old_home <- Sys.getenv("HOME", unset = "")
on.exit(Sys.setenv(HOME = old_home), add = TRUE)
if (.Platform$OS.type == "windows") Sys.setenv(HOME = Sys.getenv("USERPROFILE"))
status <- suppressWarnings(system2(
  "git", c("status", "--porcelain=v1", "--untracked-files=all"),
  stdout = TRUE, stderr = TRUE
))
if (!is.null(attr(status, "status")) && attr(status, "status") != 0L) {
  failures <- c(failures, "git scope guard could not read repository status")
} else if (length(status)) {
  status <- status[grepl("^(.. )", status)]
  paths <- sub("^.. ", "", status)
  paths <- sub("^.* -> ", "", paths)
  paths <- chartr("\\", "/", paths)
  generated <- paths %in% c("R/cpp11.R", "src/cpp11.cpp")
  if (any(generated)) {
    harmless <- vapply(paths[generated], function(path) {
      identical(suppressWarnings(system2(
        "git", c("diff", "--ignore-space-at-eol", "--quiet", "--", path)
      )), 0L)
    }, logical(1))
    generated[which(generated)[!harmless]] <- FALSE
  }
  in_scope <- vapply(paths, function(path) {
    any(path == allowed | startsWith(path, paste0(allowed, "/")))
  }, logical(1))
  in_scope[generated] <- TRUE
  check(all(in_scope), paste("out-of-scope path:", paste(paths[!in_scope], collapse = ", ")))
}

if (length(failures)) {
  cat(paste0("FAIL: ", failures, collapse = "\n"), "\n", sep = "")
  quit(status = 1L)
}
cat("HISTORY_E0_OK arms=3 candidates=4 payload_fields=28\n")

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
if (!nzchar(opt$actual)) {
  actual <- file.path(
    normalizePath(opt$`scratch-dir`, winslash = "/", mustWork = TRUE),
    paste0("history-e1-check-", Sys.getpid())
  )
  status <- system2(e0_rscript(), c(
    file.path(dirname(script_path), "run_spike.R"), "--preset", "smoke",
    "--package-root", package_root, "--out-dir", actual, "--gut", "none"
  ))
  if (status != 0L) stop("Smoke rerun failed.", call. = FALSE)
} else actual <- normalizePath(opt$actual, winslash = "/", mustWork = TRUE)

failures <- character()
check <- function(ok, message) {
  if (!isTRUE(ok)) failures <<- c(failures, message)
  invisible(ok)
}
read_csv <- function(root, file, classes = NA) {
  utils::read.csv(
    file.path(root, file), stringsAsFactors = FALSE, colClasses = classes,
    check.names = FALSE
  )
}

for (file in c(
  "payload_map.csv", "payload_summary.csv", "result_identity.csv",
  "reconstruction.csv", "shared_state.csv", "lifecycle.csv"
)) {
  check(
    identical(read_csv(actual, file, "character"), read_csv(against, file, "character")),
    paste(file, "differs from recorded smoke evidence")
  )
}

summary <- read_csv(actual, "arm_summary.csv")
check(identical(summary$arm, c("C", "D_SHARE", "D_REBUILD")), "arm order changed")
check(all(summary$status == "DONE") && all(summary$exit_status == 0L),
      "every smoke arm must finish DONE")
positive <- c(
  "parent_peak_wset", "parent_peak_private_commit", "daemon_peak_wset_sum",
  "daemon_peak_private_commit_sum", "sampled_parent_daemons_peak_wset",
  "sampled_parent_daemons_peak_private_commit", "in_process_parent_peak_wset",
  "in_process_parent_peak_private_commit"
)
check(all(vapply(summary[positive], function(x) all(is.finite(x) & x > 0), logical(1))),
      "memory observations must be finite and positive")
check(all(is.finite(summary$sample_round_interval_sec) &
          summary$sample_round_interval_sec > 0) &&
        all(is.finite(summary$max_sample_gap_sec) & summary$max_sample_gap_sec > 0),
      "sampling-round intervals and gaps must be disclosed")
check(all(summary$peak_collected_result_object_bytes > 0),
      "collected result boundaries must be measured")

identity <- read_csv(actual, "result_identity.csv", "character")
by_arm <- split(identity, identity$arm)
by_arm <- lapply(by_arm, function(x) {
  x$arm <- NULL
  x <- x[order(x$candidate_id, method = "radix"), , drop = FALSE]
  rownames(x) <- NULL
  x
})
check(
  length(by_arm) == 3L && identical(by_arm$C, by_arm$D_SHARE) &&
    identical(by_arm$D_SHARE, by_arm$D_REBUILD),
  "candidate outputs and identities must match across all arms"
)
check(all(identity$status == "DONE"), "all candidates must finish DONE")

payload <- read_csv(actual, "payload_map.csv")
reconstruction <- read_csv(actual, "reconstruction.csv")
check(nrow(reconstruction) == 8L && all(reconstruction$exact) &&
        all(reconstruction$verified) &&
        all(reconstruction$fields_compared == nrow(payload)) &&
        all(is.na(reconstruction$mismatched_fields) | reconstruction$mismatched_fields == ""),
      "both mori modes must reconstruct all four tasks exactly")

expected_mori <- c(
  "bars_by_id", "bars_mat", "static_bars_views", "pulses_posix", "pulses_iso",
  "execution_opportunities_posix", "runtime_projection", "availability_data",
  "corporate_action_rows"
)
check(setequal(payload$field[payload$mori_candidate], expected_mori),
      "E0's nine-field mori-candidate inventory changed")
meta_share <- read_csv(actual, file.path("arm_d_share", "arm_meta.csv"))
meta_rebuild <- read_csv(actual, file.path("arm_d_rebuild", "arm_meta.csv"))
check(setequal(strsplit(meta_share$mori_fields[[1L]], ";", fixed = TRUE)[[1L]],
               setdiff(expected_mori, "pulses_iso")) &&
        identical(meta_share$rebuild_fields[[1L]], "pulses_iso"),
      "D-share must share eight fields and rebuild pulses_iso")
check(setequal(strsplit(meta_rebuild$mori_fields[[1L]], ";", fixed = TRUE)[[1L]],
               setdiff(expected_mori, c("pulses_iso", "bars_mat", "static_bars_views"))) &&
        setequal(strsplit(meta_rebuild$rebuild_fields[[1L]], ";", fixed = TRUE)[[1L]],
                 c("bars_mat", "static_bars_views", "pulses_iso")),
      "D-rebuild must omit and rebuild all three derived fields")
check(meta_share$shared_wire_bytes[[1L]] < meta_share$shared_regular_bytes[[1L]] &&
        meta_rebuild$shared_wire_bytes[[1L]] < meta_rebuild$shared_regular_bytes[[1L]],
      "mori's XDR transport proxy must be compact")
check(meta_share$shared_region_count[[1L]] == 1L &&
        meta_rebuild$shared_region_count[[1L]] == 1L,
      "each mori arm must own one physical shared region")

shared <- read_csv(actual, "shared_state.csv")
check(nrow(shared) > 0L && all(shared$shared_atomic_leaves > 0L) &&
        all(shared$shared_atomic_leaves == shared$total_atomic_leaves),
      "every selected atomic leaf must remain shared before and after evaluation")

transfer <- read_csv(actual, "result_transfer.csv")
transfer_sum <- aggregate(
  cbind(result_serialized_bytes, envelope_object_bytes) ~ arm, transfer, sum
)
check(nrow(transfer_sum) == 3L &&
        length(unique(transfer_sum$result_serialized_bytes)) == 1L &&
        all(transfer_sum$result_serialized_bytes > 0L),
      "result-transfer proxies must be present and result bytes must match")
for (arm in c("arm_c", "arm_d_share", "arm_d_rebuild")) {
  retention <- read_csv(actual, file.path(arm, "retention.csv"))
  dropped <- retention[retention$label == "after_drop_promises_gc", , drop = FALSE]
  expected_labels <- c(
    "after_submit", paste0("after_collect_", seq_len(summary$n_candidates[[1L]])),
    "after_drop_promises_gc"
  )
  check(nrow(dropped) == 1L &&
          dropped$collected_result_object_bytes[[1L]] > 0L &&
          all(expected_labels %in% retention$label),
        paste(arm, "must record collection and retained-result boundaries"))
}

life <- read_csv(actual, "lifecycle.csv")
check(identical(life$mode, c("success", "failure", "forced_termination")) &&
        all(life$region_absent) &&
        all(life$cleanup_completed[life$mode != "forced_termination"]) &&
        isTRUE(life$live_mapping_before_termination[
          life$mode == "forced_termination"
        ]),
      paste(
        "shared regions must be live before forced termination and absent",
        "after success, failure, and forced termination"
      ))

root_update <- read_csv(
  file.path(dirname(script_path), "evidence", "probe"), "root_list_update.csv"
)
check(nrow(root_update) == 1L && root_update$root_shared_before &&
        !root_update$assignment_succeeded && root_update$error_contains_set_elt,
      "single-reference shared root-list replacement must fail at Set_elt")

allowed <- c(
  "dev/spikes/history_mori_feasibility",
  "inst/design/spikes/history_mori_feasibility"
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
  paths <- sub("^.. ", "", status[grepl("^.. ", status)])
  paths <- chartr("\\", "/", sub("^.* -> ", "", paths))
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
cat("HISTORY_E1_OK arms=3 candidates=4 shared=8 rebuilt=3 os_cleanup=clean\n")

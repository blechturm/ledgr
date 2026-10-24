# Check the Workstream 53 aggregate record without reading private inputs.

args <- commandArgs(trailingOnly = TRUE)
self_test <- "--self-test" %in% args
args <- setdiff(args, "--self-test")
if (length(args) != 1L) {
  stop("Usage: check_ws53.R <evidence_dir> [--self-test]", call. = FALSE)
}
root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
check_record <- function(root) {
fail <- function(...) stop(..., call. = FALSE)
expect <- function(ok, message) if (!isTRUE(ok)) fail(message)
read <- function(...) utils::read.csv(file.path(root, ...), stringsAsFactors = FALSE)
same_frame <- function(x, y, tolerance = 1e-8) {
  isTRUE(all.equal(x, y, tolerance = tolerance, check.attributes = FALSE))
}

steps <- read("steps.csv")
expected_one <- as.vector(outer(
  c("attrib_v003_la", "attrib_v003_lib", "attrib_v004_la", "attrib_v004_lib"),
  paste0("r", 1:3), paste, sep = "_"
))
expected_two <- as.vector(outer(
  c(
    "attrib_sweep_base_la", "attrib_sweep_v003_la",
    "attrib_sweep_v004_la", "attrib_sweep_v004_lib"
  ),
  paste0("r", 1:3), paste, sep = "_"
))
expected <- c(expected_one, expected_two)
expect(setequal(steps$tag, expected), "The one- and two-worker arm set changed.")
expect(all(as.integer(steps$exit_status) == 0L), "A measured arm did not exit cleanly.")
expect(all(as.numeric(steps$effective_sample_interval_s) <= 0.25), "A repeated arm missed the sampler interval.")
expect(all(as.integer(steps$other_r_at_start) == 0L), "A repeated arm started with a foreign R process.")
for (tag in expected) {
  samples <- utils::read.csv(
    gzfile(file.path(root, "samples", paste0(tag, ".csv.gz"))),
    stringsAsFactors = FALSE
  )
  row <- steps[steps$tag == tag, , drop = FALSE]
  parent_peak <- max(samples$private_bytes[samples$is_parent]) / 2^20
  r_rows <- samples[samples$role %in% c("parent", "daemon"), , drop = FALSE]
  tree_peak <- max(tapply(r_rows$private_bytes, r_rows$sample_id, sum)) / 2^20
  expect(abs(parent_peak - row$parent_peak_private_mib[[1L]]) <= 0.1,
         paste("Raw parent peak differs from steps.csv:", tag))
  expect(abs(tree_peak - row$parent_plus_daemon_peak_private_mib[[1L]]) <= 0.1,
         paste("Raw tree peak differs from steps.csv:", tag))
  sampled_span <- max(samples$epoch) - min(samples$epoch)
  expect(sampled_span <= row$elapsed_s[[1L]] + 0.5 &&
           row$elapsed_s[[1L]] - sampled_span <= 1.0,
         paste("Raw sample span differs from elapsed time:", tag))
}

arm_summary <- read("arm_summary.csv")
expect(all(arm_summary$repeats == 3L), "Every repeated contrast needs three arms.")
expected_arms <- sub("_r[123]$", "", expected)
expect(setequal(arm_summary$arm, unique(expected_arms)), "The summary arm set changed.")
derived_arm <- do.call(rbind, lapply(split(steps, sub("_r[123]$", "", steps$tag)), function(x) {
  data.frame(
    arm = sub("_r[123]$", "", x$tag[[1L]]),
    repeats = nrow(x),
    elapsed_s = stats::median(x$elapsed_s),
    parent_private_mib = stats::median(x$parent_peak_private_mib),
    tree_private_mib = stats::median(x$parent_plus_daemon_peak_private_mib),
    stringsAsFactors = FALSE
  )
}))
derived_arm <- derived_arm[order(derived_arm$arm), , drop = FALSE]
expect(same_frame(arm_summary, derived_arm), "arm_summary.csv does not derive from steps.csv.")

phase_memory <- read("phase_memory.csv")
derived_phase <- do.call(rbind, lapply(expected, function(tag) {
  markers <- read(paste0(tag, "__markers.csv"))
  samples <- utils::read.csv(
    gzfile(file.path(root, "samples", paste0(tag, ".csv.gz"))),
    stringsAsFactors = FALSE
  )
  start_label <- if ("run_start" %in% markers$label) "run_start" else "sweep_start"
  end_label <- if ("run_end" %in% markers$label) "run_end" else "sweep_end"
  start <- markers$epoch[markers$label == start_label][[1L]]
  end <- markers$epoch[markers$label == end_label][[1L]]
  bounds <- list(setup = c(-Inf, start), engine = c(start, end), result = c(end, Inf))
  do.call(rbind, lapply(names(bounds), function(phase) {
    part <- samples[samples$epoch >= bounds[[phase]][[1L]] &
                      samples$epoch <= bounds[[phase]][[2L]], , drop = FALSE]
    r_part <- part[part$role %in% c("parent", "daemon"), , drop = FALSE]
    data.frame(
      tag = tag,
      phase = phase,
      parent_private_mib = if (any(part$is_parent)) max(part$private_bytes[part$is_parent]) / 2^20 else NA_real_,
      tree_private_mib = if (nrow(r_part)) max(tapply(r_part$private_bytes, r_part$sample_id, sum)) / 2^20 else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
}))
phase_memory <- phase_memory[order(phase_memory$tag, phase_memory$phase), , drop = FALSE]
derived_phase <- derived_phase[order(derived_phase$tag, derived_phase$phase), , drop = FALSE]
expect(same_frame(phase_memory, derived_phase), "phase_memory.csv does not derive from raw samples.")
phase_summary <- read("phase_summary.csv")
derived_phase$arm <- sub("_r[123]$", "", derived_phase$tag)
derived_phase_summary <- do.call(rbind, lapply(
  split(derived_phase, list(derived_phase$arm, derived_phase$phase), drop = TRUE),
  function(x) data.frame(
    arm = x$arm[[1L]], phase = x$phase[[1L]], repeats = nrow(x),
    parent_private_mib = stats::median(x$parent_private_mib, na.rm = TRUE),
    tree_private_mib = stats::median(x$tree_private_mib, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
))
derived_phase_summary <- derived_phase_summary[
  order(derived_phase_summary$arm, derived_phase_summary$phase), , drop = FALSE
]
expect(same_frame(phase_summary, derived_phase_summary),
       "phase_summary.csv does not derive from raw phase rows.")

read_keys <- function(path) {
  x <- utils::read.csv(path, stringsAsFactors = FALSE)
  stats::setNames(as.character(x$value), as.character(x$key))
}
attrib_files <- list.files(root, pattern = "__attrib[.]csv$", full.names = TRUE)
expect(length(attrib_files) == length(expected), "An attribution result file is missing.")
attrib <- lapply(attrib_files, read_keys)
names(attrib) <- sub("__attrib[.]csv$", "", basename(attrib_files))
for (tag in expected_one) {
  required <- c(
    "product_commit", "acquisition_commit", "mode", "workers", "snapshot_hash",
    "status", "pulses", "fills", "trades", "final_equity", "fills_hash",
    "equity_hash", "trades_hash"
  )
  expect(all(required %in% names(attrib[[tag]])), paste("Run oracle is incomplete:", tag))
  expect(identical(attrib[[tag]][["status"]], "DONE"), paste("Unexpected run status:", tag))
  expect(identical(attrib[[tag]][["pulses"]], "7213"), paste("Unexpected pulse count:", tag))
  expect(identical(attrib[[tag]][["fills"]], "8798"), paste("Unexpected fill count:", tag))
  expected_trades <- if (grepl("v003", tag, fixed = TRUE)) {
    "4882"
  } else {
    "4870"
  }
  expect(
    identical(attrib[[tag]][["trades"]], expected_trades),
    paste("Unexpected trade count:", tag)
  )
}
for (tag in expected_two) {
  required <- c(
    "product_commit", "acquisition_commit", "mode", "workers", "snapshot_hash",
    "candidate_status", "candidate_count", "candidates_done", "final_equity",
    "execution_seed"
  )
  expect(all(required %in% names(attrib[[tag]])), paste("Sweep oracle is incomplete:", tag))
  expect(identical(attrib[[tag]][["candidate_status"]], "DONE;DONE"),
         paste("Unexpected candidate status:", tag))
  expect(identical(attrib[[tag]][["candidate_count"]], "2"),
         paste("Unexpected candidate count:", tag))
  expect(identical(attrib[[tag]][["candidates_done"]], "2"), paste("Unexpected candidate count:", tag))
}
groups <- list(
  v003_run = expected_one[grepl("v003", expected_one)],
  v004_run = expected_one[grepl("v004", expected_one)],
  v003_sweep = expected_two[grepl("base_la|v003_la", expected_two)],
  v004_sweep = expected_two[grepl("v004", expected_two)]
)
for (group in groups) {
  keys <- if (grepl("sweep", group[[1L]])) {
    c("candidate_status", "final_equity", "execution_seed")
  } else {
    c("status", "pulses", "fills", "trades", "final_equity", "fills_hash", "equity_hash", "trades_hash")
  }
  for (key in keys) {
    values <- vapply(group, function(tag) attrib[[tag]][[key]], "")
    expect(length(unique(values)) == 1L, paste("Native output differs for", key, "in", group[[1L]]))
  }
}
expect(length(unique(vapply(attrib, function(x) x[["product_commit"]], ""))) == 1L,
       "Repeated arms do not share one product commit.")
expect(length(unique(vapply(attrib, function(x) x[["acquisition_commit"]], ""))) == 1L,
       "Repeated arms do not share one frozen acquisition commit.")

profile <- read("current/profile_run.csv")
telemetry_run <- read("current/telemetry_run.csv")
for (x in list(profile, telemetry_run)) {
  expect(identical(x$status[[1L]], "DONE"), "The current H1 run is not DONE.")
  expect(as.integer(x$pulses[[1L]]) == 7213L, "The current H1 pulse count changed.")
  expect(as.integer(x$fills[[1L]]) == 8798L, "The current H1 fill count changed.")
}
hash_cols <- c("fills_hash", "equity_hash", "trades_hash")
expect(
  identical(as.character(profile[1L, hash_cols]), as.character(telemetry_run[1L, hash_cols])),
  "Profiling changed a native result hash."
)
phase_total <- sum(as.numeric(profile[1L, c("t_pre_s", "t_loop_s", "t_post_s")]))
expect(abs(phase_total - profile$elapsed_s[[1L]]) / profile$elapsed_s[[1L]] <= 0.10, "Public phases do not reconcile to the run wall.")
profile_total <- read("current/profile_total.csv")
canonical <- profile_total[profile_total$function_name == '"canonical_json"', , drop = FALSE]
expect(nrow(canonical) == 1L, "The canonical JSON profile row is missing.")
expect(canonical$total.time[[1L]] / profile$elapsed_s[[1L]] < 0.05, "Canonical JSON unexpectedly clears the five-percent gate.")
scheduler <- read("current/scheduler_lower_bound.csv")
expect(scheduler$wall_share[[1L]] >= 0.05, "The scheduler result no longer reaches Type 2 routing.")

workers <- read("workers/worker_scaling.csv")
expect(setequal(workers$tag, c("v003_workers2_census", "v004_workers4", "v004_workers8")), "The worker-arm set changed.")
expect(all(as.integer(workers$exit_status) == 0L), "A worker arm failed.")
expect(all(workers$effective_interval_s <= 0.25), "A worker arm missed the sampler interval.")
eight <- workers[workers$workers == 8L, , drop = FALSE]
expect(nrow(eight) == 1L, "The eight-worker trigger arm is missing.")
expect(eight$parent_plus_daemon_peak_private_mib[[1L]] <= 12 * 1024, "The eight-worker private peak exceeds 12 GiB.")
worker_results <- list.files(file.path(root, "workers"), pattern = "_result[.]csv$", full.names = TRUE)
result_rows <- lapply(worker_results, utils::read.csv, stringsAsFactors = FALSE)
v004 <- result_rows[vapply(result_rows, function(x) grepl("v004", x$tag[[1L]]), TRUE)]
expect(length(unique(vapply(v004, function(x) x$final_equity[[1L]], ""))) == 1L, "Worker count changed the v004 result.")
expect(length(unique(vapply(v004, function(x) x$execution_seed[[1L]], ""))) == 1L, "Worker count changed execution seeds.")
v004_two <- attrib[["attrib_sweep_v004_lib_r1"]]
expect(identical(v004_two[["final_equity"]], v004[[1L]]$final_equity[[1L]]),
       "The repeated two-worker result differs from the worker trigger arms.")
expect(identical(v004_two[["execution_seed"]], v004[[1L]]$execution_seed[[1L]]),
       "The repeated two-worker seeds differ from the worker trigger arms.")
for (path in worker_results) {
  tag <- sub("_result[.]csv$", "", basename(path))
  sample_path <- file.path(root, "workers", paste0(tag, "_samples.csv.gz"))
  samples <- utils::read.csv(gzfile(sample_path), stringsAsFactors = FALSE)
  row <- workers[workers$tag == tag, , drop = FALSE]
  parent_peak <- max(samples$private_bytes[samples$is_parent]) / 2^20
  r_rows <- samples[samples$is_parent | samples$process_name %in% c("r.exe", "rterm.exe", "rscript.exe"), , drop = FALSE]
  tree_peak <- max(tapply(r_rows$private_bytes, r_rows$sample_id, sum)) / 2^20
  expect(abs(parent_peak - row$parent_peak_private_mib[[1L]]) <= 1e-6,
         paste("Worker parent peak differs from raw samples:", tag))
  expect(abs(tree_peak - row$parent_plus_daemon_peak_private_mib[[1L]]) <= 1e-6,
         paste("Worker tree peak differs from raw samples:", tag))
}
worker_summary <- read("worker_summary.csv")
expected_worker_summary <- workers[, names(worker_summary), drop = FALSE]
expect(same_frame(worker_summary, expected_worker_summary),
       "worker_summary.csv does not derive from worker_scaling.csv.")

text_files <- list.files(root, pattern = "[.](csv|md|txt)$", recursive = TRUE, full.names = TRUE)
for (path in text_files) {
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect(!grepl("[A-Za-z]:[/\\\\]", text), paste("Private or local path leaked into", basename(path)))
}
invisible(TRUE)
}

check_record(root)
if (self_test) {
  mutation_fails <- function(change) {
    copy <- tempfile("ws53-check-")
    dir.create(copy)
    on.exit(unlink(copy, recursive = TRUE, force = TRUE), add = TRUE)
    file.copy(list.files(root, full.names = TRUE), copy, recursive = TRUE)
    change(copy)
    inherits(try(check_record(copy), silent = TRUE), "try-error")
  }
  raw_fails <- mutation_fails(function(copy) {
    path <- file.path(copy, "samples", "attrib_v003_la_r1.csv.gz")
    x <- utils::read.csv(gzfile(path), stringsAsFactors = FALSE)
    i <- which.max(x$private_bytes)
    x$private_bytes[[i]] <- 999999999999
    utils::write.csv(x, gzfile(path), row.names = FALSE)
  })
  arm_fails <- mutation_fails(function(copy) {
    path <- file.path(copy, "arm_summary.csv")
    x <- utils::read.csv(path, stringsAsFactors = FALSE)
    x$elapsed_s[[1L]] <- 999999
    utils::write.csv(x, path, row.names = FALSE)
  })
  phase_fails <- mutation_fails(function(copy) {
    path <- file.path(copy, "phase_summary.csv")
    x <- utils::read.csv(path, stringsAsFactors = FALSE)
    x$tree_private_mib[[1L]] <- 999999
    utils::write.csv(x, path, row.names = FALSE)
  })
  if (!all(raw_fails, arm_fails, phase_fails)) {
    stop("WS53 checker self-test did not reject every corruption.", call. = FALSE)
  }
}
cat("WS53_CHECK_OK\n")

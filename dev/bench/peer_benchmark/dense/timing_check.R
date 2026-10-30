# Record collection and exact native controls; four additional detectors only.
file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
here <- dirname(normalizePath(file, winslash = "/"))
source(file.path(here, "native.R"))

write_readable <- function(x, path) {
  text <- lapply(x, function(col) if (is.double(col)) sprintf("%.17g", col) else col)
  utils::write.csv(as.data.frame(text), path, row.names = FALSE, na = "NA")
}

timing_collect <- function(dir) {
  attempts <- jsonlite::read_json(file.path(dir, "attempts.json"), simplifyVector = TRUE)
  records <- list()
  for (i in seq_len(nrow(attempts))) {
    for (arm in c("cold", "warm")) {
      path <- file.path(attempts$scratch[i], paste0(arm, ".rds"))
      if (file.exists(path)) {
        x <- readRDS(path)
        key <- paste(x$row$shape, x$row$repetition, arm, sep = "/")
        records[[key]] <- x
      }
    }
  }
  if (!length(records)) stop("no completed clock; attempts/logs remain recorded")
  result <- list(rows = do.call(rbind, lapply(records, `[[`, "row")),
    controls = lapply(records, `[[`, "controls"), attempts = attempts,
    session = jsonlite::read_json(file.path(dir, "session.json"), simplifyVector = TRUE),
    environment_files = list.files(dir, pattern = "[.]environment[.]txt$"))
  rownames(result$rows) <- NULL
  saveRDS(result, file.path(dir, "record.rds"), version = 3L)
  write_readable(result$rows, file.path(dir, "raw.csv"))
  result
}

timing_validate <- function(record, dir) {
  r <- record$rows
  a <- record$attempts
  required_rows <- c("shape", "repetition", "arm", "pid", "source_revision", "status", "clock_sec",
    "setup_sec", "run_sec", "results_sec", "startup_sec", "import_sec", "input_sec", "snapshot_sec",
    "residual_sec", "configured_jit", "observed_jit", "installed_path", "n_instruments", "n_pulses",
    "instrument_bars", "persisted_callback_rows", "equity_pulse_rows", "warning_count", "duckdb_threads",
    "reuse", "precomputed_features", "required_outputs")
  required_attempts <- c("id", "shape", "repetition", "status", "exit_code", "source_revision",
    "harness_revision", "host_r_blob", "host_ps1_blob", "library", "scratch", "plan_guid",
    "parent_affinity", "child_affinity", "pid", "cpu_before", "cpu_after", "foreign_r_before",
    "foreign_r_after", "threads", "configured_jit", "started_utc", "elapsed_sec")
  stopifnot(is.data.frame(r), is.data.frame(a), setequal(names(r), required_rows),
    setequal(names(a), required_attempts),
    identical(record$session$attempt_limit_sec, 1200L), identical(record$session$repetitions, 5L),
    is.finite(record$session$measurement_window_sec), record$session$measurement_window_sec <= 5400,
    all(r$source_revision == record$session$source_revision),
    grepl("^[a-f0-9]{40}$", record$session$harness_revision),
    grepl("^[a-f0-9]{40}$", record$session$host_r_blob),
    grepl("^[a-f0-9]{40}$", record$session$host_ps1_blob),
    identical(record$session$host_r_path, "dev/bench/timing/host.R"),
    identical(record$session$host_ps1_path, "dev/bench/timing/host.ps1"))
  keys <- paste(r$shape, r$repetition, r$arm, sep = "/")
  expected <- expand.grid(shape = c("12x90", "500x1260"), repetition = 1:5,
    arm = c("cold", "warm"), stringsAsFactors = FALSE)
  stopifnot(nrow(r) == 20L, nrow(a) == 10L, !anyDuplicated(keys),
    setequal(keys, paste(expected$shape, expected$repetition, expected$arm, sep = "/")),
    identical(keys, names(record$controls)), all(a$status == "complete"),
    all(a$exit_code == 0L), all(a$parent_affinity == 65535), all(a$child_affinity == 65535),
    all(a$plan_guid == "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"),
    all(is.finite(a$cpu_before)), all(is.finite(a$cpu_after)),
    all(a$threads == "OMP=1;OPENBLAS=1;MKL=1;NUMEXPR=1"),
    all(a$configured_jit == 3L), all(a$elapsed_sec > 0 & a$elapsed_sec <= 1200),
    sum(a$elapsed_sec) <= 5400, !anyDuplicated(a$pid),
    all(a$harness_revision == record$session$harness_revision),
    all(a$host_r_blob == record$session$host_r_blob),
    all(a$host_ps1_blob == record$session$host_ps1_blob),
    all(r$status == "DONE"), all(is.finite(r$clock_sec) & r$clock_sec > 0),
    all(r$configured_jit == 3L), all(r$observed_jit == 3L),
    all(r$reuse == "unchanged_sealed_snapshot_and_first_use_only"),
    all(!r$precomputed_features), all(r$required_outputs == "fills;equity;cash;asset_holdings"),
    all(r$persisted_callback_rows == r$n_pulses), all(r$equity_pulse_rows == r$n_pulses),
    all(r$n_instruments == ifelse(r$shape == "12x90", 12L, 500L)),
    all(r$n_pulses == ifelse(r$shape == "12x90", 90L, 1260L)),
    all(r$instrument_bars == r$n_instruments * r$n_pulses),
    all(r$duckdb_threads > 0), length(unique(r$duckdb_threads)) == 1L,
    length(unique(r$source_revision)) == 1L, all(grepl("^[a-f0-9]{40}$", r$source_revision)),
    length(record$environment_files) == 10L,
    all(file.exists(file.path(dir, record$environment_files))))
  repo <- normalizePath(file.path(here, "../../../.."), winslash = "/", mustWork = TRUE)
  expected_host_r <- dense_git(repo, c("rev-parse",
    paste0(record$session$harness_revision, ":", record$session$host_r_path)))
  expected_host_ps1 <- dense_git(repo, c("rev-parse",
    paste0(record$session$harness_revision, ":", record$session$host_ps1_path)))
  stopifnot(identical(expected_host_r, record$session$host_r_blob),
    identical(expected_host_ps1, record$session$host_ps1_blob))
  host_csv <- c("preflight.host.csv", unlist(lapply(a$id,
    function(id) paste0(id, c(".before.host.csv", ".after.host.csv")))))
  stopifnot(all(file.exists(file.path(dir, host_csv))))
  host <- do.call(rbind, lapply(file.path(dir, host_csv), utils::read.csv,
    stringsAsFactors = FALSE))
  stopifnot(nrow(host) == 21L,
    all(host$plan_guid == "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"),
    all(is.finite(host$cpu_percent)), all(nzchar(host$root_chain)))
  ai <- match(paste(r$shape, r$repetition, sep = "_"), paste(a$shape, a$repetition, sep = "_"))
  stopifnot(!anyNA(ai), all(r$pid == a$pid[ai]), all(r$source_revision == a$source_revision[ai]),
    all(r$installed_path == gsub("\\", "/", paste0(a$library[ai], "/ledgr"), fixed = TRUE)))
  for (i in seq_len(nrow(r))) {
    phases <- c("setup_sec", "run_sec", "results_sec", "residual_sec")
    if (r$arm[i] == "cold") phases <- c(phases, "startup_sec", "import_sec", "input_sec", "snapshot_sec")
    values <- unlist(r[i, phases], use.names = FALSE)
    stopifnot(all(is.finite(values)), all(values >= -1e-6),
      abs(sum(values) - r$clock_sec[i]) <= 1e-6)
    if (r$arm[i] == "warm") stopifnot(all(is.na(r[i, c("startup_sec", "import_sec", "input_sec", "snapshot_sec")])))
  }
  for (shape in c("12x90", "500x1260")) {
    index <- which(r$shape == shape)
    first <- record$controls[[paste(shape, 1L, "cold", sep = "/")]]
    stopifnot(setequal(names(first), c("fill_count", "terminal_cash", "terminal_equity",
      "terminal_positions", "opening_cash", "opening_positions_value", "initial_state",
      "snapshot_hash", "config_hash")), is.finite(first$terminal_cash),
      is.finite(first$terminal_equity), is.character(first$initial_state), nzchar(first$initial_state))
    stopifnot(first$fill_count > 0L, first$opening_cash == 1e7, first$opening_positions_value == 0,
      nrow(first$terminal_positions) == if (shape == "12x90") 12L else 500L,
      !anyDuplicated(first$terminal_positions$instrument_id),
      all(is.finite(first$terminal_positions$qty)), all(first$terminal_positions$qty %in% c(0, 1)),
      grepl("^[a-f0-9]{64}$", first$snapshot_hash), grepl("^[a-f0-9]{64}$", first$config_hash))
    for (key in keys[index]) {
      differences <- dense_diff(first, record$controls[[key]], key)
      if (nrow(differences)) stop(paste(capture.output(print(differences)), collapse = "\n"))
    }
  }
  oracle <- readRDS(file.path(here, "oracles/20261030-pre-ws4/transition/native.rds"))$tables
  small <- record$controls[["12x90/1/cold"]]
  stopifnot(identical(small$fill_count, nrow(oracle$fills)),
    identical(small$terminal_cash, tail(oracle$equity_curve$cash, 1L)),
    identical(small$terminal_equity, tail(oracle$equity_curve$equity, 1L)),
    identical(small$terminal_positions, oracle$rebuilt_positions))
  invisible(TRUE)
}

# The lifecycle driver must use the live shared host implementation, and the
# probes must remain outside the process-cold and warm clocks.
timing_validate_source <- function(timing_path = file.path(here, "timing.R"),
                                   runner_path = file.path(here, "run_timing.ps1")) {
  timing <- readLines(timing_path, warn = FALSE)
  runner <- readLines(runner_path, warn = FALSE)
  required_timing <- c(
    'harness_dir <- file.path(repo, "dev", "bench", "timing")',
    'source(file.path(harness_dir, "host.R"))',
    'probe <- timing_host_probe(harness_dir = harness_dir)')
  stopifnot(all(required_timing %in% trimws(timing)))
  calls <- grep("Invoke-HostProbe ", runner, fixed = TRUE)
  launch <- grep("$Launch = ", runner, fixed = TRUE)
  wait <- grep("$p.WaitForExit", runner, fixed = TRUE)
  before <- grep("$Before = Invoke-HostProbe", runner, fixed = TRUE)
  after <- grep("$After = Invoke-HostProbe", runner, fixed = TRUE)
  stopifnot(length(before) == 1L, length(after) == 1L, length(launch) == 1L,
    length(wait) >= 1L, before < launch, after > max(wait),
    !any(calls > launch & calls < after))
  invisible(TRUE)
}

timing_guts <- function(record, dir) {
  timing_validate(record, dir)
  variants <- list()
  x <- record; x$rows <- x$rows[-1L, ]; variants$missing_cell <- x
  x <- record; x$attempts$child_affinity[1L] <- 16777215; variants$invalid_host <- x
  x <- record; x$attempts$status[1L] <- "censored"; variants$failed_or_censored <- x
  x <- record
  key <- "12x90/1/warm"
  x$controls[[key]]$terminal_positions$qty[1L] <- x$controls[[key]]$terminal_positions$qty[1L] + 1
  stopifnot(identical(x$rows$clock_sec, record$rows$clock_sec),
    identical(x$controls[[key]]$terminal_equity, record$controls[[key]]$terminal_equity))
  variants$asset_quantity_equity_times_unchanged <- x
  result <- lapply(names(variants), function(name) {
    error <- tryCatch({ timing_validate(variants[[name]], dir); NULL }, error = identity)
    stopifnot(inherits(error, "error"))
    data.frame(corruption = name, result = "detected", reason = conditionMessage(error))
  })
  do.call(rbind, result)
}

timing_structural_guts <- function() {
  timing <- readLines(file.path(here, "timing.R"), warn = FALSE)
  runner <- readLines(file.path(here, "run_timing.ps1"), warn = FALSE)
  variants <- list(
    shared_call_removed = list(timing = sub("timing_host_probe", "dense_host_probe", timing,
      fixed = TRUE), runner = runner),
    host_load_local = list(timing = sub('source(file.path(harness_dir, "host.R"))',
      'source(file.path(here, "host.R"))', timing, fixed = TRUE), runner = runner),
    probe_dir_local = list(timing = sub("harness_dir = harness_dir", "harness_dir = here",
      timing, fixed = TRUE), runner = runner),
    probe_inside_timer = list(timing = timing, runner = append(runner,
      "    $Bad = Invoke-HostProbe 'inside'", after = grep("$Launch = ", runner, fixed = TRUE)))
  )
  do.call(rbind, lapply(names(variants), function(name) {
    td <- tempfile("timing-structure-")
    dir.create(td)
    writeLines(variants[[name]]$timing, file.path(td, "timing.R"))
    writeLines(variants[[name]]$runner, file.path(td, "run_timing.ps1"))
    error <- tryCatch({
      timing_validate_source(file.path(td, "timing.R"), file.path(td, "run_timing.ps1"))
      NULL
    }, error = identity)
    unlink(td, recursive = TRUE)
    stopifnot(inherits(error, "error"))
    data.frame(corruption = name, result = "detected", reason = conditionMessage(error))
  }))
}

collect <- dense_arg("collect")
record_dir <- if (is.null(collect)) dense_arg("records") else collect
if (is.null(record_dir)) stop("--collect=<new raw record dir> or --records=<existing dir> required")
record <- if (is.null(collect)) readRDS(file.path(record_dir, "record.rds")) else timing_collect(collect)
timing_validate_source()
timing_validate(record, record_dir)
if ("--gut" %in% commandArgs(TRUE)) {
  guts <- rbind(timing_guts(record, record_dir), timing_structural_guts())
  print(guts, row.names = FALSE)
  output <- dense_arg("out", tempfile("timing-gut-", fileext = ".csv"))
  utils::write.csv(guts, output, row.names = FALSE)
}
summary <- do.call(rbind, lapply(split(record$rows, interaction(record$rows$shape, record$rows$arm)), function(x)
  data.frame(shape = x$shape[1L], clock = x$arm[1L], repetitions = nrow(x),
    median_sec = median(x$clock_sec), min_sec = min(x$clock_sec), max_sec = max(x$clock_sec))))
rownames(summary) <- NULL
print(summary, row.names = FALSE)
if (!is.null(collect)) write_readable(summary, file.path(record_dir, "summary.csv"))
cat("timing check: PASS; complete clocks, host/provenance and exact native controls\n")

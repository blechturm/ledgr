args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0L) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

has_flag <- function(name) {
  paste0("--", name) %in% args
}

script_arg <- commandArgs(FALSE)
script_arg <- script_arg[startsWith(script_arg, "--file=")]
if (length(script_arg) != 1L) stop("checker.R needs one --file argument.")
script_path <- normalizePath(
  sub("--file=", "", script_arg[[1L]], fixed = TRUE),
  winslash = "/",
  mustWork = TRUE
)
spike_dir <- dirname(script_path)
repo_dir <- normalizePath(
  file.path(spike_dir, "..", "..", ".."),
  winslash = "/",
  mustWork = TRUE
)
runner <- file.path(spike_dir, "runner.R")
evidence_dir <- normalizePath(
  arg_value("evidence", file.path(spike_dir, "evidence")),
  winslash = "/",
  mustWork = TRUE
)
n_inst <- as.integer(arg_value("n-inst", "500"))
n_days <- as.integer(arg_value("n-days", "1260"))
skip_rerun <- has_flag("skip-rerun")
run_gut <- has_flag("gut")
registered_shape <- identical(n_inst, 500L) && identical(n_days, 1260L)

failures <- character()
checks <- 0L

check <- function(condition, message) {
  checks <<- checks + 1L
  if (!isTRUE(condition)) failures <<- c(failures, message)
  invisible(condition)
}

read_evidence <- function(dir, name) {
  path <- file.path(dir, name)
  check(file.exists(path), sprintf("missing evidence file: %s", name))
  if (!file.exists(path)) return(data.frame())
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

as_bool <- function(x) {
  if (is.logical(x)) return(x)
  tolower(as.character(x)) == "true"
}

validate_evidence <- function(dir, expected_inst, expected_days,
                              require_profiles = TRUE,
                              registered_shape = FALSE) {
  fixture <- read_evidence(dir, "fixture.csv")
  measurements <- read_evidence(dir, "measurements.csv")
  outputs <- read_evidence(dir, "outputs.csv")
  parity <- read_evidence(dir, "parity.csv")
  spreads <- read_evidence(dir, "position_spreads.csv")
  effects <- read_evidence(dir, "pairwise_effects.csv")
  environment <- read_evidence(dir, "environment.csv")

  if (nrow(fixture) == 1L) {
    check(fixture$fixture_seed[[1L]] == 20260530L, "fixture seed changed")
    check(fixture$instruments[[1L]] == expected_inst, "instrument count changed")
    check(fixture$pulses[[1L]] == expected_days, "pulse count changed")
    check(fixture$fast_n[[1L]] == 5L, "fast SMA window changed")
    check(fixture$slow_n[[1L]] == 10L, "slow SMA window changed")
    check(
      grepl("^[0-9a-f]{64}$", fixture$snapshot_hash[[1L]]),
      "snapshot hash is not SHA-256 shaped"
    )
    check(
      identical(
        fixture$permutations[[1L]],
        "ABC;ACB;BAC;BCA;CAB;CBA"
      ),
      "permutation set changed"
    )
  }

  expected_permutations <- c("ABC", "ACB", "BAC", "BCA", "CAB", "CBA")
  expected_order <- do.call(rbind, lapply(expected_permutations, function(p) {
    data.frame(
      permutation = p,
      position = 1:3,
      arm = strsplit(p, "", fixed = TRUE)[[1L]],
      stringsAsFactors = FALSE
    )
  }))
  observed_order <- measurements[, c("permutation", "position", "arm"), drop = FALSE]
  rownames(observed_order) <- NULL
  check(identical(observed_order, expected_order), "the 18 arm-position cells changed")
  check(nrow(measurements) == 18L, "measurements must contain 18 rows")
  check(all(measurements$status == "DONE"), "one or more measured runs did not finish")
  check(all(measurements$prior_runs == 0L), "a copied store contained prior runs")
  check(
    all(measurements$cache_entries_before == 0L),
    "a measured arm started with a non-empty feature cache"
  )
  if (nrow(fixture) == 1L && nrow(measurements) > 0L) {
    check(
      all(measurements$snapshot_hash == fixture$snapshot_hash[[1L]]),
      "copied stores did not verify to the frozen snapshot hash"
    )
    check(
      all(measurements$store_sha256 == fixture$sealed_store_sha256[[1L]]),
      "an arm did not start from a byte-identical store copy"
    )
  }
  for (arm in c("A", "B", "C")) {
    for (position in 1:3) {
      count <- sum(measurements$arm == arm & measurements$position == position)
      check(count == 2L, sprintf("arm %s position %d does not occur twice", arm, position))
    }
  }
  version_columns <- c(
    "R_version", "ledgr_version", "TTR_version", "duckdb_version",
    "collapse_version"
  )
  for (name in version_columns) {
    check(
      length(unique(measurements[[name]])) == 1L,
      sprintf("child processes resolved different %s values", name)
    )
  }
  check(nrow(environment) == 1L, "environment evidence needs one row")
  check(
    all(is.finite(measurements$measured_sec) & measurements$measured_sec > 0),
    "measured clocks must be finite and positive"
  )
  check(
    all(abs(
      measurements$measured_sec -
        (measurements$experiment_sec + measurements$run_sec +
           measurements$equity_result_sec + measurements$fills_result_sec +
           measurements$trades_result_sec)
    ) < 1e-9),
    "measured phase clocks do not reconcile"
  )

  check(nrow(outputs) == 18L, "outputs must contain 18 arm rows")
  if (nrow(outputs) == 18L) {
    check(
      all(outputs$feature_rows == 2L * expected_inst * expected_days),
      "feature output does not cover every instrument, pulse and SMA"
    )
    check(all(outputs$equity_rows == expected_days), "equity output is incomplete")
    for (permutation in expected_permutations) {
      selected <- outputs[outputs$permutation == permutation, , drop = FALSE]
      check(
        length(unique(selected$feature_na_hash)) == 1L,
        sprintf("feature NA masks differ in %s", permutation)
      )
      check(
        length(unique(selected$equity_rows)) == 1L &&
          length(unique(selected$fills_rows)) == 1L &&
          length(unique(selected$trades_rows)) == 1L,
        sprintf("result row counts differ in %s", permutation)
      )
    }
  }

  check(nrow(parity) == 18L, "parity must contain 18 pair rows")
  parity_flags <- c(
    "feature_axis_identical", "feature_na_mask_identical",
    "feature_values_equal", "equity_equal", "fills_equal", "trades_equal"
  )
  for (name in parity_flags) {
    check(all(as_bool(parity[[name]])), sprintf("%s contains a failed comparison", name))
  }
  tolerance_columns <- c(
    "feature_max_relative", "equity_max_relative",
    "fills_max_relative", "trades_max_relative"
  )
  for (name in tolerance_columns) {
    check(
      all(parity[[name]] <= 1e-8),
      sprintf("%s exceeds the registered tolerance", name)
    )
  }

  check(nrow(spreads) == 72L, "position-spread table shape changed")
  check(nrow(effects) == 3L, "pairwise-effects table shape changed")
  if (nrow(effects) == 3L) {
    derived <- as_bool(effects$stable_direction) &
      as_bool(effects$exceeds_one_second) &
      as_bool(effects$exceeds_five_percent) &
      as_bool(effects$exceeds_largest_spread) &
      as_bool(effects$localized_by_phase)
    check(
      identical(derived, as_bool(effects$structural_difference)),
      "structural declarations do not implement the registered conjunction"
    )
  }

  if (isTRUE(require_profiles)) {
    for (arm in c("A", "B", "C")) {
      profile <- read_evidence(dir, sprintf("profile_%s.csv", arm))
      check(nrow(profile) > 0L, sprintf("profile %s is empty", arm))
      if (nrow(profile) > 0L) {
        check(all(profile$arm == arm), sprintf("profile %s is mislabelled", arm))
        check(
          any(grepl("ledgr_run", profile$function_name, fixed = TRUE)),
          sprintf("profile %s did not sample ledgr_run", arm)
        )
      }
    }
  }

  if (isTRUE(registered_shape)) {
    check(n_inst == 500L && n_days == 1260L, "registered evidence is not 500 by 1260")
  }
  invisible(list(
    fixture = fixture,
    measurements = measurements,
    outputs = outputs,
    parity = parity,
    spreads = spreads,
    effects = effects
  ))
}

compare_deterministic <- function(recorded, rerun) {
  stable_fixture <- c(
    "fixture_seed", "instruments", "pulses", "fast_n", "slow_n",
    "snapshot_id", "snapshot_hash", "permutations"
  )
  check(
    identical(recorded$fixture[, stable_fixture], rerun$fixture[, stable_fixture]),
    "rerun fixture identity differs"
  )
  check(
    identical(recorded$outputs, rerun$outputs),
    "rerun output hashes or row counts differ"
  )
  check(
    identical(recorded$parity, rerun$parity),
    "rerun output parity differs"
  )
}

check_scope <- function() {
  status <- system2(
    "git",
    c("-C", repo_dir, "status", "--porcelain=v1", "--untracked-files=all"),
    stdout = TRUE,
    stderr = TRUE
  )
  exit_status <- attr(status, "status")
  check(is.null(exit_status) || exit_status == 0L, "git status failed")
  if (length(status) == 0L) return(invisible(TRUE))
  paths <- trimws(sub("^..", "", status))
  paths <- gsub("\\\\", "/", paths)
  allowed <- startsWith(paths, "dev/spikes/indicator-source-attribution/") |
    paths == "inst/design/ledgr_v0_2_0_2_spec_packet/tickets.yml"
  check(
    all(allowed),
    paste("out-of-scope worktree paths:", paste(paths[!allowed], collapse = ", "))
  )
  invisible(TRUE)
}

recorded <- validate_evidence(
  evidence_dir,
  expected_inst = n_inst,
  expected_days = n_days,
  registered_shape = registered_shape
)
check_scope()

if (!skip_rerun) {
  rerun_dir <- arg_value(
    "rerun-dir",
    file.path(spike_dir, ".checker-rerun")
  )
  rerun_dir <- normalizePath(rerun_dir, winslash = "/", mustWork = FALSE)
  if (dir.exists(rerun_dir)) unlink(rerun_dir, recursive = TRUE, force = TRUE)
  status <- system2(
    Sys.which("Rscript"),
    c(
      runner,
      paste0("--out-dir=", rerun_dir),
      paste0("--n-inst=", n_inst),
      paste0("--n-days=", n_days)
    )
  )
  check(identical(status, 0L), "full evidence rerun failed")
  if (identical(status, 0L)) {
    rerun <- validate_evidence(
      rerun_dir,
      expected_inst = n_inst,
      expected_days = n_days,
      registered_shape = registered_shape
    )
    compare_deterministic(recorded, rerun)
  }
}

if (run_gut) {
  gut_dir <- file.path(spike_dir, ".checker-gut")
  if (dir.exists(gut_dir)) unlink(gut_dir, recursive = TRUE, force = TRUE)
  status <- system2(
    Sys.which("Rscript"),
    c(
      runner,
      paste0("--out-dir=", gut_dir),
      "--n-inst=5",
      "--n-days=30",
      "--gut-arm=C"
    )
  )
  check(identical(status, 0L), "gutted runner failed before producing evidence")
  before <- length(failures)
  if (identical(status, 0L)) {
    validate_evidence(
      gut_dir,
      expected_inst = 5L,
      expected_days = 30L,
      require_profiles = FALSE,
      registered_shape = FALSE
    )
  }
  gut_failures <- if (length(failures) > before) {
    failures[seq.int(before + 1L, length(failures))]
  } else {
    character()
  }
  check(
    length(failures) > before,
    "changing the public TTR slow window did not make the checker fail"
  )
  if (length(gut_failures) > 0L) {
    cat(
      "GUT_DETECTED: ",
      paste(gut_failures, collapse = " | "),
      "\n",
      sep = ""
    )
  }
  failures <- failures[seq_len(before)]
}

if (length(failures) > 0L) {
  cat("INDICATOR_ATTRIBUTION_CHECKS_FAILED\n")
  for (failure in failures) cat("- ", failure, "\n", sep = "")
  quit(status = 1L)
}
cat(sprintf("INDICATOR_ATTRIBUTION_CHECKS_OK: %d checks\n", checks))

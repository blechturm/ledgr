# Diff checker for the H2 Session D indicator-history evidence.
#
# Usage:
#   Rscript check.R <ledgr_repo>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("usage: check.R <ledgr_repo>")
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
Sys.setenv(HOME = normalizePath(Sys.getenv("USERPROFILE"), winslash = "/"))
spike <- file.path(repo, "dev/spikes/history-indicator-conformance")
recorded <- file.path(
  repo,
  "inst/design/spikes/history_indicator_conformance_spike/evidence"
)
rscript <- file.path(R.home("bin"), "Rscript")
failures <- character()
fail <- function(...) failures <<- c(failures, paste0(...))

git <- function(...) {
  suppressWarnings(system2(
    "git",
    c("-C", shQuote(repo), ...),
    stdout = TRUE,
    stderr = TRUE
  ))
}
guard_paths <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
product_paths <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man")
status_before <- git("status", "--porcelain", "--", guard_paths)

run <- function(out, gut = FALSE) {
  call_args <- c(
    shQuote(file.path(spike, "runner.R")),
    shQuote(repo),
    shQuote(out)
  )
  if (gut) call_args <- c(call_args, "--gut")
  status <- system2(rscript, call_args, stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(status, "status")) && attr(status, "status") != 0L) {
    fail("runner failed: ", paste(status, collapse = " | "))
  }
}
read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

scratch <- tempfile("history-h2-d-check-")
normal <- file.path(scratch, "normal")
gutted <- file.path(scratch, "gut")
dir.create(normal, recursive = TRUE)
dir.create(gutted, recursive = TRUE)
run(normal)
run(gutted, gut = TRUE)

files <- c(
  "metadata.csv", "inventory.csv", "raw_samples.csv", "conformance.csv",
  "gap_samples.csv", "gap_recovery.csv", "dense_oracle.csv"
)
for (file in files) {
  old <- file.path(recorded, file)
  fresh <- file.path(normal, file)
  if (!file.exists(old) || !file.exists(fresh) ||
      !identical(read_text(old), read_text(fresh))) {
    fail("recorded evidence differs from rerun: ", file)
  }
}

inventory <- utils::read.csv(file.path(normal, "inventory.csv"), stringsAsFactors = FALSE)
conformance <- utils::read.csv(file.path(normal, "conformance.csv"), stringsAsFactors = FALSE)
recovery <- utils::read.csv(file.path(normal, "gap_recovery.csv"), stringsAsFactors = FALSE)
dense <- utils::read.csv(file.path(normal, "dense_oracle.csv"), stringsAsFactors = FALSE)
gut_conf <- utils::read.csv(file.path(gutted, "conformance.csv"), stringsAsFactors = FALSE)

expected_names <- c(
  "builtin_sma", "builtin_ema", "builtin_rsi", "builtin_returns",
  "ttr_rsi_value", "ttr_sma_value", "ttr_ema_value",
  "ttr_atr_tr", "ttr_atr_atr", "ttr_atr_truehigh", "ttr_atr_truelow",
  "ttr_macd_macd", "ttr_macd_signal", "ttr_macd_histogram",
  "ttr_wma_value", "ttr_roc_value", "ttr_momentum_value", "ttr_cci_value",
  "ttr_bbands_dn", "ttr_bbands_mavg", "ttr_bbands_up", "ttr_bbands_pctb",
  "ttr_aroon_aroonup", "ttr_aroon_aroondn", "ttr_aroon_oscillator",
  "ttr_donchianchannel_high", "ttr_donchianchannel_mid",
  "ttr_donchianchannel_low", "ttr_mfi_value", "ttr_cmf_value",
  "ttr_runmean_value", "ttr_runsd_value", "ttr_runvar_value",
  "ttr_runmad_value"
)
if (!identical(inventory$indicator, expected_names)) {
  fail("indicator/output inventory does not match the 34 frozen supported outputs")
}

history_dependent <- c(
  "ttr_rsi_value", "ttr_ema_value", "ttr_atr_atr",
  "ttr_macd_macd", "ttr_macd_signal", "ttr_macd_histogram"
)
expected_class <- ifelse(
  inventory$indicator %in% history_dependent,
  "history_dependent",
  "bounded"
)
if (!identical(inventory$history_class, expected_class)) {
  fail("algorithm classification differs from frozen current-source classification")
}
aroon <- inventory[inventory$family == "aroon", , drop = FALSE]
if (!all(aroon$stable_after == 10L & aroon$dependency_bars == 11L)) {
  fail("aroon stable-after/dependency-width mismatch is no longer exposed")
}
if (!all(conformance$prefix_all_identical)) {
  fail("full-series prefix causality changed")
}
if (!all(dense$na_pattern_equal & dense$finite_values_identical)) {
  fail("internal engine no longer reproduces the public dense-run oracle")
}

bounded <- conformance$history_class == "bounded"
if (max(conformance$scalar_max_scaled_delta[bounded]) >= 1e-7) {
  fail("bounded fixture deltas no longer stay below the observed 1e-7 separator")
}
for (name in history_dependent) {
  rows <- conformance[conformance$indicator == name, , drop = FALSE]
  if (!nrow(rows) || max(rows$scalar_max_scaled_delta) <= 1e-7) {
    fail("history dependence not exposed for ", name)
  }
}

admitted <- unique(recovery$indicator[recovery$current_availability_status == "ok"])
expected_admitted <- c("builtin_sma", "builtin_returns", "ttr_sma_value")
if (!setequal(admitted, expected_admitted)) {
  fail("current availability admission set changed")
}
if (!all(recovery$observed_first_valid_lag == recovery$declared_first_valid_lag)) {
  fail("first-valid evidence no longer matches the declared stable_after boundary")
}
recursive <- recovery$history_class == "history_dependent"
if (!any(recovery$lag_until_1e_9[recursive] >
         recovery$observed_first_valid_lag[recursive], na.rm = TRUE)) {
  fail("convergence evidence no longer distinguishes readiness from first-valid")
}

normal_recursive <- max(
  conformance$scalar_max_scaled_delta[conformance$history_class == "history_dependent"]
)
gut_recursive <- max(
  gut_conf$scalar_max_scaled_delta[gut_conf$history_class == "history_dependent"]
)
if (!(normal_recursive > 1e-7 && gut_recursive == 0)) {
  fail("gut did not erase the restart comparison for history-dependent outputs")
}

status_after <- git("status", "--porcelain", "--", guard_paths)
if (!identical(status_before, status_after)) {
  fail("runner changed package or design scope")
}
product_diff <- git(
  "diff", "--name-only", "a4fdce08", "HEAD", "--", product_paths
)
if (length(product_diff)) {
  fail("product files differ from package baseline: ", paste(product_diff, collapse = ", "))
}

if (length(failures)) {
  cat("H2_D_CHECK_FAILED\n", paste("-", failures, collapse = "\n"), "\n")
  quit(status = 1L)
}
cat("H2_D_CHECK_PASS outputs=34 prefix=causal dense=identical gut=detected scope=clean\n")

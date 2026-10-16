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
  "width_witness.csv", "gap_samples.csv", "gap_recovery.csv",
  "path_plumbing.csv"
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
plumbing <- utils::read.csv(file.path(normal, "path_plumbing.csv"), stringsAsFactors = FALSE)
width_witness <- utils::read.csv(file.path(normal, "width_witness.csv"), stringsAsFactors = FALSE)
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
  "ttr_runmad_value",
  "variant_bbands_mavg_ema", "variant_cci_ema", "variant_rsi_sma",
  "variant_atr_atr_sma", "variant_macd_macd_sma",
  "variant_macd_signal_sma", "variant_macd_histogram_sma",
  "variant_ema_wilder"
)
if (!identical(inventory$indicator, expected_names)) {
  fail("indicator/output inventory does not match 34 defaults plus eight variant outputs")
}

default_history_dependent <- c(
  "ttr_rsi_value", "ttr_ema_value", "ttr_atr_atr",
  "ttr_macd_macd", "ttr_macd_signal", "ttr_macd_histogram"
)
variant_history_dependent <- c(
  "variant_bbands_mavg_ema", "variant_cci_ema", "variant_ema_wilder"
)
history_dependent <- c(default_history_dependent, variant_history_dependent)
expected_class <- ifelse(
  inventory$indicator %in% history_dependent,
  "history_dependent",
  "bounded"
)
if (!identical(inventory$history_class, expected_class)) {
  fail("family/output/algorithm classification differs from the frozen source classification")
}
defaults <- inventory$census_role == "default_arguments"
if (sum(defaults) != 34L ||
    sum(defaults & inventory$history_class == "bounded") != 28L ||
    sum(defaults & inventory$history_class == "history_dependent") != 6L) {
  fail("default-argument census is no longer 34 outputs split 28 bounded and 6 history-dependent")
}
if (sum(inventory$census_role == "algorithm_variant") != 8L) {
  fail("algorithm-variant census no longer contains eight expanded outputs")
}
aroon <- inventory[inventory$family == "aroon", , drop = FALSE]
aroon_conf <- conformance[conformance$indicator %in% aroon$indicator, , drop = FALSE]
if (!all(aroon$stable_after == 10L &
         aroon$observed_upper_bound_witness_bars == 11L) ||
    !any(aroon_conf$stable_window_max_abs_delta > 0) ||
    !all(aroon_conf$plus_one_window_max_abs_delta == 0)) {
  fail("executed aroon stable-after/plus-one width witness is no longer exposed")
}
if (!all(conformance$prefix_all_identical)) {
  fail("full-series prefix causality changed")
}
dense <- plumbing[plumbing$execution_path == "dense", , drop = FALSE]
availability <- plumbing[
  plumbing$execution_path == "availability_full_membership",
  , drop = FALSE
]
if (nrow(dense) != 42L ||
    !all(dense$na_pattern_equal & dense$finite_values_identical)) {
  fail("dense public-path plumbing no longer reproduces the current engine")
}
if (!setequal(
  availability$indicator,
  c("builtin_sma", "builtin_returns", "ttr_sma_value")
) || !all(availability$na_pattern_equal)) {
  fail("full-membership availability plumbing evidence changed")
}

# The hostile fixture records floating drift; it is not a classifier or a
# product tolerance. The fixed CSV diff preserves the exact observed values.
hostile <- conformance[conformance$fixture == "level_shift", , drop = FALSE]
for (name in c("ttr_cci_value", "ttr_bbands_pctb", "builtin_sma")) {
  rows <- hostile[hostile$indicator == name, , drop = FALSE]
  if (!nrow(rows) || rows$stable_window_max_scaled_delta <= 0) {
    fail("hostile level-shift drift is no longer exposed for ", name)
  }
}

raw_rows <- stats::setNames(
  inventory$raw_ttr_first_finite,
  inventory$indicator
)
if (!identical(as.integer(raw_rows[c(
  "ttr_atr_tr", "ttr_atr_truehigh", "ttr_atr_truelow"
)]), c(2L, 2L, 2L)) ||
    raw_rows[["ttr_macd_macd"]] != 10L ||
    raw_rows[["ttr_macd_signal"]] != 13L ||
    !all(conformance$engine_first_finite == conformance$declared_stable_after)) {
  fail("raw TTR first-finite and ledgr-masked first-valid evidence changed")
}
if (!all(width_witness$probe_status == "simpleError")) {
  fail("two-row ATR wrapper witness no longer records its backend-wide warmup limit")
}

admitted <- unique(recovery$indicator[recovery$current_availability_status == "ok"])
expected_admitted <- c("builtin_sma", "builtin_returns", "ttr_sma_value")
if (!setequal(admitted, expected_admitted)) {
  fail("current availability admission set changed")
}
if (!identical(sort(unique(recovery$gap_start)), c(61L, 141L, 201L)) ||
    !all(recovery$counterfactual ==
      "segment restart omits gap; uninterrupted full series retains gap observations")) {
  fail("gap-position or counterfactual evidence changed")
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
  conformance$stable_window_max_scaled_delta[
    conformance$history_class == "history_dependent"
  ]
)
gut_recursive <- max(
  gut_conf$stable_window_max_scaled_delta[
    gut_conf$history_class == "history_dependent"
  ]
)
if (!(normal_recursive > 0 && gut_recursive == 0)) {
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
cat("H2_D_CHECK_PASS defaults=34 variants=8 prefix=causal paths=recorded gut=detected scope=clean\n")

args <- commandArgs(trailingOnly = TRUE)
repo <- if (length(args) > 0L) normalizePath(args[[1L]], winslash = "/") else normalizePath(".", winslash = "/")
selected_library <- Sys.getenv("LEDGR_COLLAPSE_LIBRARY", unset = "")
if (!nzchar(selected_library) || !dir.exists(selected_library)) {
  stop("LEDGR_COLLAPSE_LIBRARY must name a library containing collapse 2.1.8.")
}
.libPaths(c(normalizePath(selected_library, winslash = "/"), .libPaths()))
if (!identical(as.character(utils::packageVersion("collapse")), "2.1.8")) {
  stop("The probe requires exactly collapse 2.1.8.")
}
suppressPackageStartupMessages(library(collapse))
pkgload::load_all(repo, quiet = TRUE, export_all = TRUE)

cat("R_version=", as.character(getRversion()), "\n", sep = "")
cat("platform=", R.version$platform, "\n", sep = "")
cat("collapse_version=", as.character(utils::packageVersion("collapse")), "\n", sep = "")

# Recheck the collapse 2.1.7 write-barrier failure shape using dynamically
# allocated character and list values, forced garbage collections, and the
# same 70,000-row scale recorded in ledgr's v0.1.8.9 attribution.
setv_n <- 70000L
setv_character <- character(setv_n)
base_character <- character(setv_n)
setv_list <- vector("list", setv_n)
base_list <- vector("list", setv_n)
gc(full = TRUE)
gc(full = TRUE)
setv_elapsed <- system.time({
  for (i in seq_len(setv_n)) {
    value <- paste0("dynamic-value-", i, "-", strrep(letters[[i %% 26L + 1L]], i %% 31L + 1L))
    list_value <- list(label = value, index = i)
    collapse::setv(setv_character, i, value, vind1 = TRUE)
    collapse::setv(setv_list, i, list(list_value), vind1 = TRUE, xlist = TRUE)
    base_character[[i]] <- value
    base_list[[i]] <- list_value
    if (i %% 512L == 0L) {
      allocation_pressure <- lapply(seq_len(64L), function(j) paste0(value, "-", j))
      gc(full = FALSE)
    }
  }
})
cat("setv_character_parity=", identical(setv_character, base_character), "\n", sep = "")
cat("setv_list_parity=", identical(setv_list, base_list), "\n", sep = "")
cat("setv_70k_elapsed_seconds=", setv_elapsed[["elapsed"]], "\n", sep = "")

make_current_row <- function(i, ts) {
  ledgr:::ledgr_availability_diagnostic_row(
    run_id = "synthetic-run",
    diagnostic_seq = i,
    ts_utc = ts,
    instrument_id = paste0("I", sprintf("%04d", (i - 1L) %% 505L + 1L)),
    stage = "decision",
    outcome = "recorded",
    reason_code = "decision_recorded",
    reasons = "decision_recorded",
    target = 0,
    quantity = 0,
    price = 100,
    mark_source = "current_close",
    mark_age = 0L,
    target_before_risk = 0,
    target_after_risk = 0,
    position_before = 0,
    position_after = 0
  )
}

build_columns_once <- function(n, ts) {
  data.frame(
    run_id = rep("synthetic-run", n),
    diagnostic_seq = seq_len(n),
    ts_utc = rep(ts, n),
    instrument_id = paste0("I", sprintf("%04d", (seq_len(n) - 1L) %% 505L + 1L)),
    stage = rep("decision", n),
    outcome = rep("recorded", n),
    reason_code = rep("decision_recorded", n),
    reasons = rep("decision_recorded", n),
    target = numeric(n),
    quantity = numeric(n),
    price = rep(100, n),
    mark_source = rep("current_close", n),
    mark_age = integer(n),
    decision_ts_utc = rep(ts, n),
    execution_ts_utc = rep(as.POSIXct(NA, tz = "UTC"), n),
    event_seq = rep(NA_integer_, n),
    target_before_risk = numeric(n),
    target_after_risk = numeric(n),
    position_before = numeric(n),
    position_after = numeric(n),
    feature_identity_json = rep(NA_character_, n),
    detail_json = rep("{}", n),
    stringsAsFactors = FALSE
  )
}

ts <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC")
benchmarks <- vector("list", 3L)
for (k in seq_along(c(5000L, 10000L, 20000L))) {
  n <- c(5000L, 10000L, 20000L)[[k]]
  current_rows <- vector("list", n)
  construct <- system.time({
    for (i in seq_len(n)) current_rows[[i]] <- make_current_row(i, ts)
  })
  bind <- system.time({
    current <- do.call(rbind, current_rows)
  })
  rownames(current) <- NULL
  columns <- system.time({
    proposed <- build_columns_once(n, ts)
  })
  rownames(proposed) <- NULL
  parity <- identical(current, proposed)
  benchmarks[[k]] <- data.frame(
    rows = n,
    current_construct_seconds = construct[["elapsed"]],
    current_bind_seconds = bind[["elapsed"]],
    current_list_mib = as.numeric(object.size(current_rows)) / 1024^2,
    column_build_seconds = columns[["elapsed"]],
    column_frame_mib = as.numeric(object.size(proposed)) / 1024^2,
    exact_parity = parity,
    stringsAsFactors = FALSE
  )
  rm(current_rows, current, proposed)
  gc(full = TRUE)
}
results <- do.call(rbind, benchmarks)
print(results, row.names = FALSE)
if (!isTRUE(identical(setv_character, base_character)) ||
    !isTRUE(identical(setv_list, base_list)) ||
    !all(results$exact_parity)) {
  stop("Probe parity failed.")
}

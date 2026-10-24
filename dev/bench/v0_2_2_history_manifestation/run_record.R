# LDG-3105 ordinary causal-history manifestation record.

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[[1L]] else file.path(
  "dev", "bench", "v0_2_2_history_manifestation", "evidence", "run"
)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
bench_library <- Sys.getenv("LEDGR_BENCH_LIBRARY")
if (nzchar(bench_library)) {
  .libPaths(c(normalizePath(bench_library, winslash = "/"), .libPaths()))
  library(ledgr)
} else {
  pkgload::load_all(".", quiet = TRUE)
}

affinity <- system2(
  "powershell",
  c("-NoProfile", "-Command", shQuote(sprintf(
    "$p = Get-Process -Id %d; $p.ProcessorAffinity = 0xFFFF; [string]$p.ProcessorAffinity",
    Sys.getpid()
  ), type = "cmd")),
  stdout = TRUE,
  stderr = TRUE
)
power <- system2("powercfg", "/getactivescheme", stdout = TRUE, stderr = TRUE)
if (!identical(trimws(tail(affinity, 1L)), "65535") ||
    !any(grepl("High performance", power, fixed = TRUE))) {
  stop("The record requires the registered High-performance/0xFFFF host setup.")
}

n_instrument_max <- 2332L
n_session <- 1260L
calendar <- seq(as.Date("2018-01-01"), by = "day", length.out = 1800L)
days <- calendar[as.integer(format(calendar, "%u")) <= 5L][seq_len(n_session)]
pulses <- as.POSIXct(paste(days, "21:00:00"), tz = "UTC")
ids <- sprintf("I%04d", seq_len(n_instrument_max))

make_fixture <- function(source_columns, label, instrument_ids) {
  n_time <- length(source_columns)
  n_instrument <- length(instrument_ids)
  instrument <- rep(seq_len(n_instrument), each = n_time)
  local_session <- rep(seq_len(n_time), times = n_instrument)
  global_session <- source_columns[local_session]
  close_value <- 50 + instrument / 100 + global_session / 1000
  keep <- global_session <= 5L |
    ((instrument * 131L + global_session * 17L) %% 997L != 0L)
  bars <- data.frame(
    instrument_id = instrument_ids[instrument[keep]],
    ts_utc = pulses[global_session[keep]],
    open = close_value[keep], high = close_value[keep],
    low = close_value[keep], close = close_value[keep],
    volume = 1000,
    stringsAsFactors = FALSE
  )
  source_days <- days[source_columns]
  all_days <- seq(min(source_days), max(source_days), by = "day")
  is_open <- all_days %in% source_days
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = all_days,
      status = ifelse(is_open, "open", "closed"),
      session_open = ifelse(is_open, "14:30:00", NA),
      session_close = ifelse(is_open, "21:00:00", NA),
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS", knowledge = "assume_effective"
  )
  members <- data.frame(
    effective_from = pulses[source_columns[[1L]]] - 3600,
    knowledge_time = pulses[source_columns[[1L]]] - 3600,
    source = "history_manifestation_record",
    stringsAsFactors = FALSE
  )
  members$members <- I(list(instrument_ids))
  membership <- ledgr_facts_membership_snapshots(
    members, universe_id = "U", complete = TRUE
  )
  db_path <- tempfile(pattern = paste0("ledgr-history-", label, "-"),
                      fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(
    bars, data.frame(instrument_id = instrument_ids), db_path = db_path,
    snapshot_id = paste0("history-manifestation-", label),
    facts = ledgr_facts(sessions, membership),
    price_basis = "split_adjusted"
  )
  experiment <- ledgr_experiment(
    snapshot, function(ctx, params) ctx$hold(),
    universe = ledgr_universe_members("U"), cost_model = ledgr_cost_zero()
  )
  ctx <- ledgr_pulse_snapshot(
    experiment, ts_utc = days[[source_columns[[length(source_columns)]]]]
  )
  list(ctx = ctx, snapshot = snapshot, db_path = db_path)
}

close_fixture <- function(x) {
  close(x$ctx)
  ledgr_snapshot_close(x$snapshot)
  unlink(x$db_path)
}

clock_us <- function(fn, times = 40L) {
  timing <- microbenchmark::microbenchmark(fn(), times = times, unit = "us")
  c(
    median_us = stats::median(timing$time) / 1000,
    p95_us = unname(stats::quantile(timing$time, 0.95)) / 1000
  )
}

history_memo_names <- function(ctx) {
  sort(ls(
    ledgr:::ledgr_history_memo(
      ledgr:::ledgr_history_context_view(ctx)$service$substrate
    ),
    all.names = TRUE
  ), method = "radix")
}

allocated_bytes <- function(fn) {
  path <- tempfile(fileext = ".mem")
  on.exit(unlink(path), add = TRUE)
  utils::Rprofmem(path)
  value <- fn()
  utils::Rprofmem(NULL)
  lines <- readLines(path, warn = FALSE)
  bytes <- suppressWarnings(as.numeric(sub(" .*", "", lines)))
  list(
    value = value,
    bytes = sum(bytes, na.rm = TRUE),
    allocations = bytes[is.finite(bytes)]
  )
}

read_path <- function(ctx, path, instruments, lookback) {
  if (identical(path, "matrix")) {
    ledgr_history_matrix(
      ctx, bar = "close", lookback = lookback, instruments = instruments
    )
  } else {
    ledgr_history_frame(
      ctx, bar = "close", lookback = lookback, instruments = instruments
    )
  }
}

measure <- function(ctx, path, instruments, lookback, axis, size, replicate,
                    times = 40L) {
  fn <- function() read_path(ctx, path, instruments, lookback)
  # The context owner has completed immutable preparation before this public
  # boundary. The allocation call below is therefore a genuine first read,
  # not a hidden memo warm-up; no ordinary call may change the owner memo.
  memo_before <- history_memo_names(ctx)
  if (!"base_masks" %in% memo_before) {
    stop("History owner summaries were not prepared before the public read.")
  }
  allocation <- allocated_bytes(fn)
  value <- allocation$value
  timing <- clock_us(fn, times = times)
  memo_after <- history_memo_names(ctx)
  if (!identical(memo_after, memo_before)) {
    stop("An ordinary public history read performed hidden owner preparation.")
  }
  cells <- if (identical(path, "matrix")) length(value) else
    nrow(value) * (ncol(value) - 1L)
  payload_bytes <- cells * 8
  full_temporaries <- if (payload_bytes > 0L) {
    sum(allocation$allocations >= 0.9 * payload_bytes)
  } else {
    0L
  }
  payload_copies <- if (identical(path, "matrix")) {
    max(1L, full_temporaries)
  } else {
    # Wide's returned payload is split over its numeric columns. Count it once
    # plus any additional full-payload temporary.
    1L + full_temporaries
  }
  data.frame(
    path = path, axis = axis, size = size, replicate = replicate,
    rows = as.integer(lookback), columns = length(instruments),
    returned_cells = cells,
    median_us = timing[["median_us"]], p95_us = timing[["p95_us"]],
    allocated_bytes = allocation$bytes,
    allocated_ratio = if (payload_bytes > 0L) allocation$bytes / payload_bytes else 0,
    payload_copies = payload_copies,
    owner_prepared = TRUE, memo_stable = TRUE,
    stringsAsFactors = FALSE
  )
}

focal_ids <- ids[seq_len(500L)]
full <- make_fixture(seq_len(n_session), "full", focal_ids)
on.exit(close_fixture(full), add = TRUE)
ctx <- full$ctx

records <- list()
for (path in c("matrix", "wide")) {
  for (replicate in 1:3) {
    records[[length(records) + 1L]] <- measure(
      ctx, path, focal_ids, 252L, "instrument", 500L, replicate
    )
  }
}
measure_instrument_growth <- function(n) {
  fixture <- make_fixture(seq_len(n_session), paste0("instrument-", n), ids[seq_len(n)])
  on.exit(close_fixture(fixture), add = TRUE)
  out <- list()
  for (path in c("matrix", "wide")) {
    for (replicate in 1:3) {
      out[[length(out) + 1L]] <- measure(
        fixture$ctx, path, ids[seq_len(n)], 252L,
        "instrument", n, replicate
      )
    }
  }
  out
}
for (n in c(1166L, 2332L)) {
  records <- c(records, measure_instrument_growth(n))
}
for (path in c("matrix", "wide")) {
  for (n in c(252L, 504L, 1260L)) {
    for (replicate in 1:3) {
      records[[length(records) + 1L]] <- measure(
        ctx, path, focal_ids, n, "session", n, replicate
      )
    }
  }
}
measurements <- do.call(rbind, records)

direct <- ledgr_history_matrix(
  ctx, bar = "close", lookback = 252L, instruments = focal_ids
)
wide <- ledgr_history_frame(
  ctx, bar = "close", lookback = 252L, instruments = focal_ids
)
long <- ledgr_history_frame(
  ctx, bar = "close", lookback = 252L, instruments = focal_ids,
  layout = "long"
)
wide_matrix <- ledgr_history_matrix(wide)
long_matrix <- ledgr_history_matrix(long)
direct_info <- ledgr_history_info(direct)
wide_info <- ledgr_history_info(wide)
long_info <- ledgr_history_info(long)
parity <- data.frame(
  matrix_wide_identical = identical(direct, wide_matrix),
  matrix_long_identical = identical(direct, long_matrix),
  selection_wide_identical = identical(direct_info$selection, wide_info$selection),
  selection_long_identical = identical(direct_info$selection, long_info$selection),
  used_before_wide_identical = identical(
    direct_info$used_before_window, wide_info$used_before_window
  ),
  used_before_long_identical = identical(
    direct_info$used_before_window, long_info$used_before_window
  ),
  wide_evidence_absent = is.null(attr(wide, "ledgr_history")$evidence),
  matrix_evidence_absent = is.null(attr(direct, "ledgr_history")$evidence),
  long_evidence_present = all(
    ledgr:::ledgr_history_cell_fields() %in% names(long)
  ),
  stringsAsFactors = FALSE
)

digest_calls <- 0L
trace(
  "digest", where = asNamespace("digest"), print = FALSE,
  tracer = quote(.GlobalEnv$digest_calls <- .GlobalEnv$digest_calls + 1L)
)
invisible(read_path(ctx, "matrix", ids[seq_len(500L)], 252L))
invisible(read_path(ctx, "wide", ids[seq_len(500L)], 252L))
untrace("digest", where = asNamespace("digest"))

shape_medians <- stats::aggregate(
  median_us ~ path + axis + size, data = measurements, FUN = stats::median
)
slopes <- do.call(rbind, lapply(split(shape_medians, list(
  shape_medians$path, shape_medians$axis
)), function(x) {
  data.frame(
    path = x$path[[1L]], axis = x$axis[[1L]],
    exponent = unname(stats::coef(stats::lm(
      log(median_us) ~ log(size), data = x
    ))[[2L]]),
    stringsAsFactors = FALSE
  )
}))
rownames(slopes) <- NULL

# Select the instrument-axis 500 x 252 observations, which are unambiguous.
short <- make_fixture((n_session - 251L):n_session, "short", focal_ids)
on.exit(close_fixture(short), add = TRUE)
source_scale <- do.call(rbind, lapply(c("matrix", "wide"), function(path) {
  full_fn <- function() read_path(
    full$ctx, path, focal_ids, 252L
  )
  short_fn <- function() read_path(
    short$ctx, path, focal_ids, 252L
  )
  timing <- microbenchmark::microbenchmark(
    source_1260 = full_fn(), source_252 = short_fn(),
    times = 100L, unit = "us"
  )
  medians <- stats::aggregate(time ~ expr, data = timing, FUN = stats::median)
  full_us <- medians$time[medians$expr == "source_1260"] / 1000
  short_us <- medians$time[medians$expr == "source_252"] / 1000
  data.frame(
    path = path,
    median_us_source_1260 = full_us,
    median_us_source_252 = short_us,
    absolute_delta_us = abs(full_us - short_us),
    stringsAsFactors = FALSE
  )
}))

environment <- data.frame(
  product_commit = Sys.getenv("LEDGR_PRODUCT_COMMIT"),
  r_version = R.version.string,
  platform = R.version$platform,
  collapse_version = as.character(utils::packageVersion("collapse")),
  microbenchmark_version = as.character(utils::packageVersion("microbenchmark")),
  load_mode = if (nzchar(bench_library)) "installed" else "pkgload",
  power_plan = "High performance", process_affinity = "0xFFFF",
  digest_calls = digest_calls,
  stringsAsFactors = FALSE
)
if (!nzchar(environment$product_commit)) {
  stop("Set LEDGR_PRODUCT_COMMIT before recording.")
}

utils::write.csv(measurements, file.path(out_dir, "measurements.csv"), row.names = FALSE)
utils::write.csv(slopes, file.path(out_dir, "slopes.csv"), row.names = FALSE)
utils::write.csv(parity, file.path(out_dir, "parity.csv"), row.names = FALSE)
utils::write.csv(source_scale, file.path(out_dir, "source_scale.csv"), row.names = FALSE)
utils::write.csv(environment, file.path(out_dir, "environment.csv"), row.names = FALSE)

print(measurements)
print(slopes)
print(parity)
print(source_scale)
print(environment)

# Workstream 55 direct-history matrix record (Cut 19, LDG-3099).
#
# Builds one vendor-neutral 500-instrument by 252-session availability fixture,
# prepares one real pulse context, and alternates the direct matrix reader with
# the frame-plus-adapter path. Memory is the incremental R heap peak after
# resetting gc's peak counter immediately before each arm. The adapter keeps
# both its frame and matrix alive through the measurement.

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[[1L]] else file.path(
  "dev", "bench", "v0_2_2_history_api_cleanup", "evidence"
)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(".", quiet = TRUE)

n_inst <- 500L
n_days <- 252L
calendar <- seq(as.Date("2020-01-01"), by = "day", length.out = 370L)
days <- calendar[as.integer(format(calendar, "%u")) <= 5L][seq_len(n_days)]
pulses <- as.POSIXct(paste(days, "21:00:00"), tz = "UTC")
ids <- sprintf("I%03d", seq_len(n_inst))
k <- rep(seq_len(n_days), times = n_inst)
j <- rep(seq_len(n_inst), each = n_days)
close <- 50 + j / 100 + k / 50
bars <- data.frame(
  instrument_id = rep(ids, each = n_days),
  ts_utc = rep(pulses, times = n_inst),
  open = close,
  high = close,
  low = close,
  close = close,
  volume = 1000,
  stringsAsFactors = FALSE
)

all_days <- seq(min(days), max(days), by = "day")
is_open <- all_days %in% days
sessions <- ledgr_facts_sessions(
  data.frame(
    session_date = all_days,
    status = ifelse(is_open, "open", "closed"),
    session_open = ifelse(is_open, "14:30:00", NA),
    session_close = ifelse(is_open, "21:00:00", NA),
    stringsAsFactors = FALSE
  ),
  venue_id = "XNYS",
  knowledge = "assume_effective"
)
membership_rows <- data.frame(
  effective_from = pulses[[1L]] - 3600,
  knowledge_time = pulses[[1L]] - 3600,
  source = "ws55",
  stringsAsFactors = FALSE
)
membership_rows$members <- I(list(ids))
membership <- ledgr_facts_membership_snapshots(
  membership_rows,
  universe_id = "U",
  complete = TRUE
)

db_path <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(
  bars,
  data.frame(instrument_id = ids),
  db_path = db_path,
  snapshot_id = "ws55-history-matrix",
  facts = ledgr_facts(sessions, membership),
  price_basis = "split_adjusted"
)
experiment <- ledgr_experiment(
  snapshot,
  function(ctx, params) ctx$hold(),
  universe = ledgr_universe_members("U"),
  cost_model = ledgr_cost_zero()
)
ctx <- ledgr_pulse_snapshot(experiment, ts_utc = days[[n_days]])
on.exit(close(ctx), add = TRUE)

read_direct <- function() {
  matrix <- ledgr_history_matrix(ctx, bar = "close", lookback = n_days)
  list(matrix = matrix, frame = NULL)
}
read_adapter <- function() {
  frame <- ledgr_history_frame(ctx, bar = "close", lookback = n_days)
  matrix <- ledgr_history_matrix(frame)
  list(matrix = matrix, frame = frame)
}

# Warm code and the read service before clocks begin.
invisible(read_direct())
invisible(read_adapter())

iterations <- 20L

measure <- function(pair, order, arm) {
  invisible(gc())
  base <- gc(reset = TRUE)
  elapsed <- system.time({
    for (iteration in seq_len(iterations)) {
      result <- if (identical(arm, "direct")) read_direct() else read_adapter()
    }
  })[["elapsed"]]
  peak <- gc()
  info <- ledgr_history_info(result$matrix)
  data.frame(
    pair = pair,
    order = order,
    arm = arm,
    iterations = iterations,
    elapsed_seconds_per_read = unname(elapsed) / iterations,
    peak_increment_mb = sum(peak[, 6L]) - sum(base[, 2L]),
    matrix_bytes = as.numeric(object.size(result$matrix)),
    retained_bytes = as.numeric(object.size(result)),
    rows = nrow(result$matrix),
    columns = ncol(result$matrix),
    included = length(info$included_ids),
    passed_warmup = info$passed_warmup,
    stringsAsFactors = FALSE
  )
}

orders <- list(c("direct", "adapter"), c("adapter", "direct"),
               c("direct", "adapter"))
record <- do.call(rbind, lapply(seq_along(orders), function(pair) {
  do.call(rbind, lapply(seq_along(orders[[pair]]), function(order) {
    measure(pair, order, orders[[pair]][[order]])
  }))
}))

direct <- read_direct()$matrix
adapter <- read_adapter()$matrix
stopifnot(
  identical(as.matrix(direct), as.matrix(adapter)),
  identical(ledgr_history_info(direct), ledgr_history_info(adapter)),
  is.null(ledgr_history_info(direct)$evidence),
  nrow(direct) == n_days,
  ncol(direct) == n_inst
)

utils::write.csv(record, file.path(out_dir, "history_matrix.csv"), row.names = FALSE)
summary <- aggregate(
  cbind(elapsed_seconds_per_read, peak_increment_mb, retained_bytes) ~ arm,
  record,
  stats::median
)
utils::write.csv(summary, file.path(out_dir, "summary.csv"), row.names = FALSE)
print(record)
print(summary)

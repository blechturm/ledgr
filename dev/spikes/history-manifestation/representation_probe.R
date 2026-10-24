# Follow-up probe after the v1 charter's raw-copy stop fired. This isolates the
# one representation primitive absent from that candidate: prepared finite
# observation prefix counts. It changes no package code and proves no product
# semantics.

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))

n_inst <- 1166L
n_time <- 1260L
stored <- matrix(
  50 + rep(seq_len(n_inst), n_time) / 100 +
    rep(seq_len(n_time), each = n_inst) / 1000,
  nrow = n_inst,
  ncol = n_time
)
missing <- ((row(stored) * 131L + col(stored) * 17L) %% 997L) == 0L
stored[missing] <- NA_real_

# Prepared once, outside the pulse. A production design could use a sparse
# equivalent; this dense prefix is only a cost probe for the read primitive.
finite_prefix <- t(collapse::fcumsum(t(is.finite(stored))))
storage.mode(finite_prefix) <- "integer"

rows <- seq_len(500L)
columns <- seq.int(n_time - 251L, n_time)
axis <- as.POSIXct(seq_len(n_time), origin = "2020-01-01", tz = "UTC")
ids <- sprintf("I%04d", seq_len(n_inst))
patch_index <- which(is.na(stored[rows, columns, drop = FALSE]))
patch_value <- rep(1, length(patch_index))

counts <- function() {
  right <- finite_prefix[rows, columns[[length(columns)]]]
  left <- if (columns[[1L]] > 1L) finite_prefix[rows, columns[[1L]] - 1L] else 0L
  as.integer(right - left + tabulate(
    ((patch_index - 1L) %% length(rows)) + 1L,
    nbins = length(rows)
  ))
}

values <- function() {
  out <- stored[rows, columns, drop = FALSE]
  if (length(patch_index)) out[patch_index] <- patch_value
  out
}

matrix_candidate <- function() {
  finite <- counts()
  keep <- finite >= length(columns)
  out <- t(values())
  if (!all(keep)) out <- out[, keep, drop = FALSE]
  dimnames(out) <- list(NULL, ids[rows][keep])
  structure(
    out,
    class = c("ledgr_history_matrix_candidate", "matrix", "array"),
    ledgr_history = list(
      axis = axis[columns],
      instrument_ids = ids[rows][keep],
      finite_observation_count = finite[keep],
      excluded_ids = ids[rows][!keep]
    )
  )
}

frame_candidate <- function() {
  finite <- counts()
  keep <- finite >= length(columns)
  out <- t(values())
  if (!all(keep)) out <- out[, keep, drop = FALSE]
  columns_out <- if (any(keep)) collapse::mctl(out) else list()
  names(columns_out) <- ids[rows][keep]
  structure(
    c(list(ts_utc = axis[columns]), columns_out),
    row.names = .set_row_names(length(columns)),
    class = c("ledgr_history_candidate", "data.frame"),
    ledgr_history = list(
      axis = axis[columns],
      instrument_ids = ids[rows][keep],
      finite_observation_count = finite[keep],
      excluded_ids = ids[rows][!keep]
    )
  )
}

clock <- function(fn) {
  x <- microbenchmark::microbenchmark(fn(), times = 500L, unit = "us")$time / 1000
  c(median_us = unname(stats::median(x)), p95_us = unname(stats::quantile(x, 0.95)))
}

result <- rbind(
  data.frame(path = "prepared_count", t(clock(counts))),
  data.frame(path = "matrix", t(clock(matrix_candidate))),
  data.frame(path = "frame", t(clock(frame_candidate)))
)
result$rows <- length(columns)
result$columns <- length(rows)
print(result)

out <- file.path("dev", "spikes", "history-manifestation", "evidence",
                 "representation_probe.csv")
utils::write.csv(result, out, row.names = FALSE)

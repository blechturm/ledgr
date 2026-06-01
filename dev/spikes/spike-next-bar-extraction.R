# Spike: per-fill next-bar row subset vs matrix scalar lookup
#
# Context: R/fold-engine.R:290 does `b[i + 1L, , drop = FALSE]` per fill
# where `b` is `bars_by_id[[instrument_id]]` (a data.frame or tibble).
# The row subset allocates a new sub-frame per fill with class-dispatch
# overhead. Hypothesis: at 133k fills the cumulative cost is meaningful;
# replacing with a matrix scalar lookup (bars_mat$open[inst_idx, i+1L])
# is O(1) with no allocation and may be 10x-100x faster.
#
# FAITHFULNESS: replicates bars_by_id as a named list of data.frames
# matching the production shape (ts_utc, open, high, low, close, volume,
# instrument_id columns; 1260 rows per instrument). The matrix lookup
# variant uses a pre-extracted open-price matrix [n_inst, n_pulses].
#
# Variants:
#   df_row_subset   : current pattern b[i + 1L, , drop = FALSE]
#   tibble_subset   : same but b is a tibble (tibble's [.tbl_df dispatch)
#   matrix_scalar   : bars_mat$open[inst_idx, i + 1L]
#
# CAVEAT: the spike measures just the next-bar extraction, not the
# downstream proposal logic which reads from next_bar. Production may
# benefit additionally if the proposal can be vectorized over the
# extracted scalar.

`%||%` <- function(x, y) if (is.null(x)) y else x

n_inst <- 1000L
n_pulses <- 1260L
n_fills <- 133000L  # match xlarge production fill count

set.seed(42L)

# Build bars_by_id as named list of data.frames
mk_bars_df <- function(n_pulses, inst_id) {
  ts <- as.POSIXct("2026-01-01", tz = "UTC") + (seq_len(n_pulses) - 1L) * 86400L
  data.frame(
    ts_utc = ts,
    open = runif(n_pulses, 95, 105),
    high = runif(n_pulses, 100, 110),
    low = runif(n_pulses, 90, 100),
    close = runif(n_pulses, 95, 105),
    volume = runif(n_pulses, 1e5, 1e7),
    instrument_id = rep(inst_id, n_pulses),
    stringsAsFactors = FALSE
  )
}

mk_bars_tbl <- function(n_pulses, inst_id) {
  if (!requireNamespace("tibble", quietly = TRUE)) return(NULL)
  tibble::as_tibble(mk_bars_df(n_pulses, inst_id))
}

cat(sprintf("Building bars_by_id for %d instruments x %d pulses...\n", n_inst, n_pulses))
ids <- sprintf("INST_%05d", seq_len(n_inst))
bars_by_id_df <- stats::setNames(
  lapply(ids, function(id) mk_bars_df(n_pulses, id)),
  ids
)
# Build tibble variant from the SAME df to keep parity
bars_by_id_tbl <- stats::setNames(
  lapply(bars_by_id_df, function(df) {
    if (!requireNamespace("tibble", quietly = TRUE)) return(NULL)
    tibble::as_tibble(df)
  }),
  ids
)
# Build matrix variant: bars_mat$open is [n_inst, n_pulses]
bars_mat_open <- matrix(0, nrow = n_inst, ncol = n_pulses)
for (j in seq_along(ids)) {
  bars_mat_open[j, ] <- bars_by_id_df[[ids[[j]]]]$open
}
# id -> idx map
id_to_idx <- stats::setNames(seq_along(ids), ids)

# Synthetic fill events: random (instrument, pulse) tuples
fill_inst_idx <- sample.int(n_inst, n_fills, replace = TRUE)
fill_pulse_idx <- sample.int(n_pulses - 1L, n_fills, replace = TRUE)
fill_inst_ids <- ids[fill_inst_idx]

# Variant 1: df row subset
v1_df_subset <- function() {
  acc <- 0
  for (k in seq_len(n_fills)) {
    inst_id <- fill_inst_ids[[k]]
    i <- fill_pulse_idx[[k]]
    b <- bars_by_id_df[[inst_id]]
    next_bar <- if (!is.null(b) && i < nrow(b)) b[i + 1L, , drop = FALSE] else NULL
    if (!is.null(next_bar)) acc <- acc + next_bar$open
  }
  acc
}

# Variant 2: tibble subset (tbl_df has slower [ dispatch than data.frame)
v2_tibble_subset <- function() {
  acc <- 0
  for (k in seq_len(n_fills)) {
    inst_id <- fill_inst_ids[[k]]
    i <- fill_pulse_idx[[k]]
    b <- bars_by_id_tbl[[inst_id]]
    next_bar <- if (!is.null(b) && i < nrow(b)) b[i + 1L, , drop = FALSE] else NULL
    if (!is.null(next_bar)) acc <- acc + next_bar$open
  }
  acc
}

# Variant 3: matrix scalar lookup
v3_matrix_scalar <- function() {
  acc <- 0
  for (k in seq_len(n_fills)) {
    inst_idx <- fill_inst_idx[[k]]
    i <- fill_pulse_idx[[k]]
    acc <- acc + bars_mat_open[inst_idx, i + 1L]
  }
  acc
}

cat("\n=== parity check ===\n")
acc_df <- v1_df_subset()
acc_tbl <- v2_tibble_subset()
acc_mat <- v3_matrix_scalar()
parity_ok <- isTRUE(all.equal(acc_df, acc_tbl)) && isTRUE(all.equal(acc_df, acc_mat))
cat(sprintf("df=%.6f  tibble=%.6f  matrix=%.6f  [%s]\n\n",
            acc_df, acc_tbl, acc_mat, if (parity_ok) "OK" else "FAIL"))
if (!parity_ok) stop("Parity failed.")

cat("=== timing (133k fills) ===\n")
t_df <- system.time(v1_df_subset())[["elapsed"]]
t_tbl <- system.time(v2_tibble_subset())[["elapsed"]]
t_mat <- system.time(v3_matrix_scalar())[["elapsed"]]
cat(sprintf("%-15s %10s %12s\n", "variant", "wall_s", "us_per_fill"))
cat(sprintf("%-15s %9.3fs %12.2f\n", "df_row_subset", t_df, t_df / n_fills * 1e6))
cat(sprintf("%-15s %9.3fs %12.2f\n", "tibble_subset", t_tbl, t_tbl / n_fills * 1e6))
cat(sprintf("%-15s %9.3fs %12.2f\n", "matrix_scalar", t_mat, t_mat / n_fills * 1e6))
cat(sprintf("\nSpeedup df_row_subset -> matrix_scalar: %.1fx\n", t_df / pmax(t_mat, 0.001)))
cat(sprintf("Speedup tibble_subset -> matrix_scalar: %.1fx\n", t_tbl / pmax(t_mat, 0.001)))

res <- data.frame(
  variant = c("df_row_subset", "tibble_subset", "matrix_scalar"),
  wall_s = c(t_df, t_tbl, t_mat),
  us_per_fill = c(t_df, t_tbl, t_mat) / n_fills * 1e6
)
out <- "dev/bench/results/spike_next_bar_extraction.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(res, out, row.names = FALSE)
cat(sprintf("\nWROTE %s\n", out))

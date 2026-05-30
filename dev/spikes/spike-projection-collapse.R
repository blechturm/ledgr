# Spike: projection / features_wide surface -- base-R df round-trip vs collapse
# (mctl/qM) vs a matrix-canonical surface. Tier 1 of the collapse map.
#
# The strategy reads ctx$features_wide (a data.frame) and typically converts it
# back to a matrix (`as.matrix(fw[FEATURE_COLS])`, as the bench strategy does).
# So per pulse we pay: build the wide df, then convert df->matrix. This spike
# measures, over all pulses at the real shape:
#   1. df surface, as.matrix : build df + as.matrix(df[cols])   (current)
#   2. df surface, qM        : build df + collapse::qM(...)      (faster convert)
#   3. matrix-canonical      : slice the projection matrices straight to a matrix
#                              (the RFC contract change -- no df at all)
# plus a build-method check (base-R stamp vs collapse::mctl). Parity: the matrix
# the strategy sees must be byte-identical across paths.
#
# Relates to: inst/design/collapse_optimization_map.md (Tier 1, projection),
# LDG-2453/2455 (features_wide already cheap to build). Usage:
#   Rscript dev/spikes/spike-projection-collapse.R

suppressWarnings(suppressMessages(library(collapse)))

N_INST <- 500L; N_PULSES <- 1260L; N_FEAT <- 50L
insts <- sprintf("DEMO_%04d", seq_len(N_INST))
pulses_iso <- format(as.POSIXct("2018-01-01", tz="UTC") + 86400 * (seq_len(N_PULSES) - 1L), "%Y-%m-%dT%H:%M:%SZ")
feat_ids <- sprintf("f_%03d", seq_len(N_FEAT))
set.seed(20260529L)
feat_mats <- lapply(seq_len(N_FEAT), function(f) matrix(rnorm(N_INST * N_PULSES), N_INST, N_PULSES))
names(feat_mats) <- feat_ids

fast_df <- function(cols, n) { attr(cols, "row.names") <- .set_row_names(n); class(cols) <- "data.frame"; cols }
build_df <- function(i) {
  cols <- c(list(instrument_id = insts, ts_utc = rep(pulses_iso[[i]], N_INST)),
            lapply(feat_mats, function(M) M[, i]))
  names(cols) <- c("instrument_id", "ts_utc", feat_ids)
  fast_df(cols, N_INST)
}
slice_matrix <- function(i) { m <- matrix(0, N_INST, N_FEAT, dimnames = list(NULL, feat_ids)); for (f in seq_len(N_FEAT)) m[, f] <- feat_mats[[f]][, i]; m }

cat(sprintf("shape: %d inst x %d pulses x %d feat\n\n", N_INST, N_PULSES, N_FEAT))

t1 <- system.time(for (i in seq_len(N_PULSES)) { fw <- build_df(i); m1 <- as.matrix(fw[feat_ids]) })[["elapsed"]]
t2 <- system.time(for (i in seq_len(N_PULSES)) { fw <- build_df(i); m2 <- collapse::qM(collapse::get_vars(fw, feat_ids)) })[["elapsed"]]
t3 <- system.time(for (i in seq_len(N_PULSES)) { m3 <- slice_matrix(i) })[["elapsed"]]

cat("strategy-facing matrix per pulse, over all pulses:\n")
cat(sprintf("  1. df + as.matrix   (current df round-trip) : %.3fs\n", t1))
cat(sprintf("  2. df + collapse::qM (faster convert)       : %.3fs  (%.1fx vs #1)\n", t2, t1/t2))
cat(sprintf("  3. matrix-canonical  (no df; RFC change)    : %.3fs  (%.1fx vs #1)\n", t3, t1/t3))

# parity: the strategy matrix is identical across paths (ignore dimnames)
fw <- build_df(1L); pa <- as.matrix(fw[feat_ids]); pb <- collapse::qM(collapse::get_vars(fw, feat_ids)); pc <- slice_matrix(1L)
dimnames(pa) <- dimnames(pb) <- dimnames(pc) <- NULL
cat(sprintf("\nparity (matrix values identical across paths): %s\n",
            isTRUE(all.equal(pa, pb)) && isTRUE(all.equal(pa, pc))))

# build-method: base-R stamp vs collapse::mctl for the df build
tb <- system.time(for (i in seq_len(N_PULSES)) fw <- build_df(i))[["elapsed"]]
tm <- system.time(for (i in seq_len(N_PULSES)) {
  m <- slice_matrix(i)
  cols <- c(list(instrument_id = insts, ts_utc = rep(pulses_iso[[i]], N_INST)), collapse::mctl(m))
  names(cols) <- c("instrument_id", "ts_utc", feat_ids); fw <- fast_df(cols, N_INST)
})[["elapsed"]]
cat(sprintf("\ndf build: base-R stamp %.3fs  vs  mctl-based %.3fs  (%.1fx)\n", tb, tm, tb/tm))

out <- "dev/bench/results/spike_projection_collapse.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(data.frame(path=c("df_as_matrix","df_qM","matrix_canonical","build_baseR","build_mctl"),
                            seconds=c(t1,t2,t3,tb,tm)), out, row.names = FALSE)
cat("\nWROTE", out, "\n")

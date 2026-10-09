# Paired public-path clocks and peak memory (Cut 11 LDG-2982).
#
#   Rscript run_pair.R <accepted_repo> <candidate_repo> <out_dir> <pairs> [run_record options]
#
# Runs run_record.R on the two trees in fresh R processes, interleaved and
# alternating which arm goes first in each pair, one process at a time. The
# parent samples each child's resident memory every 0.25 s and attributes
# elapsed time and peak memory to the phases the child logs. Writes
# <out_dir>/phases.csv (pair, arm, phase, elapsed_s, peak_rss_mib),
# <out_dir>/summary.csv (median per arm and phase, candidate/accepted ratio)
# and, per arm and pair, the full record directory for check_record.R.
#
# Declared before any measurement: a pair is retried once, and only once, if
# either child fails; the noise rule is a candidate/accepted median ratio above
# 1.05 for a registered phase counting as a regression.

args <- commandArgs(trailingOnly = TRUE)
accepted <- normalizePath(args[[1L]], winslash = "/")
candidate <- normalizePath(args[[2L]], winslash = "/")
out_dir <- args[[3L]]
pairs <- as.integer(args[[4L]])
pass <- if (length(args) > 4L) args[-(1:4)] else character()
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home("bin"), "Rscript")

run_child <- function(repo, record_dir) {
  p <- processx::process$new(rscript, c(file.path(here, "run_record.R"), repo, record_dir, pass),
                             stdout = file.path(record_dir, "..", paste0(basename(record_dir), ".log")),
                             stderr = "2>&1")
  samples <- list()
  while (p$is_alive()) {
    rss <- tryCatch(ps::ps_memory_info(ps::ps_handle(p$get_pid()))[["rss"]], error = function(e) NA_real_)
    samples[[length(samples) + 1L]] <- c(as.numeric(Sys.time()), rss)
    Sys.sleep(0.25)
  }
  list(status = p$get_exit_status(), samples = do.call(rbind, samples))
}
attribute <- function(record_dir, samples) {
  ph <- utils::read.csv(file.path(record_dir, "phases.csv"))
  peak <- vapply(seq_len(nrow(ph)), function(i) {
    inside <- samples[, 1L] >= ph$start[[i]] & samples[, 1L] <= ph$end[[i]]
    if (any(inside, na.rm = TRUE)) max(samples[inside, 2L], na.rm = TRUE) / 2^20 else NA_real_
  }, numeric(1))
  # A phase may appear more than once (readers): sum time, keep the max peak.
  elapsed <- tapply(ph$end - ph$start, ph$phase, sum)
  peaks <- tapply(peak, ph$phase, max)
  data.frame(phase = names(elapsed), elapsed_s = round(as.numeric(elapsed), 3),
             peak_rss_mib = round(as.numeric(peaks[names(elapsed)])), stringsAsFactors = FALSE)
}

rows <- list()
for (i in seq_len(pairs)) {
  order <- if (i %% 2L == 1L) c("accepted", "candidate") else c("candidate", "accepted")
  for (arm in order) {
    repo <- if (identical(arm, "accepted")) accepted else candidate
    record_dir <- file.path(out_dir, sprintf("%s-%d", arm, i))
    unlink(record_dir, recursive = TRUE)
    dir.create(record_dir, recursive = TRUE)
    res <- run_child(repo, record_dir)
    if (res$status != 0L) {
      cat(sprintf("pair %d %s failed (status %d); retrying once\n", i, arm, res$status))
      unlink(record_dir, recursive = TRUE)
      dir.create(record_dir, recursive = TRUE)
      res <- run_child(repo, record_dir)
      if (res$status != 0L) stop(sprintf("pair %d %s failed twice; see %s.log", i, arm, record_dir), call. = FALSE)
    }
    r <- attribute(record_dir, res$samples)
    r$pair <- i
    r$arm <- arm
    rows[[length(rows) + 1L]] <- r
    cat(sprintf("pair %d %-9s total %.1f s\n", i, arm, sum(r$elapsed_s)))
  }
}
all <- do.call(rbind, rows)
utils::write.csv(all[, c("pair", "arm", "phase", "elapsed_s", "peak_rss_mib")], file.path(out_dir, "phases.csv"), row.names = FALSE)
med <- stats::aggregate(cbind(elapsed_s, peak_rss_mib) ~ phase + arm, data = all, FUN = stats::median)
wide <- merge(med[med$arm == "accepted", -2L], med[med$arm == "candidate", -2L], by = "phase",
              suffixes = c("_accepted", "_candidate"))
wide$elapsed_ratio <- round(wide$elapsed_s_candidate / wide$elapsed_s_accepted, 3)
wide$peak_ratio <- round(wide$peak_rss_mib_candidate / wide$peak_rss_mib_accepted, 3)
utils::write.csv(wide, file.path(out_dir, "summary.csv"), row.names = FALSE)
print(wide, row.names = FALSE)

# Paired clocks for fresh-store creation (Cut 12 LDG-3016): ledgr_db_init()
# and a small ledgr_snapshot_from_df(), each on a new file store.
#
#   Rscript store_create_clock.R <accepted_repo> <candidate_repo> <out_dir> [pairs]
#
# Each pair runs both trees in fresh R processes, alternating which goes
# first. A child loads its tree, warms both calls once, then times `reps`
# calls of each and reports seconds per call. Writes <out_dir>/pairs.csv and
# <out_dir>/summary.csv (median per arm, candidate/accepted ratio).
args <- commandArgs(trailingOnly = TRUE)
rscript <- file.path(R.home("bin"), "Rscript")
if (length(args) >= 2L && identical(args[[1L]], "--child")) {
  repo <- args[[2L]]
  suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
  bars <- data.frame(instrument_id = rep(c("A", "B"), each = 20L),
                     ts_utc = rep(as.POSIXct("2020-01-01 21:00:00", tz = "UTC") + 86400 * 0:19, 2L),
                     open = 10, high = 11, low = 9, close = 10, volume = 1)
  init <- function() {
    con <- ledgr_db_init(tempfile(fileext = ".duckdb"))
    DBI::dbDisconnect(con, shutdown = TRUE)
  }
  seal <- function() ledgr_snapshot_close(ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb")))
  init(); seal()
  per_call <- function(fn, reps) {
    t0 <- proc.time()[["elapsed"]]
    for (i in seq_len(reps)) fn()
    (proc.time()[["elapsed"]] - t0) / reps
  }
  cat(sprintf("RESULT db_init %.6f\nRESULT snapshot_from_df %.6f\n", per_call(init, 40L), per_call(seal, 20L)))
  quit(save = "no")
}
accepted <- normalizePath(args[[1L]], winslash = "/")
candidate <- normalizePath(args[[2L]], winslash = "/")
out_dir <- args[[3L]]
pairs <- if (length(args) >= 4L) as.integer(args[[4L]]) else 5L
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/")
child <- function(repo) {
  out <- system2(rscript, c("--vanilla", shQuote(script), "--child", shQuote(repo)), stdout = TRUE, stderr = TRUE)
  hit <- grep("^RESULT ", out, value = TRUE)
  if (length(hit) != 2L) stop("child failed:\n", paste(out, collapse = "\n"))
  parts <- strsplit(sub("^RESULT ", "", hit), " ", fixed = TRUE)
  stats::setNames(as.numeric(vapply(parts, `[[`, "", 2L)), vapply(parts, `[[`, "", 1L))
}
rows <- list()
for (p in seq_len(pairs)) {
  order <- if (p %% 2L == 1L) c("accepted", "candidate") else c("candidate", "accepted")
  for (arm in order) {
    r <- child(if (arm == "accepted") accepted else candidate)
    rows[[length(rows) + 1L]] <- data.frame(pair = p, arm = arm, call = names(r), seconds = unname(r))
    cat(sprintf("pair %d %-9s db_init %.4f s, snapshot_from_df %.4f s\n", p, arm, r[["db_init"]], r[["snapshot_from_df"]]))
  }
}
all <- do.call(rbind, rows)
utils::write.csv(all, file.path(out_dir, "pairs.csv"), row.names = FALSE)
med <- stats::aggregate(seconds ~ call + arm, all, stats::median)
wide <- stats::reshape(med, idvar = "call", timevar = "arm", direction = "wide")
wide$ratio <- wide$seconds.candidate / wide$seconds.accepted
utils::write.csv(wide, file.path(out_dir, "summary.csv"), row.names = FALSE)
print(wide, row.names = FALSE)

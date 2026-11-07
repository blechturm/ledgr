# LDG-3215 history-read digest stream. The long intraday shapes are captured
# for preparation only (recorder/run.R, lc_workload_only): freezing their
# per-pulse packets would cost hours and repeats what the short shapes
# capture. Their history reads are checked here instead: every public
# ledgr_history_matrix() and ledgr_history_frame() call of the request set
# (prep_fixture.R, lc_prep_strategy) is digested in call order, with its
# function and pulse. A lean read path must produce the same stream.
#
#   Rscript dev/lean_core/parity/prep_digests.R --lib=<pinned library> --out=<dir>
#     [--manifests=<dir>] [--workloads=id,...] [--against=<dir>] [--lean]
#
# --lean runs each workload on lean preparation (prepare.R,
# lean_prepare_install(), restored after the workload).
#
# <out>/<workload>_reads.csv holds the per-call stream (not committed);
# <manifests>/prep_digests.csv holds per workload and function the call count,
# first and last pulse and one SHA-256 over the call digests in order.
# --against=<dir> compares each stream with <dir>/<workload>_reads.csv and
# stops at the first differing call. All data is simulated.

pd_arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
pd_here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
lib <- pd_arg("lib") %||% stop("--lib= is required", call. = FALSE)
out <- pd_arg("out") %||% stop("--out= is required", call. = FALSE)
manifests <- pd_arg("manifests", file.path(pd_here, "evidence"))
for (d in c(out, manifests)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

source(file.path(pd_here, "..", "load.R"))
lean <- lean_core_load(lib)
source(file.path(pd_here, "prep_fixture.R"))
work <- file.path(dirname(tempdir()), "ledgr_lean_core_work")
dir.create(work, showWarnings = FALSE)

pd_intraday <- function(n_inst, n_days) function() {
  id <- sprintf("lc_prep_intraday_%dx%d", n_inst, n_days)
  db <- file.path(work, paste0("digests_", id, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr::ledgr_snapshot_close(lc_prep_intraday_snapshot(n_inst, n_days, db, id))
  snapshot <- ledgr::ledgr_snapshot_open(db, id, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  close(ledgr::ledgr_run(lc_prep_intraday_experiment(snapshot), params = lc_prep_intraday_params,
                         run_id = "lc-prep", seed = 1L))
}
pd_workloads <- list(
  prep_fixture = function() {
    db <- file.path(work, "digests_prep_fixture.duckdb")
    if (file.exists(db)) unlink(db)
    fx <- lc_prep_fixture(db)
    on.exit(ledgr::ledgr_snapshot_close(fx$snapshot))
    close(ledgr::ledgr_run(fx$exp, params = lc_prep_fixture_params, run_id = "lc-prep-fixture", seed = 1L))
  },
  prep_intraday_1x100k = pd_intraday(1L, 1290L),
  prep_intraday_5x100k = pd_intraday(5L, 1290L),
  prep_intraday_20x50k = pd_intraday(20L, 645L)
)

# Format-2 serialization (materializes ALTREP), digest after the 14-byte
# header, as the recorder does (recorder/capture.R, lc_digest).
pd_digest <- function(x) digest::digest(serialize(x, NULL, version = 2L)[-seq_len(14L)], algo = "sha256", serialize = FALSE)

# Runs one workload with the two public reads wrapped; returns its stream.
pd_stream <- function(id) {
  ns <- asNamespace("ledgr")
  rec <- new.env()
  rec$fn <- rec$ts <- rec$digest <- character()
  rec$inside <- FALSE
  fns <- c("ledgr_history_matrix", "ledgr_history_frame")
  originals <- mget(fns, envir = ns)
  for (name in fns) local({
    orig <- originals[[name]]
    fn <- name
    wrapped <- function(ctx, ...) {
      if (rec$inside) return(orig(ctx, ...))
      rec$inside <- TRUE
      on.exit(rec$inside <- FALSE)
      res <- orig(ctx, ...)
      rec$fn <- c(rec$fn, fn)
      rec$ts <- c(rec$ts, ctx$ts_utc)
      rec$digest <- c(rec$digest, pd_digest(res))
      res
    }
    unlockBinding(fn, ns)
    assign(fn, wrapped, envir = ns)
    lockBinding(fn, ns)
  })
  on.exit(for (fn in fns) {
    unlockBinding(fn, ns)
    assign(fn, originals[[fn]], envir = ns)
    lockBinding(fn, ns)
  })
  pd_workloads[[id]]()
  data.frame(call = seq_along(rec$fn), fn = rec$fn, ts_utc = rec$ts, digest = rec$digest)
}

ids <- strsplit(pd_arg("workloads", paste(names(pd_workloads), collapse = ",")), ",")[[1L]]
against <- pd_arg("against")
rows <- list()
for (id in ids) {
  t0 <- proc.time()[["elapsed"]]
  restore <- if ("--lean" %in% commandArgs(TRUE)) lean$lean_prepare_install() else function() NULL
  s <- tryCatch(pd_stream(id), finally = restore())
  utils::write.csv(s, file.path(out, paste0(id, "_reads.csv")), row.names = FALSE)
  for (fn in c("all", unique(s$fn))) {
    k <- if (fn == "all") s else s[s$fn == fn, ]
    rows[[paste(id, fn)]] <- data.frame(workload = id, fn = fn, calls = nrow(k), first_ts = k$ts_utc[[1L]],
                                        last_ts = k$ts_utc[[nrow(k)]],
                                        sha256 = digest::digest(paste(k$digest, collapse = "\n"), algo = "sha256", serialize = FALSE))
  }
  cat(sprintf("%s: %d reads in %.0fs\n", id, nrow(s), proc.time()[["elapsed"]] - t0))
  if (!is.null(against)) {
    ref <- utils::read.csv(file.path(against, paste0(id, "_reads.csv")), colClasses = "character")
    ref$call <- as.integer(ref$call)
    if (!identical(nrow(ref), nrow(s))) stop(id, ": ", nrow(s), " reads, reference has ", nrow(ref), call. = FALSE)
    bad <- which(ref$fn != s$fn | ref$ts_utc != s$ts_utc | ref$digest != s$digest)
    if (length(bad)) stop(id, ": first differing read is call ", bad[[1L]], " (", s$fn[[bad[[1L]]]], " at ",
                          s$ts_utc[[bad[[1L]]]], "); ", length(bad), " differ", call. = FALSE)
    cat(sprintf("%s: identical to %s\n", id, against))
  }
}
utils::write.csv(do.call(rbind, rows), file.path(manifests, "prep_digests.csv"), row.names = FALSE)

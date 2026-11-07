# LDG-3215: where an evicted tile comes back from. Measures, per tile of W
# sessions x all instruments (six bar planes plus one feature plane):
#   hydrate   the pinned bar query (ledgr_precompute_fetch_bars_frame) on the
#             tile's session range from the sealed store, plus the pivot into
#             time-major W x N planes
#   spill     writing the tile's seven planes to a run-local binary file
#             (writeBin), and reading them back (readBin)
#   memory    copying the tile's columns out of resident full planes
# and what a lookback = Inf read pays to bring back every evicted tile.
#
#   Rscript tile_backing.R --lib=<pinned library> --store=<sealed store> --id=<snapshot id> --out=<csv> [--private]
#
# The store is opened read-only through the verified handle and never
# changed. With --private only aggregates are written (no identifiers).

arg <- function(n, d = NULL) {
  hit <- grep(paste0("^--", n, "(=|$)"), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(d)
  v <- sub(paste0("^--", n, "=?"), "", hit[[1L]])
  if (nzchar(v)) v else TRUE
}
.libPaths(c(arg("lib"), .libPaths()))
suppressPackageStartupMessages(library(ledgr))
ns <- asNamespace("ledgr")
snapshot <- ledgr_snapshot_open(arg("store"), arg("id"), verify = TRUE)
con <- ns$get_connection(snapshot)
ids <- DBI::dbGetQuery(con, "SELECT instrument_id FROM snapshot_instruments WHERE snapshot_id = ? ORDER BY instrument_id",
                       params = list(arg("id")))$instrument_id
axis <- sort(unique(as.POSIXct(DBI::dbGetQuery(con, "SELECT DISTINCT ts_utc FROM snapshot_bars WHERE snapshot_id = ?",
                                                params = list(arg("id")))$ts_utc, tz = "UTC")))
n <- length(ids)
t_all <- length(axis)
fields <- c("open", "high", "low", "close", "volume")
now <- function() as.numeric(Sys.time())

# Time-major planes for a frame of bars over the sessions `cols`.
pivot <- function(rows, cols) {
  i <- match(rows$instrument_id, ids)
  j <- match(as.numeric(rows$ts_utc), as.numeric(axis[cols]))
  out <- lapply(fields, function(f) {
    m <- matrix(NA_real_, length(cols), n)
    m[cbind(j, i)] <- rows[[f]]
    m
  })
  observed <- matrix(FALSE, length(cols), n)
  observed[cbind(j, i)] <- TRUE
  c(out, list(observed))
}

full_rows <- ns$ledgr_precompute_fetch_bars_frame(snapshot, ids, axis[[1L]], axis[[t_all]])
full <- pivot(full_rows, seq_len(t_all))
feature <- full[[4L]] / rbind(NA_real_, full[[4L]][-t_all, , drop = FALSE]) - 1  # a stand-in feature plane
full <- c(full, list(feature))
rm(full_rows)
invisible(gc())
spill <- tempfile(fileext = ".bin")
on.exit(unlink(spill))

rows <- list()
for (w in c(63L, 126L, 252L)) {
  starts <- seq.int(1L, t_all, by = w)
  for (rep in 1:3) {
    for (s in starts) {
      cols <- seq.int(s, min(s + w - 1L, t_all))
      t0 <- now()
      tile_rows <- ns$ledgr_precompute_fetch_bars_frame(snapshot, ids, axis[[cols[[1L]]]], axis[[cols[[length(cols)]]]])
      tile <- pivot(tile_rows, cols)
      t1 <- now()
      tile <- c(tile, list(feature[cols, , drop = FALSE]))
      if (!identical(tile[1:6], lapply(full[1:6], function(m) m[cols, , drop = FALSE]))) stop("hydrated tile differs")
      t2 <- now()
      con_w <- file(spill, "wb")
      for (m in tile) writeBin(as.vector(m, if (is.logical(m)) "logical" else "double"), con_w)
      close(con_w)
      t3 <- now()
      con_r <- file(spill, "rb")
      back <- lapply(tile, function(m) {
        v <- readBin(con_r, if (is.logical(m)) "logical" else "double", length(m))
        dim(v) <- dim(m)
        v
      })
      close(con_r)
      t4 <- now()
      if (!identical(back, tile)) stop("spilled tile differs")
      t5 <- now()
      copy <- lapply(full, function(m) m[cols, , drop = FALSE])
      t6 <- now()
      rows[[length(rows) + 1L]] <- data.frame(width = w, rep = rep, tile = match(s, starts), sessions = length(cols),
        stored = mean(colSums(tile[[6L]]) > 0),
        mb = sum(vapply(tile, function(m) as.numeric(object.size(m)), 0)) / 2^20,
        hydrate_ms = 1e3 * (t1 - t0), spill_write_ms = 1e3 * (t3 - t2), spill_read_ms = 1e3 * (t4 - t3),
        memory_ms = 1e3 * (t6 - t5))
    }
  }
}
ledgr_snapshot_close(snapshot)
raw <- do.call(rbind, rows)
raw <- raw[raw$sessions == raw$width, ]  # full tiles only
med <- function(x) stats::median(x)
summary <- do.call(rbind, lapply(split(raw, raw$width), function(d) data.frame(
  shape = if (isTRUE(arg("private"))) "private_h1" else sprintf("%dx%d", n, t_all),
  instruments = n, sessions = t_all, width = d$width[[1L]], tiles = length(unique(d$tile)),
  tile_mb = round(med(d$mb), 2), stored_share = round(mean(d$stored), 3), hydrate_ms = round(med(d$hydrate_ms), 2),
  spill_write_ms = round(med(d$spill_write_ms), 2), spill_read_ms = round(med(d$spill_read_ms), 2),
  memory_ms = round(med(d$memory_ms), 2),
  inf_read_hydrate_ms = round(med(d$hydrate_ms) * ceiling(t_all / d$width[[1L]]), 0),
  inf_read_spill_ms = round(med(d$spill_read_ms) * ceiling(t_all / d$width[[1L]]), 0),
  inf_read_memory_ms = round(med(d$memory_ms) * ceiling(t_all / d$width[[1L]]), 0))))
print(summary, row.names = FALSE)
out <- arg("out")
if (!is.null(out)) utils::write.csv(summary, out, row.names = FALSE)

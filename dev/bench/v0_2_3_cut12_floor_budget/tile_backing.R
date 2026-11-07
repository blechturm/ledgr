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
#   Rscript tile_backing.R --lib=<pinned library> --store=<sealed store> --id=<snapshot id> --out=<csv>
#     [--widths=63,126,252] [--private]
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

# Time-major planes for a frame of bars over the sessions `cols` (positions by
# collapse::fmatch, about 1 ms per 252 x 500 tile below base match()).
pivot <- function(rows, cols) {
  i <- collapse::fmatch(rows$instrument_id, ids)
  j <- collapse::fmatch(as.numeric(rows$ts_utc), as.numeric(axis[cols]))
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
widths <- as.integer(strsplit(arg("widths", "63,126,252"), ",")[[1L]])
for (w in widths) {
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
# Whole hydration passes over every tile, three ways, alternating, 3 reps:
#   per_tile  one pinned query per tile range (the rows above)
#   stream    one query ordered by time, fetched a tile's rows at a time
#   long      the pin's one query for the whole history, then sliced
# Each pass builds every tile and checks it against the full planes; the
# rows held in R at once are its hydration memory.
placeholders <- paste(rep("?", n), collapse = ", ")
stream_sql <- sprintf(paste("SELECT instrument_id, ts_utc, open, high, low, close, volume FROM snapshot_bars",
                            "WHERE snapshot_id = ? AND instrument_id IN (%s) AND ts_utc >= ? AND ts_utc <= ?",
                            "ORDER BY ts_utc, instrument_id"), placeholders)
check_tile <- function(tile, cols) {
  if (!identical(tile, lapply(full[1:6], function(m) m[cols, , drop = FALSE]))) stop("pass tile differs")
}
pass <- function(mode, w) {
  starts <- seq.int(1L, t_all, by = w)
  held <- 0
  t0 <- now()
  if (mode == "per_tile") {
    for (s in starts) {
      cols <- seq.int(s, min(s + w - 1L, t_all))
      r <- ns$ledgr_precompute_fetch_bars_frame(snapshot, ids, axis[[cols[[1L]]]], axis[[cols[[length(cols)]]]])
      held <- max(held, nrow(r))
      check_tile(pivot(r, cols), cols)
    }
  } else if (mode == "stream") {
    res <- DBI::dbSendQuery(con, stream_sql, params = c(list(arg("id")), as.list(ids), list(axis[[1L]], axis[[t_all]])))
    buf <- NULL
    for (s in starts) {
      cols <- seq.int(s, min(s + w - 1L, t_all))
      end <- as.numeric(axis[[cols[[length(cols)]]]])
      while ((is.null(buf) || !nrow(buf) || as.numeric(buf$ts_utc[[nrow(buf)]]) <= end) && !DBI::dbHasCompleted(res)) {
        chunk <- DBI::dbFetch(res, n = w * n)
        chunk$instrument_id <- as.character(chunk$instrument_id)
        chunk$ts_utc <- as.POSIXct(chunk$ts_utc, tz = "UTC")
        buf <- if (is.null(buf)) chunk else rbind(buf, chunk)
      }
      held <- max(held, nrow(buf))
      take <- as.numeric(buf$ts_utc) <= end
      check_tile(pivot(buf[take, , drop = FALSE], cols), cols)
      buf <- buf[!take, , drop = FALSE]
    }
    DBI::dbClearResult(res)
  } else {
    r <- ns$ledgr_precompute_fetch_bars_frame(snapshot, ids, axis[[1L]], axis[[t_all]])
    held <- nrow(r)
    j <- collapse::fmatch(as.numeric(r$ts_utc), as.numeric(axis))
    for (s in starts) {
      cols <- seq.int(s, min(s + w - 1L, t_all))
      check_tile(pivot(r[j >= cols[[1L]] & j <= cols[[length(cols)]], , drop = FALSE], cols), cols)
    }
  }
  data.frame(width = w, mode = mode, ms = 1e3 * (now() - t0), rows_held = held)
}
passes <- list()
for (w in widths) for (rep in 1:3) for (mode in c("per_tile", "stream", "long")[c(rep, rep %% 3 + 1, (rep + 1) %% 3 + 1)]) {
  invisible(gc())
  passes[[length(passes) + 1L]] <- pass(mode, w)
}
passes <- do.call(rbind, passes)
pass_ms <- tapply(passes$ms, list(passes$width, passes$mode), stats::median)
pass_rows <- tapply(passes$rows_held, list(passes$width, passes$mode), max)
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
  inf_read_memory_ms = round(med(d$memory_ms) * ceiling(t_all / d$width[[1L]]), 0),
  pass_per_tile_ms = round(pass_ms[as.character(d$width[[1L]]), "per_tile"], 0),
  pass_stream_ms = round(pass_ms[as.character(d$width[[1L]]), "stream"], 0),
  pass_long_ms = round(pass_ms[as.character(d$width[[1L]]), "long"], 0),
  rows_held_per_tile = pass_rows[as.character(d$width[[1L]]), "per_tile"],
  rows_held_stream = pass_rows[as.character(d$width[[1L]]), "stream"],
  rows_held_long = pass_rows[as.character(d$width[[1L]]), "long"])))
print(summary, row.names = FALSE)
out <- arg("out")
if (!is.null(out)) utils::write.csv(summary, out, row.names = FALSE)

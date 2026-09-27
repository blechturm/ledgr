# Probe: does collapse::rsplit() reproduce base split() at ledgr's two
# bars-by-instrument preparation sites? Smallest runnable fork, one seam.
#
# The seam is in memory only: the production function body is copied, its one
# split() call is replaced by a capturing splitter, and the copy is installed in
# the loaded namespace for the duration of one call. Tracked files are unchanged.
#
# Usage, from the repository root:
#   Rscript dev/spikes/collapse-preparation/probe.R

suppressMessages(pkgload::load_all(".", quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")

replace_call <- function(expr, target, replacement) {
  hits <- 0L
  walk <- function(e) {
    if (is.call(e)) {
      if (identical(e, target)) { hits <<- hits + 1L; return(replacement) }
      for (i in seq_along(e)) if (!is.null(e[[i]])) e[[i]] <- walk(e[[i]])
    }
    e
  }
  out <- walk(expr)
  if (hits != 1L) stop(sprintf("expected one split() site, found %d", hits))
  out
}
seam <- function(name, target, splitter) {
  f <- get(name, envir = ns)
  replacement <- as.call(c(list(splitter), as.list(target)[-1L]))
  body(f) <- replace_call(body(f), target, replacement)
  f
}
with_binding <- function(name, value, code) {
  old <- get(name, envir = ns)
  unlockBinding(name, ns); assign(name, value, envir = ns)
  on.exit({ assign(name, old, envir = ns); lockBinding(name, ns) }, add = TRUE)
  force(code)
}

captured <- new.env()
capture_split <- function(site) function(x, f) {
  captured[[site]] <- list(x = x, f = f)
  split(x, f)
}
precompute_target <- quote(split(rows, rows$instrument_id))
runner_target <- quote(split(bars_all, as.character(bars_all$instrument_id)))

# Small deterministic fixture on the public bar schema.
ids <- c("DEMO_01", "DEMO_02", "DEMO_03")
ts <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5
bars <- data.frame(
  ts_utc = rep(ts, times = length(ids)),
  instrument_id = rep(ids, each = length(ts)),
  open = 100 + seq_len(18), high = 101 + seq_len(18), low = 99 + seq_len(18),
  close = 100.5 + seq_len(18), volume = c(1000, NA, rep(1000, 16)),
  stringsAsFactors = FALSE
)
db_path <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = "probe")

fetch <- seam("ledgr_precompute_fetch_bars", precompute_target, capture_split("precompute"))
invisible(fetch(snapshot, ids, "2020-01-01T00:00:00Z", "2020-01-06T00:00:00Z"))

exp <- ledgr_experiment(snapshot, function(ctx, params) ctx$flat(), cost_model = ledgr_cost_zero())
run_fold <- seam("ledgr_run_fold", runner_target, capture_split("runner"))
run <- with_binding("ledgr_run_fold", run_fold, ledgr_run(exp, run_id = "probe-run"))
close(run)

describe <- function(site) {
  x <- captured[[site]]$x
  f <- captured[[site]]$f
  base <- split(x, f)
  cand <- collapse::rsplit(x, f, sort = TRUE, simplify = FALSE)
  cat(sprintf("\n== %s: %d rows, columns %s\n", site, nrow(x),
    paste(sprintf("%s<%s>", names(x), vapply(x, function(v) class(v)[[1L]], "")), collapse = " ")))
  cat("names identical:", identical(names(base), names(cand)), " [", names(base), "] vs [", names(cand), "]\n")
  for (g in names(base)) {
    b <- base[[g]]; r <- cand[[g]]
    cat(sprintf("  %s identical=%s  values-equal-ignoring-attrs=%s\n", g, identical(b, r),
      isTRUE(all.equal(b, r, check.attributes = FALSE))))
    ab <- attributes(b); ar <- attributes(r)
    for (a in union(names(ab), names(ar))) if (!identical(ab[[a]], ar[[a]])) {
      cat(sprintf("    attr %s: base=%s | rsplit=%s\n", a,
        paste(deparse(ab[[a]]), collapse = ""), paste(deparse(ar[[a]]), collapse = "")))
    }
    for (col in names(b)) if (!identical(attributes(b[[col]]), attributes(r[[col]]))) {
      cat(sprintf("    column %s attributes differ\n", col))
    }
  }
}
describe("precompute")
describe("runner")

ledgr_snapshot_close(snapshot)
unlink(db_path)

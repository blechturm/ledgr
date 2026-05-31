# fetch_lean_reference.R
#
# Scrape QuantConnect's LEAN engine-performance benchmarks into a tidy CSV that
# ledgr's benchmark suite (v0.1.8.6 Workstream S) uses as the external
# comparison baseline.
#
# PRODUCES
#   dev/bench/references/lean_reference.csv, one row per (benchmark, language):
#     benchmark, language, dps_median, dps_latest, n_points, ledgr_scenario,
#     comparable, source_url, notes
#
# METRIC
#   "DPS" = data points per second as QuantConnect reports it. A data point is
#   one security's bar at one timestamp (a security-bar). The comparable ledgr
#   metric is therefore:
#       security_bars_sec = n_inst * n_pulses / t_wall
#         (defined for EVERY scenario, with or without features)
#   NOT the feature-payload spike's feature-cells throughput:
#       feature_cells_sec = n_inst * n_pulses * n_feat / t_wall
#         (n_feat times larger; undefined for the empty/no-feature scenarios)
#   Do not conflate the two. This is a THROUGHPUT comparison, NOT a parity claim:
#   LEAN is a compiled C# engine; the Python column is a compiled engine with an
#   interpreted Python callback; ledgr is interpreted R end to end.
#
# HOW THE DATA IS OBTAINED
#   QuantConnect inlines the Highcharts series (arrays of [timestamp_ms, dps]
#   points measured over time) directly in the /performance page HTML, and lists
#   each benchmark's source link in a table. This scraper extracts both. If QC
#   ever moves the series to an async XHR, the scraper FAILS LOUDLY rather than
#   returning stale numbers.
#
# USAGE
#   Rscript -e 'source("dev/bench/references/fetch_lean_reference.R"); fetch_lean_reference()'
#   # offline / deterministic (against a saved copy of the page):
#   fetch_lean_reference(source = "path/to/qc_perf.html")
#
# DEPENDENCIES: jsonlite and digest (already ledgr dependencies). No rvest
# required.

LEAN_PERF_URL <- "https://www.quantconnect.com/performance"

# Map each LEAN benchmark (base name, without the [CS]/[PY] prefix) to the
# nearest ledgr benchmark scenario and how comparable the shapes are.
.lean_scenario_map <- list(
  "Basic Template"              = c(scenario = "baseline_single_run",    comparable = "yes",     note = "1 sym, minute, buy-and-hold; end-to-end baseline"),
  "Equity 1 Symbol (second)"    = c(scenario = "pulse_loop_empty",       comparable = "yes",     note = "1 sym, empty OnData; pure loop / data-feed throughput"),
  "Equity 400 Symbols (minute)" = c(scenario = "wide_panel_no_features", comparable = "yes",     note = "400 sym, empty OnData; universe-width loop"),
  "Indicator"                   = c(scenario = "indicator_payload",      comparable = "partial", note = "50 chained indicators on 1 sym (depth); ledgr payload is width (inst x feat)"),
  "History"                     = c(scenario = NA,                       comparable = "no",      note = "History() requests; ledgr has no analogue (ctx$window deferred)"),
  "Schedule Events"             = c(scenario = NA,                       comparable = "no",      note = "scheduled events; no ledgr analogue"),
  "Coarse Fine Universe"        = c(scenario = NA,                       comparable = "no",      note = "universe selection / fundamental filter; no ledgr analogue"),
  "Stateful Universe"           = c(scenario = NA,                       comparable = "no",      note = "universe selection; no ledgr analogue"),
  "Stateless Universe"          = c(scenario = NA,                       comparable = "no",      note = "universe selection; no ledgr analogue")
)

.lean_read_html <- function(source) {
  if (file.exists(source)) {
    return(paste(readLines(source, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
  }
  con <- url(source, open = "r")
  on.exit(close(con), add = TRUE)
  paste(readLines(con, warn = FALSE), collapse = "\n")
}

.lean_extract_series <- function(html) {
  if (!grepl("Highcharts.chart", html, fixed = TRUE) || !grepl("series:", html, fixed = TRUE)) {
    stop("LEAN /performance format changed: no inline Highcharts series found. Update fetch_lean_reference.R.")
  }
  after <- sub("(?s)^.*?series:\\s*", "", html, perl = TRUE)
  arr <- trimws(sub("(?s)\\s*\\}\\).*$", "", after, perl = TRUE))
  series <- tryCatch(
    jsonlite::fromJSON(arr, simplifyVector = FALSE),
    error = function(e) stop("Failed to parse LEAN series JSON (page format may have changed): ", conditionMessage(e))
  )
  if (!length(series)) stop("LEAN series array parsed but empty; update the scraper.")
  series
}

.lean_extract_sources <- function(html) {
  pat <- '<td>(\\[(?:CS|PY)\\][^<]*)</td>\\s*<td><a href="([^"]+)"'
  hits <- regmatches(html, gregexpr(pat, html, perl = TRUE))[[1]]
  if (!length(hits)) return(stats::setNames(character(0), character(0)))
  nm <- trimws(sub(paste0("(?s)", pat, ".*$"), "\\1", hits, perl = TRUE))
  ur <- sub(paste0("(?s)", pat, ".*$"), "\\2", hits, perl = TRUE)
  stats::setNames(ur, nm)
}

fetch_lean_reference <- function(source = LEAN_PERF_URL,
                                 out = "dev/bench/references/lean_reference.csv") {
  html <- .lean_read_html(source)
  series <- .lean_extract_series(html)
  sources <- .lean_extract_sources(html)

  rows <- lapply(series, function(s) {
    full_name <- s$name
    lang <- if (grepl("^\\[CS\\]", full_name)) "C#" else if (grepl("^\\[PY\\]", full_name)) "Python" else NA_character_
    base <- trimws(sub("^\\[(?:CS|PY)\\]\\s*", "", full_name))
    dps <- vapply(s$data, function(p) as.numeric(p[[2]]), numeric(1))
    map <- .lean_scenario_map[[base]]
    data.frame(
      benchmark      = base,
      language       = lang,
      dps_median     = round(stats::median(dps, na.rm = TRUE)),
      dps_latest     = round(as.numeric(s$data[[length(s$data)]][[2]])),
      n_points       = length(dps),
      ledgr_scenario = if (is.null(map)) NA_character_ else unname(map["scenario"]),
      comparable     = if (is.null(map)) "unmapped" else unname(map["comparable"]),
      source_url     = unname(sources[full_name]),
      notes          = if (is.null(map)) NA_character_ else unname(map["note"]),
      stringsAsFactors = FALSE
    )
  })
  df <- do.call(rbind, rows)
  df <- df[order(df$comparable != "yes", df$comparable != "partial", df$benchmark, df$language), , drop = FALSE]
  rownames(df) <- NULL

  if (!is.null(out)) {
    dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
    utils::write.csv(df, out, row.names = FALSE)
    # Provenance sidecar: which external baseline these numbers came from, so a
    # future comparison knows the page may have changed underneath it.
    meta <- list(
      source       = source,
      page_url     = LEAN_PERF_URL,
      retrieved_at = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
      page_sha256  = digest::digest(html, algo = "sha256", serialize = FALSE),
      n_rows       = nrow(df),
      n_benchmarks = length(unique(df$benchmark)),
      metric       = "security_bars_sec = n_inst * n_pulses / t_wall; LEAN DPS = security-bars/sec"
    )
    meta_path <- sub("\\.csv$", ".meta.json", out)
    jsonlite::write_json(meta, meta_path, auto_unbox = TRUE, pretty = TRUE)
    message(sprintf("[lean_reference] wrote %d rows to %s + provenance %s (source: %s)",
                    nrow(df), out, meta_path, source))
  }
  invisible(df)
}

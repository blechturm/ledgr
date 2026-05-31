# fetch_ziplime_reference.R
#
# Scrape the Ziplime project's published Python-backtester benchmark into a tidy
# CSV that ledgr's benchmark suite uses as an EXTERNAL ORIENTATION reference for
# the interpreted, event-driven peer group (Ziplime / Zipline / Backtrader).
#
# PROVENANCE / HONESTY
#   These numbers come from the Ziplime README, which is a VENDOR SELF-BENCHMARK
#   (Ziplime promoting its Polars data layer against competitors). No methodology
#   is published: no repeats, no warmup, no variance, and no definition of what
#   "execution time" includes (it very likely includes data load/ingest, which is
#   precisely what Ziplime is selling). The machine is Apple Silicon M3, which is
#   NOT the ledgr benchmark host. Therefore every row is marked
#   `comparable = "orientation_only"`: useful for peer ORDERING, never a
#   controlled head-to-head. A real comparison requires running these engines and
#   ledgr's matched `peer_sma_crossover` scenario on the SAME machine.
#
# DELIBERATELY EXCLUDED
#   The VectorBT row that circulates with this table is dropped on purpose:
#     (1) it is not in the cited source (the figure is "community consensus", not
#         a measurement), and
#     (2) VectorBT is a VECTORIZED engine, not an event-driven one. Mixing it with
#         per-bar event engines is the same category error as comparing ledgr's
#         per-bar loop to a vectorized backtest. Out of scope for this reference.
#
# WORKLOAD (as stated in the source)
#   500 assets, 5 years daily data, SMA crossover strategy. ledgr's matched
#   scenario is `peer_sma_crossover` in run_benchmarks.R.
#
# USAGE
#   Rscript -e 'source("dev/bench/references/fetch_ziplime_reference.R"); fetch_ziplime_reference()'
#   # offline / deterministic (against a saved copy of the README):
#   fetch_ziplime_reference(source = "path/to/ziplime_README.md")
#
# DEPENDENCIES: jsonlite and digest (already ledgr dependencies). No rvest/gh.

ZIPLIME_REPO_URL   <- "https://github.com/Limex-com/ziplime"
ZIPLIME_README_URL <- "https://raw.githubusercontent.com/Limex-com/ziplime/master/README.md"

# Workload constants stated in the source benchmark block.
.ziplime_n_assets <- 500L
.ziplime_years    <- 5L
.ziplime_trading_days_per_year <- 252L

# Event-driven rows we keep, in source label -> tidy framework name. VectorBT is
# intentionally absent (see header).
.ziplime_frameworks <- list(
  list(label = "Ziplime (Polars)", framework = "Ziplime (Polars backend)",
       note = "vendor's own engine; Polars/Rust data layer is the thing being sold"),
  list(label = "Zipline (pandas)", framework = "Zipline (original pandas)",
       note = "legacy pandas/NumPy data layer"),
  list(label = "Backtrader",       framework = "Backtrader (pure Python)",
       note = "pure-Python event loop")
)

.ziplime_read_readme <- function(source) {
  if (file.exists(source)) {
    return(paste(readLines(source, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
  }
  con <- url(source, open = "r")
  on.exit(close(con), add = TRUE)
  paste(readLines(con, warn = FALSE), collapse = "\n")
}

# Extract "<n>s" timing from the single line that contains BOTH the framework
# label and a seconds figure (guards against prose mentions of the names).
.ziplime_extract_seconds <- function(lines, label) {
  has_time <- grepl("[0-9]+(\\.[0-9]+)?s", lines, perl = TRUE)
  hits <- lines[grepl(label, lines, fixed = TRUE) & has_time]
  if (!length(hits)) {
    stop(sprintf(
      "Ziplime README format changed: no benchmark line for '%s'. Update fetch_ziplime_reference.R.",
      label
    ))
  }
  m <- regmatches(hits[[1L]], regexpr("[0-9]+(\\.[0-9]+)?s", hits[[1L]], perl = TRUE))
  as.numeric(sub("s$", "", m))
}

fetch_ziplime_reference <- function(source = ZIPLIME_README_URL,
                                    out = "dev/bench/references/ziplime_reference.csv") {
  readme <- .ziplime_read_readme(source)
  lines <- strsplit(readme, "\n", fixed = TRUE)[[1L]]

  # Sanity-gate the workload so we never attach 500x5yr/SMA metadata to a README
  # whose benchmark has silently changed shape.
  if (!grepl("500 assets", readme, ignore.case = TRUE) ||
      !grepl("SMA crossover", readme, ignore.case = TRUE) ||
      !grepl("5 year", readme, ignore.case = TRUE)) {
    stop("Ziplime README benchmark workload ('5 years daily, 500 assets, SMA crossover') not found; refusing to trust the numbers. Update fetch_ziplime_reference.R.")
  }

  bars <- .ziplime_n_assets * .ziplime_years * .ziplime_trading_days_per_year
  rows <- lapply(.ziplime_frameworks, function(fw) {
    secs <- .ziplime_extract_seconds(lines, fw$label)
    data.frame(
      framework            = fw$framework,
      language             = "Python",
      engine_class         = "event_driven",
      execution_time_sec   = secs,
      n_assets             = .ziplime_n_assets,
      years                = .ziplime_years,
      data_frequency       = "Daily",
      strategy             = "SMA Crossover",
      bars                 = bars,
      implied_bars_per_sec = round(bars / secs),
      hardware             = "Apple Silicon M3, Python 3.12",
      ledgr_scenario       = "peer_sma_crossover",
      comparable           = "orientation_only",
      source_url           = ZIPLIME_REPO_URL,
      notes                = paste0(
        fw$note,
        "; vendor self-reported, methodology unstated, likely includes data load; ",
        "M3 host != ledgr bench host -- ordering only, not a controlled head-to-head"
      ),
      stringsAsFactors = FALSE
    )
  })
  df <- do.call(rbind, rows)
  df <- df[order(df$execution_time_sec), , drop = FALSE]
  rownames(df) <- NULL

  if (!is.null(out)) {
    dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
    utils::write.csv(df, out, row.names = FALSE)
    meta <- list(
      source               = source,
      page_url             = ZIPLIME_REPO_URL,
      readme_url           = ZIPLIME_README_URL,
      retrieved_at         = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
      page_sha256          = digest::digest(readme, algo = "sha256", serialize = FALSE),
      n_rows               = nrow(df),
      vendor_self_reported = TRUE,
      methodology          = "unstated (no repeats/warmup/variance; execution-time boundary undefined, likely includes data load)",
      workload             = "500 assets, 5 years daily, SMA crossover",
      hardware             = "Apple Silicon M3, Python 3.12 (NOT the ledgr bench host)",
      comparability        = "orientation_only: peer ordering, not a controlled head-to-head",
      excluded             = "VectorBT (vectorized engine; figure not in source / 'community consensus'; category mismatch with event-driven engines)",
      ledgr_matched_scenario = "peer_sma_crossover (run_benchmarks.R)"
    )
    meta_path <- sub("\\.csv$", ".meta.json", out)
    jsonlite::write_json(meta, meta_path, auto_unbox = TRUE, pretty = TRUE)
    message(sprintf("[ziplime_reference] wrote %d rows to %s + provenance %s (source: %s)",
                    nrow(df), out, meta_path, source))
  }
  invisible(df)
}

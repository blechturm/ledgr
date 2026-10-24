# Spot-crypto readiness, Stage 1: crypto2 data probe.
#
# Question: can the CRAN package crypto2 supply, for 2022-01-01..2023-12-31,
# the inputs of a point-in-time ledgr snapshot of a top-100 crypto universe:
# daily OHLCV for every coin ever in the top 100 (dead coins included),
# historical rank snapshots, lifetime/terminal information, at acceptable
# download cost?
#
# Usage:
#   Rscript <abs path>/dev/spikes/crypto-readiness/data_probe.R <out_dir> <cache_dir> [lib_dir]
# out_dir   aggregate evidence CSVs + data_probe_log.txt (keep outside the repo)
# cache_dir raw crypto2 downloads as RDS (keep outside the repo); a cached
#           fetch is never repeated, so reruns make no network requests
# lib_dir   optional library holding crypto2 (prepended to .libPaths())
# Loads ledgr from this checkout with pkgload for the smoke check only; never
# edits package code. Network calls are sequential with crypto2's own retry
# pacing plus sleep = 1 s between requests.

args <- commandArgs(trailingOnly = FALSE)
script <- normalizePath(sub("^--file=", "", args[grep("^--file=", args)][1]), winslash = "/")
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), winslash = "/")
trail <- commandArgs(trailingOnly = TRUE)
stopifnot(length(trail) >= 2L)
out_dir <- trail[[1L]]
cache_dir <- trail[[2L]]
if (length(trail) >= 3L) .libPaths(c(trail[[3L]], .libPaths()))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
setwd(repo)
host_tz <- Sys.timezone()
Sys.setenv(TZ = "UTC")  # crypto2 parses CMC ISO times with no tz (see section 6)
suppressMessages(library(crypto2))

log_con <- file(file.path(out_dir, "data_probe_log.txt"), open = "wt")
sink(log_con, split = TRUE)
sink(log_con, type = "message")
options(width = 160, pillar.width = 160, tibble.width = 160, digits = 10, warn = 1)
section <- function(x) cat("\n==== ", x, " ====\n", sep = "")
write_ev <- function(df, name) {
  utils::write.csv(as.data.frame(df), file.path(out_dir, paste0(name, ".csv")), row.names = FALSE)
}
cat("git HEAD:", system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE), "\n")
cat("crypto2 version:", as.character(utils::packageVersion("crypto2")), "\n")
cat("host time zone:", host_tz, " (probe runs with TZ=UTC)\n")
WIN_START <- as.Date("2022-01-01")
WIN_END <- as.Date("2023-12-31")
TOP_N <- 100L

# ---------------------------------------------------------------------------
# fetch(): one cached network call. Records elapsed time, messages (crypto2
# retry notices) and warnings with the cached value, so reruns report the
# original download cost without repeating the request.
timings <- list()
fetch <- function(name, fn) {
  path <- file.path(cache_dir, paste0(name, ".rds"))
  if (file.exists(path)) {
    rec <- readRDS(path)
    src <- "cache"
  } else {
    msgs <- character()
    warns <- character()
    t0 <- Sys.time()
    value <- withCallingHandlers(
      tryCatch(fn(), error = function(e) {
        cat("[", name, "] ERROR: ", conditionMessage(e), "\n", sep = "")
        structure(list(), class = "fetch_error", msg = conditionMessage(e))
      }),
      message = function(m) {
        msgs <<- c(msgs, trimws(conditionMessage(m)))
        invokeRestart("muffleMessage")
      },
      warning = function(w) {
        warns <<- c(warns, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    rec <- list(value = value, elapsed = as.numeric(difftime(Sys.time(), t0, units = "secs")),
                msgs = msgs, warns = warns, fetched_at = Sys.time())
    if (!inherits(value, "fetch_error")) saveRDS(rec, path)
    src <- "network"
  }
  n_retry <- sum(grepl("(?i)retr|429|too many|rate", rec$msgs, perl = TRUE))
  timings[[length(timings) + 1L]] <<- data.frame(
    fetch = name, source = src, elapsed_s = round(rec$elapsed, 1),
    n_messages = length(rec$msgs), n_retry_messages = n_retry, n_warnings = length(rec$warns)
  )
  for (w in unique(rec$warns)) cat("[", name, "] warning: ", substr(w, 1, 300), "\n", sep = "")
  for (m in unique(rec$msgs[grepl("(?i)retr|429|too many|rate|fail|error", rec$msgs, perl = TRUE)])) {
    cat("[", name, "] message: ", substr(m, 1, 300), "\n", sep = "")
  }
  rec$value
}
raw_cmc <- function(path, v) crypto2:::safeFromJSON(crypto2:::construct_url(path, v = v))

# ---------------------------------------------------------------------------
section("1. crypto_list(only_active = FALSE, add_untracked = TRUE)")
coins <- fetch("crypto_list_all", function() crypto_list(only_active = FALSE, add_untracked = TRUE))
coins <- as.data.frame(coins)
status_lab <- c(`1` = "active", `0` = "inactive", `-1` = "untracked")
coins$status <- unname(status_lab[as.character(coins$is_active)])
cat("rows:", nrow(coins), " distinct ids:", length(unique(coins$id)), "\n")
st <- do.call(rbind, lapply(split(coins, coins$status), function(d) data.frame(
  status = d$status[1], n = nrow(d),
  first_hist_min = min(d$first_historical_data, na.rm = TRUE),
  first_hist_max = max(d$first_historical_data, na.rm = TRUE),
  last_hist_min = min(d$last_historical_data, na.rm = TRUE),
  last_hist_max = max(d$last_historical_data, na.rm = TRUE),
  n_na_first = sum(is.na(d$first_historical_data)), n_na_last = sum(is.na(d$last_historical_data))
)))
print(st)
write_ev(st, "coin_status_counts")
cat("ids listed under more than one status:", sum(duplicated(coins$id)), "\n")
cat("inactive coins whose last_historical_data falls in the window:",
    sum(coins$status == "inactive" & coins$last_historical_data >= WIN_START &
          coins$last_historical_data <= WIN_END, na.rm = TRUE), "\n")

section("1b. Raw CMC map for inactive and untracked coins (are the dates in the source?)")
for (lst in c("inactive", "untracked")) {
  rm_ <- fetch(paste0("raw_map_", lst), function() raw_cmc(paste0("cryptocurrency/map?listing_status=", lst), v = 1))
  d <- as.data.frame(rm_$data)
  cat(lst, ": rows", nrow(d), " fields:", paste(names(d), collapse = ", "), "\n")
  if (nrow(d)) {
    if ("is_active" %in% names(d)) print(table(is_active = d$is_active, useNA = "ifany"))
    for (f in intersect(c("first_historical_data", "last_historical_data"), names(d))) {
      v <- d[[f]]
      cat("  ", f, ": non-NA", sum(!is.na(v)), " sample:", paste(utils::head(unique(v[!is.na(v)]), 3), collapse = " | "), "\n")
    }
    cat("  ids also in the crypto2 inactive set:", sum(d$id %in% coins$id[coins$status == "inactive"]), "\n")
  }
}

# ---------------------------------------------------------------------------
section("2. Raw listing JSON for one date (field names and timestamps before crypto2 parsing)")
raw_l <- fetch("raw_listing_20220510", function() raw_cmc(
  "cryptocurrency/listings/historical?date=2022-05-10&convertId=2781&sort=cmc_rank&sort_dir=asc&limit=3&start=1", v = 3))
rd <- raw_l$data
cat("top-level fields:", paste(names(rd), collapse = ", "), "\n")
print(rd[, intersect(c("id", "symbol", "cmcRank", "lastUpdated", "dateAdded", "circulatingSupply"), names(rd))])
q1 <- rd$quotes[[1]]
cat("quote fields:", paste(names(q1), collapse = ", "), "\n")
print(q1[, intersect(c("name", "price", "marketCap", "lastUpdated", "volume24h"), names(q1))])

section("2b. Earliest historical listing (2013-04-28, limit 10)")
early <- fetch("listing_20130428", function() crypto_listings(
  which = "historical", start_date = "20130428", end_date = "20130428", limit = 10, quote = TRUE, sleep = 1))
cat("rows on 2013-04-28:", nrow(early), "\n")

# ---------------------------------------------------------------------------
section("3. Daily historical listings 2022-01-01..2023-12-31, limit = 100")
q_starts <- seq(WIN_START, by = "quarter", length.out = 8L)
q_ends <- c(q_starts[-1L] - 1L, WIN_END)
listings <- do.call(rbind, lapply(seq_along(q_starts), function(k) {
  x <- fetch(sprintf("listings_top%d_%s", TOP_N, format(q_starts[k], "%Y%m%d")), function() crypto_listings(
    which = "historical", start_date = format(q_starts[k], "%Y%m%d"), end_date = format(q_ends[k], "%Y%m%d"),
    interval = "day", limit = TOP_N, quote = TRUE, sleep = 1))
  as.data.frame(x)
}))
cat("listing columns:", paste(names(listings), collapse = ", "), "\n")
listings$date <- as.Date(listings$date)
rank_col <- intersect(c("cmc_rank", "rank"), names(listings))[1]
cat("rank column used:", rank_col, "\n")
listings$rank <- listings[[rank_col]]
listings <- listings[listings$rank <= TOP_N, ]
per_day <- do.call(rbind, lapply(split(listings, listings$date), function(d) data.frame(
  date = d$date[1], n = nrow(d), min_rank = min(d$rank), max_rank = max(d$rank),
  dup_ids = sum(duplicated(d$id)), ranks_complete = setequal(d$rank, seq_len(TOP_N)),
  last_updated = paste(sort(unique(as.character(d$last_updated))), collapse = "|")
)))
all_days <- seq(WIN_START, WIN_END, by = "day")
cat("calendar days in window:", length(all_days), " days with a listing:", nrow(per_day),
    " missing days:", paste(head(setdiff(as.character(all_days), as.character(per_day$date)), 20), collapse = ", "), "\n")
cat("rows per day: min", min(per_day$n), " max", max(per_day$n), "; days with ranks exactly 1..100:",
    sum(per_day$ranks_complete), "; days with duplicate ids:", sum(per_day$dup_ids > 0), "\n")
cat("last_updated vs snapshot date (distinct offsets in days):\n")
lu <- as.Date(listings$last_updated)
print(table(offset_days = as.integer(lu - listings$date), useNA = "ifany"))
write_ev(per_day, "listing_per_day")
# Frequency: does the snapshot change every day, or repeat (weekly snapshots)?
lp <- listings[order(listings$id, listings$date), c("id", "date", "price", "market_cap", "rank")]
prev_same <- c(FALSE, lp$id[-1] == lp$id[-nrow(lp)] & as.integer(diff(lp$date)) == 1L)
same_price <- prev_same & c(FALSE, lp$price[-1] == lp$price[-nrow(lp)])
cat("coin-days with a previous-day row:", sum(prev_same), " of which price identical to the previous day:",
    sum(same_price), sprintf(" (%.2f%%)", 100 * sum(same_price) / sum(prev_same)), "\n")
churn <- vapply(seq_len(nrow(per_day) - 1L), function(i) {
  a <- listings$id[listings$date == per_day$date[i]]
  b <- listings$id[listings$date == per_day$date[i + 1L]]
  length(setdiff(b, a))
}, integer(1))
cat("daily top-100 entries (new ids vs previous day): mean", round(mean(churn), 2), " max", max(churn),
    " days with zero churn:", sum(churn == 0), "of", length(churn), "\n")

# ---------------------------------------------------------------------------
section("4. Union of top-100 members over the window")
mem <- do.call(rbind, lapply(split(listings, listings$id), function(d) data.frame(
  id = d$id[1], symbol = d$symbol[nrow(d)], slug = d$slug[nrow(d)], name = d$name[nrow(d)],
  top100_days = nrow(d), first_top100 = min(d$date), last_top100 = max(d$date), best_rank = min(d$rank)
)))
mem <- merge(mem, coins[!duplicated(coins$id), c("id", "status", "first_historical_data", "last_historical_data")],
             by = "id", all.x = TRUE)
cat("union size (distinct CMC ids):", nrow(mem), "\n")
print(table(status = mem$status, useNA = "ifany"))
dup_sym <- mem$symbol[duplicated(mem$symbol)]
cat("symbols shared by more than one id in the union:", length(unique(dup_sym)), "\n")
print(mem[mem$symbol %in% dup_sym, c("id", "symbol", "slug", "name", "status", "first_top100", "last_top100")])
dup_all <- sum(duplicated(coins$symbol) | duplicated(coins$symbol, fromLast = TRUE))
cat("rows in crypto_list sharing a symbol with another id (whole universe):", dup_all, "of", nrow(coins), "\n")
cat("union coins not in crypto_list at all:", sum(is.na(mem$status)), "\n")

# ---------------------------------------------------------------------------
section("5. crypto_history for every union coin over the window (batches of 20)")
mem <- mem[order(mem$id), ]
batches <- split(mem, ceiling(seq_len(nrow(mem)) / 20))
hist <- do.call(rbind, lapply(seq_along(batches), function(k) {
  b <- batches[[k]]
  x <- fetch(sprintf("history_%s_%s_b%02d_%d", format(WIN_START, "%Y%m%d"), format(WIN_END, "%Y%m%d"), k, b$id[1]),
             function() crypto_history(coin_list = b[, c("id", "slug", "name", "symbol")],
                                       start_date = format(WIN_START, "%Y%m%d"), end_date = format(WIN_END, "%Y%m%d"),
                                       sleep = 1, finalWait = FALSE))
  as.data.frame(x)
}))
tm <- do.call(rbind, timings)
hist_tm <- tm[grepl("^history_", tm$fetch), ]
cat("history batches:", nrow(hist_tm), " total download seconds (as recorded at fetch):", sum(hist_tm$elapsed_s),
    " retry messages:", sum(hist_tm$n_retry_messages), " warnings:", sum(hist_tm$n_warnings), "\n")
cat("history columns:", paste(names(hist), collapse = ", "), "\n")
cat("timestamp class:", paste(class(hist$timestamp), collapse = "/"), " tz attr:", attr(as.POSIXct(hist$timestamp), "tzone"), "\n")
hist$timestamp <- as.POSIXct(hist$timestamp)
for (tc in c("time_open", "time_close", "time_high", "time_low")) hist[[tc]] <- as.POSIXct(hist[[tc]])
hist$date <- as.Date(hist$timestamp, tz = "UTC")
hist <- hist[hist$date >= WIN_START & hist$date <= WIN_END, ]
got <- unique(hist$id)
cat("coins requested:", nrow(mem), " coins with >= 1 bar:", length(got), " coins with no bars:",
    paste(setdiff(mem$id, got), collapse = ", "), "\n")
cat("bar rows:", nrow(hist), " duplicate (id, date) rows:", sum(duplicated(hist[, c("id", "date")])), "\n")
# CMC returns a fixed 400 daily points ending at timeEnd (section 6), so crypto2's
# 400-day chunks overlap; check the overlapping rows agree before dropping them.
dkey <- paste(hist$id, hist$date)
dups <- hist[dkey %in% dkey[duplicated(dkey)], c("id", "date", "open", "high", "low", "close", "volume", "market_cap")]
cat("duplicate rows fall on", paste(format(range(dups$date)), collapse = ".."),
    "; duplicate groups with differing values:", nrow(unique(dups)) - length(unique(paste(dups$id, dups$date))), "\n")
hist <- hist[!duplicated(dkey), ]
cat("bar rows after dropping exact duplicates:", nrow(hist), "\n")
miss <- mem[!mem$id %in% got, c("id", "symbol", "name", "status", "top100_days", "first_top100", "last_top100", "best_rank")]
cat("top-100 members with no price history from crypto_history:\n"); print(miss)
cat("max bar date:", format(max(hist$date)), " min bar date:", format(min(hist$date)), "\n")
hms <- function(x) format(x, "%H:%M:%S", tz = "UTC")
cat("timestamp clock times (UTC):\n"); print(table(hms(hist$timestamp)))
cat("time_open clock times (UTC):\n"); print(head(sort(table(hms(hist$time_open)), decreasing = TRUE), 5))
cat("time_close clock times (UTC):\n"); print(head(sort(table(hms(hist$time_close)), decreasing = TRUE), 5))
cat("time_open date == bar date:", mean(as.Date(hist$time_open, tz = "UTC") == hist$date),
    " time_close date == bar date:", mean(as.Date(hist$time_close, tz = "UTC") == hist$date), "\n")
cat("sub-second part of timestamp (should be 0 after crypto2 parse):",
    max(as.numeric(hist$timestamp) %% 1), "\n")
ohlc_bad <- with(hist, is.na(close) | close <= 0 | high < pmax(open, close) | low > pmin(open, close) | low <= 0)
cat("bars with NA/non-positive close or inconsistent OHLC:", sum(ohlc_bad, na.rm = TRUE),
    " (NA in any OHLC:", sum(!stats::complete.cases(hist[, c("open", "high", "low", "close")])), ")\n")
cat("bars with zero volume:", sum(hist$volume == 0, na.rm = TRUE), "\n")
if ("circulating_supply" %in% names(hist)) {
  rel <- abs(hist$close * hist$circulating_supply / hist$market_cap - 1)
  cat("market_cap == close * circulating_supply: share within 1e-6:", round(mean(rel < 1e-6, na.rm = TRUE), 4),
      " rows with market_cap 0 or NA:", sum(is.na(hist$market_cap) | hist$market_cap == 0), "\n")
}

per_coin <- do.call(rbind, lapply(split(hist, hist$id), function(d) {
  d <- d[order(d$date), ]
  span <- as.integer(max(d$date) - min(d$date)) + 1L
  data.frame(id = d$id[1], first_bar = min(d$date), last_bar = max(d$date), n_bars = nrow(d),
             gap_days = span - length(unique(d$date)), min_close = min(d$close), last_close = d$close[nrow(d)],
             max_close = max(d$close))
}))
mem <- merge(mem, per_coin, by = "id", all.x = TRUE)
cat("coins with internal gaps:", sum(mem$gap_days > 0, na.rm = TRUE), " total gap days:", sum(mem$gap_days, na.rm = TRUE), "\n")
print(mem[!is.na(mem$gap_days) & mem$gap_days > 0, c("id", "symbol", "status", "first_bar", "last_bar", "n_bars", "gap_days")])
gap_dates <- unlist(lapply(split(hist$date, hist$id), function(x) {
  format(as.Date(setdiff(seq(min(x), max(x), by = "day"), x), origin = "1970-01-01"))
}))
cat("missing bar dates across coins (date: coins):\n"); print(table(gap_dates))
cat("coins whose first bar is after the window start:", sum(mem$first_bar > WIN_START, na.rm = TRUE), "\n")
cat("first top-100 date before first bar (listed before priced):", sum(mem$first_top100 < mem$first_bar, na.rm = TRUE), "\n")
ended <- mem[!is.na(mem$last_bar) & mem$last_bar < WIN_END, ]
cat("coins whose window series ends before", format(WIN_END), ":", nrow(ended), "\n")
print(ended[, c("id", "symbol", "name", "status", "last_top100", "last_bar", "last_historical_data", "last_close", "max_close")])

# ---------------------------------------------------------------------------
section("6. Timestamp parse: crypto2 parses CMC ISO strings with no time zone")
raw_h <- fetch("raw_history_btc_20220508", function() raw_cmc(
  sprintf("cryptocurrency/historical?id=1&convertId=2781&timeStart=%s&timeEnd=%s&interval=daily",
          format(as.numeric(as.POSIXct("2022-05-07", tz = "UTC")), scientific = FALSE),
          format(as.numeric(as.POSIXct("2022-05-10", tz = "UTC")), scientific = FALSE)), v = "3.1"))
rq <- raw_h$data$quotes
cat("requested timeStart 2022-05-07, timeEnd 2022-05-10 (3 days); rows returned:", nrow(rq),
    " first timeOpen:", rq$timeOpen[1], " last timeOpen:", rq$timeOpen[nrow(rq)], "\n")
print(utils::tail(data.frame(timeOpen = rq$timeOpen, timeClose = rq$timeClose, quote_timestamp = rq$quote$timestamp,
                             close = rq$quote$close, marketCap = rq$quote$marketCap,
                             circulatingSupply = rq$quote$circulatingSupply), 3), digits = 12)
btc_list <- data.frame(id = 1L, slug = "bitcoin", name = "Bitcoin", symbol = "BTC")
tz_demo <- fetch("tz_demo_btc_host_tz", function() {
  Sys.setenv(TZ = "Europe/Vienna")
  on.exit(Sys.setenv(TZ = "UTC"))
  x <- crypto_history(coin_list = btc_list, start_date = "20220508", end_date = "20220510", sleep = 1)
  data.frame(timestamp_epoch = as.numeric(as.POSIXct(x$timestamp)), close = x$close)
})
btc_utc <- hist[hist$id == 1 & hist$date %in% as.Date(c("2022-05-08", "2022-05-09", "2022-05-10")), c("timestamp", "close")]
cat("same bars fetched under TZ=Europe/Vienna, as UTC instants:\n")
print(data.frame(vienna_run = format(as.POSIXct(tz_demo$timestamp_epoch, origin = "1970-01-01", tz = "UTC"), tz = "UTC"),
                 close = tz_demo$close))
cat("under TZ=UTC:\n"); print(data.frame(utc_run = format(btc_utc$timestamp, tz = "UTC"), close = btc_utc$close))

# ---------------------------------------------------------------------------
section("7. Dead coins: terminal series of union coins that CMC lists as inactive or untracked")
# The CMC map gives inactive coins no dates (section 1b) and none of them stops
# inside the window, so the death date has to come from the price series:
# fetch each one from the window end to a fixed probe date, plus crypto_info().
PROBE_END <- as.Date("2026-10-23")
dead <- mem[!is.na(mem$status) & mem$status != "active", ]
cat("union coins not active today:", nrow(dead), "\n")
term_rows <- list()
for (i in seq_len(nrow(dead))) {
  d <- dead[i, ]
  x <- fetch(sprintf("terminal_%d_%s", d$id, format(PROBE_END, "%Y%m%d")), function() crypto_history(
    coin_list = d[, c("id", "slug", "name", "symbol")], start_date = format(WIN_END + 1L, "%Y%m%d"),
    end_date = format(PROBE_END, "%Y%m%d"), sleep = 1))
  inf <- fetch(sprintf("info_%d", d$id), function() crypto_info(coin_list = d[, c("id", "slug", "name", "symbol")], sleep = 1))
  inf <- as.data.frame(inf)
  x <- as.data.frame(x)
  row <- data.frame(id = d$id, symbol = d$symbol, name = d$name, best_rank = d$best_rank,
                    info_status = if (nrow(inf) && "status" %in% names(inf)) inf$status[1] else NA,
                    info_date_added = if (nrow(inf) && "date_added" %in% names(inf)) inf$date_added[1] else as.Date(NA),
                    info_notice = if (nrow(inf) && "notice" %in% names(inf)) substr(gsub("\\s+", " ", inf$notice[1]), 1, 160) else NA)
  if (!nrow(x)) {
    term_rows[[length(term_rows) + 1L]] <- cbind(row, post_window_rows = 0L, last_bar = as.Date(NA), last_close = NA,
      max_close_post = NA, ratio_last_to_max = NA, flat_tail_days = NA, zero_vol_tail_days = NA, gap_days = NA)
    next
  }
  x$date <- as.Date(as.POSIXct(x$timestamp), tz = "UTC")
  x <- x[order(x$date), ]
  x <- x[!duplicated(x$date), ]
  n <- nrow(x)
  flat <- 0L
  while (flat < n - 1L && x$close[n - flat] == x$close[n - flat - 1L]) flat <- flat + 1L
  zv <- 0L
  while (zv < n && isTRUE(x$volume[n - zv] == 0)) zv <- zv + 1L
  term_rows[[length(term_rows) + 1L]] <- cbind(row, post_window_rows = n, last_bar = max(x$date),
    last_close = x$close[n], max_close_post = max(x$close), ratio_last_to_max = x$close[n] / max(x$close),
    flat_tail_days = flat, zero_vol_tail_days = zv, gap_days = as.integer(max(x$date) - min(x$date)) + 1L - n)
  cat(sprintf("\n-- id %d %s: last 6 post-window bars\n", d$id, d$symbol))
  print(utils::tail(x[, c("date", "open", "high", "low", "close", "volume", "market_cap")], 6), digits = 8)
}
term <- if (length(term_rows)) do.call(rbind, term_rows) else data.frame()
print(term)
write_ev(term, "dead_coin_terminal")

section("7b. Window collapses: LUNA (4172), UST (7129), FTT (4195), new LUNA (20314)")
for (cid in c(4172L, 7129L, 4195L, 20314L)) {
  d <- hist[hist$id == cid, ]
  if (!nrow(d)) { cat("id", cid, ": no bars in window\n"); next }
  d <- d[order(d$date), ]
  m <- mem[mem$id == cid, ]
  cat(sprintf("id %d %s (%s, status %s): bars %s..%s, max close %.6g, min close %.6g on %s, last close %.6g, top-100 %s..%s\n",
              cid, d$symbol[1], d$name[1], m$status, min(d$date), max(d$date), max(d$close), min(d$close),
              d$date[which.min(d$close)], d$close[nrow(d)], m$first_top100, m$last_top100))
}

# ---------------------------------------------------------------------------
section("8. crypto_global_quotes(which = 'historical') over the window")
gq <- fetch("global_quotes_2022_2023", function() crypto_global_quotes(
  which = "historical", quote = TRUE, start_date = "20220101", end_date = "20231231", interval = "daily"))
gq <- as.data.frame(gq)
cat("rows:", nrow(gq), " columns:", paste(names(gq), collapse = ", "), "\n")
if (nrow(gq)) {
  gq$timestamp <- as.Date(gq$timestamp)
  cat("dates:", format(min(gq$timestamp)), "..", format(max(gq$timestamp)), " distinct:", length(unique(gq$timestamp)),
      " missing calendar days:", length(setdiff(as.character(all_days), as.character(gq$timestamp))), "\n")
  mc_col <- grep("total_market_cap$", names(gq), value = TRUE)[1]
  top_cap <- tapply(listings$market_cap, listings$date, sum)
  share <- top_cap[as.character(gq$timestamp)] / gq[[mc_col]]
  cat("top-100 listing market cap / global total market cap: median", round(stats::median(share, na.rm = TRUE), 4),
      " range", paste(round(range(share, na.rm = TRUE), 4), collapse = ".."), "\n")
}

# ---------------------------------------------------------------------------
section("9. Lookahead: what instant does a listing snapshot dated D reflect?")
hx <- hist[, c("id", "date", "open", "close", "market_cap")]
lk <- listings[, c("id", "date", "rank", "price", "market_cap")]
names(lk)[4:5] <- c("l_price", "l_mcap")
cmp <- function(shift) {
  h <- hx
  h$date <- h$date + shift   # bar of day D - shift aligned to snapshot day D
  m <- merge(lk, h, by = c("id", "date"))
  data.frame(bar_day = sprintf("D%+d", -shift), n = nrow(m),
             med_rel_price_vs_close = stats::median(abs(m$l_price / m$close - 1)),
             share_price_eq_close_1e4 = mean(abs(m$l_price / m$close - 1) < 1e-4),
             med_rel_price_vs_open = stats::median(abs(m$l_price / m$open - 1)),
             med_rel_mcap = stats::median(abs(m$l_mcap / m$market_cap - 1), na.rm = TRUE))
}
la <- do.call(rbind, lapply(c(1L, 0L, -1L), cmp))
print(la)
write_ev(la, "lookahead_price_alignment")
# Membership: listing top 100 on D vs the top 100 by bar market cap on D-1 and D (union coins).
memb <- function(shift) {
  ds <- per_day$date[per_day$date - shift >= WIN_START & per_day$date - shift <= WIN_END]
  ov <- vapply(ds, function(D) {
    h <- hx[hx$date == D - shift & !is.na(hx$market_cap), ]
    top <- h$id[order(-h$market_cap)][seq_len(min(TOP_N, nrow(h)))]
    length(intersect(top, listings$id[listings$date == D])) / TOP_N
  }, numeric(1))
  data.frame(bar_day = sprintf("D%+d", -shift), days = length(ds), mean_overlap = mean(ov), min_overlap = min(ov))
}
mo <- do.call(rbind, lapply(c(1L, 0L), memb))
print(mo)
write_ev(mo, "lookahead_membership_overlap")

# ---------------------------------------------------------------------------
section("10. Download cost")
tm <- do.call(rbind, timings)
print(tm)
write_ev(tm, "fetch_timings")
grp <- sub("_(b\\d+|\\d{8}).*$", "", tm$fetch)
print(aggregate(cbind(elapsed_s, n_retry_messages, n_warnings) ~ grp, data = transform(tm, grp = grp), FUN = sum))
mem_out <- mem[, c("id", "symbol", "status", "top100_days", "first_top100", "last_top100", "best_rank",
                   "first_historical_data", "last_historical_data", "first_bar", "last_bar", "n_bars", "gap_days")]
write_ev(mem_out, "union_coins")

# ---------------------------------------------------------------------------
section("11. ledgr smoke check: three coins, 23:59:59 UTC bars, 24/7 sessions, seal")
suppressMessages(pkgload::load_all(repo, quiet = TRUE))
cat("ledgr version:", as.character(utils::packageVersion("ledgr")), "\n")
# BTC, LUNA classic (collapse to ~1e-4 USD in May 2022), Anchor (Terra-era coin, inactive on CMC today)
pick <- intersect(c(1L, 4172L, 8857L), unique(hist$id))
cat("smoke coins (CMC ids):", paste(pick, collapse = ", "), "\n")
sb <- hist[hist$id %in% pick, ]
bars <- data.frame(
  instrument_id = paste0("CMC", sb$id),
  ts_utc = as.POSIXct(paste(format(sb$date), "23:59:59"), tz = "UTC"),
  open = sb$open, high = sb$high, low = sb$low, close = sb$close, volume = sb$volume
)
bars <- bars[order(bars$instrument_id, bars$ts_utc), ]
cat("smoke bar rows:", nrow(bars), " per coin:", paste(names(table(bars$instrument_id)), table(bars$instrument_id), collapse = ", "), "\n")
sessions <- ledgr_facts_sessions(
  data.frame(session_date = all_days, status = "open", session_open = "00:00:00", session_close = "23:59:59"),
  venue_id = "CMC_AGG", knowledge = "assume_effective", timezone = "UTC")
db_path <- file.path(out_dir, "crypto2_smoke.duckdb")
if (file.exists(db_path)) unlink(db_path)
seal <- function(mode) tryCatch(
  ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = unique(bars$instrument_id)),
                         facts = ledgr_facts(sessions), price_basis = "split_adjusted", db_path = db_path,
                         snapshot_id = paste0("crypto2_smoke_", mode), invalid_observations = mode),
  error = function(e) {
    cat("seal (", mode, ") ERROR <", paste(class(e), collapse = "/"), ">: ", conditionMessage(e), "\n", sep = "")
    NULL
  })
snap <- seal("error")
if (is.null(snap)) snap <- seal("quarantine")
if (!is.null(snap)) {
  print(snap)
  info <- ledgr_snapshot_info(snap)
  cat("snapshot_hash:", info$snapshot_hash, "\n")
  ledgr_snapshot_close(snap)
}
cat("\nprobe complete; evidence in", out_dir, "\n")
sink(type = "message")
sink()
close(log_con)

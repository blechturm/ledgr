# Spot-crypto readiness, Stage 2: point-in-time top-100 survivorship probe.
#
# Question: does a point-in-time top-100 crypto universe built from crypto2
# run through ledgr end to end, and how far do the results of a long-only
# strategy differ when coins that later die are included versus excluded?
# Kill condition: ledgr cannot represent a held coin's end of life.
#
# Usage:
#   Rscript <abs path>/dev/spikes/crypto-readiness/survivorship_probe.R \
#     <out_dir> <cache_dir> <probe1_cache_dir> <lib_dir> [download|analyze|all]
# out_dir    evidence CSVs, logs and the DuckDB store (keep outside the repo)
# cache_dir  raw crypto2 downloads as RDS (keep outside the repo); a cached
#            fetch is never repeated, so reruns make no network requests
# probe1_cache_dir  the Stage 1 cache, read-only, reused where it overlaps
# lib_dir    library holding crypto2 (prepended to .libPaths())
# "download" only fetches; "analyze" refuses any network call; "all" does both.
# Loads ledgr from this checkout with pkgload and never edits package code.
# Network calls are sequential: crypto2's own retry pacing, sleep = 1 s between
# requests, and a 1 s pause between calls.

args <- commandArgs(trailingOnly = FALSE)
script <- normalizePath(sub("^--file=", "", args[grep("^--file=", args)][1]), winslash = "/")
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), winslash = "/")
trail <- commandArgs(trailingOnly = TRUE)
stopifnot(length(trail) >= 4L)
out_dir <- trail[[1L]]
cache_dir <- trail[[2L]]
probe1_dir <- trail[[3L]]
.libPaths(c(trail[[4L]], .libPaths()))
stage <- if (length(trail) >= 5L) trail[[5L]] else "all"
stopifnot(stage %in% c("download", "analyze", "all"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
setwd(repo)
Sys.setenv(TZ = "UTC")  # crypto2 parses CMC ISO times with no tz (Stage 1)
suppressMessages(library(crypto2))

log_con <- file(file.path(out_dir, paste0("survivorship_", stage, "_log.txt")), open = "wt")
sink(log_con, split = TRUE)
sink(log_con, type = "message")
options(width = 160, digits = 10, warn = 1, pillar.width = 160)
section <- function(x) cat("\n==== ", x, " ====\n", sep = "")
write_ev <- function(df, name) {
  utils::write.csv(as.data.frame(df), file.path(out_dir, paste0(name, ".csv")), row.names = FALSE)
}
cat("git HEAD:", system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE), "\n")
cat("crypto2 version:", as.character(utils::packageVersion("crypto2")), " stage:", stage, "\n")
WIN_START <- as.Date("2020-01-01")
WIN_END <- as.Date("2025-12-31")
TOP_N <- 100L
ALIVE_SLACK <- 7L  # a series ending within 7 days of the window end counts as alive

# ---------------------------------------------------------------------------
# fetch(): one cached network call (Stage 1 pattern). The probe1 cache is read
# first-hand where a name matches; nothing is ever written there.
timings <- list()
fetch <- function(name, fn, cache_errors = FALSE) {
  path <- file.path(cache_dir, paste0(name, ".rds"))
  p1 <- file.path(probe1_dir, paste0(name, ".rds"))
  if (file.exists(path) || file.exists(p1)) {
    rec <- readRDS(if (file.exists(path)) path else p1)
    src <- if (file.exists(path)) "cache" else "probe1_cache"
  } else {
    if (stage == "analyze") stop("analyze stage refuses a network call; missing cache entry: ", name)
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
    if (cache_errors || !inherits(value, "fetch_error")) saveRDS(rec, path)
    src <- "network"
    Sys.sleep(1)
  }
  timings[[length(timings) + 1L]] <<- data.frame(
    fetch = name, source = src, elapsed_s = round(rec$elapsed, 1),
    n_retry_messages = sum(grepl("(?i)retr|429|too many|rate", rec$msgs, perl = TRUE)),
    n_warnings = length(rec$warns), fetched_at = format(rec$fetched_at, tz = "UTC")
  )
  rec
}

# ---------------------------------------------------------------------------
section("1. Daily top-100 listings 2019-12-31..2025-12-31")
q_starts <- seq(WIN_START, by = "quarter", length.out = 24L)
q_ends <- c(q_starts[-1L] - 1L, WIN_END)
get_listing <- function(from, to) {
  rec <- fetch(sprintf("listings_top%d_%s", TOP_N, format(from, "%Y%m%d")), function() crypto_listings(
    which = "historical", start_date = format(from, "%Y%m%d"), end_date = format(to, "%Y%m%d"),
    interval = "day", limit = TOP_N, quote = TRUE, sleep = 1))
  as.data.frame(rec$value)[, c("date", "id", "name", "symbol", "slug", "cmc_rank", "price", "market_cap", "date_added")]
}
listings <- do.call(rbind, c(list(get_listing(WIN_START - 1L, WIN_START - 1L)),
                             lapply(seq_along(q_starts), function(k) get_listing(q_starts[k], q_ends[k]))))
listings$date <- as.Date(listings$date)
listings <- listings[listings$cmc_rank <= TOP_N & listings$date >= WIN_START - 1L & listings$date <= WIN_END, ]
snap_days <- seq(WIN_START - 1L, WIN_END - 1L, by = "day")  # snapshot D governs pulse D + 1
per_day <- data.frame(date = snap_days,
                      n = as.integer(table(factor(listings$date, levels = as.character(snap_days)))))
cat("snapshot days needed:", length(snap_days), " days with no listing:", sum(per_day$n == 0),
    " days with fewer than", TOP_N, "ranks:", sum(per_day$n > 0 & per_day$n < TOP_N),
    " min/max rows:", min(per_day$n), max(per_day$n), "\n")
lst_win <- listings[listings$date <= WIN_END - 1L, ]
mem <- do.call(rbind, lapply(split(lst_win, lst_win$id), function(d) {
  d <- d[order(d$date), ]
  data.frame(id = d$id[1], slug = d$slug[nrow(d)], name = d$name[nrow(d)], symbol = d$symbol[nrow(d)],
             top100_days = nrow(d), first_top100 = min(d$date), last_top100 = max(d$date),
             best_rank = min(d$cmc_rank), date_added = min(d$date_added))
}))
mem <- mem[order(mem$id), ]
cat("union of top-100 members (distinct CMC ids):", nrow(mem), "\n")

# ---------------------------------------------------------------------------
section("2. Daily history for every union coin (reusing Stage 1's 2022-2023 bars)")
norm_hist <- function(x) {
  x <- as.data.frame(x)
  if (!nrow(x)) return(NULL)
  ts <- as.POSIXct(x$timestamp)
  data.frame(id = as.integer(x$id), symbol = x$symbol, date = as.Date(ts, tz = "UTC"),
             clock = format(ts, "%H:%M:%S", tz = "UTC"), open = x$open, high = x$high, low = x$low,
             close = x$close, volume = x$volume, market_cap = x$market_cap)
}
p1_files <- list.files(probe1_dir, "^history_20220101_20231231_b\\d+_\\d+\\.rds$", full.names = TRUE)
p1_hist <- do.call(rbind, lapply(p1_files, function(f) norm_hist(readRDS(f)$value)))
p1_ids <- unique(p1_hist$id)
spans <- list(A = c(WIN_START, as.Date("2021-12-31")), C = c(as.Date("2024-01-01"), WIN_END),
              F = c(WIN_START, WIN_END))
fetch_hist <- function(coins, tag, batch_size = 10L) {
  if (!nrow(coins)) return(NULL)
  batches <- split(coins, ceiling(seq_len(nrow(coins)) / batch_size))
  do.call(rbind, lapply(seq_along(batches), function(k) {
    b <- batches[[k]]
    rec <- fetch(sprintf("hist_%s_b%03d_%d", tag, k, b$id[1]), function() crypto_history(
      coin_list = b[, c("id", "slug", "name", "symbol")], start_date = format(spans[[substr(tag, 1, 1)]][1], "%Y%m%d"),
      end_date = format(spans[[substr(tag, 1, 1)]][2], "%Y%m%d"), sleep = 1, finalWait = FALSE))
    norm_hist(rec$value)
  }))
}
old <- mem[mem$id %in% p1_ids, ]
new <- mem[!mem$id %in% p1_ids, ]
cat("coins with Stage 1 bars for 2022-2023:", nrow(old), " coins fetched over the whole window:", nrow(new), "\n")
hist <- rbind(p1_hist[p1_hist$id %in% mem$id, ], fetch_hist(old, "A"), fetch_hist(old, "C"), fetch_hist(new, "F"))
coverage <- function(h) {
  do.call(rbind, lapply(split(h, h$id), function(d) {
    dd <- sort(unique(d$date))
    data.frame(id = d$id[1], first_bar = min(dd), last_bar = max(dd), n_bars = length(dd),
               max_gap = if (length(dd) > 1L) max(as.integer(diff(dd))) - 1L else 0L)
  }))
}
hist <- hist[hist$date >= WIN_START & hist$date <= WIN_END, ]
cov0 <- merge(mem[, c("id", "date_added", "first_top100")], coverage(hist), by = "id", all.x = TRUE)
# A failed crypto2 chunk is swallowed (purrr::possibly) and leaves a hole of up
# to 400 days; refetch suspicious coins one at a time over the whole window.
suspect <- cov0$id[is.na(cov0$first_bar) | cov0$max_gap > 30L |
                     cov0$first_bar > pmax(cov0$date_added, WIN_START) + 1L]
cat("coins with suspicious coverage (no bars, gap > 30 days, or first bar after max(date_added, window start)):",
    length(suspect), "\n")
retry <- do.call(rbind, lapply(suspect, function(cid) {
  rec <- fetch(sprintf("hist_R_%d", cid), function() crypto_history(
    coin_list = mem[mem$id == cid, c("id", "slug", "name", "symbol")], start_date = format(WIN_START, "%Y%m%d"),
    end_date = format(WIN_END, "%Y%m%d"), sleep = 1, finalWait = FALSE))
  norm_hist(rec$value)
}))
if (!is.null(retry)) hist <- rbind(hist, retry[retry$date >= WIN_START & retry$date <= WIN_END, ])
key <- paste(hist$id, hist$date)
dups <- hist[key %in% key[duplicated(key)], ]
dkey <- paste(dups$id, dups$date)
n_diff <- nrow(unique(dups[, c("id", "date", "open", "high", "low", "close", "volume")])) - length(unique(dkey))
cat("bar rows before dedup:", nrow(hist), " duplicate (id, date) rows:", sum(duplicated(key)),
    " duplicate groups whose OHLCV differ:", n_diff, "\n")
hist <- hist[order(hist$id, hist$date, -hist$volume), ]
hist <- hist[!duplicated(paste(hist$id, hist$date)), ]
cat("bar rows after dedup:", nrow(hist), " clock times:", paste(names(table(hist$clock)), table(hist$clock), collapse = ", "), "\n")
cov <- merge(mem, coverage(hist), by = "id", all.x = TRUE)
cat("coins with no bars at all:", sum(is.na(cov$first_bar)), " still suspicious after retry:",
    sum(cov$id %in% suspect & (is.na(cov$first_bar) | cov$max_gap > 30L)), "\n")

# ---------------------------------------------------------------------------
section("3. crypto_info for coins whose series ends inside the window, or that have no bars")
ended <- cov[is.na(cov$last_bar) | cov$last_bar < WIN_END - ALIVE_SLACK, ]
info <- do.call(rbind, lapply(seq_len(nrow(ended)), function(i) {
  d <- ended[i, ]
  v <- fetch(sprintf("info_%d", d$id), function() crypto_info(
    coin_list = d[, c("id", "slug", "name", "symbol")], sleep = 1), cache_errors = TRUE)$value
  x <- if (inherits(v, "fetch_error")) data.frame() else as.data.frame(v)
  data.frame(id = d$id, info_status = if (nrow(x) && "status" %in% names(x)) x$status[1] else NA_character_,
             info_notice = if (nrow(x) && "notice" %in% names(x)) gsub("\\s+", " ", x$notice[1]) else NA_character_)
}))
cat("coins ending inside the window or without bars:", nrow(ended), "\n")
if (!is.null(info)) print(table(status = info$info_status, useNA = "ifany"))

tm <- do.call(rbind, timings)
write_ev(tm, "fetch_timings")
grp <- sub("_(b\\d+|\\d+).*$", "", tm$fetch)
cat("\nfetch cost by group (seconds as recorded at fetch time):\n")
print(aggregate(cbind(elapsed_s, n_retry_messages, n_warnings) ~ grp + source, data = transform(tm, grp = grp), FUN = sum))
cat("network fetches this process:", sum(tm$source == "network"), "\n")
cat("first/last fetch time (UTC):", paste(range(tm$fetched_at[tm$source != "probe1_cache"]), collapse = " .. "), "\n")
saveRDS(list(listings = listings, mem = mem, hist = hist, cov = cov, info = info, per_day = per_day),
        file.path(out_dir, "assembled.rds"))
if (stage == "download") {
  cat("\ndownload stage complete\n")
  sink(type = "message"); sink(); close(log_con)
  quit(save = "no")
}
# ---------------------------------------------------------------------------
section("4. Adapter: bars, price units, ranks without bars, end-of-life labels")
suppressMessages(pkgload::load_all(repo, quiet = TRUE))
cat("ledgr version:", as.character(utils::packageVersion("ledgr")), "\n")
hist <- hist[order(hist$id, hist$date), ]
bad <- with(hist, !(is.finite(open) & is.finite(high) & is.finite(low) & is.finite(close) &
                      pmin(open, high, low, close) > 0 & high >= pmax(open, close) & low <= pmin(open, close)))
cat("bar rows:", nrow(hist), " coins:", length(unique(hist$id)), " rows failing OHLC checks:", sum(bad),
    " zero-volume rows:", sum(hist$volume == 0, na.rm = TRUE), "\n")
# ledgr rounds every stored price to 8 decimals (contracts.md, Bar Validation).
# Measure what that does to raw crypto2 prices, then quote each coin whose
# smallest low is under 0.01 USD in units of 10^k tokens so that every stored
# price keeps at least 6 significant digits (provisional adapter duty).
rel_err <- abs(round(hist$close, 8) / hist$close - 1)
min_low <- tapply(hist$low, hist$id, min)
scale_k <- pmax(0L, ceiling(log10(1e-2 / min_low)))
units <- data.frame(id = as.integer(names(min_low)), min_low = as.numeric(min_low), unit_tokens = 10^as.numeric(scale_k))
cat("raw prices under 8-decimal rounding: closes rounding to <= 0:", sum(round(hist$close, 8) <= 0),
    " closes with relative rounding error > 1e-4:", sum(rel_err > 1e-4, na.rm = TRUE),
    " coins affected:", length(unique(hist$id[rel_err > 1e-4])), " max relative error:", signif(max(rel_err, na.rm = TRUE), 3), "\n")
cat("coins re-quoted in units of 10^k tokens:", sum(units$unit_tokens > 1), " (k range",
    paste(range(scale_k[scale_k > 0]), collapse = ".."), ")\n")
sc <- units$unit_tokens[match(hist$id, units$id)]
bars <- data.frame(
  instrument_id = paste0("CMC", hist$id),
  ts_utc = as.POSIXct(paste(format(hist$date), "23:59:59"), tz = "UTC"),
  open = hist$open * sc, high = hist$high * sc, low = hist$low * sc, close = hist$close * sc,
  volume = hist$volume / sc
)
priced_ids <- sort(unique(hist$id))
snap_days <- seq(WIN_START - 1L, WIN_END - 1L, by = "day")
lst_m <- listings[listings$date %in% snap_days, ]
nobar <- lst_m[!lst_m$id %in% priced_ids, ]
cat("ranked coin-days whose coin has no bars at all (dropped from membership):", nrow(nobar),
    " coins:", length(unique(nobar$id)), "(", paste(unique(nobar$symbol), collapse = ", "), ")\n")
lst_m <- lst_m[lst_m$id %in% priced_ids, ]
bar_key <- paste(hist$id, hist$date)
unpriced_member_pulses <- sum(!paste(lst_m$id, lst_m$date + 1L) %in% bar_key)
cat("member-pulses (snapshot D, pulse D+1) with no bar on the pulse (kept as members, missing observation):",
    unpriced_member_pulses, "of", nrow(lst_m), "\n")
per_snap <- table(factor(as.character(lst_m$date), levels = as.character(snap_days)))
cat("snapshot days with no listing (previous complete set persists):", sum(per_snap == 0),
    " with fewer than", TOP_N, "priced members:", sum(per_snap > 0 & per_snap < TOP_N), "\n")

cov$alive_at_end <- !is.na(cov$last_bar) & cov$last_bar >= WIN_END - ALIVE_SLACK
ended <- merge(cov[!is.na(cov$last_bar) & !cov$alive_at_end, ], info, by = "id", all.x = TRUE)
ended$terminal_event <- ifelse(grepl("(?i)migrat|swap|rebrand|renam|convert|redenominat|upgrad|updated to", ended$info_notice, perl = TRUE),
                               "migrated", "abandoned")
last_close <- tapply(hist$close, hist$id, function(x) x[length(x)])
max_close <- tapply(hist$close, hist$id, max)
ended$last_close_to_max <- as.numeric(last_close[as.character(ended$id)] / max_close[as.character(ended$id)])
tail_flat <- vapply(ended$id, function(cid) {
  x <- hist$close[hist$id == cid]
  n <- length(x); k <- 0L
  while (k < n - 1L && x[n - k] == x[n - k - 1L]) k <- k + 1L
  k
}, integer(1))
ended$flat_tail_days <- tail_flat
cat("coins alive at the window end:", sum(cov$alive_at_end), " coins whose series ends inside the window:", nrow(ended), "\n")
print(table(terminal_event = ended$terminal_event, crypto_info_status = ended$info_status, useNA = "ifany"))
write_ev(ended[order(ended$last_bar), c("id", "symbol", "best_rank", "top100_days", "last_top100", "first_bar", "last_bar",
                                        "info_status", "terminal_event", "last_close_to_max", "flat_tail_days")], "ended_coins")
write_ev(data.frame(
  coins_in_union = nrow(cov), coins_with_bars = length(priced_ids), coins_without_bars = sum(is.na(cov$first_bar)),
  coins_alive_at_end = sum(cov$alive_at_end), coins_ended_in_window = nrow(ended),
  ended_abandoned = sum(ended$terminal_event == "abandoned"), ended_migrated = sum(ended$terminal_event == "migrated"),
  bar_rows = nrow(bars), coins_requoted = sum(units$unit_tokens > 1),
  ranked_days_without_bars = nrow(nobar), member_pulses_without_bar = unpriced_member_pulses
), "universe_counts")

# ---------------------------------------------------------------------------
section("5. Facts: 24/7 sessions, lagged membership snapshots, lifetime")
all_days <- seq(WIN_START, WIN_END, by = "day")
sessions <- ledgr_facts_sessions(
  data.frame(session_date = all_days, status = "open", session_open = "00:00:00", session_close = "23:59:59",
             knowledge_time = as.POSIXct(format(WIN_START - 1L), tz = "UTC")),
  venue_id = "CMC_AGG", knowledge = "evidenced", timezone = "UTC")
# Snapshot dated D decides membership from pulse D + 1: effective_from and
# knowledge_time are both the civil date D + 1, which resolve to its session
# open (00:00:00 UTC), one second after the D close that the listing reflects.
membership_for <- function(l, universe_id) {
  sp <- split(paste0("CMC", l$id), factor(as.character(l$date), levels = as.character(snap_days)))
  keep <- lengths(sp) > 0L
  df <- data.frame(effective_from = snap_days[keep] + 1L, knowledge_time = snap_days[keep] + 1L,
                   source = "crypto2_cmc_historical_listing")
  df$members <- I(unname(sp[keep]))
  ledgr_facts_membership_snapshots(df, universe_id = universe_id, complete = TRUE, knowledge = "evidenced")
}
alive_ids <- cov$id[cov$alive_at_end]
mem_pit <- membership_for(lst_m, "cmc_top100")
mem_surv <- membership_for(lst_m[lst_m$id %in% alive_ids, ], "cmc_top100_survivors")
fb <- cov[!is.na(cov$first_bar), ]
life <- data.frame(instrument_id = paste0("CMC", fb$id), effective_from = fb$first_bar,
                   effective_to = as.Date(ifelse(fb$alive_at_end, NA, fb$last_bar + 1L), origin = "1970-01-01"),
                   assertion = "known_active", terminal_event = NA_character_, source = "crypto2_bars")
if (nrow(ended)) {
  life <- rbind(life, data.frame(instrument_id = paste0("CMC", ended$id), effective_from = ended$last_bar + 1L,
                                 effective_to = as.Date(NA), assertion = "known_inactive",
                                 terminal_event = ended$terminal_event, source = "crypto2_bars_and_crypto_info"))
}
lifetime <- ledgr_facts_lifetime(life, knowledge = "assume_effective")
cat("membership universes: cmc_top100 (", nrow(lst_m), "member rows ), cmc_top100_survivors (",
    sum(lst_m$id %in% alive_ids), "member rows ); lifetime rows:", nrow(life), "\n")

db_path <- file.path(out_dir, "survivorship.duckdb")
if (file.exists(db_path)) unlink(db_path)
instruments <- data.frame(instrument_id = paste0("CMC", priced_ids))
seal <- function(facts, snapshot_id) {
  mode <- if (any(bad)) "quarantine" else "error"
  t0 <- Sys.time()
  s <- ledgr_snapshot_from_df(bars, instruments_df = instruments, facts = facts, price_basis = "split_adjusted",
                              db_path = db_path, snapshot_id = snapshot_id, invalid_observations = mode)
  info <- ledgr_snapshot_info(s)
  cat(snapshot_id, ": sealed in", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s, mode", mode,
      ", hash", substr(info$snapshot_hash, 1, 12), ", quarantined", nrow(ledgr_snapshot_quarantine(s)), "\n")
  s
}
snap <- seal(ledgr_facts(sessions, mem_pit, mem_surv, lifetime), "crypto_top100")
snap_nolife <- seal(ledgr_facts(sessions, mem_pit), "crypto_top100_no_lifetime")
# Lag check: the first coin entering the top 100 after the window start is a
# member at the close of the day after its first ranked snapshot, not before.
ld <- sort(unique(lst_m$date))
entry <- NULL
for (k in seq_along(ld)[-1L]) {
  new_ids <- setdiff(lst_m$id[lst_m$date == ld[k]], lst_m$id[lst_m$date == ld[k - 1L]])
  if (length(new_ids)) { entry <- list(id = paste0("CMC", new_ids[1]), D = ld[k]); break }
}
for (at in list(entry$D, entry$D + 1L)) {
  r <- ledgr_facts_resolve(snap, family = "membership", scope_id = "cmc_top100",
                           at = as.POSIXct(paste(format(at), "23:59:59"), tz = "UTC"), instruments = entry$id)$rows
  cat("lag check:", entry$id, "first ranked in snapshot", format(entry$D), "; at the", format(at), "close: member =",
      r$member, " reason =", r$reason, "\n")
}

# ---------------------------------------------------------------------------
section("6. Strategies")
# Equal weight over the current members, rebalanced on each month's first
# session, sized fractionally (ledgr_target_rebalance() floors to whole units).
# Holdings it does not size (held nonmembers, restricted or unpriced) are
# reserved at their risk marks, as the helper does; members leaving the
# universe are sold.
equal_weight <- function(ctx, params) {
  fraction <- params$fraction %||% 0.95
  axis <- ctx |> ledgr_history_frame(bar = "close", lookback = 2L, instruments = character())
  months <- format(axis$ts_utc, "%Y-%m", tz = "UTC")
  if (length(months) == 2L && months[[1L]] == months[[2L]]) return(ctx$hold())
  ids <- ctx$universe
  position <- stats::setNames(as.numeric(ctx$vec$position), ids)
  close <- as.numeric(ctx$vec$close)
  eligible <- as.logical(ctx$vec$admissible)
  priced <- eligible & is.finite(close) & close > 0
  reserved <- position != 0 & !priced
  marks <- as.numeric(ctx$vec$risk_mark)[reserved]
  if (any(!is.finite(marks))) return(ctx$hold())
  allocatable <- max(0, ctx$equity - sum(abs(position[reserved] * marks)))
  target <- position
  if (any(priced)) target[priced] <- fraction * allocatable / sum(priced) / close[priced]
  target[position != 0 & !as.logical(ctx$vec$member)] <- 0
  target
}

# The WS48 article strategy (vignettes/minimum-variance.qmd at c6374bb2),
# copied verbatim except step 6, where ledgr_target_rebalance() is replaced by
# the same arithmetic without its whole-unit floor.
min_variance <- function(ctx, params) {
  lookback <- params$lookback %||% 252L
  threshold <- params$threshold %||% 0.2
  shrink <- params$shrink %||% 0.5
  min_obs <- params$min_obs %||% 60L
  eig_floor <- params$eig_floor %||% 1e-6
  keep_excluded <- params$keep_excluded %||% TRUE
  hold <- function(outcome) structure(ctx$hold(), outcome = outcome)

  axis <- ctx |>
    ledgr_history_frame(bar = "close", lookback = 2L, instruments = character())
  months <- format(axis$ts_utc, "%Y-%m", tz = "UTC")
  if (length(months) == 2L && months[[1L]] == months[[2L]]) {
    return(hold("not_a_decision_date"))
  }

  closes <- ctx |> ledgr_history_frame(bar = "close", lookback = lookback)
  if (!ledgr_history_sufficient(closes)) {
    return(hold("insufficient_history"))
  }
  selection <- ledgr_history_info(closes)$selection
  selection <- selection[selection$requested, , drop = FALSE]
  candidates <- selection$instrument_id[selection$carried_input_share <= threshold]

  returns <- ctx |>
    ledgr_history_frame(feature = "return_1", lookback = lookback,
                        instruments = candidates, na_action = "keep")
  valid <- colSums(is.finite(ledgr_history_matrix(returns)))
  estimated <- ledgr_history_info(returns)$included_ids[valid >= min_obs]
  if (length(estimated) < 2L) {
    return(hold("too_few_instruments"))
  }
  returns <- ctx |>
    ledgr_history_frame(feature = "return_1", lookback = lookback,
                        instruments = estimated, na_action = "keep")

  sigma <- stats::cov(ledgr_history_matrix(returns), use = "pairwise.complete.obs")
  sigma <- (1 - shrink) * sigma + shrink * diag(diag(sigma))
  if (anyNA(sigma)) {
    return(hold("covariance_not_positive_definite"))
  }
  values <- eigen(sigma, symmetric = TRUE, only.values = TRUE)$values
  largest <- max(values)
  if (!(largest > 0)) {
    return(hold("covariance_not_positive_definite"))
  }
  if (min(values) < eig_floor * largest) {
    decomposition <- eigen(sigma, symmetric = TRUE)
    floored <- decomposition$values
    floored[floored < eig_floor * largest] <- eig_floor * largest
    sigma <- decomposition$vectors %*% (floored * t(decomposition$vectors))
    sigma <- (sigma + t(sigma)) / 2
  }

  n <- ncol(sigma)
  solution <- tryCatch(
    quadprog::solve.QP(Dmat = sigma, dvec = rep(0, n),
                       Amat = cbind(rep(1, n), diag(n)),
                       bvec = c(1, rep(0, n)), meq = 1L)$solution,
    error = function(e) NULL
  )
  if (is.null(solution) || any(!is.finite(solution)) ||
      any(solution < -1e-8) || abs(sum(solution) - 1) > 1e-8) {
    return(hold("solver_failure"))
  }
  solution[solution < 0] <- 0
  solution <- solution / sum(solution)

  # 6. Keep every holding the estimate left out, and target the rest.
  #    CRYPTO CHANGE: ledgr_target_rebalance(ctx, equity_fraction = 0.95,
  #    keep = held_excluded) floors to whole units; the lines below are its
  #    availability-aware arithmetic without the floor.
  held <- ctx$universe[ctx$vec$position != 0]
  held_excluded <- if (isTRUE(keep_excluded)) setdiff(held, estimated) else character()
  weights <- ledgr_align_weights(solution, returns)
  ids <- ctx$universe
  position <- stats::setNames(as.numeric(ctx$vec$position), ids)
  eligible <- as.logical(ctx$vec$admissible)
  stopifnot(all(names(weights) %in% ids[eligible]))
  target <- position
  target[eligible] <- 0
  target[held_excluded] <- position[held_excluded]
  reserved <- union(ids[position != 0 & !eligible], held_excluded[position[held_excluded] != 0])
  marks <- as.numeric(ctx$vec$risk_mark)[match(reserved, ids)]
  if (any(!is.finite(marks))) {
    return(hold("no_permissible_mark"))
  }
  allocatable <- max(0, ctx$equity - sum(abs(position[reserved] * marks)))
  w <- as.numeric(weights)
  w_ids <- names(weights)[w > 0]
  w <- w[w > 0]
  price <- as.numeric(ctx$vec$close)[match(w_ids, ids)]
  ok <- is.finite(price) & price > 0
  sized <- w[ok] * 0.95 * allocatable
  skip_idx <- match(w_ids[!ok], ids)
  target[w_ids[!ok]] <- position[skip_idx]
  held_skip <- skip_idx[position[skip_idx] != 0]
  skip_marks <- as.numeric(ctx$vec$risk_mark)[held_skip]
  if (any(!is.finite(skip_marks))) {
    return(hold("no_permissible_mark"))
  }
  exposure <- sum(abs(position[held_skip] * skip_marks))
  if (sum(sized) > 0 && sum(sized) + exposure > allocatable) {
    sized <- sized * max(0, allocatable - exposure) / sum(sized)
  }
  #    CRYPTO CHANGE 2: the floor also zeroed the solver's near-zero weights;
  #    without it they become dust targets, so drop targets under min_notional.
  qty <- sized / price[ok]
  qty[sized < (params$min_notional %||% 1)] <- 0
  target[w_ids[ok]] <- qty

  leavers <- ctx$universe[ctx$vec$position != 0 & !ctx$vec$member]
  target[leavers] <- 0
  structure(target, outcome = "solved")
}
for (s in list(equal_weight, min_variance)) {
  pf <- ledgr_strategy_preflight(s)
  cat("preflight tier:", pf$tier, "\n")
}

# ---------------------------------------------------------------------------
section("7. Runs: point in time vs survivors only")
exp_for <- function(snapshot, strategy, universe_id, features = list()) {
  ledgr_experiment(snapshot, strategy, features = features, universe = ledgr_universe_members(universe_id),
                   cost_model = ledgr_cost_notional_bps_fee(10), opening = ledgr_opening(cash = 1e6),
                   metric_context = ledgr_metric_crypto())
}
plan <- ledgr_experiment_plan(exp_for(snap, equal_weight, "cmc_top100"))
print(plan)
runs <- list(
  ew_pit = list(snap, equal_weight, "cmc_top100", list()),
  ew_surv = list(snap, equal_weight, "cmc_top100_survivors", list()),
  mv_pit = list(snap, min_variance, "cmc_top100", list(ledgr_ind_returns(1L))),
  mv_surv = list(snap, min_variance, "cmc_top100_survivors", list(ledgr_ind_returns(1L))),
  ew_pit_no_lifetime = list(snap_nolife, equal_weight, "cmc_top100", list()),
  mv_pit_no_dust_rule = list(snap, min_variance, "cmc_top100", list(ledgr_ind_returns(1L)), list(min_notional = 0))
)
ended_ids <- paste0("CMC", ended$id)
sym <- stats::setNames(cov$symbol, paste0("CMC", cov$id))
# Dollar-pegged coins, from prices only: 90% of closes within 3% of 1 USD.
pegged <- paste0("CMC", names(which(tapply(abs(hist$close - 1) < 0.03, hist$id, mean) >= 0.9)))
cat("dollar-pegged coins by price behaviour:", length(pegged), "(", paste(sort(unname(sym[pegged])), collapse = ", "), ")\n")
rows <- list()
terminal_rows <- list()
run_times <- list()
for (rid in names(runs)) {
  r <- runs[[rid]]
  t0 <- Sys.time()
  bt <- tryCatch(ledgr_run(exp_for(r[[1]], r[[2]], r[[3]], r[[4]]), params = if (length(r) > 4L) r[[5]] else list(), run_id = rid),
                 error = function(e) {
                   cat(rid, ": ERROR <", paste(class(e), collapse = "/"), ">: ", conditionMessage(e), "\n", sep = "")
                   rows[[rid]] <<- data.frame(run = rid, status = "ERROR", stop_reason = class(e)[1])
                   NULL
                 })
  run_times[[rid]] <- data.frame(run = rid, seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  if (is.null(bt)) next
  cat("\n---", rid, "---\n")
  print(bt)
  comp <- ledgr_run_completion(bt)
  m <- ledgr_compute_metrics(bt)
  val <- ledgr_valuation_summary(bt)
  fills <- as.data.frame(ledgr_results(bt, "fills"))
  eq <- as.data.frame(ledgr_results(bt, "equity"))
  av <- as.data.frame(ledgr_results(bt, "availability"))
  term <- as.data.frame(ledgr_corporate_action_summary(bt)$terminal_outcomes)
  years <- as.numeric(difftime(max(eq$ts_utc), min(eq$ts_utc), units = "days")) / 365
  trade <- fills[fills$side %in% c("BUY", "SELL"), ]
  held_av <- av[av$held, ]
  held_counts <- tapply(av$held, format(av$ts_utc), sum)
  frozen_ids <- unique(held_av$instrument_id[held_av$mark_source == "frozen_close"])
  held_dead <- intersect(unique(held_av$instrument_id), ended_ids)
  # held on the session of its last bar, i.e. held when its series ended
  at_death <- unique(held_av$instrument_id[paste(held_av$instrument_id, format(as.Date(held_av$ts_utc))) %in%
                                             paste0("CMC", ended$id, " ", format(ended$last_bar))])
  death_label <- ended$terminal_event[match(at_death, paste0("CMC", ended$id))]
  rows[[rid]] <- data.frame(
    run = rid, status = comp$completion_status, stop_reason = comp$stop_reason %||% NA_character_,
    total_return = m$total_return, cagr = m$annualized_return, volatility = m$volatility, sharpe = m$sharpe_ratio,
    max_drawdown = m$max_drawdown, turnover_per_year = sum(abs(trade$qty * trade$price)) / mean(eq$equity) / years,
    mean_holdings = mean(as.numeric(held_counts)), max_holdings = max(as.numeric(held_counts)),
    pegged_share_of_held = mean(held_av$instrument_id %in% pegged),
    ended_coins_ever_held = length(held_dead), held_at_death = length(at_death),
    held_at_death_abandoned = sum(death_label == "abandoned"), held_at_death_migrated = sum(death_label == "migrated"),
    terminal_dispositions = nrow(term),
    frozen_coins_held = length(frozen_ids), frozen_at_end_value = val$frozen_at_end_value %||% NA_real_,
    total_return_if_frozen_worthless = val$total_return_if_frozen_worthless %||% NA_real_
  )
  if (nrow(term)) terminal_rows[[rid]] <- cbind(run = rid, symbol = unname(sym[term$instrument_id]), term)
  close(bt)
}
cols <- unique(unlist(lapply(rows, names)))
res <- do.call(rbind, lapply(rows, function(x) { x[setdiff(cols, names(x))] <- NA; x[cols] }))
print(res)
write_ev(res, "run_comparison")
if (length(terminal_rows)) {
  tt <- do.call(rbind, lapply(terminal_rows, function(x) x[, intersect(c("run", "instrument_id", "symbol", "terminal_event", "choice",
                                                                         "assumption_label", "ts_utc", "proceeds"), names(x))]))
  print(tt)
  write_ev(tt, "terminal_outcomes")
}
gap <- data.frame(strategy = c("equal_weight", "min_variance"))
for (f in c("total_return", "cagr", "volatility", "sharpe", "max_drawdown")) {
  v <- function(run) if (run %in% res$run) res[res$run == run, f] else NA_real_
  gap[[paste0(f, "_pit_minus_surv")]] <- c(v("ew_pit") - v("ew_surv"), v("mv_pit") - v("mv_surv"))
}
print(gap)
write_ev(gap, "survivorship_gap")
rt <- do.call(rbind, run_times)
print(rt)
utils::write.csv(rt, file.path(out_dir, "run_seconds.txt"), row.names = FALSE)  # timing, excluded from the CSV diff
ledgr_snapshot_close(snap)
ledgr_snapshot_close(snap_nolife)
cat("\nprobe complete; evidence in", out_dir, "\n")
sink(type = "message")
sink()
close(log_con)

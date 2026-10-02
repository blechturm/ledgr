# Long-window scaling reproducer: build one sealed synthetic snapshot.
# Vendor-neutral, deterministic. Generalizes the availability-closeout fixture
# (dev/spikes/availability-hot-path-representation/spike_runner.R) with
# membership churn, a wider physical axis and lifetime terminals.
#
# Rscript lw_build.R <repo> <out_dir> sessions instruments members sets churn terminals [seed]
args <- commandArgs(TRUE)
repo <- args[[1]]; out_dir <- args[[2]]
spec <- list(
  sessions = as.integer(args[[3]]), instruments = as.integer(args[[4]]),
  members = as.integer(args[[5]]), sets = as.integer(args[[6]]),
  churn = as.numeric(args[[7]]), terminals = as.integer(args[[8]]),
  seed = if (length(args) >= 9) as.integer(args[[9]]) else 1L
)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
set.seed(spec$seed)
t0 <- proc.time()[["elapsed"]]

ids <- sprintf("I%04d", seq_len(spec$instruments))
first <- as.Date("1998-01-05")
civil <- seq(first, by = "day", length.out = as.integer(ceiling(spec$sessions * 7 / 5)) + 7L)
open <- as.POSIXlt(civil)$wday %in% 1:5
civil <- civil[seq_len(which(cumsum(open) == spec$sessions)[[1L]])]
open <- as.POSIXlt(civil)$wday %in% 1:5
session_dates <- civil[open]
publish <- as.POSIXct(paste(first - 3, "00:00:00"), tz = "UTC")
sessions <- data.frame(
  session_date = civil, status = ifelse(open, "open", "closed"),
  session_open = ifelse(open, "14:30:00", NA_character_),
  session_close = ifelse(open, "21:00:00", NA_character_),
  knowledge_time = publish, source = "synthetic_calendar", stringsAsFactors = FALSE
)

S <- spec$sessions; W <- spec$instruments
ret <- matrix(rnorm(S * W, mean = 0.0003, sd = 0.02), nrow = S)
close <- 100 * exp(apply(ret, 2, cumsum))
keep <- matrix(TRUE, nrow = S, ncol = W)

# Membership: `sets` complete snapshots; each replaces round(churn * members)
# members with instruments from the non-member pool.
pool_n <- W - spec$members
stopifnot(pool_n >= 0)
n_swap <- as.integer(round(spec$churn * spec$members))
current <- seq_len(spec$members)
set_idx <- 1L + (seq_len(spec$sets) - 1L) * (S %/% spec$sets)
member_rows <- vector("list", spec$sets)
ever_member <- rep(FALSE, W)
for (k in seq_len(spec$sets)) {
  if (k > 1L && n_swap > 0L && pool_n > 0L) {
    outside <- setdiff(seq_len(W), current)
    swap_n <- min(n_swap, length(outside))
    current[sample.int(length(current), swap_n)] <- outside[sample.int(length(outside), swap_n)]
  }
  ever_member[current] <- TRUE
  at <- session_dates[set_idx[[k]]]
  member_rows[[k]] <- data.frame(
    instrument_id = ids[current],
    effective_from = as.POSIXct(paste(at, "00:00:00"), tz = "UTC"),
    knowledge_time = as.POSIXct(paste(at - 1, "00:00:00"), tz = "UTC"),
    source = "synthetic_membership", stringsAsFactors = FALSE
  )
}
membership <- do.call(rbind, member_rows)

# Lifetime: everyone known_active from the start; `terminals` never-member
# instruments become known_inactive mid-window and their bars stop there, so
# a terminal never hits a holding and never stops the run.
window_start <- as.POSIXct(paste(session_dates[[1L]], "00:00:00"), tz = "UTC")
lifetime <- data.frame(instrument_id = ids, effective_from = window_start,
                       effective_to = as.POSIXct(NA, tz = "UTC"),
                       knowledge_time = publish, assertion = "known_active",
                       source = "synthetic_lifetime", stringsAsFactors = FALSE)
term_ids <- character()
if (spec$terminals > 0L) {
  candidates <- which(!ever_member)
  stopifnot(length(candidates) >= spec$terminals)
  term <- candidates[seq_len(spec$terminals)]
  at <- sample(seq.int(S %/% 4L, 3L * S %/% 4L), spec$terminals, replace = TRUE)
  for (j in seq_along(term)) keep[(at[[j]] + 1L):S, term[[j]]] <- FALSE
  end_at <- as.POSIXct(paste(session_dates[at + 1L], "00:00:00"), tz = "UTC")
  lifetime$effective_to[term] <- end_at
  lifetime <- rbind(lifetime, data.frame(
    instrument_id = ids[term],
    effective_from = end_at, effective_to = as.POSIXct(NA, tz = "UTC"),
    knowledge_time = as.POSIXct(paste(session_dates[at], "00:00:00"), tz = "UTC"),
    assertion = "known_inactive", source = "synthetic_lifetime", stringsAsFactors = FALSE))
  term_ids <- ids[term]
}
status <- data.frame(instrument_id = ids, effective_from = window_start, knowledge_time = publish,
                     status = "active", source = "synthetic_status", stringsAsFactors = FALSE)

ts <- as.POSIXct(paste(session_dates, "21:00:00"), tz = "UTC")
cl <- as.vector(close)
bars <- data.frame(
  ts_utc = rep(ts, times = W), instrument_id = rep(ids, each = S),
  open = cl, high = cl * 1.005, low = cl * 0.995, close = cl, volume = 1e5,
  stringsAsFactors = FALSE
)[as.vector(keep), ]

facts <- ledgr_facts(
  ledgr_facts_sessions(sessions, "SYNTH", timezone = "UTC"),
  ledgr_facts_membership_snapshots(membership, "synthetic_members", complete = TRUE),
  ledgr_facts_trading_status(status),
  ledgr_facts_lifetime(lifetime)
)
t1 <- proc.time()[["elapsed"]]
db <- file.path(out_dir, "snapshot.duckdb")
unlink(db)
snap <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = ids),
                               db_path = db, snapshot_id = "lw", facts = facts)
ledgr_snapshot_close(snap)
t2 <- proc.time()[["elapsed"]]
info <- c(spec, list(bar_rows = nrow(bars), membership_rows = nrow(membership),
                     lifetime_rows = nrow(lifetime), terminal_ids = length(term_ids),
                     generate_s = t1 - t0, seal_s = t2 - t1,
                     first_session = format(session_dates[[1]]), last_session = format(session_dates[[S]])))
jsonlite::write_json(info, file.path(out_dir, "build.json"), auto_unbox = TRUE, pretty = TRUE)
cat("BUILD_OK", jsonlite::toJSON(info, auto_unbox = TRUE), "\n")

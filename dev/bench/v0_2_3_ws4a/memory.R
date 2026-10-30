# WS4a memory method (LDG-3163 scope d, decision 5). Changes no product code.
# Rscript memory.R --lib=<ledgr library> [--scratch=<dir>] [--records=<dir>]
#   [--mode=driver|prepare|child|rprofmem|summarize] [--calibrate=1]
# Gated metric (maintainer decision, 2026-10-30, after the peak-commit candidate
# failed validation): peak R heap, sum(gc()[, "max used"] * c(56, 8)) in a fresh
# child after gc(reset = TRUE) at the phase boundary. It covers the R heap only
# (not DuckDB's native memory) and is a high-water mark, so uncollected garbage
# counts. Observation only: lifetime peak_pagefile minus a matched load-only
# child's. --mode=summarize recomputes validation.csv from children.csv (no preparation). Exit 1 on an
# integrity refusal, or unless every cell is stable, isolated, its controls breach and its alias does not.
a <- commandArgs(TRUE)
arg <- function(key, default = NULL) {
  z <- grep(paste0("^--", key, "="), a, value = TRUE)
  if (length(z)) sub(paste0("^--", key, "="), "", z[[1L]]) else default
}
self <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/")
lib <- normalizePath(arg("lib"), winslash = "/", mustWork = TRUE)
scratch <- arg("scratch", "C:/Users/maxth/AppData/Local/Temp/ledgr-ws4a-mem")
records <- arg("records", file.path(dirname(self), "records", "memory"))
prepared <- file.path(scratch, "prepared")
mode <- arg("mode", "driver")
.libPaths(c(lib, .libPaths()))
seed <- 20260530L
n_deep <- 250L # deep-book instruments: 15 single-unit buys, then one 15-lot close
reps <- 5L
budget <- 1.10
control_fraction <- 0.20 # frozen excess size as a fraction of the base metric

# SMA 5/10 transitions on every instrument (wide); the first n_deep instruments
# of the deep shape ramp 1..15 units and close all fifteen lots in one fill.
strategy <- function(ctx, params) {
  fast <- ctx$vec$feature("fast"); slow <- ctx$vec$feature("slow")
  usable <- is.finite(fast) & is.finite(slow); above <- usable & fast > slow
  prev_above <- if (is.null(ctx$state_prev$above)) rep(FALSE, length(usable)) else as.logical(ctx$state_prev$above)
  prev_usable <- if (is.null(ctx$state_prev$usable)) rep(FALSE, length(usable)) else as.logical(ctx$state_prev$usable)
  tick <- if (is.null(ctx$state_prev$tick)) 1L else as.integer(ctx$state_prev$tick) + 1L
  targets <- ctx$hold()
  targets[prev_usable & usable & above & !prev_above] <- 1
  targets[prev_usable & usable & !above & prev_above] <- 0
  if (params$shape == "deep") {
    step <- (tick - 1L) %% 16L
    targets[seq_len(params$n_deep)] <- if (step < 15L) step + 1 else 0
  }
  list(targets = targets, state_update = list(above = above, usable = usable, tick = tick))
}
experiment <- function(snapshot, cash = 1e9) {
  ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = cash), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none())
}
run_child <- function(args, out) {
  code <- system2(file.path(R.home("bin"), "Rscript.exe"), shQuote(c(self, paste0("--lib=", lib),
    paste0("--scratch=", scratch), args)), stdout = paste0(out, ".log"), stderr = paste0(out, ".log"))
  if (code) stop("child failed: ", out)
  utils::read.csv(paste0(out, ".csv"))
}
other_r <- function() {
  p <- ps::ps()
  sum(tolower(p$name) %in% c("rscript.exe", "rterm.exe", "r.exe") & !(p$pid %in% c(Sys.getpid(), ps::ps_ppid())))
}

if (mode == "prepare") {
  suppressPackageStartupMessages(library(ledgr))
  dir.create(prepared, recursive = TRUE, showWarnings = FALSE)
  build <- function(n, days, producer, path) {
    bars <- ledgr_sim_bars(n, days, seed = seed)
    bars$ts_utc <- bars$ts_utc + 21 * 3600 # stamp at the declared session close
    dates <- sort(unique(as.Date(bars$ts_utc)))
    calendar <- seq(min(dates), max(dates), by = "day"); open <- calendar %in% dates
    facts <- ledgr_facts(ledgr_facts_sessions(data.frame(session_date = calendar,
      status = ifelse(open, "open", "closed"), session_open = ifelse(open, "14:30:00", NA_character_),
      session_close = ifelse(open, "21:00:00", NA_character_), knowledge_time = as.POSIXct(calendar, tz = "UTC") - 1),
      "mem", timezone = "UTC"), ledgr_facts_lifetime(data.frame(instrument_id = sort(unique(bars$instrument_id)),
      effective_from = as.POSIXct(min(dates), tz = "UTC"), knowledge_time = as.POSIXct(min(dates), tz = "UTC") - 1,
      assertion = "known_active")))
    ledgr_snapshot_from_df(bars, db_path = path, snapshot_id = "mem", price_basis = "split_adjusted",
      facts = if (producer == "availability") facts else NULL)
  }
  build(5000L, 252L, "availability", file.path(prepared, "snap5k.duckdb"))
  for (producer in c("dense", "availability")) build(500L, 1260L, producer, file.path(prepared, paste0("p500_", producer, ".duckdb")))
  facts <- list()
  for (shape in c("wide", "deep")) {
    store <- file.path(prepared, paste0("replay_", shape, ".duckdb"))
    stopifnot(file.copy(file.path(prepared, "snap5k.duckdb"), store))
    snapshot <- ledgr_snapshot_open(store, snapshot_id = "mem")
    bt <- suppressWarnings(ledgr_run(experiment(snapshot), params = list(shape = shape, n_deep = n_deep), run_id = "mem", seed = seed))
    f <- as.data.frame(ledgr_results(bt, "fills"))
    deep <- f$instrument_id %in% sort(unique(f$instrument_id), method = "radix")[seq_len(n_deep)]
    close15 <- deep & f$side == "SELL" & f$qty == 15
    facts[[shape]] <- data.frame(shape, instruments = 5000L, sessions = 252L, fills = nrow(f),
      deep_buy_qty_max = if (any(deep)) max(f$qty[deep & f$side == "BUY"]) else NA,
      deep_close15_fills = sum(close15), deep_close15_instruments = length(unique(f$instrument_id[close15])))
    close(bt)
  }
  utils::write.csv(do.call(rbind, facts), file.path(prepared, "workloads.csv"), row.names = FALSE)
  quit(save = "no")
}

if (mode == "child") {
  shape <- arg("shape"); op <- arg("op"); phase <- arg("phase"); out <- arg("out")
  store <- paste0(out, ".duckdb")
  src <- if (op == "forward") "snap5k.duckdb" else paste0("replay_", shape, ".duckdb")
  stopifnot(file.copy(file.path(prepared, src), store, overwrite = TRUE))
  suppressPackageStartupMessages(library(ledgr)); loadNamespace("ps")
  concurrent <- other_r()
  snapshot <- ledgr_snapshot_open(store, snapshot_id = "mem")
  if (op == "forward") exp <- experiment(snapshot) else bt <- ledgr_run_open(snapshot, "mem")
  gc(reset = TRUE) # phase boundary: identical in load-only and measured children
  block_bytes <- 0; live <- NA
  if (phase == "control") {
    n <- ceiling(as.numeric(arg("block")) / 8)
    block <- rep(1, n) # independently allocated and written: every page touched
    addr <- tracemem(block); untracemem(block); block_bytes <- 8 * n
  } else if (phase == "alias") {
    block <- if (op == "forward") exp else bt # a second name for existing storage
  }
  rows <- NA_integer_ # the measured operation: forward growth, or one full fills replay
  if (phase != "load" && op == "forward") bt <- suppressWarnings(ledgr_run(exp, params = list(shape = shape, n_deep = n_deep), run_id = "mem2", seed = seed))
  if (phase != "load" && op == "replay") rows <- nrow(ledgr_results(bt, "fills"))
  if (phase == "control") {
    live <- identical(tracemem(block), addr) && length(block) == n && sum(block) == n
    untracemem(block); rm(block); invisible(gc())
  }
  m <- ps::ps_memory_info()
  g <- gc()
  utils::write.csv(data.frame(shape, op, phase, rep = as.integer(arg("rep")), peak_pagefile = m[["peak_pagefile"]],
    pagefile_end = m[["pagefile"]], peak_wset = m[["peak_wset"]], gc_max_used_bytes = sum(g[, "max used"] * c(56, 8)),
    block_bytes, block_live = live, replay_rows = rows, concurrent_r = concurrent,
    gc_env = paste(Sys.getenv(c("R_GC_MEM_GROW", "R_MAX_VSIZE", "R_GC_GROWFRAC")), collapse = "|")),
    paste0(out, ".csv"), row.names = FALSE)
  unlink(store)
  quit(save = "no")
}

if (mode == "rprofmem") {
  producer <- arg("producer"); out <- arg("out")
  store <- paste0(out, ".duckdb"); log <- paste0(out, ".alloc")
  stopifnot(file.copy(file.path(prepared, paste0("p500_", producer, ".duckdb")), store, overwrite = TRUE))
  suppressPackageStartupMessages(library(ledgr))
  exp <- experiment(ledgr_snapshot_open(store, snapshot_id = "mem"), cash = 1e7)
  grid <- ledgr_grid_named(ws4a = list(strategy = list(shape = "wide", n_deep = 0L)))
  Rprofmem(log, threshold = 0) # the probe's boundary: the sweep call, sequential
  sw <- suppressWarnings(ledgr_sweep(exp, grid, retain = ledgr_sweep_retention(returns = "completed", trades = "closed"),
    workers = 1L, seed = seed, stop_on_error = TRUE))
  Rprofmem(NULL)
  bytes <- 0; con <- file(log, "r") # explicit-size records only; "new page" lines are unpriced
  while (length(x <- readLines(con, n = 1e6L, warn = FALSE))) bytes <- bytes + sum(suppressWarnings(as.numeric(sub(" ?:.*", "", x))), na.rm = TRUE)
  close(con); unlink(log)
  bt <- suppressWarnings(ledgr_run(exp, params = list(shape = "wide", n_deep = 0L), run_id = "fills", seed = seed))
  fills <- nrow(ledgr_results(bt, "fills")); close(bt)
  utils::write.csv(data.frame(producer, workflow = "sweep", bytes, fills, bytes_per_fill = bytes / fills),
    paste0(out, ".csv"), row.names = FALSE)
  quit(save = "no")
}

# Driver --------------------------------------------------------------------
dir.create(records, recursive = TRUE, showWarnings = FALSE)
cells <- expand.grid(op = c("forward", "replay"), shape = c("wide", "deep"), stringsAsFactors = FALSE)
alias_rep <- 1L
gc_declared <- "||" # default collection policy: R_GC_MEM_GROW, R_MAX_VSIZE and R_GC_GROWFRAC unset
child <- function(cell, phase, rep, block = 0) {
  tag <- file.path(scratch, "children", paste(cell$shape, cell$op, phase, rep, sep = "_"))
  z <- run_child(c("--mode=child", paste0("--shape=", cell$shape), paste0("--op=", cell$op), paste0("--phase=", phase),
    paste0("--rep=", rep), paste0("--block=", block), paste0("--out=", tag)), tag)
  cat(tag, z$peak_pagefile, "\n"); flush.console(); z
}
pair <- function(x, phase) { # gated metric, plus the matched commit subtraction as an observation
  op <- x[x$phase == phase, ]; ld <- x[x$phase == "load", ]
  op$metric <- op$gc_max_used_bytes
  op$commit <- op$peak_pagefile - ld$peak_pagefile[match(paste(op$shape, op$op, op$rep), paste(ld$shape, ld$op, ld$rep))]
  op
}
sized <- file.path(records, "control_size.csv")
if (identical(mode, "summarize")) { # dispatched before any preparation: reads records only
  all <- utils::read.csv(file.path(records, "children.csv"))
  size <- utils::read.csv(sized)
} else {
  dir.create(file.path(scratch, "children"), recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(file.path(prepared, "workloads.csv"))) run_child("--mode=prepare", file.path(prepared, "workloads"))
  rows <- list()
  for (i in seq_len(nrow(cells))) for (r in seq_len(reps)) for (ph in if (r %% 2L) c("load", "op") else c("op", "load"))
    rows[[length(rows) + 1L]] <- child(cells[i, ], ph, r)
  base <- do.call(rbind, rows)
  # Control blocks were frozen at 0.20 x the commit observation of the base run;
  # they are kept as frozen, and must still breach the gated metric's budget.
  med <- aggregate(commit ~ shape + op, pair(base, "op"), stats::median)
  if (identical(arg("calibrate", "0"), "1")) utils::write.csv(data.frame(med[c("shape", "op")], base_metric = med$commit,
    block_bytes = ceiling(control_fraction * med$commit / 8) * 8), sized, row.names = FALSE)
  size <- utils::read.csv(sized)
  for (i in seq_len(nrow(cells))) {
    b <- size$block_bytes[size$shape == cells$shape[i] & size$op == cells$op[i]]
    for (r in seq_len(reps)) rows[[length(rows) + 1L]] <- child(cells[i, ], "control", r, b)
    rows[[length(rows) + 1L]] <- child(cells[i, ], "alias", alias_rep)
  }
  all <- do.call(rbind, rows)
  utils::write.csv(all, file.path(records, "children.csv"), row.names = FALSE)
}
# Record integrity: registered grid, finite metrics, frozen control sizes, live controls, GC policy, replay rows.
wl <- utils::read.csv(file.path(if (identical(mode, "summarize")) records else prepared, "workloads.csv"))
grid <- merge(cells, data.frame(phase = c(rep(c("load", "op", "control"), each = reps), "alias"), rep = c(rep(seq_len(reps), 3L), alias_rep)))
key <- paste(all$shape, all$op, all$phase, all$rep)
ctl <- all[all$phase %in% "control", ]
rp <- all[all$op %in% "replay" & !(all$phase %in% "load"), ]
bad <- c(if (anyDuplicated(key)) "duplicate rows",
  if (!setequal(key, paste(grid$shape, grid$op, grid$phase, grid$rep))) "rows differ from the registered grid",
  if (!isTRUE(all(is.finite(all$gc_max_used_bytes) & all$gc_max_used_bytes > 0 & is.finite(all$peak_pagefile) & all$peak_pagefile > 0))) "nonfinite or nonpositive metric",
  if (!isTRUE(all(ctl$block_bytes == size$block_bytes[match(paste(ctl$shape, ctl$op), paste(size$shape, size$op))]))) "control bytes differ from control_size.csv",
  if (!isTRUE(all(ctl$block_live))) "control block not live",
  if (!isTRUE(all(all$gc_env == gc_declared))) "undeclared GC environment",
  if (!isTRUE(all(rp$replay_rows == wl$fills[match(rp$shape, wl$shape)]))) "replay rows differ from workloads.csv")
if (length(bad)) stop("memory records REFUSED: ", paste(bad, collapse = "; ")) # Rscript exits 1
measured <- rbind(pair(all, "op"), pair(all, "control"), pair(all, "alias"))
check <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
  k <- measured[measured$shape == cells$shape[i] & measured$op == cells$op[i], ]
  sel <- all$shape == cells$shape[i] & all$op == cells$op[i]; ld <- all$gc_max_used_bytes[sel & all$phase == "load"]
  m <- k$metric[k$phase == "op"]; ctl <- k[k$phase == "control", ]; al <- k$metric[k$phase == "alias"]
  ref <- stats::median(m) # the gated base value for this cell
  data.frame(shape = cells$shape[i], op = cells$op[i], metric = "peak_r_heap_bytes", base_median = ref,
    spread = diff(range(m)) / ref, stable = diff(range(m)) / ref <= 0.05,
    isolation = max(ld) < min(m), load_heap_max = max(ld),
    block_bytes = ctl$block_bytes[[1L]], control_ratio_min = min(ctl$metric) / ref,
    control_live = all(ctl$block_live), control_breaches = all(ctl$block_live) && all(ctl$metric > budget * ref),
    alias_ratio = al / ref, alias_breaches = al > budget * ref,
    commit_median_observed = stats::median(k$commit[k$phase == "op"]),
    commit_spread_observed = diff(range(k$commit[k$phase == "op"])) / stats::median(k$commit[k$phase == "op"]),
    concurrent_r_max = max(all$concurrent_r[sel]))
}))
utils::write.csv(check, file.path(records, "validation.csv"), row.names = FALSE)
ok <- all(check$stable & check$isolation & check$control_breaches & !check$alias_breaches)
if (!ok) cat("memory validation FAILED: a cell is unstable or not isolated, a control misses the budget or an alias breaches it\n")
if (identical(mode, "summarize")) {
  print(check)
  quit(save = "no", status = if (ok) 0L else 1L)
}
alloc <- do.call(rbind, lapply(c("dense", "availability"), function(p) {
  tag <- file.path(scratch, "children", paste0("rprofmem_", p))
  run_child(c("--mode=rprofmem", paste0("--producer=", p), paste0("--out=", tag)), tag)
}))
utils::write.csv(alloc, file.path(records, "rprofmem.csv"), row.names = FALSE)
file.copy(file.path(prepared, "workloads.csv"), file.path(records, "workloads.csv"), overwrite = TRUE)
print(check); print(alloc)
quit(save = "no", status = if (ok) 0L else 1L)

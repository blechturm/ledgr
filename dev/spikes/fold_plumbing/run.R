# Fold plumbing spike runner.
#
#   Rscript run.R --pkg=<ledgr source tree at d5b3a151> --out=<dir> [--reps=5]
#
# 1. Times the real fold loop of both workloads (ledgr telemetry t_loop).
# 2. Records one real fold of each workload as a tape (tape.R).
# 3. Replays each tape through the skeleton fold (sim.R) in both variants and
#    checks that each reproduces the real events, diagnostic blocks and
#    equity record exactly; also runs one gutted path and the reference
#    recorder trap.
# 4. Times the skeleton variants, whole and with one component removed at a
#    time, interleaved, and measures their allocation per pulse.

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  entry <- file.path(here, "..", "..", "bench", "v0_2_3_ws16_entry")
  source(file.path(entry, "common.R"))
  source(file.path(entry, "workloads.R"))
  assign("fp_here", here, envir = globalenv())
})
pkg <- normalizePath(ws16_need("pkg"), winslash = "/")
out <- ws16_out(ws16_need("out"))
reps <- as.integer(ws16_arg("reps", "5"))
commit <- ws16_load_source(pkg)
if (!identical(commit, "d5b3a151")) stop("source tree is not the d5b3a151 pin", call. = FALSE)
source(file.path(fp_here, "tape.R"))
source(file.path(fp_here, "sim.R"))

work <- file.path(tempdir(), "fold_plumbing")
dir.create(work, showWarnings = FALSE)
workloads <- list(
  momentum_40x504 = function() {
    snapshot <- ws16_momentum_snapshot(40L, 504L, file.path(work, "momentum.duckdb"), "fp_momentum")
    exp <- ws16_momentum_experiment(snapshot, 63L)
    list(snapshot = snapshot, run = function(id) {
      close(ledgr_run(exp, params = list(lookback = 63L, n = 10L), run_id = id, seed = 1L))
    })
  },
  fill_heavy_500x1260 = function() {
    snapshot <- ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = file.path(work, "fill.duckdb"),
                                       snapshot_id = "fp_fill")
    exp <- ws16_fill_heavy_experiment(snapshot)
    list(snapshot = snapshot, run = function(id) {
      close(suppressWarnings(ledgr_run(exp, run_id = id, seed = 20260530L)))
    })
  }
)
prepared <- lapply(workloads, function(make) make())

# 1. The real loop, before any stage wrapper exists.
fp_rec$t_loop <- NULL
ws16_wrap("ledgr_fold_envelope", function(orig) {
  force(orig)
  function(execution, output_handler) {
    out <- orig(execution, output_handler)
    fp_rec$t_loop <- out$telemetry$t_loop
    out
  }
})
real <- list()
for (r in seq_len(reps)) for (w in names(prepared)) {
  prepared[[w]]$run(sprintf("fp-real-%s-%d", w, r))
  real[[length(real) + 1L]] <- data.frame(workload = w, rep = r, t_loop = fp_rec$t_loop)
}
real <- do.call(rbind, real)

# 2. Tapes.
fp_install_wrappers()
tapes <- lapply(names(prepared), function(w) fp_capture(function() prepared[[w]]$run(paste0("fp-tape-", w))))
names(tapes) <- names(prepared)
for (w in names(prepared)) ledgr_snapshot_close(prepared[[w]]$snapshot)

# 3. Parity of the skeleton folds against the real outputs.
same <- function(a, b) isTRUE(identical(unname(a), unname(b)))
parity <- list()
census <- list()
for (w in names(tapes)) {
  tape <- tapes[[w]]
  o <- tape$oracle
  runs <- list(today = list(variant = "today"), prealloc = list(variant = "prealloc"),
               prealloc_gut_reservation = list(variant = "prealloc", gut = "reservation"))
  for (label in names(runs)) {
    fp_rec$blocks <- new.env()
    fp_rec$blocks$list <- list()
    fp_rec$checks <- if (identical(label, "today")) new.env() else NULL
    res <- fp_fold(tape, runs[[label]]$variant, gut = runs[[label]]$gut %||% "")
    ev_same <- vapply(names(o$events), function(nm) same(res$events[[nm]], o$events[[nm]]), logical(1))
    eq_cols <- c("ts", "cash", "positions_value", "realized_pnl", "cost_basis", "n")
    parity[[length(parity) + 1L]] <- data.frame(
      workload = w, variant = label,
      output = c("events", "diagnostic_blocks", "equity"),
      rows = c(length(o$events$event_seq),
               sum(vapply(o$diagnostics, function(b) length(b$diagnostic_seq), 0)),
               o$equity$n),
      identical = c(all(ev_same), same(fp_rec$blocks$list, o$diagnostics),
                    all(vapply(eq_cols, function(nm) same(res$equity[[nm]], o$equity[[nm]]), logical(1)))),
      first_diff = c(paste(names(ev_same)[!ev_same][1L]), "", ""))
    if (identical(label, "today")) {
      sim_checks <- fp_table(fp_rec$checks, c("stage", "group"))
      m <- merge(tape$checks, sim_checks, by = c("stage", "group"), all = TRUE, suffixes = c("_real", "_skeleton"))
      m[is.na(m)] <- 0
      census[[w]] <- cbind(workload = w, m)
    }
  }
  # The recorder trap: P2's preallocated output recorded by reference.
  res <- fp_fold(tape, "prealloc", keep_refs = TRUE)
  decided <- which(vapply(res$refs, Negate(is.null), logical(1)))
  matches <- vapply(decided, function(i) {
    same(fp_used(res$refs[[i]], "target_qty"), tape$pulses[[i]]$P2$target_qty)
  }, logical(1))
  parity[[length(parity) + 1L]] <- data.frame(
    workload = w, variant = "prealloc_recorded_by_reference", output = "decision_per_pulse",
    rows = length(decided), identical = all(matches),
    first_diff = paste(sum(!matches), "of", length(decided), "pulses differ"))
}
fp_rec$blocks <- NULL
fp_rec$checks <- NULL
parity <- do.call(rbind, parity)
census <- do.call(rbind, census)
ws16_write(parity, file.path(out, "parity.csv"))
ws16_write(census, file.path(out, "check_census.csv"))
if (!all(parity$identical[!grepl("gut|by_reference", parity$variant)])) {
  print(parity)
  stop("kill condition: a skeleton fold does not reproduce the real outputs", call. = FALSE)
}

# Sizes the skeleton moved, per pulse.
sizes <- list()
for (w in names(tapes)) {
  p <- tapes[[w]]$pulses
  bytes <- function(f) vapply(p, function(e) as.numeric(utils::object.size(f(e))), 0)
  len <- function(f) vapply(p, function(e) length(f(e)), 0)
  objs <- list(
    decision_packet = function(e) e$P1$observation$packet,
    decision_data = function(e) e$P1$observation$data[setdiff(names(e$P1$observation$data), "history")],
    execution_packet = function(e) e$P1$execution,
    decision = function(e) e$P2[names(ledgr:::.ledgr_carrier_fields$decision)],
    fill = function(e) e$P3$batch$fill,
    rejection = function(e) e$P3$batch$rejection)
  axis <- list(decision_packet = function(e) e$P1$observation$packet$context_pos,
               decision_data = function(e) e$P1$observation$data$source_row,
               execution_packet = function(e) e$P1$execution$open,
               decision = function(e) e$P2$context_pos, fill = function(e) e$P3$batch$fill$k,
               rejection = function(e) e$P3$batch$rejection$k)
  for (g in names(objs)) {
    b <- bytes(objs[[g]])
    a <- len(axis[[g]])
    sizes[[length(sizes) + 1L]] <- data.frame(
      workload = w, object = g, fields = length(objs[[g]](p[[1L]])),
      rows_median = stats::median(a), rows_max = max(a), kb_median = round(stats::median(b) / 1024, 1))
  }
  ops <- vapply(p, function(e) length(e$staging), 0)
  rows <- vapply(tapes[[w]]$oracle$diagnostics, function(b) length(b$diagnostic_seq), 0)
  fills <- vapply(p, function(e) sum(vapply(e$payload, function(x) length(x$i), 0)), 0)
  svc <- tapes[[w]]$services
  sizes[[length(sizes) + 1L]] <- data.frame(
    workload = w, object = c("services", "staging_calls", "diagnostic_rows_kept", "fills"),
    fields = c(length(svc), NA, NA, NA),
    rows_median = c(NA, stats::median(ops), stats::median(rows), stats::median(fills)),
    rows_max = c(NA, max(ops), max(rows), max(fills)),
    kb_median = c(round(as.numeric(utils::object.size(svc)) / 1024, 1), NA, NA, NA))
}
sizes <- do.call(rbind, sizes)
ws16_write(sizes, file.path(out, "sizes.csv"))
reads <- do.call(rbind, lapply(names(tapes), function(w) {
  plan <- fp_read_plan(tapes[[w]])
  data.frame(workload = w, stage = names(plan), reads_per_call = lengths(plan),
             distinct_fields = vapply(plan, function(f) length(unique(f)), 0))
}))
ws16_write(reads, file.path(out, "reads_per_call.csv"))

# 4. Timing without any wrapper in the path: reload the pinned tree so the
# namespace holds the pinned functions again (ws16_wrap keeps no originals).
commit <- ws16_load_source(pkg)
source(file.path(fp_here, "sim.R"))

configs <- list(today = fp_flags_all, prealloc = fp_flags_all)
for (part in names(fp_flags_all)) {
  for (v in c("today", "prealloc")) {
    if (identical(v, "prealloc") && identical(part, "validate")) next
    f <- fp_flags_all
    f[[part]] <- FALSE
    configs[[paste0(v, "-", part)]] <- f
  }
}
none <- fp_flags_all
none[] <- FALSE
configs[["today-all"]] <- none
timing <- list()
for (w in names(tapes)) {
  for (k in seq_len(2L)) for (cfg in names(configs)) {
    fp_fold(tapes[[w]], sub("-.*$", "", cfg), configs[[cfg]])
  }
  for (r in seq_len(reps)) for (cfg in names(configs)) {
    res <- fp_fold(tapes[[w]], sub("-.*$", "", cfg), configs[[cfg]])
    timing[[length(timing) + 1L]] <- data.frame(workload = w, config = cfg, rep = r,
                                                us_per_pulse = 1e6 * res$elapsed / res$pulses)
  }
}
timing <- do.call(rbind, timing)
ws16_write(timing, file.path(out, "timing_raw.csv"))

# Allocation per pulse (Rprofmem: large vectors exactly, small vectors as
# 2,000-byte pages).
fp_alloc_bytes <- function(f) {
  file <- tempfile(fileext = ".txt")
  utils::Rprofmem(file, threshold = 0)
  f()
  utils::Rprofmem(NULL)
  lines <- readLines(file, warn = FALSE)
  big <- suppressWarnings(as.numeric(sub(" :.*$", "", lines)))
  sum(big, na.rm = TRUE) + 2000 * sum(startsWith(lines, "new page"))
}
alloc <- do.call(rbind, lapply(names(tapes), function(w) {
  do.call(rbind, lapply(c("today", "prealloc"), function(v) {
    bytes <- fp_alloc_bytes(function() fp_fold(tapes[[w]], v))
    data.frame(workload = w, variant = v, kb_per_pulse = round(bytes / 1024 / length(tapes[[w]]$pulses), 1))
  }))
}))
ws16_write(alloc, file.path(out, "alloc.csv"))

summary <- aggregate(us_per_pulse ~ workload + config, data = timing, FUN = stats::median)
real_us <- aggregate(t_loop ~ workload, data = real, FUN = stats::median)
real_us$us_per_pulse <- 1e6 * real_us$t_loop / vapply(real_us$workload, function(w) length(tapes[[w]]$pulses), 0)
summary <- rbind(summary, data.frame(workload = real_us$workload, config = "ledgr_real_loop",
                                     us_per_pulse = real_us$us_per_pulse))
summary$us_per_pulse <- round(summary$us_per_pulse, 1)
ws16_write(summary[order(summary$workload, summary$config), ], file.path(out, "timing.csv"))
print(parity)
print(summary)
print(alloc)
cat("fold plumbing evidence written to", out, "\n")

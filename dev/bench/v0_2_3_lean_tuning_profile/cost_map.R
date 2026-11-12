# Whole-run cost map of the lean loop and the pin (LDG-3221, Cut 14 R4, N1).
# Measurement only. Extends profile.R (whose a1966cf9 results stay as they
# are) to both arms, four shapes, named lean stages and a strategy split.
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/cost_map.R --lib=<pinned library>
#     --out=<dir> [--shapes=10x7200,20x23400,500x1260,1166x252] [--reps=5]
#     [--prof-reps=10x7200:3,...] [--selftest=1]
#
# Both arms, every shape: the crossover fixture (r_floor_fixture, SMA 5/10,
# seed 20260530), a fresh copy of the sealed snapshot per run (same store
# history), one warm-up run, gc() before every run, arms alternated by rep,
# the lean functions byte-compiled like the installed pin, debug off, lean
# with the inert hooks plus a clock on fold_end. Clocks (unprofiled runs):
# snapshot open and verification; the committed run (ledgr_run on the open
# snapshot); the envelope; the pulse loop (lean: one outer clock around the
# pulses; pin: its t_loop, which also holds the pin's per-pulse store
# writes). Fills and equity must match between arms, and the lean arm must
# have run the lean fold, before any time is used.
#
# Attribution (separate Rprof runs, 5 ms): each sample goes to exactly one
# cell, walking its stack from the leaf. Strategy cells: own work (in the
# strategy's frame or base code it calls), ledgr callees (context and state
# reads, helpers, result construction, called from the strategy), the call
# wrapper (ledgr_call_strategy_fn and the condition handling around it).
# P2's own cells exclude all three. Cells are estimates (share x a measured
# clock), reconciled to their clock with the residual published.
#
# Matched strategy replay (separate runs): on every pulse the unchanged
# strategy runs on the real context, then on a plain list materialized from
# it after the call (same features, holdings, state, parameters and helper
# results); each call is timed alone and both returns must be identical.
#
# --selftest=1 shows the checks reject a replay mismatch and a duplicated
# attribution cell, on a 3 x 40 run.
#
# Outputs in <out>: identity.txt, clock_raw.csv, cells.csv, reconcile.csv,
# strategy_split.csv, replay.csv (and selftest.csv).

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(arg("lib"), debug = FALSE)
for (f in ls(lean, all.names = TRUE)) {
  g <- get(f, envir = lean)
  if (is.function(g) && identical(environment(g), lean)) assign(f, compiler::cmpfun(g), envir = lean)
}
ns <- asNamespace("ledgr")
pin_call_strategy_fn <- get("ledgr_call_strategy_fn", envir = ns)
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
out <- arg("out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
selftest <- identical(arg("selftest", "0"), "1")
shapes <- strsplit(arg("shapes", if (selftest) "10x300" else "10x7200,20x23400,500x1260,1166x252"), ",")[[1L]]
reps <- as.integer(arg("reps", if (selftest) "1" else "5"))
# Profile runs per shape, so each loop gets enough samples (a short loop
# gets more runs); shape:runs pairs, or one number for every shape.
prof_spec <- arg("prof-reps", if (selftest) "2" else "10x7200:3,20x23400:1,500x1260:10,1166x252:40")
prof_reps <- if (grepl(":", prof_spec)) {
  kv <- strsplit(strsplit(prof_spec, ",")[[1L]], ":")
  stats::setNames(as.integer(vapply(kv, `[[`, "", 2L)), vapply(kv, `[[`, "", 1L))
} else stats::setNames(rep(as.integer(prof_spec), length(shapes)), shapes)
now <- function() proc.time()[["elapsed"]]
hr <- function() as.numeric(Sys.time())

writeLines(c(
  paste("command:", paste(commandArgs(), collapse = " ")),
  paste("head:", system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)),
  paste("dev/lean_core changes against head:", length(system2("git", c("-C", repo, "status", "--porcelain", "dev/lean_core"), stdout = TRUE))),
  paste("pin:", lean$.lean_pin), paste("library:", lean$.lean_lib), paste("R:", R.version.string),
  paste("platform:", R.version$platform), paste("power plan:", paste(tryCatch(system2("powercfg", "/getactivescheme", stdout = TRUE),
    error = function(e) "unknown"), collapse = " ")),
  paste("started:", format(Sys.time(), tz = "UTC", usetz = TRUE))), file.path(out, "identity.txt"))

work <- file.path(tempdir(), "cost_map")
dir.create(work, showWarnings = FALSE)
dims <- function(s) as.integer(strsplit(s, "x")[[1L]])
sealed <- list()
for (s in shapes) {
  sealed[[s]] <- file.path(work, paste0(s, ".duckdb"))
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(r_floor_fixture(dims(s)[[1L]], dims(s)[[2L]])$bars,
    db_path = sealed[[s]], snapshot_id = paste0("cm_", s), price_basis = "split_adjusted"))
}
experiment <- function(snapshot) {
  strategy <- r_floor_transition
  environment(strategy) <- ns
  ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
}
rebind <- function(name, value) {
  old <- get(name, envir = ns)
  unlockBinding(name, ns); assign(name, value, envir = ns); lockBinding(name, ns)
  function() { unlockBinding(name, ns); assign(name, old, envir = ns); lockBinding(name, ns) }
}

# --- the matched strategy replay ------------------------------------------
materialize <- function(ctx) {
  names_read <- setdiff(names(unclass(ctx)), c("flat", "hold"))
  names_read <- c(names_read[!startsWith(names_read, ".")], .subset2(ctx, ".pulse_lookup")$readable_feature_names)
  plain <- lapply(stats::setNames(unique(names_read), unique(names_read)), function(n) do.call(`$`, list(ctx, n)))
  plain$state <- unclass(ctx$state)
  held <- ctx$hold()
  flat0 <- ctx$flat()
  plain$hold <- function() held
  plain$flat <- function(default = 0) if (identical(default, 0)) flat0 else ctx$flat(default)
  plain
}
replay <- new.env(parent = emptyenv())
replay_wrapper <- function(fn, ctx, params = list(), signature = NULL) {
  k <- replay$k <- replay$k + 1L
  t0 <- hr(); r <- fn(ctx, params); t1 <- hr()
  plain <- materialize(ctx)
  if (identical(replay$perturb_at, k)) {
    shifted <- plain$hold() + 1
    plain$hold <- function() shifted
  }
  t2 <- hr(); r2 <- fn(plain, params); t3 <- hr()
  replay$real[[k]] <- t1 - t0
  replay$plain[[k]] <- t3 - t2
  replay$same[[k]] <- identical(unclass(r), unclass(r2))
  r
}

# --- one run ----------------------------------------------------------------
run_arm <- function(arm, shape, mode = "clock", perturb_at = NULL) {
  db <- file.path(work, "run.duckdb")
  if (file.exists(db)) unlink(db)
  file.copy(sealed[[shape]], db)
  t0 <- now()
  snapshot <- ledgr::ledgr_snapshot_open(db, paste0("cm_", shape), verify = TRUE)
  open_s <- now() - t0
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- experiment(snapshot)
  clock <- new.env(parent = emptyenv())
  # Every run starts from the pin's bindings; the restores below run in
  # reverse order of installation (after = FALSE), so the pin's come back last.
  if (!identical(get("ledgr_fold_envelope", envir = ns), lean$lean_pin_envelope) ||
      !identical(get("ledgr_call_strategy_fn", envir = ns), pin_call_strategy_fn)) {
    stop("run ", arm, " ", shape, ": the pin's bindings are not in place", call. = FALSE)
  }
  if (arm == "lean") {
    restore_lean <- lean$lean_loop_install(hooks = FALSE)
    on.exit(restore_lean(), add = TRUE)
    lean$lean_hooks <- utils::modifyList(lean$lean_hooks_inert(), list(fold_end = function(stats) clock$pulses <- stats$pulses))
  }
  envelope <- get("ledgr_fold_envelope", envir = ns)
  restore_envelope <- rebind("ledgr_fold_envelope", function(execution, output_handler) {
    t0 <- now()
    res <- envelope(execution, output_handler)
    clock$envelope <- now() - t0
    clock$t_loop <- res$telemetry$t_loop
    res
  })
  on.exit(restore_envelope(), add = TRUE, after = FALSE)
  if (mode == "replay") {
    replay$k <- 0L; replay$real <- numeric(); replay$plain <- numeric(); replay$same <- logical()
    replay$perturb_at <- perturb_at
    restore_call <- rebind("ledgr_call_strategy_fn", replay_wrapper)
    on.exit(restore_call(), add = TRUE, after = FALSE)
  }
  prof <- file.path(work, "run.rprof")
  invisible(gc())
  if (mode == "profile") Rprof(prof, interval = 0.005)
  t0 <- now()
  bt <- ledgr::ledgr_run(exp, run_id = "cm-run", seed = 20260530L)
  whole <- now() - t0
  if (mode == "profile") Rprof(NULL)
  digest <- rlang::hash(list(ledgr::ledgr_results(bt, "fills"), ledgr::ledgr_results(bt, "equity")))
  close(bt)
  lean_ran <- !is.null(clock$pulses)
  if (lean_ran != (arm == "lean")) stop(arm, " arm on ", shape, ": lean fold ran = ", lean_ran, call. = FALSE)
  row <- data.frame(arm = arm, shape = shape, pulses = dims(shape)[[2L]], instruments = dims(shape)[[1L]],
    snapshot_open_s = open_s, run_s = whole, envelope_s = clock$envelope,
    loop_s = if (arm == "lean") clock$pulses else clock$t_loop, digest = digest, stringsAsFactors = FALSE)
  list(row = row, prof = if (mode == "profile") readLines(prof) else NULL)
}

# --- attribution --------------------------------------------------------------
wrapper_frames <- c("ledgr_call_strategy_fn", "tryCatch", "tryCatchList", "tryCatchOne", "doTryCatch", "withCallingHandlers")
callee <- function(f) grepl("^\\$\\.ledgr_|^ledgr_|\\$hold$|\\$flat$|^hold$|^flat$", f)
stage_cells <- c(
  lean_context = "P2 context", lean_p1_value = "P1", lean_p2_decide = "P2 other", lean_p3_plan = "P3",
  lean_lot_fill = "P4 FIFO", lean_p4_apply = "P4 other", lean_p5_commit = "P5", lean_e_advance = "E advance",
  ledgr_fold_stage_observe_settle = "P1", ledgr_fold_stage_decide = "P2 other", ledgr_fold_stage_plan = "P3",
  ledgr_fold_stage_apply = "P4 other", ledgr_fold_stage_commit = "P5")
loop_cells <- c("strategy: own work", "strategy: ledgr callees", "strategy: call wrapper", unique(stage_cells),
                "loop: residual")
is_loop_cell <- function(cell) cell %in% loop_cells | startsWith(cell, "loop: ")
# Cells every run of an arm has; a required cell without samples is
# reported as unresolved, never as zero.
required_cells <- list(
  lean = c("strategy: own work", "strategy: ledgr callees", "strategy: call wrapper", "P1", "P2 context", "P2 other",
           "P3", "P4 FIFO", "P4 other", "P5", "E advance", "loop: residual"),
  pin = c("strategy: own work", "strategy: ledgr callees", "strategy: call wrapper", "P1", "P2 other", "P3", "P4 other",
          "P5", "loop: residual"))
base_names <- ls(baseenv(), all.names = TRUE)
other_cells <- c(
  lean_loop_expand = "transfer: expand", lean_loop_layout = "transfer: expand", lean_loop_keep = "transfer: expand",
  lean_loop_positions_at = "transfer: expand", lean_loop_explicit_block = "transfer: expand",
  # the transfer runs as `fn` inside the publish hook
  lean_loop_publish = "transfer: write", "hooks$publish" = "transfer: write", envelope = "envelope: setup and commit",
  ledgr_fold_envelope = "envelope: setup and commit",
  ledgr_history_compute_feature_series = "pre: features", ledgr_projection_from_feature_matrix = "pre: feature projection",
  ledgr_history_substrate_bind_features = "pre: feature projection",
  ledgr_history_substrate_for_experiment = "pre: bars substrate", ledgr_history_substrate = "pre: bars substrate",
  ledgr_availability_provider_from_substrate = "pre: provider",
  ledgr_experiment_materialize_feature_result = "pre: feature declarations",
  ledgr_strategy_preflight = "pre: strategy preflight", ledgr_run_snapshot_guard = "pre: snapshot guard",
  ledgr_run_registration = "pre: store and registration", ledgr_run_registration_provenance = "pre: store and registration",
  ledgr_validate_schema_once = "pre: store and registration", ledgr_store_open = "pre: store and registration",
  ledgr_config = "pre: config", ledgr_run_finalize = "post: finalise", ledgr_finalize_fold_telemetry = "post: telemetry",
  new_ledgr_backtest = "post: result object")
cell_of <- function(s) {
  # the strategy frame: `fn` called by ledgr_call_strategy_fn
  js <- which(s == "fn" & c(s[-1L], "") == "ledgr_call_strategy_fn")
  if (length(js)) {
    below <- s[seq_len(js[[1L]] - 1L)]
    return(if (any(callee(below))) "strategy: ledgr callees" else "strategy: own work")
  }
  for (j in seq_along(s)) {
    f <- s[[j]]
    if (f %in% c("ledgr_call_strategy_fn")) return("strategy: call wrapper")
    if (f %in% c("lean_p2_decide", "ledgr_fold_stage_decide") && j > 1L && all(s[seq_len(j - 1L)] %in% wrapper_frames) &&
        any(s[seq_len(j - 1L)] == "tryCatch")) return("strategy: call wrapper")
    if (f %in% names(stage_cells)) return(stage_cells[[f]])
    if (f %in% names(other_cells)) return(other_cells[[f]])
    if (identical(f, "fn") && j < length(s) && identical(s[[j + 1L]], "withCallingHandlers") && "ledgr_fold_envelope" %in% s) {
      # the loop body itself: its direct named callee, else base code
      callee_name <- if (j > 1L) s[[j - 1L]] else ""
      if (nzchar(callee_name) && !callee_name %in% base_names && !startsWith(callee_name, "<")) {
        return(paste0("loop: ", callee_name))
      }
      return("loop: residual")
    }
  }
  if ("ledgr_run" %in% s) "run: other" else "outside the run"
}
attribute <- function(lines) {
  lines <- lines[!grepl("^sample.interval|^#", lines)]
  cells <- vapply(strsplit(lines, " ", fixed = TRUE), function(s) cell_of(gsub('"', "", s)), character(1L))
  table(cells[cells != "outside the run"])
}

# --- checks (also used by the self-test) --------------------------------------
check_cells <- function(cells, reconcile) {
  key <- paste(cells$arm, cells$shape, cells$cell)
  if (anyDuplicated(key)) return("duplicated attribution cell")
  for (i in seq_len(nrow(reconcile))) {
    r <- reconcile[i, ]
    have <- cells$cell[cells$arm == r$arm & cells$shape == r$shape]
    if (length(setdiff(required_cells[[r$arm]], have))) return("missing required cell")
  }
  for (i in seq_len(nrow(reconcile))) {
    r <- reconcile[i, ]
    x <- cells[cells$arm == r$arm & cells$shape == r$shape, ]
    if (abs(sum(x$est_run_s, na.rm = TRUE) - r$run_median_s) > 1e-6 * max(1, r$run_median_s)) return("run cells do not sum to the run clock")
    lx <- x[is_loop_cell(x$cell), ]
    if (abs(sum(lx$est_loop_s, na.rm = TRUE) - r$loop_median_s) > 1e-6 * max(1, r$loop_median_s)) return("loop cells do not sum to the loop clock")
  }
  "ok"
}
check_replay <- function(same) if (all(same)) "ok" else sprintf("replay output differs on %d pulse(s)", sum(!same))

# --- runs -----------------------------------------------------------------------
arms <- c("lean", "pin")
for (s in shapes) for (a in arms) run_arm(a, s)   # warm-up
clock <- list()
for (r in seq_len(reps)) for (s in shapes) for (a in if (r %% 2L) arms else rev(arms)) {
  x <- run_arm(a, s)$row
  x$rep <- r
  clock[[length(clock) + 1L]] <- x
  cat(sprintf("clock rep %d %-9s %-4s open %.2f  run %.2f  envelope %.2f  loop %.2f s\n", r, s, a,
              x$snapshot_open_s, x$run_s, x$envelope_s, x$loop_s))
}
clock <- do.call(rbind, clock)
sig <- tapply(clock$digest, clock$shape, function(d) length(unique(d)))
if (any(sig != 1L)) stop("lean and pin results differ on: ", paste(names(sig)[sig != 1L], collapse = ", "), call. = FALSE)
utils::write.csv(clock, file.path(out, "clock_raw.csv"), row.names = FALSE)
med <- stats::aggregate(cbind(snapshot_open_s, run_s, envelope_s, loop_s) ~ arm + shape + pulses + instruments, clock, stats::median)

samples <- list()
for (s in shapes) for (r in seq_len(prof_reps[[s]])) for (a in if (r %% 2L) arms else rev(arms)) {
  tab <- attribute(run_arm(a, s, "profile")$prof)
  samples[[length(samples) + 1L]] <- data.frame(arm = a, shape = s, cell = names(tab), samples = as.integer(tab))
}
samples <- stats::aggregate(samples ~ arm + shape + cell, do.call(rbind, samples), sum)
# Required cells with no sample are kept with zero samples.
for (a in arms) for (s in shapes) {
  absent <- setdiff(required_cells[[a]], samples$cell[samples$arm == a & samples$shape == s])
  if (length(absent)) samples <- rbind(samples, data.frame(arm = a, shape = s, cell = absent, samples = 0L))
}
cells <- merge(samples, med, by = c("arm", "shape"))
cells$profile_runs <- prof_reps[cells$shape]
cells$share_of_run <- cells$samples / stats::ave(cells$samples, cells$arm, cells$shape, FUN = sum)
cells$est_run_s <- cells$share_of_run * cells$run_s
in_loop <- is_loop_cell(cells$cell)
loop_samples <- stats::ave(ifelse(in_loop, cells$samples, 0L), cells$arm, cells$shape, FUN = sum)
cells$share_of_loop <- ifelse(in_loop, cells$samples / loop_samples, NA_real_)
cells$est_loop_s <- ifelse(in_loop, cells$share_of_loop * cells$loop_s, NA_real_)
cells$est_us_per_pulse <- ifelse(in_loop, 1e6 * cells$est_loop_s / cells$pulses, NA_real_)
# Resolution: no sample leaves the cell unresolved (no estimate); fewer than
# ten samples make it rough.
cells$resolution <- ifelse(cells$samples == 0L, "unresolved", ifelse(cells$samples < 10L, "rough", "measured"))
for (col in c("share_of_run", "est_run_s", "share_of_loop", "est_loop_s", "est_us_per_pulse")) {
  cells[[col]][cells$samples == 0L] <- NA_real_
}
cells <- cells[order(cells$arm, cells$shape, -cells$samples), c("arm", "shape", "cell", "samples", "profile_runs",
  "resolution", "share_of_run", "est_run_s", "share_of_loop", "est_loop_s", "est_us_per_pulse")]
utils::write.csv(cells, file.path(out, "cells.csv"), row.names = FALSE)

reconcile <- do.call(rbind, lapply(split(cells, paste(cells$arm, cells$shape)), function(x) {
  m <- med[med$arm == x$arm[[1L]] & med$shape == x$shape[[1L]], ]
  lx <- x[is_loop_cell(x$cell), ]
  data.frame(arm = m$arm, shape = m$shape, run_median_s = m$run_s, loop_median_s = m$loop_s,
    envelope_median_s = m$envelope_s, snapshot_open_median_s = m$snapshot_open_s, samples = sum(x$samples),
    loop_samples = sum(lx$samples),
    # sample-derived loop time against the measured loop clock
    loop_estimate_over_clock = (sum(lx$samples) / sum(x$samples)) * m$run_s / m$loop_s,
    loop_residual_share = sum(lx$samples[lx$cell == "loop: residual"]) / max(1L, sum(lx$samples)))
}))
cells_for_check <- cells
utils::write.csv(reconcile, file.path(out, "reconcile.csv"), row.names = FALSE)
status <- check_cells(cells_for_check, reconcile)
if (!identical(status, "ok")) stop("attribution: ", status, call. = FALSE)

split_rows <- do.call(rbind, lapply(split(cells, paste(cells$arm, cells$shape)), function(x) {
  # an unresolved cell stays NA, never zero
  get_cell <- function(name) { v <- x$est_us_per_pulse[x$cell == name]; if (length(v) == 1L) v else stop("missing cell ", name) }
  n <- dims(x$shape[[1L]])[[1L]]
  own <- get_cell("strategy: own work"); callees <- get_cell("strategy: ledgr callees"); wrap <- get_cell("strategy: call wrapper")
  data.frame(arm = x$arm[[1L]], shape = x$shape[[1L]], instruments = n,
    body_inclusive_us = own + callees, own_work_us = own, ledgr_callees_us = callees, call_wrapper_us = wrap,
    samples = sum(x$samples[grepl("^strategy", x$cell)]),
    unresolved = paste(x$cell[grepl("^strategy", x$cell) & x$resolution == "unresolved"], collapse = "; "),
    own_work_us_per_instrument = own / n, ledgr_callees_us_per_instrument = callees / n, call_wrapper_us_per_instrument = wrap / n)
}))
utils::write.csv(split_rows, file.path(out, "strategy_split.csv"), row.names = FALSE)

replay_rows <- list()
for (s in shapes) for (a in arms) {
  run_arm(a, s, "replay")
  keep <- seq_along(replay$real) > min(20L, length(replay$real) %/% 4L)   # warm-up pulses dropped
  status <- check_replay(replay$same)
  if (!identical(status, "ok")) stop("replay ", a, " ", s, ": ", status, call. = FALSE)
  n <- dims(s)[[1L]]
  replay_rows[[length(replay_rows) + 1L]] <- data.frame(arm = a, shape = s, instruments = n, calls = sum(keep),
    identical = all(replay$same), real_median_us = 1e6 * stats::median(replay$real[keep]),
    plain_median_us = 1e6 * stats::median(replay$plain[keep]), real_mean_us = 1e6 * mean(replay$real[keep]),
    plain_mean_us = 1e6 * mean(replay$plain[keep]),
    context_premium_us_per_instrument = 1e6 * (stats::median(replay$real[keep]) - stats::median(replay$plain[keep])) / n)
}
replay_rows <- do.call(rbind, replay_rows)
utils::write.csv(replay_rows, file.path(out, "replay.csv"), row.names = FALSE)

if (selftest) {
  run_arm("lean", shapes[[1L]], "replay", perturb_at = 5L)
  r1 <- check_replay(replay$same)
  dup <- rbind(cells_for_check, cells_for_check[1L, ])
  r2 <- check_cells(dup, reconcile)
  gone <- cells_for_check[!(cells_for_check$arm == "lean" & cells_for_check$cell == "strategy: call wrapper"), ]
  r3 <- check_cells(gone, reconcile)
  st <- data.frame(check = c("replay mismatch", "duplicated attribution cell", "missing required cell"),
                   result = c(r1, r2, r3), rejected = c(r1 != "ok", r2 != "ok", r3 != "ok"))
  utils::write.csv(st, file.path(out, "selftest.csv"), row.names = FALSE)
  print(st, row.names = FALSE)
  if (!all(st$rejected)) quit(status = 1L)
}
print(reconcile, row.names = FALSE)
print(split_rows, row.names = FALSE)
print(replay_rows, row.names = FALSE)

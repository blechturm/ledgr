# Shortcut timing for LDG-3220 (Cut 14 R3). In one process, on the crossover
# fixtures 10 x 7,200, 20 x 23,400 and 500 x 1,260, it times byte-compiled,
# debug-off lean arms with the inert hooks (plus a clock on fold_end) and
# the same inputs, store state and GC policy:
#
#   --mode=shortcuts  the restructured all-shortcuts arm against six arms,
#                     each delegating exactly one shortcut to the pin
#   --mode=final      the final arm against 4a3e08b8's loop, loaded in the
#                     same process by the same method
#
# Each comparison of the first arm with another runs in its own pairs, the
# order reversed on every pair; every run gets a fresh copy of the sealed snapshot and a gc() first,
# outside the clocks. Clocks: the pulse loop (one outer clock inside the
# envelope, reported through fold_end), the complete envelope and the whole
# ledgr_run() call. Every run's fills and equity must equal the first arm's
# before any time is used.
#
#   Rscript dev/lean_core/parity/loop_shortcuts.R --lib=<pinned library>
#     --mode=shortcuts|final --out=<dir> [--rounds=7] [--shapes=10x7200,...]
#
# Writes <out>/<mode>_raw.csv (one row per run) and <out>/<mode>_summary.csv.
# Paired saving of a delegated arm in a round: (delegated - shortcut) /
# delegated on the pulse loop. A shortcut is deleted when its median paired
# saving is below 0.02 on every shape and at least rounds - 1 of its paired
# savings lie below 0.02 on every shape; it is kept when, on some shape, at
# least rounds - 1 lie at or above 0.02; anything else is unresolved and goes
# to the maintainer.

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
lib <- arg("lib")
mode <- arg("mode")
out <- arg("out")
rounds <- as.integer(arg("rounds", "7"))
shapes <- strsplit(arg("shapes", "10x7200,20x23400,500x1260"), ",")[[1L]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(here, "loop_edits.R"))
source(file.path(here, "..", "load.R"))
lean <- lean_core_load(lib, debug = FALSE)
ns <- asNamespace("ledgr")
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))

# The delegation arms: one edit set each, against the tracked loop.R and
# loop_harness.R.
e <- lean_edit
delegations <- list(
  # (the state-view method was deleted by this rule, LDG-3220)
  ctx_dollar = list(e("loop_harness.R", "lean_loop_install",
    "               \"$.ledgr_pulse_context\" = lean_ctx_dollar,",
    "               \"$.ledgr_pulse_context\" = lean_pin_ctx_dollar,")),
  hold = list(e("loop.R", "lean_ctx_helpers",
    "      if (is.double(p) && identical(attributes(p), list(names = lookup$universe)) && all(is.finite(p))) p",
    "      if (FALSE) p")),
  targets = list(e("loop.R", "lean_p2_decide",
    "    targets <- if (is.numeric(raw_targets) && identical(attributes(raw_targets), ids_attr) &&",
    "    targets <- if (FALSE &&")),
  state_patch = list(e("loop.R", "lean_p5_commit", "      patched <- lean_state_patch(unclass(state_update))",
    c("      patched <- ledgr_strategy_state_apply_values(strategy_state, unclass(state_update), state_declaration, ids,",
      "        patch = TRUE, default_scalars = state_defaults)"))),
  gross = list(
    e("loop.R", "lean_p5_commit", "    intended <- lean_gross(sq, close)", "    intended <- ledgr_availability_marked_gross(sq, close)"),
    e("loop.R", "lean_p5_commit", "      lean_gross(pos, close),", "      ledgr_availability_marked_gross(pos, close),"))
)

# An arm: the lean environment's other files, with loop.R and loop_harness.R
# evaluated from `texts` (file name -> lines), byte-compiled.
make_arm <- function(texts) {
  env <- new.env(parent = ns)
  list2env(as.list(lean, all.names = TRUE), envir = env)
  for (f in c("loop.R", "loop_harness.R")) eval(parse(text = texts[[f]], keep.source = FALSE), envir = env)
  for (nm in ls(env, all.names = TRUE)) {
    f <- get(nm, envir = env)
    if (is.function(f) && identical(environment(f), env)) assign(nm, compiler::cmpfun(f), envir = env)
  }
  env
}
tracked <- lapply(c(loop.R = "loop.R", loop_harness.R = "loop_harness.R"), function(f) readLines(file.path(lean_core_home, f)))
edited <- function(edits) {
  t <- tracked
  for (f in unique(vapply(edits, `[[`, "", "file"))) t[[f]] <- lean_apply_edits(t[[f]], Filter(function(x) x$file == f, edits))
  t
}
at_commit <- function(commit) lapply(c(loop.R = "loop.R", loop_harness.R = "loop_harness.R"), function(f)
  system2("git", c("-C", repo, "show", paste0(commit, ":dev/lean_core/", f)), stdout = TRUE))
arms <- if (mode == "shortcuts") {
  c(list(shortcuts = make_arm(tracked)), lapply(delegations, function(d) make_arm(edited(d))))
} else if (mode == "final") {
  list(final = make_arm(tracked), base_4a3e08b8 = make_arm(at_commit("4a3e08b8")))
} else stop("--mode must be shortcuts or final", call. = FALSE)

work <- file.path(tempdir(), "loop_shortcuts")
dir.create(work, showWarnings = FALSE)
sealed <- list()
for (s in shapes) {
  d <- as.integer(strsplit(s, "x")[[1L]])
  path <- file.path(work, paste0(s, ".duckdb"))
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(r_floor_fixture(d[[1L]], d[[2L]])$bars, db_path = path,
    snapshot_id = paste0("sc_", s), price_basis = "split_adjusted"))
  sealed[[s]] <- path
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
now <- function() proc.time()[["elapsed"]]
run_arm <- function(env, shape, label) {
  db <- file.path(work, paste0("run_", label, ".duckdb"))
  if (file.exists(db)) unlink(db)
  file.copy(sealed[[shape]], db)
  snapshot <- ledgr::ledgr_snapshot_open(db, paste0("sc_", shape), verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- experiment(snapshot)
  clock <- new.env(parent = emptyenv())
  restore <- env$lean_loop_install(hooks = FALSE)
  on.exit(restore(), add = TRUE)
  env$lean_hooks <- utils::modifyList(env$lean_hooks_inert(), list(fold_end = function(stats) clock$pulses <- stats$pulses))
  envelope <- get("ledgr_fold_envelope", envir = ns)
  unlockBinding("ledgr_fold_envelope", ns)
  assign("ledgr_fold_envelope", function(execution, output_handler) {
    t0 <- now(); on.exit(clock$envelope <- now() - t0); envelope(execution, output_handler)
  }, envir = ns)
  lockBinding("ledgr_fold_envelope", ns)
  invisible(gc())
  t0 <- now()
  bt <- ledgr::ledgr_run(exp, run_id = "sc-run", seed = 20260530L)
  whole <- now() - t0
  digest <- rlang::hash(list(ledgr::ledgr_results(bt, "fills"), ledgr::ledgr_results(bt, "equity")))
  close(bt)
  if (is.null(clock$pulses)) stop("arm ", label, " did not run the lean fold on ", shape, call. = FALSE)
  data.frame(shape = shape, arm = label, pulses_s = as.numeric(clock$pulses), envelope_s = clock$envelope,
             whole_s = whole, digest = digest, stringsAsFactors = FALSE)
}

raw <- list()
for (s in shapes) for (a in names(arms)) run_arm(arms[[a]], s, a)   # warm-up, discarded
# Each comparison (the first arm against one other) runs in its own pairs,
# the two arms' order reversed on every pair (cut review R3).
ref <- names(arms)[[1L]]
for (r in seq_len(rounds)) for (s in shapes) for (a in setdiff(names(arms), ref)) {
  pair <- if (r %% 2L == 1L) c(ref, a) else c(a, ref)
  for (b in pair) {
    x <- run_arm(arms[[b]], s, b)
    x$round <- r
    x$comparison <- a
    raw[[length(raw) + 1L]] <- x
    cat(sprintf("pair %d %-10s %-16s %-16s pulses %.3f s  envelope %.3f s  whole %.3f s\n", r, s, a, b,
                x$pulses_s, x$envelope_s, x$whole_s))
  }
}
raw <- do.call(rbind, raw)
utils::write.csv(raw, file.path(out, paste0(mode, "_raw.csv")), row.names = FALSE)
bad <- unlist(lapply(split(raw, raw$shape), function(x) x$arm[x$digest != x$digest[x$arm == ref][[1L]]]))
if (length(bad)) stop("arms with different fills or equity: ", paste(unique(bad), collapse = ", "), call. = FALSE)

# Paired comparison of each other arm against the first, per shape, within
# that comparison's own pairs.
summary <- do.call(rbind, lapply(setdiff(names(arms), ref), function(a) do.call(rbind, lapply(shapes, function(s) {
  x <- raw[raw$shape == s & raw$comparison == a, ]
  p <- merge(x[x$arm == ref, c("round", "pulses_s", "envelope_s", "whole_s")],
             x[x$arm == a, c("round", "pulses_s", "envelope_s", "whole_s")], by = "round", suffixes = c("_ref", "_arm"))
  saving <- (p$pulses_s_arm - p$pulses_s_ref) / p$pulses_s_arm
  data.frame(arm = a, shape = s, rounds = nrow(p),
    ref_pulses_median = stats::median(p$pulses_s_ref), arm_pulses_median = stats::median(p$pulses_s_arm),
    ref_envelope_median = stats::median(p$envelope_s_ref), arm_envelope_median = stats::median(p$envelope_s_arm),
    ref_whole_median = stats::median(p$whole_s_ref), arm_whole_median = stats::median(p$whole_s_arm),
    saving_median = stats::median(saving), saving_below_002 = sum(saving < 0.02), saving_min = min(saving),
    saving_max = max(saving), stringsAsFactors = FALSE)
}))))
if (mode == "shortcuts") {
  summary$decision <- ave(seq_len(nrow(summary)), summary$arm, FUN = function(i) {
    x <- summary[i, ]
    n <- x$rounds
    below <- all(x$saving_median < 0.02) && all(x$saving_below_002 >= n - 1L)
    above <- any(n - x$saving_below_002 >= n - 1L)
    rep(if (below) 1L else if (above) 2L else 3L, length(i))
  })
  summary$decision <- c("delete", "keep", "unresolved")[summary$decision]
}
utils::write.csv(summary, file.path(out, paste0(mode, "_summary.csv")), row.names = FALSE)
print(summary, row.names = FALSE)

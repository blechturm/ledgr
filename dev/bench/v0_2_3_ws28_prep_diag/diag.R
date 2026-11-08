# WS28 diagnostic before the LDG-3217 timing gate (maintainer 2026-11-08):
# where lean preparation and the registered reads lose time against the pin
# on 500 x 5,040, isolated, before another expensive timing record.
#
#   Rscript dev/bench/v0_2_3_ws28_prep_diag/diag.R --lib=<pinned lib>
#     --out=<dir> --mode=clock|stages [--rounds=3] [--arms=pinned,lean]
#
# Arms: the pinned build, and lean preparation as committed (whole planes,
# chunked hydration: LDG-3216 after the whole-planes amendment). The tile
# arms this diagnostic first compared (inst, inst_one, time, plain_src,
# plain, fast_g, fast, whole) ran on the tile prepare.R; they and their
# evidence are recorded at e17559aa. LDG-3217 uses the clock mode as its
# preview before the timing record.
#
# clock   cut12-prep-1's clocks (prep, r1-r6) per slot, arms alternating;
#         unwrapped. Writes clock.csv.
# stages  one wrapped run per arm: inclusive and self seconds and calls for
#         every ledgr_history_*/projection/availability/precompute function
#         and every lean_* function, split by whether a public read is on the
#         stack. Wrapping inflates absolute times; use it for shares only.
#         Writes stages.csv.
# Every slot's work string (decided pulses, fills, final equity, a digest of
# every read's results) must be identical across arms.

repo <- normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
  value = TRUE)[[1L]]), winslash = "/")), "..", "..", ".."), winslash = "/")
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(default %||% stop("--", name, "= is required", call. = FALSE))
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
`%||%` <- function(x, y) if (is.null(x)) y else x
out <- arg("out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
mode <- arg("mode")
rounds <- as.integer(arg("rounds", if (mode == "clock") "3" else "1"))
arms <- strsplit(arg("arms", "pinned,lean"), ",")[[1L]]

source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(arg("lib"), debug = FALSE)
source(file.path(repo, "dev/bench/timing/protocols/cut12-prep-1/workloads.R"))

# One sealed store, copied into each slot (the workload builds it per slot).
prebuilt <- file.path(out, "prebuilt.duckdb")
if (!file.exists(prebuilt)) {
  ledgr::ledgr_snapshot_close(cut12_prep_snapshot(500L, 5040L, prebuilt, "cut12_prep_500x5040"))
}
cut12_prep_snapshot <- function(n_inst, n_days, db_path, snapshot_id, seed = NULL) {
  if (!file.copy(prebuilt, db_path, overwrite = TRUE)) stop("could not copy the prebuilt store")
  ledgr::ledgr_snapshot_open(db_path, snapshot_id, verify = FALSE)
}

arm_setup <- function(arm) {
  if (arm == "pinned") return(function() NULL)
  stopifnot(arm == "lean")
  lean$lean_prepare_install()
}

# --- stage wrappers ---------------------------------------------------------
ST <- new.env()
unsafe <- "sys\\.call|match\\.call|sys\\.function|nargs|substitute|parent\\.frame|sys\\.frame|environment\\(\\)"
skip <- c("lean_prepare_install", "lean_core_load", "lean_core_source", "lean_pinned")
wrappable <- function(env, pattern) {
  nms <- ls(env, all.names = TRUE)
  nms <- nms[grepl(pattern, nms) & !grepl("<-", nms, fixed = TRUE) & !nms %in% skip]
  nms[vapply(nms, function(n) {
    f <- get(n, envir = env)
    is.function(f) && !is.primitive(f) && !grepl(unsafe, paste(deparse(body(f)), collapse = "\n"))
  }, TRUE)]
}
make_wrapper <- function(name, orig) {
  force(name); force(orig)
  read_entry <- name %in% c("ledgr_history_matrix", "ledgr_history_frame")
  structure(function(...) {
    outer_read <- read_entry && ST$reads == 0L
    if (read_entry) ST$reads <- ST$reads + 1L
    key <- paste(name, if (ST$reads > 0L) "read" else "prep", sep = "\t")
    saved <- ST$child
    ST$child <- 0
    t0 <- as.numeric(Sys.time())
    on.exit({
      el <- as.numeric(Sys.time()) - t0
      ST$incl[[key]] <- (ST$incl[[key]] %||% 0) + el
      ST$self[[key]] <- (ST$self[[key]] %||% 0) + el - ST$child
      ST$calls[[key]] <- (ST$calls[[key]] %||% 0L) + 1L
      ST$child <- saved + el
      if (read_entry) ST$reads <- ST$reads - 1L
    })
    orig(...)
  }, diag_orig = orig)
}
wrap_all <- function() {
  ns <- asNamespace("ledgr")
  undo <- list()
  # The feature-engine version fingerprints history functions by body; it
  # sees each wrapped function's original.
  fp <- get("ledgr_function_fingerprint", envir = ns)
  undo[[1L]] <- list(env = ns, name = "ledgr_function_fingerprint", value = fp, locked = TRUE)
  unlockBinding("ledgr_function_fingerprint", ns)
  assign("ledgr_function_fingerprint", function(fn, ...) fp(attr(fn, "diag_orig") %||% fn, ...), envir = ns)
  lockBinding("ledgr_function_fingerprint", ns)
  targets <- list(list(env = ns, pattern = "^ledgr_(history|projection|availability|precompute)_", locked = TRUE),
                  list(env = lean, pattern = "^(ledgr|lean)_", locked = FALSE))
  for (t in targets) for (n in wrappable(t$env, t$pattern)) {
    orig <- get(n, envir = t$env)
    undo[[length(undo) + 1L]] <- list(env = t$env, name = n, value = orig, locked = t$locked)
    if (t$locked) unlockBinding(n, t$env)
    assign(n, make_wrapper(n, orig), envir = t$env)
    if (t$locked) lockBinding(n, t$env)
  }
  function() for (u in rev(undo)) {
    if (u$locked) unlockBinding(u$name, u$env)
    assign(u$name, u$value, envir = u$env)
    if (u$locked) lockBinding(u$name, u$env)
  }
}

# --- slots ------------------------------------------------------------------
clock <- list()
stages <- list()
for (r in seq_len(rounds)) for (arm in arms) {
  wd <- file.path(out, sprintf("slot_%s_%d", arm, r))
  unlink(wd, recursive = TRUE)
  dir.create(wd, showWarnings = FALSE)
  restore <- arm_setup(arm)
  unwrap <- function() NULL
  if (mode == "stages") {
    ST$incl <- list(); ST$self <- list(); ST$calls <- list(); ST$child <- 0; ST$reads <- 0L
    unwrap <- wrap_all()
  }
  t0 <- proc.time()[["elapsed"]]
  res <- tryCatch(cut12_prep(list(shape = "500x5040"), wd), finally = { unwrap(); restore() })
  wall <- proc.time()[["elapsed"]] - t0
  clock[[length(clock) + 1L]] <- data.frame(round = r, arm = arm, wall = round(wall, 2),
                                            t(round(res$seconds, 4)), work = res$work)
  print(clock[[length(clock)]][, 1:10], row.names = FALSE)
  if (mode == "stages") {
    keys <- names(ST$incl)
    parts <- do.call(rbind, strsplit(keys, "\t", fixed = TRUE))
    stages[[length(stages) + 1L]] <- data.frame(arm = arm, fn = parts[, 1L], phase = parts[, 2L],
      calls = unlist(ST$calls[keys]), incl = round(unlist(ST$incl[keys]), 4),
      self = round(unlist(ST$self[keys]), 4), row.names = NULL)
  }
  unlink(wd, recursive = TRUE)
}
clock <- do.call(rbind, clock)
same <- length(unique(clock$work)) == 1L
cat("\nwork strings identical across arms and rounds:", same, "\n")
utils::write.csv(clock, file.path(out, paste0(mode, "_clock.csv")), row.names = FALSE)
if (mode == "clock") {
  med <- aggregate(. ~ arm, data = clock[, c("arm", "prep", paste0("r", 1:6))], FUN = stats::median)
  base <- med[med$arm == "pinned", -1L]
  if (nrow(base)) {
    ratio <- cbind(arm = med$arm, round(sweep(as.matrix(med[, -1L]), 2L, unlist(base), "/"), 3))
    cat("\nmedian seconds\n"); print(med, row.names = FALSE)
    cat("\nmedian ratio to pinned\n"); print(as.data.frame(ratio), row.names = FALSE)
  }
}
if (mode == "stages") utils::write.csv(do.call(rbind, stages), file.path(out, "stages.csv"), row.names = FALSE)
if (!same) quit(save = "no", status = 1L)

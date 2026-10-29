# RNG baseline successor probe (LDG-3161; ws2_rng_design.md Sections 8 and
# 8.2.1).
#
# Sources the unchanged RNG baseline probe (dev/bench/v0_2_3_rng_baseline/
# probe.R), with its fixtures, strategies, canonical writer and record writer,
# and replaces only its observation in the ways Section 8 permits:
#
#   1. the pulse_seeds table and the rule_overlap "current" rule read
#      ledgr_pulse_seeds (the deleted scalar helper is gone);
#   2. the census observes the accessor ledgr_pulse_seed_at, taking the
#      execution seed from the fold's services;
#   3. the census splits RNGkind() queries from argument-bearing mutations,
#      records their immediate callers, and appends the seven Section 8.2.1
#      observer columns (typed NA in the two copy rows).
#
# rp_pulse_seeds, rp_rules$current, rp_census_case and rp_census are the only
# functions redefined; each keeps the original's body except for those edits.
#
# Usage: Rscript probe.R [--out=<dir>]
#   --out defaults to records/ next to this script

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  source(file.path(here, "..", "lib.R"))
})
# Loads the package tree that holds the original probe (this tree).
source(file.path(sr_root, "dev", "bench", "v0_2_3_rng_baseline", "probe.R"))

# Edit 1: the current rule reads ledgr_pulse_seeds.
rp_pulse_seeds <- function() {
  g <- expand.grid(pulse_idx = c(1:10, 100L, 1000L, 7200L),
    execution_seed = c(-1L, 0L, 1L, 2L, 7L, 2591L, .Machine$integer.max), KEEP.OUT.ATTRS = FALSE)
  g$pulse_seed <- mapply(function(s, p) rp_fn("ledgr_pulse_seeds")(s, p), g$execution_seed, g$pulse_idx)
  a0_canon(g[c("execution_seed", "pulse_idx", "pulse_seed")], "pulse_seeds", c("execution_seed", "pulse_idx"))
}
rp_rules$current <- function(s, p) mapply(function(a, b) rp_fn("ledgr_pulse_seeds")(a, b), s, p)

# Edits 2 and 3: the census observer.
.sr_trace_rngkind <- function(kind, normal.kind, sample.kind) {
  heads <- vapply(sys.calls(), function(cl) paste(deparse(cl[[1L]], nlines = 1L), collapse = ""), character(1))
  at <- max(which(heads == "RNGkind"))
  query <- is.null(kind) && is.null(normal.kind) && is.null(sample.kind)
  rp_log$kind[[length(rp_log$kind) + 1L]] <- data.frame(query = query,
    caller = if (at > 1L) substr(heads[[at - 1L]], 1L, 60L) else "<top>", stringsAsFactors = FALSE)
}

rp_census_case <- function(path, seed, expr_fn) {
  rp_log$rng <- list(); rp_log$pulse <- list(); rp_log$kind <- list()
  rp_log$preserve <- 0L; rp_log$vectors <- 0L
  entry_seed_present <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  # Each wrapper forces its original at creation: a0_with_patches() builds
  # them in a loop, so an unforced promise would bind the last original.
  counter <- list(
    ledgr_pulse_seed_at = function(orig) { force(orig); function(services, pulse_idx) {
      v <- orig(services, pulse_idx)
      execution_seed <- services$execution_seed
      rp_log$pulse[[length(rp_log$pulse) + 1L]] <- c(if (is.null(execution_seed)) NA else execution_seed, if (is.null(v)) NA else v)
      v
    }},
    ledgr_pulse_seeds = function(orig) { force(orig); function(execution_seed, pulse_idx) {
      rp_log$vectors <- rp_log$vectors + 1L
      orig(execution_seed, pulse_idx)
    }},
    ledgr_rng_preserve_caller = function(orig) { force(orig); function(expr) {
      rp_log$preserve <- rp_log$preserve + 1L
      orig(expr)
    }}
  )
  suppressMessages({
    trace("set.seed", tracer = quote(.rp_trace_log("set.seed", seed, kind)), where = baseenv(), print = FALSE)
    trace("RNGkind", tracer = quote({
      .rp_trace_log("RNGkind", NULL, kind)
      .sr_trace_rngkind(kind, normal.kind, sample.kind)
    }), where = baseenv(), print = FALSE)
  })
  value <- tryCatch(a0_with_patches(counter, suppressWarnings(expr_fn())), error = function(e) e,
    finally = suppressMessages({
      untrace("set.seed", where = baseenv()); untrace("RNGkind", where = baseenv())
    }))
  rng <- do.call(rbind, c(list(data.frame(fn = character(), seed = character(), kind = character(),
    caller = character())), rp_log$rng))
  kinds <- do.call(rbind, c(list(data.frame(query = logical(), caller = character())), rp_log$kind))
  pulse <- do.call(rbind, c(list(matrix(numeric(), 0L, 2L)), rp_log$pulse))
  ss <- rng[rng$fn == "set.seed", , drop = FALSE]
  u <- function(x) if (length(x)) paste(sort(unique(x), method = "radix"), collapse = ",") else ""
  list(value = value, row = data.frame(path = path, seed_arg = if (is.null(seed)) "NULL" else as.character(seed),
    outcome = if (inherits(value, "error")) sprintf("ERROR %s: %s", class(value)[[1L]], conditionMessage(value)) else "ok",
    set_seed_calls = nrow(ss), set_seed_seeds = u(ss$seed), set_seed_kind_args = u(ss$kind),
    set_seed_callers = u(ss$caller), rngkind_calls = sum(rng$fn == "RNGkind"),
    pulse_seed_calls = nrow(pulse), pulse_seed_nonnull = sum(!is.na(pulse[, 2L])),
    pulse_seed_execution_seeds = u(format(pulse[, 1L][!is.na(pulse[, 1L])], scientific = FALSE, trim = TRUE)),
    stringsAsFactors = FALSE),
    extra = data.frame(entry_seed_present = entry_seed_present, preserve_calls = rp_log$preserve,
      rngkind_query_calls = sum(kinds$query), rngkind_query_callers = u(kinds$caller[kinds$query]),
      rngkind_mutation_calls = sum(!kinds$query), rngkind_mutation_callers = u(kinds$caller[!kinds$query]),
      pulse_seed_vectors = rp_log$vectors, stringsAsFactors = FALSE))
}

rp_census <- function(work) {
  fx <- a0_fx_walk_forward(file.path(work, "census.duckdb"))
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  rows <- list(); extras <- list()
  copy_extra <- data.frame(entry_seed_present = NA, preserve_calls = NA_integer_, rngkind_query_calls = NA_integer_,
    rngkind_query_callers = "", rngkind_mutation_calls = NA_integer_, rngkind_mutation_callers = "",
    pulse_seed_vectors = NA_integer_, stringsAsFactors = FALSE)
  keep <- function(r) { rows[[length(rows) + 1L]] <<- r$row; extras[[length(extras) + 1L]] <<- r$extra }
  for (seed in list(NULL, fx$seed)) {
    tag <- if (is.null(seed)) "null" else "seed"
    r <- rp_census_case("ledgr_run", seed, function() close(ledgr_run(fx$exp, params = list(qty = 2),
      run_id = paste0("census-run-", tag), seed = seed)))
    keep(r)
    r <- rp_census_case("ledgr_sweep", seed, function() ledgr_sweep(fx$exp, fx$grid, seed = seed))
    keep(r)
    sw <- r$value
    r$row$path <- "ledgr_sweep (stored candidate execution_seed)"
    r$row[, setdiff(names(r$row), c("path", "seed_arg"))] <- ""
    r$row$set_seed_seeds <- paste(ifelse(is.na(sw$execution_seed), "NA", sw$execution_seed), collapse = ",")
    r$extra <- copy_extra
    keep(r)
    r <- rp_census_case("ledgr_promote", seed, function() close(ledgr_promote(fx$exp, ledgr_candidate(sw, 1L),
      run_id = paste0("census-promote-", tag))))
    keep(r)
    r <- rp_census_case("ledgr_walk_forward", seed, function() {
      wf <- ledgr_walk_forward(fx$exp, grid = fx$grid, folds = fx$folds,
        selection_rule = ledgr_rule_argmax("sharpe_ratio"), seed = seed)
      lapply(wf$test_runs, close)
    })
    keep(r)
  }
  out <- do.call(rbind, rows)
  out$default_seed <- vapply(out$path, function(p) {
    f <- sub(" .*", "", p)
    if (f == "ledgr_promote") "<candidate$execution_seed>" else paste(deparse(formals(get(f, envir = rp_ns))$seed), collapse = "")
  }, character(1))
  out$case <- sprintf("%02d", seq_len(nrow(out)))
  out <- cbind(out, do.call(rbind, extras))
  a0_canon(out, "census", "case")
}

out_dir <- sr_arg("out", file.path(sr_dir, "rng", "records"))
work <- file.path(tempdir(), "rng_successor_work")
dir.create(work, showWarnings = FALSE)
if (dir.exists(out_dir)) invisible(file.remove(list.files(out_dir, recursive = TRUE, full.names = TRUE)))
tables <- rp_records(work)
manifest <- rp_write_records(tables, out_dir)
cat(sprintf("rng successor probe: %d tables, %s bytes -> %s (root %s)\n", nrow(manifest),
  sum(as.numeric(manifest$bytes)), out_dir, rp_root))

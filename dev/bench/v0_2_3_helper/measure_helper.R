# Cut 17 (LDG-3232): the sizing helpers' cost on genuine pulse views.
#
#   Rscript dev/bench/v0_2_3_helper/measure_helper.R --lib=<library> --out=<dir>
#     --mode=timing|sites [--sizes=10,500,1166] [--target-s=3]
#
# --mode=timing runs under the host policy (High performance plan, P-core
# affinity through dev/bench/v0_2_3_lean_tuning_profile/pcore.ps1). For each
# size and verb:
# - first use: one call on each of K untouched views captured on
#   consecutive pulses (the first view supplies the arguments and is not
#   timed), K chosen so the batch lasts about one second;
# - cached context: `reps` calls on one warmed view, reps chosen so the
#   batch lasts about --target-s seconds.
# Writes timings.csv and host_timing.txt.
#
# --mode=sites (same host policy) attributes the cached call to the rewrite
# sites of sites.csv. Rprof is not used: on this host it records about 3-50
# samples per second (the system timer), too few to attribute a call. One
# call runs the library commit's helper code (parsed from git, marker file)
# with a hook that keeps the call's local variables just before the notes
# update; each site's expression is then evaluated on those real operands
# repeatedly for about 0.3 s and its per-evaluation time divided by the
# whole call's time. Shares are inclusive and may overlap (S12 includes its
# setdiff; S15_16 is the name check inside S17). Writes sites_timing.csv and
# host_sites.txt.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
out <- opt("out"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
mode <- opt("mode", "")
if (!mode %in% c("timing", "sites")) stop("--mode must be timing or sites", call. = FALSE)
sizes <- as.integer(strsplit(opt("sizes", "10,500,1166"), ",")[[1L]])
target_s <- as.numeric(opt("target-s", "3"))
suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
ns <- asNamespace("ledgr")
commit <- trimws(readLines(file.path(lib, "LEDGR_INSTALLED_FROM_COMMIT"), warn = FALSE)[[1L]])
sys.source(file.path(repo, "dev/spikes/r_floor/fixture.R"), envir = globalenv(), keep.source = FALSE)
sys.source(file.path(here, "views.R"), envir = globalenv(), keep.source = FALSE)

# the helper functions of the library's commit, with a hook in
# ledgr_target_size() that keeps the call's locals before the notes update
src_env <- new.env(parent = ns)
for (f in c("R/strategy-helpers.R", "R/strategy-types.R")) {
  eval(parse(text = system2("git", c("-C", repo, "show", paste0(commit, ":", f)), stdout = TRUE), keep.source = FALSE), envir = src_env)
}
site_capture <- new.env()
local({
  f <- src_env$ledgr_target_size
  b <- as.list(body(f))
  idx <- which(vapply(b, function(x) startsWith(paste(deparse(x), collapse = ""), "notes <- unclass(ctx)"), TRUE))
  if (length(idx) != 1L) stop("site hook: the notes statement was not found once in ledgr_target_size()", call. = FALSE)
  body(f) <- as.call(c(b[seq_len(idx - 1L)], quote(site_capture$env <- environment()), b[idx:length(b)]))
  environment(f) <- src_env
  assign("ledgr_target_size", f, envir = src_env)
})
environment(src_env$ledgr_target_size) <- list2env(list(site_capture = site_capture), parent = src_env)
site_locals <- function(verb, a) {
  site_capture$env <- NULL
  if (verb == "rebalance") src_env$ledgr_target_rebalance(a$ctx, weights = a$w, keep = a$k, capital_base = "total_equity")
  else src_env$ledgr_target_adjust(a$ctx, weights = a$w, add_value = a$a, exit = a$ex)
  e <- site_capture$env
  if (is.null(e)) stop("site hook did not fire", call. = FALSE)
  e$raw_w <- a$w; e$raw_a <- a$a; e$raw_keep <- a$k; e$raw_exit <- a$ex
  e
}
# Each site's operation, evaluated on the captured operands (sites.csv).
site_exprs <- list(
  S01a = quote(union(weighted_ids, addition_ids)),
  S01b = quote(buyable[match(requested_ids, universe)]),
  S02 = quote(intersect(weighted_ids, addition_ids)),
  S03a = quote(setdiff(held_leavers, explicit_keep)),
  S04 = quote(buyable & !logical_keep & !universe %in% explicit_keep),
  S05a = quote(union(explicit_keep, universe[logical_keep & (member | !identical(index_leavers, "sell"))])),
  S05b = quote(match(keep_ids, universe)),
  S06 = quote(intersect(weighted_ids, keep_ids)),
  S07 = quote(union(intersect(weighted_ids, universe[exits]), intersect(addition_ids, universe[exits]))),
  S08a = quote(universe[preserve & position != 0 & !universe %in% weighted_ids]),
  S08b = quote(match(preserved_ids, universe)),
  S09 = quote(union(skipped, skipped_weight)),
  S11 = quote(union(character(), skipped)),
  S12a = quote(ledgr_target_named_amount(raw_w, "weights", universe, allow_null = TRUE)),
  S12b = quote(ledgr_target_named_amount(raw_a, "add_value", universe, allow_null = TRUE)),
  S13 = quote(ledgr_target_keep(raw_keep, universe)),
  S14 = quote(ledgr_target_logical(raw_exit, universe, "exit")),
  S15_16 = quote(ledgr_strategy_type_check_names(target, "x", universe = universe, full_universe = TRUE)),
  S17 = quote(ledgr_target(target, universe = universe, origin = "ledgr_target_rebalance")))
# Whether the site's statement ran on the captured call, read from which
# branch-local variables exist (the rebalance branch defines parsed_keep,
# the adjust branch conflict; the positive-weight block skipped_weight).
site_executed <- function(s, env) {
  has <- function(v) exists(v, envir = env, inherits = FALSE)
  reb <- has("parsed_keep"); adj <- has("conflict")
  notes <- unclass(env$ctx)[[".notes"]]
  switch(s,
    S03a = , S04 = , S05a = , S05b = , S06 = , S13 = reb,
    S07 = adj,
    S14 = adj || (reb && !is.null(env$raw_keep) && !is.character(env$raw_keep)),
    S09 = has("skipped_weight"),
    S11 = is.environment(notes) && length(env$skipped) > 0L,
    TRUE)
}
elapsed <- function() as.numeric(Sys.time())
resolution <- local({ x <- numeric(); t <- elapsed(); while (length(x) < 20L) { u <- elapsed(); if (u > t) { x <- c(x, u - t); t <- u } }; stats::median(x) })
time_expr <- function(e, env, budget = 0.3) {
  eval(e, env)
  m <- 0L; t0 <- elapsed()
  while (elapsed() - t0 < budget) { for (i in 1:50) eval(e, env); m <- m + 50L }
  1e6 * (elapsed() - t0) / m
}

timings <- list(); sites_out <- list()
for (n in sizes) {
  for (verb in c("rebalance", "adjust")) {
    probe <- helper_capture_views(n, keep = 4L)
    a <- helper_view_args(probe$views[[1L]], verb)
    helper_call(verb, a)
    m <- 0L; t0 <- elapsed(); while (elapsed() - t0 < 0.3) { helper_call(verb, a); m <- m + 1L }; per <- (elapsed() - t0) / m
    reps <- max(100L, as.integer(ceiling(target_s / per)))
    if (mode == "timing") {
      k <- max(50L, as.integer(ceiling(1 / per)))
      cap <- helper_capture_views(n, keep = 4:(4L + k), pulses = 4L + k)
      a <- helper_view_args(cap$views[[1L]], verb)
      fresh <- cap$views[-1L]
      invisible(gc(FALSE))
      t0 <- elapsed()
      for (v in fresh) { a$ctx <- v; helper_call(verb, a) }
      first_s <- elapsed() - t0
      a$ctx <- cap$views[[1L]]
      helper_call(verb, a)
      invisible(gc(FALSE))
      t0 <- elapsed(); for (i in seq_len(reps)) helper_call(verb, a); cached_s <- elapsed() - t0
      timings[[length(timings) + 1L]] <- data.frame(instruments = n, verb = verb, first_use_calls = length(fresh),
        first_use_s = first_s, first_use_us = 1e6 * first_s / length(fresh), cached_calls = reps, cached_s = cached_s,
        cached_us = 1e6 * cached_s / reps, timer_resolution_s = resolution,
        resolution_share = resolution / min(first_s, cached_s), stringsAsFactors = FALSE)
      cat(sprintf("%4d %-9s first use %7.1f us (%d views), cached %7.1f us (%d calls)\n", n, verb, 1e6 * first_s / length(fresh),
                  length(fresh), 1e6 * cached_s / reps, reps))
    } else {
      # the call's locals just before the notes update, from the library's own code
      site_env <- site_locals(verb, a)
      whole <- time_expr(quote(helper_call(verb, a)), environment())
      for (s in names(site_exprs)) {
        e <- site_exprs[[s]]
        if (!all(all.vars(e) %in% c(ls(site_env, all.names = TRUE), "ledgr_target_named_amount", "ledgr_target_keep",
                                      "ledgr_target_logical", "ledgr_strategy_type_check_names", "ledgr_target", "union",
                                      "intersect", "setdiff", "match", "identical"))) next
        us <- time_expr(e, site_env)
        sites_out[[length(sites_out) + 1L]] <- data.frame(instruments = n, verb = verb, site = sub("[a-z]$", "", s), part = s,
          expression = paste(deparse(e, width.cutoff = 500L), collapse = " "), executed = site_executed(s, site_env),
          site_us = us, call_us = whole, share_of_call = us / whole, stringsAsFactors = FALSE)
      }
      cat(sprintf("%4d %-9s sites timed against a %.1f us call\n", n, verb, whole))
    }
  }
}
host <- c(paste("mode:", mode), paste("library:", lib), paste("installed from:", commit), paste("R:", R.version.string),
          paste("collapse:", as.character(utils::packageVersion("collapse"))),
          paste("power plan:", paste(system2("powercfg", "/getactivescheme", stdout = TRUE), collapse = " ")),
          paste("process affinity:", tryCatch(system2("powershell", c("-NoProfile", "-Command",
            shQuote(sprintf("(Get-Process -Id %d).ProcessorAffinity", Sys.getpid()))), stdout = TRUE)[[1L]], error = function(e) NA)),
          paste("timer resolution s:", resolution), paste("finished:", format(Sys.time(), tz = "UTC", usetz = TRUE)))
if (mode == "timing") {
  utils::write.csv(do.call(rbind, timings), file.path(out, "timings.csv"), row.names = FALSE)
  writeLines(host, file.path(out, "host_timing.txt"))
} else {
  utils::write.csv(do.call(rbind, sites_out), file.path(out, "sites_timing.csv"), row.names = FALSE)
  writeLines(host, file.path(out, "host_sites.txt"))
}

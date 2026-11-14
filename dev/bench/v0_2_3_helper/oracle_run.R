# Cut 17 (LDG-3232): one arm of the differential oracle.
#
#   Rscript dev/bench/v0_2_3_helper/oracle_run.R --lib=<arm library> --source=<commit>
#     --out=<file.rds> [--mutation=<id>] [--expect-lib=<path>] [--drop-case=<id>]
#
# Loads ledgr only from --lib and refuses unless the loaded namespace comes
# from that library and every function of Cut 17 decision (2) equals the
# one parsed from --source's R files (so an arm cannot silently resolve a
# changed callee from another build). --expect-lib (controls only) names the
# library the arm claims to be; a mismatch refuses. --mutation applies one
# deliberate change from oracle_mutations.R to the loaded namespace (the
# source comparison then expects exactly that change).
#
# Captures genuine pulse views at 10, 500 and 1,166 instruments from short
# runs of the arm's own package, then evaluates every case of
# oracle_cases.R with the same invocation expression, a fresh .notes
# environment per evaluation, and records the value, the ordered warnings
# and messages, the terminal condition (class, message, call, parent and
# payload fields; no trace), and the notes bindings before and after.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
source_commit <- opt("source")
out <- opt("out")
mutation <- opt("mutation", "")
expect_lib <- opt("expect-lib", "")
drop_case <- opt("drop-case", "")
if (is.null(source_commit) || is.null(out)) stop("oracle_run.R: --source and --out are required", call. = FALSE)

if (nzchar(expect_lib) && !identical(normalizePath(expect_lib, winslash = "/", mustWork = FALSE), lib)) {
  cat("CONTROL REFUSED: the arm claims library", expect_lib, "but loads", lib, "\n")
  quit(status = 3L)
}
suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
ns <- asNamespace("ledgr")
loaded <- normalizePath(getNamespaceInfo(ns, "path"), winslash = "/")
if (!identical(dirname(loaded), lib)) {
  cat("ARM REFUSED: ledgr loaded from", loaded, "not from", lib, "\n")
  quit(status = 3L)
}
marker <- file.path(lib, "LEDGR_INSTALLED_FROM_COMMIT")
installed_from <- if (file.exists(marker)) trimws(readLines(marker, warn = FALSE)[[1L]]) else NA_character_

changed <- c("ledgr_target_size", "ledgr_target_named_amount", "ledgr_target_keep", "ledgr_target_logical",
             "ledgr_target", "ledgr_strategy_type_check_names")
sys.source(file.path(here, "oracle_mutations.R"), envir = globalenv(), keep.source = FALSE)
src_env <- new.env(parent = ns)
for (f in c("R/strategy-helpers.R", "R/strategy-types.R")) {
  txt <- system2("git", c("-C", repo, "show", paste0(source_commit, ":", f)), stdout = TRUE)
  eval(parse(text = txt, keep.source = FALSE), envir = src_env)
}
if (nzchar(mutation)) oracle_apply_mutation(mutation, ns, src_env)
# Control (--mixed-from=<commit>): rebind ledgr_target_size() to an
# environment in which ledgr_target_named_amount() is that commit's, as an
# arm that resolves a changed callee from another build would. The
# resolution check below must refuse it.
mixed_from <- opt("mixed-from", "")
if (nzchar(mixed_from)) {
  other <- new.env(parent = ns)
  eval(parse(text = system2("git", c("-C", repo, "show", paste0(mixed_from, ":R/strategy-helpers.R")), stdout = TRUE),
             keep.source = FALSE), envir = other)
  f <- get("ledgr_target_size", envir = ns)
  environment(f) <- list2env(list(ledgr_target_named_amount = other$ledgr_target_named_amount), parent = ns)
  unlockBinding("ledgr_target_size", ns); assign("ledgr_target_size", f, envir = ns); lockBinding("ledgr_target_size", ns)
}
fn_digest <- function(f) digest::digest(deparse(f, control = c("keepNA", "keepInteger", "niceNames", "showAttributes")))
mismatch <- changed[vapply(changed, function(n) !identical(fn_digest(get(n, envir = ns)), fn_digest(get(n, envir = src_env))), TRUE)]
if (length(mismatch)) {
  cat("ARM REFUSED: loaded functions differ from", source_commit, "source:", paste(mismatch, collapse = ", "), "\n")
  quit(status = 3L)
}
# Resolution: every function of the two helper files, as loaded, must be
# enclosed by the arm's own namespace, so each callee it names resolves from
# this arm's build (a body check alone cannot see a rebound environment).
defined <- intersect(ls(src_env, all.names = TRUE), ls(ns, all.names = TRUE))
defined <- defined[vapply(defined, function(n) is.function(get(n, envir = ns)), TRUE)]
foreign <- defined[!vapply(defined, function(n) identical(environment(get(n, envir = ns)), ns), TRUE)]
if (length(foreign)) {
  cat("ARM REFUSED: functions not enclosed by the arm's namespace:", paste(foreign, collapse = ", "), "\n")
  quit(status = 3L)
}

# ---- genuine pulse views ---------------------------------------------------
sys.source(file.path(repo, "dev/spikes/r_floor/fixture.R"), envir = globalenv(), keep.source = FALSE)
sys.source(file.path(here, "views.R"), envir = globalenv(), keep.source = FALSE)
caps <- lapply(c(10L, 500L, 1166L), function(n) helper_capture_views(n, keep = 4L))
oracle_views <- stats::setNames(lapply(caps, function(x) x$views[[1L]]), c("v10", "v500", "v1166"))
provenance <- do.call(rbind, lapply(caps, `[[`, "provenance"))

# ---- evaluate the cases ----------------------------------------------------
sys.source(file.path(here, "oracle_cases.R"), envir = globalenv(), keep.source = FALSE)
cases <- oracle_cases()
with_notes <- function(ctx, notes) {
  if (is.null(ctx) || is.null(notes)) return(list(ctx = ctx, env = NULL))
  env <- new.env(parent = emptyenv())
  for (n in names(notes)) assign(n, notes[[n]], envir = env)
  cls <- class(ctx)
  x <- unclass(ctx)
  x$.notes <- env
  class(x) <- cls
  list(ctx = x, env = env)
}
snap_notes <- function(env) if (is.null(env)) NULL else as.list(env, all.names = TRUE, sorted = TRUE)
# One normalizer for terminal errors, their parents (recursively), warnings
# and messages: class, message, call, every payload field (presence and
# value) and the parent. Only the backtrace (`trace`) is excluded.
cond_fields <- function(c) {
  if (is.null(c)) return(NULL)
  f <- unclass(c)
  list(class = class(c), message = conditionMessage(c), call = conditionCall(c),
       parent = cond_fields(f$parent),
       fields = f[setdiff(names(f), c("message", "call", "trace", "parent"))],
       field_names = setdiff(names(f), "trace"))
}
run_case <- function(case) {
  data <- case$data()
  w <- with_notes(data$ctx, if (is.null(case$notes)) NULL else case$notes)
  if (!is.null(data$ctx)) data$ctx <- w$ctx
  env <- list2env(data, parent = globalenv())
  signals <- list()
  before <- snap_notes(w$env)
  value <- NULL
  err <- NULL
  err <- tryCatch({
    value <- withCallingHandlers(eval(case$expr, env),
      warning = function(c) { signals[[length(signals) + 1L]] <<- c(list(type = "warning"), cond_fields(c)); invokeRestart("muffleWarning") },
      message = function(c) { signals[[length(signals) + 1L]] <<- c(list(type = "message"), cond_fields(c)); invokeRestart("muffleMessage") })
    NULL
  }, error = function(e) e)
  # A declared reach predicate is evaluated on the value; on a refusal it is
  # FALSE (the case did not reach its value branch). Refusals and notes are
  # asserted against the manifest's frozen message and notes digest.
  reach <- if (is.function(case$reach)) is.null(err) && isTRUE(case$reach(value)) else NA
  list(id = case$id, expect = case$expect, tag = case$tag, sites = case$sites, view = case$view %||% "",
       outcome = if (is.null(err)) "value" else "error", value = value, error = cond_fields(err), signals = signals,
       notes_before = before, notes_after = snap_notes(w$env), notes_present = !is.null(w$env), reach = reach)
}
`%||%` <- function(a, b) if (is.null(a)) b else a
results <- lapply(cases, run_case)
names(results) <- vapply(results, `[[`, "", "id")
if (nzchar(drop_case)) results[[drop_case]] <- NULL
meta <- list(lib = lib, loaded = loaded, installed_from = installed_from, source = source_commit,
             source_sha = system2("git", c("-C", repo, "rev-parse", source_commit), stdout = TRUE),
             mutation = mutation, R = R.version.string, collapse = as.character(utils::packageVersion("collapse")),
             changed_digests = vapply(changed, function(n) fn_digest(get(n, envir = ns)), ""),
             provenance = provenance, cases = length(results))
saveRDS(list(meta = meta, results = results), out, version = 3L)
cat(sprintf("arm %s: %d cases, mutation '%s', ledgr from %s (installed from %s)\n", source_commit, length(results), mutation,
            lib, installed_from))

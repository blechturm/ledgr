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
fn_digest <- function(f) digest::digest(deparse(f, control = c("keepNA", "keepInteger", "niceNames", "showAttributes")))
mismatch <- changed[vapply(changed, function(n) !identical(fn_digest(get(n, envir = ns)), fn_digest(get(n, envir = src_env))), TRUE)]
if (length(mismatch)) {
  cat("ARM REFUSED: loaded functions differ from", source_commit, "source:", paste(mismatch, collapse = ", "), "\n")
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
cond_fields <- function(c) {
  if (is.null(c)) return(NULL)
  f <- unclass(c)
  drop <- c("message", "call", "trace", "parent", "rlang", "body", "footer", "use_cli_format")
  list(class = class(c), message = conditionMessage(c), call = conditionCall(c),
       parent = if (!is.null(f$parent)) list(class = class(f$parent), message = conditionMessage(f$parent)) else NULL,
       fields = f[setdiff(names(f), drop)], field_names = setdiff(names(f), c("trace", "rlang")))
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
      warning = function(c) { signals[[length(signals) + 1L]] <<- list(type = "warning", class = class(c), message = conditionMessage(c)); invokeRestart("muffleWarning") },
      message = function(c) { signals[[length(signals) + 1L]] <<- list(type = "message", class = class(c), message = conditionMessage(c)); invokeRestart("muffleMessage") })
    NULL
  }, error = function(e) e)
  reach <- if (is.null(err) && is.function(case$reach)) isTRUE(case$reach(value)) else NA
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

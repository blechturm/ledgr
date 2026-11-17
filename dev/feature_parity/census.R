# The feature-engine census (Cut 22 decision 5, LDG-3253).
#
# Walk: every ledgr namespace function reachable, by codetools::findGlobals(),
# from the feature preparation of a run, an implicit sweep, an explicit
# precompute and a pulse inspection (substrate construction and the
# calculation bounds included), from the definition conversion, and from the
# emitted built-in and TTR closures (their called helpers are not part of the
# indicator fingerprint, which hashes the closures' own code and captures).
# Each reached helper gets its file:line and whether
# ledgr_feature_engine_version() binds it.
#
# Check: census.csv classifies every walked helper (missing or extra rows
# fail) as `engine version` (bound by the engine version's helper list),
# `excluded: <reason>` (not a semantic rule of reusable prepared state), or
# `identity: <complete identity>` (bound by another complete identity). Each
# row is proved by replacement: replacing an `engine version` helper must
# move the version, replacing any other must not (helpers the version
# computation itself runs are skipped). A false claim either way fails.
#
#   Rscript census.R --lib=<library> | --source=<tree>  --out=<dir> [--census=<census.csv>]
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else NULL
  }
  if (!is.null(arg("lib"))) {
    suppressPackageStartupMessages(library(ledgr, lib.loc = normalizePath(arg("lib"), winslash = "/")))
    src <- NULL
  } else {
    src <- normalizePath(arg("source"), winslash = "/")
    pkgload::load_all(src, quiet = TRUE, export_all = FALSE)
  }
  ns <- asNamespace("ledgr")
  out <- arg("out")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  fns <- Filter(function(n) is.function(get(n, ns)), ls(ns, all.names = TRUE))
  callees <- function(f) sort(intersect(codetools::findGlobals(f, merge = TRUE), fns))

  roots <- c(
    # substrate construction and calculation bounds (R/history-substrate.R)
    "ledgr_history_substrate", "ledgr_history_substrate_for_experiment", "ledgr_history_calculation_start",
    # definition conversion and the calculation (run)
    "ledgr_precompute_feature_def_from_indicator", "ledgr_history_compute_feature_series",
    "ledgr_projection_from_feature_matrix",
    # the prepared representation (implicit sweep, explicit precompute, pulse inspection)
    "ledgr_precompute_unique_feature_defs", "ledgr_history_precompute_payload", "ledgr_projection_from_payload",
    "ledgr_precompute_history_axis", "ledgr_precompute_available_counts", "ledgr_precompute_warmup_table",
    "ledgr_precompute_feature_union",
    # the five read-side entries left unbound by decision 5 (walked so their
    # dependencies are classified too)
    "ledgr_history_feature_evidence", "ledgr_history_feature_compact", "ledgr_history_plane_lookup",
    "ledgr_history_plane_run", "ledgr_history_feature_planes")
  closures <- list(
    sma = ledgr::ledgr_ind_sma(3), ema = ledgr::ledgr_ind_ema(3), rsi = ledgr::ledgr_ind_rsi(3),
    returns = ledgr::ledgr_ind_returns(1),
    ttr = ledgr::ledgr_ind_ttr("SMA", input = "close", n = 3L),
    ttr_bundle = ns$ledgr_indicator_bundle_indicators(ledgr::ledgr_ind_ttr_outputs("MACD", input = "close", nFast = 2L, nSlow = 3L, nSig = 2L))[[3L]])
  reached <- list()
  queue <- lapply(roots, function(r) list(name = r, via = r))
  for (k in names(closures)) for (slot in c("fn", "series_fn")) {
    for (callee in callees(closures[[k]][[slot]])) queue[[length(queue) + 1L]] <- list(name = callee, via = paste0(k, "$", slot))
  }
  while (length(queue)) {
    item <- queue[[1L]]
    queue <- queue[-1L]
    if (!is.null(reached[[item$name]])) next
    reached[[item$name]] <- item$via
    for (callee in callees(get(item$name, ns))) {
      if (is.null(reached[[callee]])) queue[[length(queue) + 1L]] <- list(name = callee, via = item$via)
    }
  }
  # The engine version's bind list: its `bound <- c(...)` statement.
  find_bound <- function(x) {
    if (!is.call(x)) return(NULL)
    if (identical(x[[1L]], as.name("<-")) && identical(x[[2L]], as.name("bound"))) return(eval(x[[3L]], baseenv()))
    for (part in as.list(x)[-1L]) {
      hit <- find_bound(part)
      if (!is.null(hit)) return(hit)
    }
    NULL
  }
  bound <- find_bound(body(ns$ledgr_feature_engine_version)) %||% character()
  where <- character()
  r_dir <- if (is.null(src)) NULL else file.path(src, "R")
  if (!is.null(r_dir)) {
    for (f in list.files(r_dir, pattern = "[.]R$", full.names = TRUE)) {
      lines <- readLines(f, warn = FALSE)
      hit <- regmatches(lines, regexec("^([A-Za-z0-9_.]+) <- function", lines))
      for (i in which(lengths(hit) == 2L)) where[[hit[[i]][[2L]]]] <- paste0("R/", basename(f), ":", i)
    }
  }
  walk <- data.frame(helper = names(reached), first_root = unlist(reached, use.names = FALSE),
                     location = if (length(where)) unname(where[names(reached)]) else NA_character_,
                     bound = names(reached) %in% bound, stringsAsFactors = FALSE)
  walk <- walk[order(walk$location, walk$helper, method = "radix"), ]
  utils::write.csv(walk, file.path(out, "census_walk.csv"), row.names = FALSE)
  cat("reachable:", nrow(walk), " bound by the engine version:", sum(walk$bound), "\n")
  cat("bound but not reachable:", paste(setdiff(bound, walk$helper), collapse = ", "), "\n")
  census_file <- arg("census")
  if (is.null(census_file)) return(invisible())

  # ---- check ----------------------------------------------------------------
  census <- utils::read.csv(census_file, stringsAsFactors = FALSE)
  bad <- 0L
  fail <- function(...) { cat("FAIL:", ..., "\n"); bad <<- bad + 1L }
  missing <- setdiff(walk$helper, census$helper)
  extra <- setdiff(census$helper, walk$helper)
  if (length(missing)) fail("walked helpers missing from the census:", paste(missing, collapse = ", "))
  if (length(extra)) fail("census rows not reached from the roots:", paste(extra, collapse = ", "))
  kind <- ifelse(census$binding == "engine version", "engine",
                 ifelse(startsWith(census$binding, "excluded: "), "excluded",
                        ifelse(startsWith(census$binding, "identity: "), "identity", "invalid")))
  if (any(kind == "invalid")) fail("rows without a valid binding:", paste(census$helper[kind == "invalid"], collapse = ", "))
  claimed <- census$helper[kind == "engine"]
  if (!setequal(claimed, bound)) {
    fail("census engine rows and the engine's helper list differ:",
         paste(c(setdiff(claimed, bound), setdiff(bound, claimed)), collapse = ", "))
  }
  base <- ns$ledgr_feature_engine_version()
  version_with <- function(h) {
    local_env <- new.env(parent = ns)
    original <- get(h, envir = ns)
    replacement <- function(...) stop("replaced helper")
    assign(h, replacement, envir = local_env)
    f <- ns$ledgr_feature_engine_version
    environment(f) <- local_env
    tryCatch(f(), error = function(e) NA_character_)
  }
  moved <- vapply(census$helper, function(h) {
    v <- version_with(h)
    if (is.na(v)) NA else !identical(v, base)
  }, NA)
  # NA: the version computation itself runs the helper (fingerprint
  # machinery); such a row must not claim an engine binding.
  census$moved <- moved
  wrong <- (kind == "engine" & !(moved %in% TRUE)) | (kind != "engine" & moved %in% TRUE)
  if (any(wrong)) fail("replacement disagrees with the claimed binding:", paste(census$helper[wrong], collapse = ", "))
  utils::write.csv(census, file.path(out, "census_proof.csv"), row.names = FALSE)
  counts <- table(kind)
  print(counts)
  utils::write.csv(as.data.frame(counts), file.path(out, "census_counts.csv"), row.names = FALSE)
  if (bad > 0L) {
    cat("CENSUS CHECK FAIL:", bad, "\n")
    quit(save = "no", status = 1L)
  }
  cat("CENSUS CHECK PASS\n")
})

# Compares two identity.R records. Two modes:
#
# --mode=changed-engine (default; Cut 22 decision 6): every identity equal
# between the base and the candidate, except the engine version, which must
# differ; the candidate reading the base's explicit precompute must refuse it
# with ledgr_precomputed_engine_mismatch before any candidate runs, and the
# base's stored run and sweeps must stay readable.
#
# --mode=unchanged-engine --engine-prefix=<hex> (Cut 23 decision 5b): every
# recorded identity equal, the engine version included; each arm holds
# exactly one engine-version record, equal, starting with the prefix; no
# record is missing or duplicated; the base's explicit precompute is reused
# by the candidate (no refusal, strategy calls made) with the same result
# table as fresh preparation; the base's stored run and sweeps stay readable.
#
#   Rscript identity_check.R --base=<identity.R out> --candidate=<identity.R out --old=base>
#                            [--mode=changed-engine | --mode=unchanged-engine --engine-prefix=<hex>]
local({
  argv <- commandArgs(TRUE)
  arg <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
  }
  read <- function(d) utils::read.csv(file.path(d, "identities.csv"), stringsAsFactors = FALSE, colClasses = "character")
  a <- read(arg("base"))
  b <- read(arg("candidate"))
  mode <- arg("mode", "changed-engine")
  if (!mode %in% c("changed-engine", "unchanged-engine")) stop("unknown --mode: ", mode)
  bad <- 0L
  ev <- "engine_version (expected to change)"
  get <- function(n) b$value[b$name == n]
  if (identical(mode, "changed-engine")) {
    declared <- grepl("^engine_version|^saved_sweep:|^old_", a$name)
    comparable <- a$name[!declared]
    missing <- setdiff(comparable, b$name)
    if (length(missing)) { cat("MISSING in candidate:", paste(missing, collapse = ", "), "\n"); bad <- bad + 1L }
    both <- intersect(comparable, b$name)
    same <- a$value[match(both, a$name)] == b$value[match(both, b$name)]
    cat(sprintf("identities compared: %d, equal: %d\n", length(both), sum(same)))
    if (!all(same)) { cat("DIFFER:", paste(both[!same], collapse = ", "), "\n"); bad <- bad + 1L }
    cat("engine version base", a$value[a$name == ev], "candidate", b$value[b$name == ev], "\n")
    if (identical(a$value[a$name == ev], b$value[b$name == ev])) { cat("engine version did not change\n"); bad <- bad + 1L }
    cat("old precompute:", get("old_precompute:refusal"), "strategy calls", get("old_precompute:strategy_calls"), "\n")
    if (!identical(get("old_precompute:refusal"), "ledgr_precomputed_engine_mismatch") ||
        !identical(get("old_precompute:strategy_calls"), "0")) bad <- bad + 1L
  } else {
    prefix <- arg("engine-prefix")
    if (is.null(prefix) || !nzchar(prefix)) stop("--mode=unchanged-engine needs --engine-prefix=<hex>")
    for (arm in list(list("base", a), list("candidate", b))) {
      dup <- unique(arm[[2]]$name[duplicated(arm[[2]]$name)])
      if (length(dup)) { cat("DUPLICATE in", arm[[1]], ":", paste(dup, collapse = ", "), "\n"); bad <- bad + 1L }
      n_ev <- sum(arm[[2]]$name == ev)
      if (n_ev != 1L) { cat(arm[[1]], "has", n_ev, "engine-version records\n"); bad <- bad + 1L }
    }
    comparable <- a$name[!grepl("^saved_sweep:|^old_", a$name)]
    missing <- setdiff(comparable, b$name)
    if (length(missing)) { cat("MISSING in candidate:", paste(missing, collapse = ", "), "\n"); bad <- bad + 1L }
    extra <- setdiff(b$name[!grepl("^saved_sweep:|^old_", b$name)], comparable)
    if (length(extra)) { cat("EXTRA in candidate:", paste(extra, collapse = ", "), "\n"); bad <- bad + 1L }
    both <- intersect(comparable, b$name)
    same <- vapply(both, function(n) identical(a$value[a$name == n], b$value[b$name == n]), logical(1))
    cat(sprintf("identities compared: %d, equal: %d (engine version included)\n", length(both), sum(same)))
    if (!all(same)) { cat("DIFFER:", paste(both[!same], collapse = ", "), "\n"); bad <- bad + 1L }
    ea <- a$value[a$name == ev]
    eb <- b$value[b$name == ev]
    cat("engine version base", ea, "candidate", eb, "expected prefix", prefix, "\n")
    if (length(ea) != 1L || length(eb) != 1L || !identical(ea, eb) || !startsWith(eb, prefix)) {
      cat("engine version is not the unchanged expected version\n")
      bad <- bad + 1L
    }
    calls <- suppressWarnings(as.integer(get("old_precompute:strategy_calls")))
    cat("old precompute:", get("old_precompute:refusal"), "strategy calls", get("old_precompute:strategy_calls"),
        "| reused table", get("old_precompute:reused_table"), "fresh table", get("old_precompute:fresh_table"), "\n")
    if (!identical(get("old_precompute:refusal"), "none") || length(calls) != 1L || is.na(calls) || calls < 1L) {
      cat("old precompute was not reused\n")
      bad <- bad + 1L
    }
    reused <- get("old_precompute:reused_table")
    fresh <- get("old_precompute:fresh_table")
    if (length(reused) != 1L || length(fresh) != 1L || !identical(reused, fresh)) {
      cat("reused precompute result differs from fresh preparation\n")
      bad <- bad + 1L
    }
  }
  cat("old store: run", get("old_store:run_open"), "equity rows", get("old_store:equity_rows"),
      "sweep list", get("old_store:sweep_list"), "\n")
  if (!identical(get("old_store:run_open"), "readable")) bad <- bad + 1L
  saved <- a$value[a$name == "saved_sweep:engine"]
  cat("old stored sweep keeps its engine version:", get("old_store:sweep_engine"), "(saved with", saved, ")\n")
  if (!identical(get("old_store:sweep_engine"), saved)) bad <- bad + 1L
  if (bad) { cat("IDENTITY CHECK FAIL\n"); quit(save = "no", status = 1L) }
  cat("IDENTITY CHECK PASS\n")
})

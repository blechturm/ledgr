# Compares two identity.R records (Cut 22 decision 6): every identity equal
# between the base and the candidate, except the engine version, which must
# differ; the candidate reading the base's explicit precompute must refuse it
# with ledgr_precomputed_engine_mismatch before any candidate runs, and the
# base's stored run and sweeps must stay readable.
#
#   Rscript identity_check.R --base=<identity.R out> --candidate=<identity.R out --old=base>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  read <- function(d) utils::read.csv(file.path(d, "identities.csv"), stringsAsFactors = FALSE, colClasses = "character")
  a <- read(arg("base"))
  b <- read(arg("candidate"))
  bad <- 0L
  declared <- grepl("^engine_version|^saved_sweep:|^old_", a$name)
  comparable <- a$name[!declared]
  missing <- setdiff(comparable, b$name)
  if (length(missing)) { cat("MISSING in candidate:", paste(missing, collapse = ", "), "\n"); bad <- bad + 1L }
  both <- intersect(comparable, b$name)
  same <- a$value[match(both, a$name)] == b$value[match(both, b$name)]
  cat(sprintf("identities compared: %d, equal: %d\n", length(both), sum(same)))
  if (!all(same)) { cat("DIFFER:", paste(both[!same], collapse = ", "), "\n"); bad <- bad + 1L }
  ev <- "engine_version (expected to change)"
  cat("engine version base", a$value[a$name == ev], "candidate", b$value[b$name == ev], "\n")
  if (identical(a$value[a$name == ev], b$value[b$name == ev])) { cat("engine version did not change\n"); bad <- bad + 1L }
  get <- function(n) b$value[b$name == n]
  cat("old precompute:", get("old_precompute:refusal"), "strategy calls", get("old_precompute:strategy_calls"), "\n")
  if (!identical(get("old_precompute:refusal"), "ledgr_precomputed_engine_mismatch") ||
      !identical(get("old_precompute:strategy_calls"), "0")) bad <- bad + 1L
  cat("old store: run", get("old_store:run_open"), "equity rows", get("old_store:equity_rows"),
      "sweep list", get("old_store:sweep_list"), "\n")
  if (!identical(get("old_store:run_open"), "readable")) bad <- bad + 1L
  saved <- a$value[a$name == "saved_sweep:engine"]
  cat("old stored sweep keeps its engine version:", get("old_store:sweep_engine"), "(saved with", saved, ")\n")
  if (!identical(get("old_store:sweep_engine"), saved)) bad <- bad + 1L
  if (bad) { cat("IDENTITY CHECK FAIL\n"); quit(save = "no", status = 1L) }
  cat("IDENTITY CHECK PASS\n")
})

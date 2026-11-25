# Controls for identity_check.R. Each control writes edited copies of the
# records into --scratch and must fail the checker; the unedited records must
# pass.
#
# --mode=unchanged-engine (default; Cut 23 decision 5b): the candidate's
# engine-version record changed, one identity record missing, a record
# duplicated, the same identity lost from both arms alike, one identity
# renamed in both arms (close review F1); and Cut 22's changed-engine mode
# must fail on two arms with an unchanged engine.
# --mode=changed-engine (Cut 24 cut review R4, LDG-3258), on records whose
# engine differs (Cut 22's base and final): one required identity removed
# from both arms, renamed in both arms, dropped from one arm, duplicated in
# one arm, and the candidate's engine record removed.
#
#   Rscript identity_controls.R --base=<identity.R out> --candidate=<identity.R out> --scratch=<dir> --engine-prefix=<hex>
#   Rscript identity_controls.R --mode=changed-engine --base=<dir> --candidate=<dir> --scratch=<dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
  }
  `%||%` <- function(x, y) if (is.null(x)) y else x
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  checker <- file.path(here, "identity_check.R")
  rscript <- file.path(R.home("bin"), "Rscript")
  read <- function(d) utils::read.csv(file.path(d, "identities.csv"), stringsAsFactors = FALSE, colClasses = "character")
  base <- read(arg("base")); cand <- read(arg("candidate"))
  mode <- arg("mode", "unchanged-engine")
  ev <- "engine_version (expected to change)"
  ordinary <- function(x) which(!grepl("^engine_version|^saved_sweep:|^old_", x$name))[[1L]]
  victim <- cand$name[ordinary(cand)]
  drop <- function(x) x[x$name != victim, ]
  rename <- function(x) { x$name[x$name == victim] <- paste0(victim, "_renamed"); x }
  edits <- if (identical(mode, "changed-engine")) {
    list(
      missing_both = list(base = drop, candidate = drop),
      renamed_both = list(base = rename, candidate = rename),
      missing_one = list(candidate = drop),
      duplicate_identity = list(candidate = function(x) rbind(x, x[x$name == victim, ])),
      engine_removed = list(candidate = function(x) x[x$name != ev, ]))
  } else {
    list(
      changed_engine = list(candidate = function(x) { x$value[x$name == ev] <- paste0(x$value[x$name == ev], "0"); x }),
      missing_identity = list(candidate = drop),
      duplicate_identity = list(candidate = function(x) rbind(x, x[x$name == victim, ])),
      missing_both = list(base = drop, candidate = drop),
      renamed_both = list(base = rename, candidate = rename))
  }
  run <- function(base_dir, cand_dir, mode) {
    args <- c(checker, paste0("--base=", base_dir), paste0("--candidate=", cand_dir), paste0("--mode=", mode))
    if (identical(mode, "unchanged-engine")) args <- c(args, paste0("--engine-prefix=", arg("engine-prefix")))
    out <- suppressWarnings(system2(rscript, shQuote(args), stdout = TRUE, stderr = TRUE))
    list(status = attr(out, "status") %||% 0L, last = tail(out, 1L))
  }
  ok <- TRUE
  r <- run(arg("base"), arg("candidate"), mode)
  cat(sprintf("%-22s %s exit %d  %s\n", "none", mode, r$status, r$last))
  ok <- ok && r$status == 0L
  for (k in names(edits)) {
    dirs <- c(base = arg("base"), candidate = arg("candidate"))
    for (side in names(edits[[k]])) {
      d <- file.path(arg("scratch"), k, side)
      dir.create(d, recursive = TRUE, showWarnings = FALSE)
      utils::write.csv(edits[[k]][[side]](if (side == "base") base else cand), file.path(d, "identities.csv"), row.names = FALSE)
      dirs[[side]] <- d
    }
    r <- run(dirs[["base"]], dirs[["candidate"]], mode)
    cat(sprintf("%-22s %s exit %d  %s  (edited: %s; identity %s)\n", k, mode, r$status, r$last,
                paste(names(edits[[k]]), collapse = "+"), victim))
    ok <- ok && r$status == 1L
  }
  if (identical(mode, "unchanged-engine")) {
    r <- run(arg("base"), arg("candidate"), "changed-engine")
    cat(sprintf("%-22s changed-engine   exit %d  %s\n", "none", r$status, r$last))
    ok <- ok && r$status == 1L
  }
  cat(if (ok) "CONTROLS PASS\n" else "CONTROLS FAIL\n")
  if (!ok) quit(save = "no", status = 1L)
})

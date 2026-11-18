# Cut 23 decision 5b controls: identity_check.R --mode=unchanged-engine must
# fail when the candidate's engine-version record changes, when one identity
# record is missing, when a record is duplicated, when the same identity is
# lost from both arms alike, and when one identity is renamed in both arms
# (close review F1); and Cut 22's changed-engine mode must fail on two arms
# with an unchanged engine. Each control writes edited copies of the records
# into --scratch.
#
#   Rscript identity_controls.R --base=<identity.R out> --candidate=<identity.R out> --scratch=<dir> --engine-prefix=<hex>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  `%||%` <- function(x, y) if (is.null(x)) y else x
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  checker <- file.path(here, "identity_check.R")
  rscript <- file.path(R.home("bin"), "Rscript")
  read <- function(d) utils::read.csv(file.path(d, "identities.csv"), stringsAsFactors = FALSE, colClasses = "character")
  base <- read(arg("base")); cand <- read(arg("candidate"))
  ev <- "engine_version (expected to change)"
  ordinary <- function(x) which(!grepl("^engine_version|^saved_sweep:|^old_", x$name))[[1L]]
  victim <- cand$name[ordinary(cand)]
  edits <- list(
    changed_engine = list(candidate = function(x) { x$value[x$name == ev] <- paste0(x$value[x$name == ev], "0"); x }),
    missing_identity = list(candidate = function(x) x[x$name != victim, ]),
    duplicate_identity = list(candidate = function(x) rbind(x, x[x$name == victim, ])),
    missing_both = list(base = function(x) x[x$name != victim, ], candidate = function(x) x[x$name != victim, ]),
    renamed_both = list(base = function(x) { x$name[x$name == victim] <- paste0(victim, "_renamed"); x },
                        candidate = function(x) { x$name[x$name == victim] <- paste0(victim, "_renamed"); x }))
  run <- function(base_dir, cand_dir, mode) {
    args <- c(checker, paste0("--base=", base_dir), paste0("--candidate=", cand_dir), paste0("--mode=", mode))
    if (identical(mode, "unchanged-engine")) args <- c(args, paste0("--engine-prefix=", arg("engine-prefix")))
    out <- suppressWarnings(system2(rscript, shQuote(args), stdout = TRUE, stderr = TRUE))
    list(status = attr(out, "status") %||% 0L, last = tail(out, 1L))
  }
  ok <- TRUE
  r <- run(arg("base"), arg("candidate"), "unchanged-engine")
  cat(sprintf("%-22s unchanged-engine exit %d  %s\n", "none", r$status, r$last))
  ok <- ok && r$status == 0L
  for (k in names(edits)) {
    dirs <- c(base = arg("base"), candidate = arg("candidate"))
    for (side in names(edits[[k]])) {
      d <- file.path(arg("scratch"), k, side)
      dir.create(d, recursive = TRUE, showWarnings = FALSE)
      utils::write.csv(edits[[k]][[side]](if (side == "base") base else cand), file.path(d, "identities.csv"), row.names = FALSE)
      dirs[[side]] <- d
    }
    r <- run(dirs[["base"]], dirs[["candidate"]], "unchanged-engine")
    cat(sprintf("%-22s unchanged-engine exit %d  %s  (edited: %s; identity %s)\n", k, r$status, r$last,
                paste(names(edits[[k]]), collapse = "+"), victim))
    ok <- ok && r$status == 1L
  }
  r <- run(arg("base"), arg("candidate"), "changed-engine")
  cat(sprintf("%-22s changed-engine   exit %d  %s\n", "none", r$status, r$last))
  ok <- ok && r$status == 1L
  cat(if (ok) "CONTROLS PASS\n" else "CONTROLS FAIL\n")
  if (!ok) quit(save = "no", status = 1L)
})

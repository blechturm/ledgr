# Cut 23 decision 5b controls: identity_check.R --mode=unchanged-engine must
# fail when the candidate's engine-version record changes, when one identity
# record is missing, or when a record is duplicated; and Cut 22's
# changed-engine mode must fail on two arms with an unchanged engine. Each
# control copies the candidate record with one edit into --scratch.
#
#   Rscript identity_controls.R --base=<identity.R out> --candidate=<identity.R out> --scratch=<dir> --engine-prefix=<hex>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  checker <- file.path(here, "identity_check.R")
  rscript <- file.path(R.home("bin"), "Rscript")
  base <- arg("base")
  cand <- utils::read.csv(file.path(arg("candidate"), "identities.csv"), stringsAsFactors = FALSE, colClasses = "character")
  ev <- "engine_version (expected to change)"
  first_identity <- which(!grepl("^engine_version|^saved_sweep:|^old_", cand$name))[[1L]]
  edits <- list(
    changed_engine = function(x) { x$value[x$name == ev] <- paste0(x$value[x$name == ev], "0"); x },
    missing_identity = function(x) x[-first_identity, ],
    duplicate_identity = function(x) rbind(x, x[first_identity, ]))
  run <- function(cand_dir, mode) {
    args <- c(checker, paste0("--base=", base), paste0("--candidate=", cand_dir), paste0("--mode=", mode))
    if (identical(mode, "unchanged-engine")) args <- c(args, paste0("--engine-prefix=", arg("engine-prefix")))
    out <- suppressWarnings(system2(rscript, shQuote(args), stdout = TRUE, stderr = TRUE))
    status <- attr(out, "status") %||% 0L
    list(status = status, last = tail(out, 1L))
  }
  `%||%` <- function(x, y) if (is.null(x)) y else x
  ok <- TRUE
  r <- run(arg("candidate"), "unchanged-engine")
  cat(sprintf("%-22s unchanged-engine exit %d  %s\n", "none", r$status, r$last))
  ok <- ok && r$status == 0L
  for (k in names(edits)) {
    d <- file.path(arg("scratch"), k)
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(edits[[k]](cand), file.path(d, "identities.csv"), row.names = FALSE)
    r <- run(d, "unchanged-engine")
    cat(sprintf("%-22s unchanged-engine exit %d  %s\n", k, r$status, r$last))
    ok <- ok && r$status == 1L
  }
  r <- run(arg("candidate"), "changed-engine")
  cat(sprintf("%-22s changed-engine   exit %d  %s\n", "none", r$status, r$last))
  ok <- ok && r$status == 1L
  cat(if (ok) "CONTROLS PASS\n" else "CONTROLS FAIL\n")
  if (!ok) quit(save = "no", status = 1L)
})

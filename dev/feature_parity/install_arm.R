# Installs one committed ledgr tree as an oracle arm, the way the timing
# harness installs its arms (dev/bench/timing/runner.R, install_arm): git
# archive of the commit, R CMD INSTALL into <lib>. Writes the commit marker
# and the R/ source hashes beside the package, which runner.R records.
#
#   Rscript install_arm.R --repo=<git tree> --commit=<sha or ref> --lib=<new dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  repo <- normalizePath(arg("repo"), winslash = "/", mustWork = TRUE)
  lib <- arg("lib")
  if (dir.exists(lib) && length(list.files(lib))) stop("--lib must be a new or empty directory: ", lib)
  git <- function(...) {
    out <- system2("git", c("-C", shQuote(repo), ...), stdout = TRUE)
    if (!is.null(attr(out, "status"))) stop("git failed: ", paste(c(...), collapse = " "))
    out
  }
  sha <- git("rev-parse", "--verify", paste0(arg("commit"), "^{commit}"))[[1L]]
  dir.create(lib, recursive = TRUE)
  lib <- normalizePath(lib, winslash = "/")
  work <- paste0(lib, "_src")
  dir.create(work, showWarnings = FALSE)
  zip <- file.path(work, "tree.zip")
  git("archive", "--format=zip", "-o", shQuote(zip), sha)
  utils::unzip(zip, exdir = file.path(work, "src"))
  log <- file.path(work, "install.log")
  status <- system2(file.path(R.home("bin"), "R"), c("CMD", "INSTALL", "--no-docs", "--no-html",
    paste0("--library=", shQuote(lib)), shQuote(file.path(work, "src"))), stdout = log, stderr = log)
  if (!identical(as.integer(status), 0L)) stop("R CMD INSTALL failed; see ", log)
  writeLines(sha, file.path(lib, "ledgr_arm_commit.txt"))
  files <- sort(list.files(file.path(work, "src", "R"), pattern = "[.]R$"), method = "radix")
  writeLines(paste(files, vapply(file.path(work, "src", "R", files),
                                 function(f) digest::digest(file = f, algo = "sha256"), ""), sep = "="),
             file.path(lib, "ledgr_arm_r_sources.txt"))
  cat("installed", sha, "into", lib, "\n")
})

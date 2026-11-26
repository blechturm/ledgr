# LDG-3270: R CMD build of the cut25 worktree and R CMD check of the tarball
# in the maintainer's default library (duckdb 2.0.1; no verification library),
# in cut25-scratch/buildcheck, with Quarto and Pandoc from RStudio as
# dev/build-site.R sets them. The check log is copied beside this script.
qbin <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin"
Sys.setenv(PATH = paste(c(qbin, file.path(qbin, "tools"), Sys.getenv("PATH")), collapse = ";"),
           QUARTO_PATH = file.path(qbin, "quarto.exe"),
           RSTUDIO_PANDOC = file.path(qbin, "tools"))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                              winslash = "/"))
tree <- "C:/Users/maxth/ledgr-wt/cut25"
out <- "C:/Users/maxth/ledgr-wt/cut25-scratch/buildcheck"
dir.create(out, showWarnings = FALSE)
setwd(out)
cat("tree", tree, "HEAD", system2("git", c("-C", tree, "rev-parse", "HEAD"), stdout = TRUE),
    "duckdb", as.character(utils::packageVersion("duckdb")), "\n")
r <- file.path(R.home("bin"), "R")
b <- system2(r, c("CMD", "build", shQuote(tree)), stdout = "build.log", stderr = "build.log")
cat("build exit", b, "\n")
tar <- list.files(out, pattern = "^ledgr_.*\\.tar\\.gz$")
if (length(tar) != 1L) stop("expected one tarball, found: ", paste(tar, collapse = ", "))
k <- system2(r, c("CMD", "check", "--no-manual", "--no-build-vignettes", tar), stdout = "check.log", stderr = "check.log")
cat("check exit", k, "\n")
file.copy("check.log", file.path(here, "r_cmd_check.log"), overwrite = TRUE)
cat(tail(readLines("check.log"), 8), sep = "\n")

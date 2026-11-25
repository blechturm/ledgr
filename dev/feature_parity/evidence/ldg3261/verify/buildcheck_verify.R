# LDG-3261 close review F1: R CMD build and check with the isolated verification library (duckdb 2.0.0, nanonext 1.10.4, mirai 2.7.4) first on R_LIBS.
# R CMD build of the ws43 worktree and R CMD check of the tarball, in
# cut24-scratch/buildcheck, with Quarto and Pandoc from RStudio as
# dev/build-site.R sets them.
qbin <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin"
Sys.setenv(PATH = paste(c(qbin, file.path(qbin, "tools"), Sys.getenv("PATH")), collapse = ";"),
           QUARTO_PATH = file.path(qbin, "quarto.exe"),
           RSTUDIO_PANDOC = file.path(qbin, "tools"))
verify <- "C:/Users/maxth/ledgr-wt/cut24-scratch/verify-lib"
Sys.setenv(R_LIBS = paste(c(verify, Sys.getenv("R_LIBS")), collapse = ";"))
out <- "C:/Users/maxth/ledgr-wt/cut24-scratch/buildcheck-verify"
dir.create(out, showWarnings = FALSE)
setwd(out)
r <- file.path(R.home("bin"), "R")
b <- system2(r, c("CMD", "build", shQuote("C:/Users/maxth/ledgr-wt/ws43")), stdout = "build.log", stderr = "build.log")
cat("build exit", b, "\n")
tar <- list.files(out, pattern = "^ledgr_.*\\.tar\\.gz$")
if (length(tar) != 1L) stop("expected one tarball, found: ", paste(tar, collapse = ", "))
k <- system2(r, c("CMD", "check", "--no-manual", "--no-build-vignettes", tar), stdout = "check.log", stderr = "check.log")
cat("check exit", k, "\n")
cat(tail(readLines("check.log"), 8), sep = "\n")

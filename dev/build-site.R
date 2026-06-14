#!/usr/bin/env Rscript
# dev/build-site.R -- reliable local pkgdown build for ledgr.
#
# A bare `Rscript` does not inherit RStudio's environment, so a plain
# `pkgdown::build_site()` fails in two ways that are tedious to rediscover:
#   1. the Quarto CLI and Pandoc are not on PATH, so vignette rendering and
#      home/footer markdown both abort ("Pandoc not available", quarto not
#      found);
#   2. a stale or 0-byte `src/*.dll` left by an interrupted install makes
#      `pkgload::load_all()` (run in every vignette setup chunk) die with
#      "LoadLibrary failure: %1 is not a valid Win32 application".
#
# This wrapper points R at RStudio's bundled Quarto/Pandoc, falls back to the
# user library if needed, cleans the compiled artifacts, then builds.
#
# Usage -- run with an R >= 4.5 whose library has pkgdown + quarto:
#   "C:/Program Files/R/R-4.5.2/bin/Rscript.exe" dev/build-site.R
#   "C:/Program Files/R/R-4.5.2/bin/Rscript.exe" dev/build-site.R --check
# `--check` verifies the toolchain and exits without building.

check_only <- "--check" %in% commandArgs(trailingOnly = TRUE)

# Run from the package root regardless of where Rscript was launched.
root <- if (file.exists("DESCRIPTION")) {
  normalizePath(getwd())
} else if (file.exists("../DESCRIPTION")) {
  normalizePath("..")
} else {
  stop("Run from the ledgr package root (DESCRIPTION not found).")
}
setwd(root)

first_existing <- function(paths) {
  paths <- paths[nzchar(paths)]
  hit <- paths[file.exists(paths)]
  if (length(hit)) hit[[1]] else NA_character_
}

# --- Quarto CLI -------------------------------------------------------------
if (!nzchar(Sys.getenv("QUARTO_PATH"))) {
  quarto_which <- Sys.which("quarto")
  quarto_bin <- first_existing(c(
    if (nzchar(quarto_which)) quarto_which else "",
    "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe",
    "C:/Program Files/Quarto/bin/quarto.exe"
  ))
  if (!is.na(quarto_bin)) Sys.setenv(QUARTO_PATH = quarto_bin)
}

# --- Pandoc (pkgdown reads RSTUDIO_PANDOC as a directory) -------------------
if (!nzchar(Sys.getenv("RSTUDIO_PANDOC"))) {
  pandoc_which <- Sys.which("pandoc")
  pandoc_dir <- first_existing(c(
    if (nzchar(pandoc_which)) dirname(pandoc_which) else "",
    "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools"
  ))
  if (!is.na(pandoc_dir)) Sys.setenv(RSTUDIO_PANDOC = pandoc_dir)
}

# --- Library fallback (bare Rscript may miss the user library) --------------
ver <- paste(R.version$major, sub("\\..*", "", R.version$minor), sep = ".")
for (lib in c(file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", ver),
              file.path(Sys.getenv("USERPROFILE"), "Documents", "R", "win-library", ver))) {
  if (dir.exists(lib) && !(lib %in% .libPaths())) .libPaths(c(.libPaths(), lib))
}

# --- Diagnostics ------------------------------------------------------------
cat("ledgr site build\n")
cat("  R       :", as.character(getRversion()), "\n")
cat("  root    :", root, "\n")
cat("  quarto  :", Sys.getenv("QUARTO_PATH"), "\n")
cat("  pandoc  :", Sys.getenv("RSTUDIO_PANDOC"), "\n")
have_pkgdown <- requireNamespace("pkgdown", quietly = TRUE)
cat("  pkgdown :", have_pkgdown, "\n")
cat("  quarto R:", requireNamespace("quarto", quietly = TRUE), "\n")
if (!have_pkgdown) {
  stop("pkgdown not on .libPaths(); run with an R >= 4.5 that has pkgdown installed.")
}

if (check_only) {
  cat("--check: toolchain OK, skipping build.\n")
  quit(status = 0)
}

# --- Clean stale compiled artifacts (the 0-byte DLL trap) -------------------
stale <- list.files("src", pattern = "\\.(o|dll|so|dylib)$", full.names = TRUE)
if (length(stale)) {
  cat("  cleaning:", length(stale), "src artifact(s)\n")
  file.remove(stale)
}

# --- Build ------------------------------------------------------------------
pkgdown::build_site(new_process = FALSE, preview = FALSE)
cat("=== build_site DONE ===\n")

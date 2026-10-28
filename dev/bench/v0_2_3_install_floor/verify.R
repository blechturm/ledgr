# M4: verify that a library holds exactly the manifest's packages and versions.
#
# Usage:
#   Rscript --vanilla dev/bench/v0_2_3_install_floor/verify.R \
#     --lib=C:/Users/maxth/ledgr-wt/m4-libs/lib [--manifest=<manifest.csv>]
#
# Fails (exit status 1) on any manifest package that is missing from the
# library or installed at a different version, and on any package in the
# library that the manifest does not list (ledgr itself excepted). Reads the
# installed DESCRIPTION files directly; nothing is loaded.

args <- commandArgs(trailingOnly = TRUE)
value_arg <- function(name, default = NULL) {
  hit <- args[startsWith(args, paste0("--", name, "="))]
  if (length(hit) == 0L) default else sub(paste0("^--", name, "="), "", hit[[length(hit)]])
}
file_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
here <- normalizePath(dirname(file_arg), winslash = "/")
manifest_path <- value_arg("manifest", file.path(here, "manifest.csv"))
lib <- value_arg("lib")
if (is.null(lib) || !dir.exists(lib)) stop("--lib=<existing library> is required.")

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, colClasses = "character")
if (anyDuplicated(manifest$package)) stop("Manifest lists a package twice.")
installed <- utils::installed.packages(lib.loc = lib, noCache = TRUE)[, c("Package", "Version"), drop = FALSE]
have <- setNames(installed[, "Version"], installed[, "Package"])

found <- unname(have[manifest$package])
diffs <- data.frame(
  package = manifest$package,
  expected = manifest$version,
  installed = found,
  problem = ifelse(is.na(found), "missing", ifelse(found != manifest$version, "version", "")),
  stringsAsFactors = FALSE
)
extra <- setdiff(names(have), c(manifest$package, "ledgr"))
if (length(extra) > 0L) {
  diffs <- rbind(diffs, data.frame(
    package = extra, expected = NA_character_, installed = unname(have[extra]),
    problem = "not_in_manifest", stringsAsFactors = FALSE
  ))
}
bad <- diffs[nzchar(diffs$problem), , drop = FALSE]
cat(sprintf("verify: manifest %s, library %s\n", manifest_path, normalizePath(lib, winslash = "/")))
cat(sprintf("verify: %d manifest packages, %d installed (ledgr %s)\n",
            nrow(manifest), length(have),
            if ("ledgr" %in% names(have)) have[["ledgr"]] else "absent"))
if (nrow(bad) > 0L) {
  print(bad, row.names = FALSE)
  cat(sprintf("VERIFY_FAIL differences=%d\n", nrow(bad)))
  quit(save = "no", status = 1L)
}
cat("VERIFY_OK\n")

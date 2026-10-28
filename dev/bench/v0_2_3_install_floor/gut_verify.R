# M4 gut demonstration for verify.R: run it against the recorded manifest
# (must pass) and against a copy with one version changed (must fail).
#
# Usage:
#   Rscript --vanilla dev/bench/v0_2_3_install_floor/gut_verify.R \
#     --lib=C:/Users/maxth/ledgr-wt/m4-libs/lib [--package=duckdb] [--version=1.5.6]

args <- commandArgs(trailingOnly = TRUE)
value_arg <- function(name, default = NULL) {
  hit <- args[startsWith(args, paste0("--", name, "="))]
  if (length(hit) == 0L) default else sub(paste0("^--", name, "="), "", hit[[length(hit)]])
}
file_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
here <- normalizePath(dirname(file_arg), winslash = "/")
lib <- value_arg("lib")
pkg <- value_arg("package", "duckdb")
gut_version <- value_arg("version", "1.5.6")
out <- value_arg("out", file.path(here, "verify_gut.csv"))
rscript <- file.path(R.home("bin"), "Rscript")
verify <- file.path(here, "verify.R")

manifest <- utils::read.csv(file.path(here, "manifest.csv"), stringsAsFactors = FALSE, colClasses = "character")
if (!pkg %in% manifest$package) stop("Package not in manifest: ", pkg)
original <- manifest$version[manifest$package == pkg]
if (identical(original, gut_version)) stop("Gut version equals the manifest version.")
gutted <- manifest
gutted$version[gutted$package == pkg] <- gut_version
gutted_path <- file.path(tempdir(), "manifest_gutted.csv")
utils::write.csv(gutted, gutted_path, row.names = FALSE)

run <- function(manifest_path) {
  output <- suppressWarnings(system2(rscript, c("--vanilla", shQuote(verify),
    paste0("--lib=", lib), paste0("--manifest=", manifest_path)), stdout = TRUE, stderr = TRUE))
  status <- attr(output, "status")
  cat(output, sep = "\n")
  list(status = if (is.null(status)) 0L else as.integer(status),
       verdict = tail(grep("^VERIFY_", output, value = TRUE), 1L))
}
cat("== recorded manifest ==\n")
real <- run(file.path(here, "manifest.csv"))
cat(sprintf("== gutted manifest (%s %s -> %s) ==\n", pkg, original, gut_version))
gut <- run(gutted_path)

result <- data.frame(
  case = c("recorded_manifest", "gutted_manifest"),
  change = c("none", sprintf("%s %s -> %s", pkg, original, gut_version)),
  exit_code = c(real$status, gut$status),
  verdict = c(real$verdict, gut$verdict),
  expected_exit = c("0", "nonzero"),
  stringsAsFactors = FALSE
)
utils::write.csv(result, out, row.names = FALSE)
print(result, row.names = FALSE)
if (real$status != 0L || gut$status == 0L) {
  cat("GUT_FAIL: verify.R did not separate the recorded and gutted manifests.\n")
  quit(save = "no", status = 1L)
}
cat("GUT_OK: verify.R passes the recorded manifest and fails the gutted copy.\n")

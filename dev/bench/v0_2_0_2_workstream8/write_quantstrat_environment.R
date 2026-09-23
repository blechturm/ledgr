args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Usage: write_quantstrat_environment.R <record-prefix>", call. = FALSE)
}

record_prefix <- normalizePath(args[[1L]], winslash = "/", mustWork = FALSE)
quantstrat_lib <- "C:/tmp/ledgr-quantstrat-batch10-lib"
collapse_lib <- "C:/tmp/ledgr-collapse-218-lib"
user_lib <- "C:/Users/maxth/Documents/R/win-library/4.6"
.libPaths(c(quantstrat_lib, collapse_lib, user_lib, .libPaths()))

package_record <- function(package) {
  description <- utils::packageDescription(package)
  package_path <- find.package(package)
  field <- function(name) {
    value <- unname(description[[name]])
    if (is.null(value) || !nzchar(value)) NULL else value
  }
  list(
    version = as.character(utils::packageVersion(package)),
    library = normalizePath(package_path, winslash = "/"),
    remote_type = field("RemoteType"),
    remote_host = field("RemoteHost"),
    remote_repo = field("RemoteRepo"),
    remote_username = field("RemoteUsername"),
    remote_sha = field("RemoteSha"),
    repository = field("Repository")
  )
}

environment_path <- paste0(record_prefix, "_environment.json")
environment <- jsonlite::read_json(environment_path, simplifyVector = TRUE)
packages <- c(
  "quantstrat", "blotter", "FinancialInstrument", "xts", "TTR",
  "collapse", "duckdb"
)
output <- list(
  created_at = environment$created_at,
  record_prefix = record_prefix,
  R = R.version.string,
  primary_library = quantstrat_lib,
  packages = stats::setNames(lapply(packages, package_record), packages)
)
jsonlite::write_json(
  output,
  paste0(record_prefix, "_quantstrat_environment.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

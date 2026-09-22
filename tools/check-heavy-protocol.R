args <- commandArgs(trailingOnly = TRUE)

value_arg <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0L) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
root <- normalizePath(file.path(dirname(script), ".."), winslash = "/")
protocol <- value_arg("protocol")
census_path <- value_arg("census")
source(file.path(root, "tests", "test-control-plane.R"), local = TRUE)
manifest <- ledgr_test_heavy_protocols_read(file.path(root, "tests", "heavy-protocols.yml"))
ids <- vapply(manifest, `[[`, character(1), "id")
if (is.null(protocol) || !protocol %in% ids) stop("Unknown heavy protocol.")
if (is.null(census_path) || !file.exists(census_path)) stop("Heavy census is missing.")

preflight <- ledgr_test_preflight(file.path(root, "tests", "testthat"))
expected <- ledgr_test_select(preflight, "heavy_protocol")
census <- utils::read.csv(census_path, stringsAsFactors = FALSE)
actual <- census[, c("file", "title", "key", "status"), drop = FALSE]
ledgr_test_reconcile_execution(expected, actual)
claims <- ledgr_test_claims_read(file.path(root, "tests", "claims.yml"), preflight)
ledgr_test_claims_check(claims, preflight, actual, "heavy_protocol")
cat(sprintf("LEDGR_HEAVY_CENSUS_OK protocol=%s blocks=%d\n", protocol, nrow(actual)))

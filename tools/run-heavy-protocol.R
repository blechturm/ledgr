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
census <- value_arg("census", tempfile(fileext = ".csv"))
summary <- value_arg("summary", tempfile(fileext = ".csv"))
source(file.path(root, "tests", "test-control-plane.R"), local = TRUE)
manifest <- ledgr_test_heavy_protocols_read(file.path(root, "tests", "heavy-protocols.yml"))
ids <- vapply(manifest, `[[`, character(1), "id")
if (is.null(protocol) || !protocol %in% ids) stop("Unknown heavy protocol.")

status <- system2(
  file.path(R.home("bin"), "Rscript"),
  c(
    "--vanilla",
    shQuote(file.path(root, "tools", "run-test-profile.R")),
    "--profile=heavy_protocol",
    "--mode=ordinary",
    shQuote(paste0("--root=", root)),
    shQuote(paste0("--census=", census)),
    shQuote(paste0("--summary=", summary))
  )
)
if (!identical(status, 0L)) stop("Heavy protocol execution failed.")
check <- system2(
  file.path(R.home("bin"), "Rscript"),
  c(
    "--vanilla",
    shQuote(file.path(root, "tools", "check-heavy-protocol.R")),
    paste0("--protocol=", protocol),
    shQuote(paste0("--census=", census))
  )
)
if (!identical(check, 0L)) stop("Heavy protocol census checker failed.")
cat(sprintf("LEDGR_HEAVY_PROTOCOL_OK protocol=%s\n", protocol))

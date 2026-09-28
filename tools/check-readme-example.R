script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
if (is.null(script_file)) {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg) > 0) script_file <- sub("^--file=", "", file_arg[[1]])
}
if (is.null(script_file)) {
  script_file <- "tools/check-readme-example.R"
}

repo_root <- normalizePath(
  file.path(dirname(script_file), ".."),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)

check_lib <- tempfile("ledgr-readme-lib-")
dir.create(check_lib, recursive = TRUE, showWarnings = FALSE)

repo_lib <- file.path(repo_root, "lib")
lib_paths <- unique(c(
  normalizePath(check_lib, winslash = "/", mustWork = TRUE),
  if (dir.exists(repo_lib)) normalizePath(repo_lib, winslash = "/", mustWork = TRUE),
  .libPaths()
))
.libPaths(lib_paths)
Sys.setenv(R_LIBS = paste(lib_paths, collapse = .Platform$path.sep))

require_package <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package '%s' is required for the README check.", pkg), call. = FALSE)
  }
}

for (pkg in c("knitr")) require_package(pkg)

message("Installing ledgr into temporary library for README check: ", check_lib)
install_status <- system2(
  file.path(R.home("bin"), "R"),
  c("CMD", "INSTALL", "-l", shQuote(check_lib), ".")
)
if (!identical(install_status, 0L)) {
  stop("Temporary package installation failed.", call. = FALSE)
}

readme <- file.path(repo_root, "README.Rmd")
if (!file.exists(readme)) {
  stop("README.Rmd not found.", call. = FALSE)
}

env <- new.env(parent = globalenv())
output <- tempfile("README-", fileext = ".md")

message("Executing README.Rmd chunks under installed-package semantics.")
knitr::knit(input = readme, output = output, quiet = TRUE, envir = env)

if (!exists("bt", envir = env, inherits = FALSE)) {
  stop("README did not create the expected `bt` run handle.", call. = FALSE)
}

bt <- get("bt", envir = env, inherits = FALSE)

if (!inherits(bt, "ledgr_backtest")) {
  stop("README `bt` object is not a ledgr_backtest handle.", call. = FALSE)
}

for (name in c("above_trend", "run_id")) {
  if (!exists(name, envir = env, inherits = FALSE)) {
    stop(sprintf("README did not create the expected `%s` object.", name), call. = FALSE)
  }
}

# The README shows the strategy contract in full, so its strategy must stay a
# self-contained Tier 1 function.
above_trend <- get("above_trend", envir = env, inherits = FALSE)
if (!identical(ledgr::ledgr_strategy_preflight(above_trend)$tier, "tier_1")) {
  stop("README strategy is not a self-contained Tier 1 strategy.", call. = FALSE)
}

run_id <- get("run_id", envir = env, inherits = FALSE)
if (!identical(bt$run_id, run_id)) {
  stop("README did not reopen its run by the durable locator.", call. = FALSE)
}

for (what in c("ledger", "equity", "trades")) {
  out <- ledgr::ledgr_results(bt, what = what)
  if (!is.data.frame(out)) {
    stop(sprintf("README result table `%s` is not a data frame.", what), call. = FALSE)
  }
}

if (!exists("snapshot", envir = env, inherits = FALSE)) {
  stop("README did not create a snapshot handle.", call. = FALSE)
}
snapshot <- get("snapshot", envir = env, inherits = FALSE)
if (!inherits(snapshot, "ledgr_snapshot")) {
  stop("README `snapshot` object is not a ledgr_snapshot handle.", call. = FALSE)
}

if ("package:pkgload" %in% search()) {
  stop("README check attached pkgload; README must use installed-package APIs.", call. = FALSE)
}

message("README example check passed.")

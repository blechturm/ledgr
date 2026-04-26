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

if (!exists("run_a", envir = env, inherits = FALSE) ||
    !exists("run_b", envir = env, inherits = FALSE)) {
  stop("README determinism objects `run_a` and `run_b` were not created.", call. = FALSE)
}

run_a <- get("run_a", envir = env, inherits = FALSE)
run_b <- get("run_b", envir = env, inherits = FALSE)

if (!identical(run_a$ledger, run_b$ledger)) {
  stop("README determinism check failed: normalized ledgers differ.", call. = FALSE)
}
if (!identical(run_a$equity, run_b$equity)) {
  stop("README determinism check failed: normalized equity curves differ.", call. = FALSE)
}

if ("package:pkgload" %in% search()) {
  stop("README check attached pkgload; README must use installed-package APIs.", call. = FALSE)
}

message("README example check passed.")

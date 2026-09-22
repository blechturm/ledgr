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
library_path <- value_arg("library")
if (is.null(library_path) || !nzchar(library_path)) {
  stop("Use --library=<empty-or-new-directory>.")
}
library_path <- normalizePath(library_path, winslash = "/", mustWork = FALSE)
if (dir.exists(library_path) && length(list.files(library_path, all.files = TRUE, no.. = TRUE)) > 0L) {
  stop("The isolated library must be new or empty.")
}
dir.create(library_path, recursive = TRUE, showWarnings = FALSE)

description <- read.dcf(file.path(root, "DESCRIPTION"))
dependency_fields <- intersect(c("Depends", "Imports", "LinkingTo"), colnames(description))
tokens <- unlist(strsplit(description[1L, dependency_fields], ",|\n"), use.names = FALSE)
hard <- trimws(sub("\\s*\\(.*$", "", tokens))
hard <- setdiff(hard[nzchar(hard)], c("R", rownames(installed.packages(priority = "base"))))
seeds <- unique(c(hard, "pkgload", "testthat", "yaml", "brio", "withr"))
database <- installed.packages()
missing <- setdiff(seeds, rownames(database))
if (length(missing) > 0L) stop("Missing required package(s): ", paste(missing, collapse = ", "))
dependencies <- tools::package_dependencies(
  seeds,
  db = database,
  which = c("Depends", "Imports", "LinkingTo"),
  recursive = TRUE
)
packages <- unique(c(seeds, unlist(dependencies, use.names = FALSE)))
packages <- intersect(packages, rownames(database))
priority <- database[packages, "Priority"]
copy_packages <- packages[is.na(priority) | !priority %in% c("base", "recommended")]

for (package in copy_packages) {
  source <- find.package(package, quiet = TRUE)
  if (!nzchar(source)) stop("Cannot locate installed package: ", package)
  ok <- file.copy(source, library_path, recursive = TRUE, copy.date = TRUE)
  if (!isTRUE(ok)) stop("Failed to copy package into isolated library: ", package)
}
manifest <- data.frame(
  package = sort(copy_packages),
  version = vapply(sort(copy_packages), function(package) {
    as.character(utils::packageVersion(package, lib.loc = library_path))
  }, character(1)),
  reason = ifelse(sort(copy_packages) %in% hard, "ledgr hard dependency", "test harness closure"),
  stringsAsFactors = FALSE
)
manifest_path <- file.path(library_path, "_ledgr_cran_library_manifest.csv")
utils::write.csv(manifest, manifest_path, row.names = FALSE)
github_env <- Sys.getenv("GITHUB_ENV", unset = "")
if (nzchar(github_env)) {
  read_only_workdir <- normalizePath(.Library, winslash = "/", mustWork = TRUE)
  cat(sprintf("LEDGR_CRAN_LIBRARY=%s\n", library_path), file = github_env, append = TRUE)
  cat(sprintf("LEDGR_CRAN_LIBRARY_MANIFEST=%s\n", manifest_path),
      file = github_env, append = TRUE)
  cat(sprintf("LEDGR_CRAN_WORKDIR=%s\n", read_only_workdir),
      file = github_env, append = TRUE)
}
cat(sprintf("LEDGR_CRAN_LIBRARY_OK packages=%d manifest=%s\n", nrow(manifest), manifest_path))

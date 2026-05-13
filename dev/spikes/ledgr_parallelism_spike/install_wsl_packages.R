# Install WSL-only spike dependencies into the repo-local lib-wsl directory.
#
# Run from the repository root:
# Rscript dev/spikes/ledgr_parallelism_spike/install_wsl_packages.R

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
lib <- file.path(repo_root, "lib-wsl")
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))

required <- c("mirai", "mori")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  install.packages(missing, lib = lib, repos = "https://cloud.r-project.org")
}

cat("lib-wsl:", lib, "\n")
cat("missing installed:", paste(missing, collapse = ", "), "\n")

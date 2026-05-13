repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
local_lib <- if (.Platform$OS.type == "unix") {
  file.path(repo_root, "lib-wsl")
} else {
  file.path(repo_root, "lib")
}
if (dir.exists(local_lib)) {
  .libPaths(c(local_lib, .libPaths()))
}
for (p in c("mirai", "mori", "DBI", "duckdb", "ledgr")) {
  cat(p, ": ")
  if (requireNamespace(p, quietly = TRUE)) {
    cat(as.character(utils::packageVersion(p)), "\n")
  } else {
    cat("missing\n")
  }
}

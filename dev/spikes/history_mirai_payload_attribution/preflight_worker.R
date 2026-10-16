#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
source(file.path(dirname(script_path), "common.R"), local = globalenv())
opt <- e0_parse_args(commandArgs(trailingOnly = TRUE), list(
  `package-root` = ".", `out-dir` = tempfile("e0-preflight-")
))
.libPaths(e0_lib_paths())
package_root <- normalizePath(opt$`package-root`, winslash = "/", mustWork = TRUE)
out_dir <- normalizePath(opt$`out-dir`, winslash = "/", mustWork = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

started <- proc.time()[["elapsed"]]
pkgload::load_all(package_root, quiet = TRUE, compile = TRUE)
elapsed <- proc.time()[["elapsed"]] - started
dll <- file.path(package_root, "src", paste0("ledgr", .Platform$dynlib.ext))
if (!file.exists(dll)) stop("Compiled ledgr DLL was not created.", call. = FALSE)

e0_write_csv(data.frame(
  preflight = "clean_process_pkgload_compile_true",
  elapsed_sec = elapsed,
  dll_exists = TRUE,
  dll_bytes = file.info(dll)$size,
  stringsAsFactors = FALSE
), file.path(out_dir, "preflight.csv"))
cat("E0_PREFLIGHT_OK dll_bytes=", file.info(dll)$size, "\n", sep = "")

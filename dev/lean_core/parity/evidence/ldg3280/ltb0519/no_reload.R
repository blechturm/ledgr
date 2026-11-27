# LTB-0519 (LDG-3280): writes a copy of a candidate dev/lean_core whose
# lean_core_load() does not reload ledgr when the namespace is already loaded
# from the pinned source archive. Otherwise the copy is unchanged. In a sweep worker the pin's setup has
# then already loaded ledgr (running the test's observer, which it appends to
# ledgr_parallel_ledgr_load_expr()), and the lean worker boot keeps that
# namespace instead of discarding it with a second pkgload::load_all().
#   Rscript no_reload.R --out=<dir> [--lean=<candidate dev/lean_core>]
local({
  argv <- commandArgs(TRUE)
  arg <- function(n, d = NULL) { v <- grep(paste0("^--", n, "="), argv, value = TRUE); if (length(v)) sub(paste0("^--", n, "="), "", v[[1L]]) else d }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  lean <- normalizePath(arg("lean", file.path(here, "..", "..", "..", "..")), winslash = "/", mustWork = TRUE)
  stopifnot(file.exists(file.path(lean, "load.R")))
  root <- arg("out")
  dir.create(file.path(root, "dev", "lean_core"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "dev", "bench", "v0_2_3_ws16_entry"), recursive = TRUE, showWarnings = FALSE)
  file.copy(list.files(lean, pattern = "[.]R$", full.names = TRUE), file.path(root, "dev", "lean_core"), overwrite = TRUE)
  file.copy(file.path(lean, "..", "bench", "v0_2_3_ws16_entry", "common.R"),
            file.path(root, "dev", "bench", "v0_2_3_ws16_entry"), overwrite = TRUE)
  p <- file.path(root, "dev", "lean_core", "load.R")
  x <- readLines(p, warn = FALSE, encoding = "UTF-8")
  old <- "  commit <- if (from_source) ws16_load_source(lib) else ws16_load_installed(lib)"
  i <- which(x == old)
  if (length(i) != 1L) stop("load site not unique: ", length(i))
  x[[i]] <- paste0(
    "  commit <- if (from_source && \"ledgr\" %in% loadedNamespaces() && identical(loaded_from(), origin)) ",
    "readLines(file.path(lib, \"LEDGR_SOURCE_COMMIT\"), warn = FALSE)[[1L]] ",
    "else if (from_source) ws16_load_source(lib) else ws16_load_installed(lib)   # LTB-0519 demonstration: no reload")
  writeLines(x, p, useBytes = TRUE)
  cat("no-reload candidate:", file.path(root, "dev", "lean_core"), "(load.R:", i, ")\n")
})

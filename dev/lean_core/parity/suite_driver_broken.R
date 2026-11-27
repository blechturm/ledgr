# The suite driver's broken-candidate guard (LDG-3280): writes three broken
# copies of a candidate dev/lean_core under <out>, each with the bench loader
# that load.R sources, for suite_driver.R --lean=<copy>/dev/lean_core:
# - crash: the envelope stops on entry;
# - reconciled: P4 books every pulse's cash scan one fill short (the
#   product's own cash reconciliation refuses it);
# - silent: P1 records the equity positions value 1e-12 high (a wrong answer no
#   product check sees; only the comparison with the pin can).
# The driver must refuse all three before any test runs.
#   Rscript suite_driver_broken.R --out=<dir> [--lean=<candidate dev/lean_core>]
local({
  argv <- commandArgs(TRUE)
  arg <- function(n, d = NULL) { v <- grep(paste0("^--", n, "="), argv, value = TRUE); if (length(v)) sub(paste0("^--", n, "="), "", v[[1L]]) else d }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  lean <- normalizePath(arg("lean", file.path(here, "..")), winslash = "/", mustWork = TRUE)
  out <- arg("out")
  bench <- file.path(lean, "..", "bench", "v0_2_3_ws16_entry", "common.R")
  breaks <- list(
    crash = list(old = "lean_fold_envelope_plain <- function(execution, output_handler) {",
                 new = "lean_fold_envelope_plain <- function(execution, output_handler) { stop(\"broken candidate\")"),
    reconciled = list(old = "cash <<- ledgr_cash_scan(cash, fill$cash_delta)[[n_fill]]",
                      new = "cash <<- ledgr_cash_scan(cash, fill$cash_delta)[[max(1L, n_fill - 1L)]]"),
    silent = list(old = "eq$positions_value[[n_eq]] <<- pv",
                  new = "eq$positions_value[[n_eq]] <<- pv * (1 + 1e-12)")
  )
  for (b in names(breaks)) {
    root <- file.path(out, b)
    dir.create(file.path(root, "dev", "lean_core"), recursive = TRUE, showWarnings = FALSE)
    dir.create(file.path(root, "dev", "bench", "v0_2_3_ws16_entry"), recursive = TRUE, showWarnings = FALSE)
    file.copy(list.files(lean, pattern = "[.]R$", full.names = TRUE), file.path(root, "dev", "lean_core"), overwrite = TRUE)
    file.copy(bench, file.path(root, "dev", "bench", "v0_2_3_ws16_entry"), overwrite = TRUE)
    p <- file.path(root, "dev", "lean_core", "loop.R")
    x <- readLines(p, warn = FALSE, encoding = "UTF-8")
    i <- which(trimws(x) == breaks[[b]]$old)
    if (length(i) != 1L) stop("break site not unique for ", b, ": ", length(i))
    x[[i]] <- sub(breaks[[b]]$old, breaks[[b]]$new, x[[i]], fixed = TRUE)
    writeLines(x, p, useBytes = TRUE)
    cat(b, ": ", file.path(root, "dev", "lean_core"), " (loop.R:", i, ")\n", sep = "")
  }
})

# Cut 24 decision 3: calibration of the cut24-feature-1 repetitions, frozen
# before the base A/A record (LDG-3258). Runs every cell's workload once in a
# fresh process with a small rep count on the cut base library and reports
# seconds per preparation; the frozen rule sets reps so that each timed batch
# lasts at least `target` seconds on the base (wide feature and admission
# cells at least 6 s, so a stage-3 saving of up to half still leaves about
# 3 s; certification and 10 x 7,200 cells at least 3 s). Descriptive, not a
# record.
#
#   Rscript calibrate.R --lib=<cut base library> --work=<dir> --out=<csv>
#   Rscript calibrate.R --child --lib=<lib> --cell=<cell> --work=<dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else NULL
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  protocol <- normalizePath(file.path(here, "..", "timing", "protocols", "cut24-feature-1"), winslash = "/")
  matrix <- utils::read.csv(file.path(protocol, "matrix.csv"), colClasses = "character")
  parse <- function(text) {
    parts <- strsplit(strsplit(text, ";", fixed = TRUE)[[1L]], "=", fixed = TRUE)
    stats::setNames(lapply(parts, `[[`, 2L), vapply(parts, `[[`, "", 1L))
  }
  if ("--child" %in% argv) {
    suppressPackageStartupMessages(library(ledgr, lib.loc = normalizePath(arg("lib"), winslash = "/")))
    env <- new.env()
    sys.source(file.path(protocol, "workloads.R"), envir = env)
    row <- matrix[matrix$cell == arg("cell"), ]
    args <- parse(row$args)
    args$reps <- "2"
    dir.create(arg("work"), recursive = TRUE, showWarnings = FALSE)
    res <- get(row$workload, envir = env)(args, arg("work"))
    cat(sprintf("RESULT %s %.6f %s\n", arg("cell"), res$seconds[[row$clock]] / 2, res$work))
    return(invisible())
  }
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  rows <- list()
  for (cell in matrix$cell) {
    wd <- file.path(arg("work"), cell)
    unlink(wd, recursive = TRUE)
    out <- system2(rscript, c(file.path(here, "calibrate.R"), "--child", paste0("--lib=", arg("lib")),
                              paste0("--cell=", cell), paste0("--work=", wd)), stdout = TRUE, stderr = TRUE)
    hit <- grep("^RESULT ", out, value = TRUE)
    if (!length(hit)) { cat(out, sep = "\n"); stop("calibration child failed: ", cell) }
    p <- strsplit(sub("^RESULT ", "", hit), " ", fixed = TRUE)[[1L]]
    wide <- grepl("500x1260|1166x252|^adm_", cell)
    target <- if (wide) 6 else 3
    per <- as.numeric(p[[2L]])
    rows[[cell]] <- data.frame(cell = cell, seconds_per_prep = per, target_s = target,
                               reps = max(1L, as.integer(ceiling(target / per))), work = p[[3L]], stringsAsFactors = FALSE)
    cat(cell, per, "->", rows[[cell]]$reps, "\n")
  }
  out <- do.call(rbind, rows)
  utils::write.csv(out, arg("out"), row.names = FALSE)
})

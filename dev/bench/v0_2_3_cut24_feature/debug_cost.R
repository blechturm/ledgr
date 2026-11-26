# Cut 24 LDG-3265 (synthesis rule 9): the debug-on cost of stage 3,
# reported separately and labelled descriptive. Not a decision statistic,
# not the timing harness: production timings and the retention decision use
# debug = 0 (protocols/cut24-feature-1). With debug on, every admitted cell is
# also computed by the general path and compared, so the six feature cells
# (all instruments admitted) show the comparison's full cost.
#
# Per cell: `--pairs` alternating fresh children (debug 0 first in odd
# pairs), each one cut24_feature() workload of the frozen protocol with the
# cell's frozen reps; seconds per preparation; median(debug 1) /
# median(debug 0). Both settings must report the same logical result.
#
#   Rscript debug_cost.R --lib=<candidate lib> --work=<dir> --out=<csv> [--pairs=3]
#   Rscript debug_cost.R --child --lib=<lib> --shape=<n x m> --path=<run|sweep> --reps=<n> --debug=<0|1> --work=<dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "(=|$)"), argv, value = TRUE)
    if (!length(hit)) return(default)
    if (!grepl("=", hit[[1L]], fixed = TRUE)) return(TRUE)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  workloads <- normalizePath(file.path(here, "..", "timing", "protocols", "cut24-feature-1", "workloads.R"),
                             winslash = "/")
  lib <- normalizePath(arg("lib"), winslash = "/")
  if (isTRUE(arg("child"))) {
    suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
    wl <- new.env()
    sys.source(workloads, envir = wl)
    dir.create(arg("work"), recursive = TRUE, showWarnings = FALSE)
    r <- wl$cut24_feature(list(shape = arg("shape"), path = arg("path"), reps = arg("reps"), debug = arg("debug")),
                          arg("work"))
    cat(sprintf("RESULT %.6f %s\n", r$seconds[["feature"]], sub("^.*[|]", "", r$work)))
    quit(save = "no", status = 0L)
  }
  matrix <- utils::read.csv(file.path(here, "..", "timing", "protocols", "cut24-feature-1", "matrix.csv"),
                            stringsAsFactors = FALSE)
  cells <- matrix[matrix$workload == "cut24_feature", ]
  pairs <- as.integer(arg("pairs", "3"))
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  self <- file.path(here, "debug_cost.R")
  rows <- list()
  slot <- 0L
  for (k in seq_len(nrow(cells))) {
    kv <- strsplit(strsplit(cells$args[[k]], ";", fixed = TRUE)[[1L]], "=", fixed = TRUE)
    a <- stats::setNames(vapply(kv, `[`, "", 2L), vapply(kv, `[`, "", 1L))
    for (p in seq_len(pairs)) {
      for (d in if (p %% 2L == 1L) c("0", "1") else c("1", "0")) {
        slot <- slot + 1L
        work <- file.path(arg("work"), paste0("slot-", slot))
        out <- system2(rscript, c(self, "--child", paste0("--lib=", lib), paste0("--shape=", a[["shape"]]),
                                  paste0("--path=", a[["path"]]), paste0("--reps=", a[["reps"]]),
                                  paste0("--debug=", d), paste0("--work=", work)), stdout = TRUE, stderr = FALSE)
        res <- strsplit(sub("^RESULT ", "", grep("^RESULT ", out, value = TRUE)), " ", fixed = TRUE)[[1L]]
        rows[[length(rows) + 1L]] <- data.frame(cell = cells$cell[[k]], pair = p, debug = d,
          seconds_per_prep = as.numeric(res[[1L]]) / as.integer(a[["reps"]]), logical = res[[2L]],
          stringsAsFactors = FALSE)
        cat(cells$cell[[k]], "pair", p, "debug", d, round(as.numeric(res[[1L]]) / as.integer(a[["reps"]]), 4), "\n")
      }
    }
  }
  raw <- do.call(rbind, rows)
  summary <- do.call(rbind, lapply(split(raw, raw$cell), function(x) {
    s0 <- stats::median(x$seconds_per_prep[x$debug == "0"])
    s1 <- stats::median(x$seconds_per_prep[x$debug == "1"])
    data.frame(cell = x$cell[[1L]], debug0_s = round(s0, 4), debug1_s = round(s1, 4),
               ratio_debug1_over_debug0 = round(s1 / s0, 3),
               same_logical_result = length(unique(x$logical)) == 1L,
               label = "descriptive: debug-on cost, not a decision statistic", stringsAsFactors = FALSE)
  }))
  utils::write.csv(raw, sub("[.]csv$", "_raw.csv", arg("out")), row.names = FALSE)
  utils::write.csv(summary, arg("out"), row.names = FALSE)
  print(summary, row.names = FALSE)
})

#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
source(file.path(dirname(script_path), "common.R"), local = globalenv())
opt <- e0_parse_args(args, list(mode = "success", `out-dir` = tempfile("e1-life-")))
if (!opt$mode %in% c("success", "failure", "forced_termination")) stop("Bad lifecycle mode.")
.libPaths(e0_lib_paths())
dir.create(opt$`out-dir`, recursive = TRUE, showWarnings = FALSE)
mirai::daemons(2L)
clean <- function() {
  try({
    x <- mirai::everywhere({
      if (exists(".ledgr_e1_lifecycle", .GlobalEnv, inherits = FALSE)) {
        rm(".ledgr_e1_lifecycle", envir = .GlobalEnv)
      }
      gc()
      TRUE
    }, .min = 2L)
    invisible(x[mirai::.flat])
  }, silent = TRUE)
  try(mirai::daemons(0L), silent = TRUE)
}
on.exit(clean(), add = TRUE)

owner <- mori::share(list(x = seq_len(2e6), y = rep.int(1, 2e6)))
root_name <- sub("\\[.*$", "", mori::shared_name(owner))
e0_write_csv(data.frame(name = root_name), file.path(opt$`out-dir`, "shared_name.csv"))
pids <- as.integer(unlist(
  mirai::everywhere(Sys.getpid(), .min = 2L)[mirai::.flat], use.names = FALSE
))
e0_write_csv(data.frame(pid = pids), file.path(opt$`out-dir`, "daemon_pids.csv"))
stage <- do.call(
  mirai::everywhere,
  list(.expr = quote(TRUE), .ledgr_e1_lifecycle = owner, .min = 2L)
)
invisible(stage[mirai::.flat])
file.create(file.path(opt$`out-dir`, "ready"))

if (identical(opt$mode, "failure")) {
  failed <- mirai::mirai({
    mapped <- .ledgr_e1_lifecycle
    stop("E1_INTENTIONAL_WORKER_FAILURE", call. = FALSE)
  })[]
  if (!inherits(failed, "errorValue") ||
      !grepl("E1_INTENTIONAL_WORKER_FAILURE", as.character(failed), fixed = TRUE)) {
    stop("Intentional worker failure was not observed.", call. = FALSE)
  }
}

if (identical(opt$mode, "forced_termination")) {
  repeat Sys.sleep(1)
}

clean()
rm(owner)
invisible(gc())
e0_write_csv(
  data.frame(mode = opt$mode, cleanup_completed = TRUE),
  file.path(opt$`out-dir`, "result.csv")
)

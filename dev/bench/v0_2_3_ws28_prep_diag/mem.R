# WS28 diagnostic: process memory of one cut12-prep-1 run per arm, in a fresh
# process (memory_probe.R method: ps private commit and working set, current
# and lifetime peak). Marks: after the verified snapshot open, after
# preparation (the fold reader built), after the run.
#
#   Rscript dev/bench/v0_2_3_ws28_prep_diag/mem.R --lib=<pinned lib> --arm=<arm>
#     --shape=500x5040|h1 [--state=<private build-state.json>] --prebuilt=<store>
#     --out=<csv, appended>
#
# Arms as diag.R (pinned, lean); the tile arms are recorded at e17559aa.
# Private H1 rows carry megabytes only.

repo <- normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
  value = TRUE)[[1L]]), winslash = "/")), "..", "..", ".."), winslash = "/")
`%||%` <- function(x, y) if (is.null(x)) y else x
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(default %||% stop("--", name, "= is required", call. = FALSE))
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
arm <- arg("arm")
shape <- arg("shape")
me <- ps::ps_handle()
marks <- list()
mark <- function(phase) {
  m <- ps::ps_memory_info(me)
  marks[[length(marks) + 1L]] <<- data.frame(
    shape = shape, arm = arm, phase = phase, private_mib = round(m[["pagefile"]] / 2^20),
    peak_private_mib = round(m[["peak_pagefile"]] / 2^20), wset_mib = round(m[["wset"]] / 2^20),
    peak_wset_mib = round(m[["peak_wset"]] / 2^20))
}

source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(arg("lib"), debug = FALSE)
source(file.path(repo, "dev/bench/timing/protocols/cut12-prep-1/workloads.R"))
prebuilt <- arg("prebuilt", "")
cut12_prep_snapshot <- function(n_inst, n_days, db_path, snapshot_id, seed = NULL) {
  if (!file.copy(prebuilt, db_path, overwrite = TRUE)) stop("could not copy the prebuilt store")
  ledgr::ledgr_snapshot_open(db_path, snapshot_id, verify = FALSE)
}
mark("loaded")

restore <- function() NULL
if (arm != "pinned") {
  stopifnot(arm == "lean")
  restore <- lean$lean_prepare_install()
}
ns <- asNamespace("ledgr")
hook <- function(name, phase, when) {
  orig <- get(name, envir = ns)
  unlockBinding(name, ns)
  assign(name, function(...) {
    res <- orig(...)
    if (when(list(...))) mark(phase)
    res
  }, envir = ns)
  lockBinding(name, ns)
}
hook("ledgr_snapshot_open", "after_verified_open", function(a) isTRUE(a$verify))
hook("ledgr_history_substrate_fold_reader", "after_preparation", function(a) TRUE)

wd <- file.path(tempdir(), "mem_slot")
dir.create(wd, showWarnings = FALSE)
args <- list(shape = shape)
if (shape == "h1") args$state <- arg("state")
res <- tryCatch(cut12_prep(args, wd), finally = restore())
mark("after_run")
out <- do.call(rbind, marks)
out$work_digest <- substr(digest::digest(res$work), 1L, 12L)
print(out, row.names = FALSE)
path <- arg("out")
utils::write.table(out, path, sep = ",", row.names = FALSE, col.names = !file.exists(path), append = file.exists(path))
unlink(wd, recursive = TRUE)

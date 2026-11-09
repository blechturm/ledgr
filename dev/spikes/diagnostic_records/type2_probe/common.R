repo <- "C:/Users/maxth/ledgr-wt/diag-records-t2"
probe_root <- "C:/Users/maxth/ledgr-wt/diag-records-t2-out/probe"
out <- Sys.getenv("LEDGR_DIAG_T2_OUT",probe_root)
lib <- "C:/Users/maxth/AppData/Local/Temp/claude/a337d437c6e22de3/78383ced-ac83-4579-b480-65f39660106d/scratchpad/ws16/lib-d5b3a151"
source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/common.R"))
pin <- ws16_load_installed(lib)
ns <- asNamespace("ledgr")
work <- file.path(out, "work")
dir.create(work, recursive = TRUE, showWarnings = FALSE)
source(file.path(repo, "dev/spikes/diagnostic_records/workloads.R"))
clock <- function() proc.time()[["elapsed"]]
csv <- function(x, name) write.csv(x, file.path(out, paste0(name, ".csv")), row.names = FALSE)
wrap <- function(name, make) ws16_wrap(name, make)
restore <- function(name, value) {
  unlockBinding(name, ns)
  assign(name, value, ns)
  lockBinding(name, ns)
}

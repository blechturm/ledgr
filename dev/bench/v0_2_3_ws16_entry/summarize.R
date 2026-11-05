# Collects the per-process memory folders into evidence CSVs and groups the
# fold-entry components into the skeleton synthesis Section 5.1 categories.
#
#   Rscript summarize.R --work=<dir with mem_* folders> --out=<evidence dir> [--prefix=memory]

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  source(file.path(here, "common.R"))
})
work <- ws16_need("work")
out <- ws16_out(ws16_need("out"))
prefix <- ws16_arg("prefix", "memory")
dirs <- list.files(work, pattern = "^(mem|noverify)_", full.names = TRUE)
dirs <- dirs[file.exists(file.path(dirs, "memory_run.csv"))]
read_all <- function(file) {
  do.call(rbind, lapply(dirs, function(d) {
    x <- utils::read.csv(file.path(d, file), stringsAsFactors = FALSE)
    # Runs before the --verify switch existed opened with verify = TRUE.
    if (identical(file, "memory_run.csv") && is.null(x$verify)) x$verify <- TRUE
    cbind(run = basename(d), rep = sub(".*_", "", basename(d)), x)
  }))
}
phases <- read_all("memory_phases.csv")
components <- read_all("memory_components.csv")
runs <- read_all("memory_run.csv")

# Section 5.1 categories. Stack objects may share memory with the named
# components and are reported apart.
category <- function(group, name) {
  out <- rep("other", length(name))
  hs <- group == "history_substrate"
  out[hs & name %in% c("bars", "bar_gap_runs")] <- "source/history: bar planes"
  out[hs & name %in% c("segments", "segment_counts", "sessions", "provider_plan", "axis",
                       "pulse_index", "instrument_ids", "instrument_index")] <- "source/history: facts and axes"
  out[hs & name == "feature_projection"] <- "feature payload"
  out[hs & name == "history_memo"] <- "retained views (history memo)"
  out[group == "execution" & name %in% c("state")] <- "lots and opening state"
  out[group == "execution" & name %in% c("availability_provider", "schedule_sessions",
                                          "corporate_action_plan")] <- "provider and schedule"
  out[group == "output_handler"] <- "output buffers (handler)"
  out[group == "fold_result" & name == "state"] <- "lots and final state"
  out[group == "fold_result" & name == "equity_facts"] <- "output: equity record"
  out[startsWith(group, "stack:")] <- "stack objects >= 1 MB (may share)"
  out
}
components$category <- category(components$group, components$name)
by_cat <- stats::aggregate(mib ~ run + shape + at + category, components, sum)

ws16_write(phases, file.path(out, paste0(prefix, "_phases.csv")))
ws16_write(components, file.path(out, paste0(prefix, "_components.csv")))
ws16_write(by_cat, file.path(out, paste0(prefix, "_categories.csv")))
ws16_write(runs, file.path(out, paste0(prefix, "_runs.csv")))
peak <- stats::aggregate(cbind(peak_private_mib, peak_wset_mib) ~ run + shape, phases, max)
print(merge(runs, peak), row.names = FALSE)

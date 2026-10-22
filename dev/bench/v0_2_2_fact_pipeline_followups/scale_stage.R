# WS45 scale probe: one stage, one tree, one size, one fresh process.
#   Rscript scale_stage.R <tree> <arm> <stage> <rows> <cache_dir> <out_csv>
# Stages: lineage, conflicts, resolve, hash. Inputs are built from
# scale_fixtures.R; a tree's constructed Date family is cached per size so
# the timed call is the stage itself. Wall clock around the stage only,
# averaged over repeated calls when one call is faster than a second.
args <- commandArgs(trailingOnly = TRUE)
tree <- args[[1L]]
arm <- args[[2L]]
stage <- args[[3L]]
rows <- as.integer(args[[4L]])
cache_dir <- args[[5L]]
out_csv <- args[[6L]]
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
source(file.path(here, "scale_fixtures.R"))

per <- 100L
n_inst <- rows %/% per
sessions_df <- ws45_sessions_df(600L)
open <- ws45_open_dates(sessions_df)
sessions <- ledgr_facts_sessions(sessions_df, "XNYS", timezone = "America/New_York")

family_cache <- file.path(cache_dir, sprintf("%s_membership_date_%d.rds", arm, rows))
date_family <- function() {
  if (!file.exists(family_cache)) {
    family <- ledgr_facts_membership_intervals(ws45_membership_df(n_inst, per, open), "u")
    saveRDS(family, family_cache)
  }
  readRDS(family_cache)
}

if (identical(stage, "prepare")) {
  invisible(date_family())
  quit(save = "no")
}
input <- switch(stage,
  lineage = ws45_status_df(n_inst, per, open, every = 10L, depth = 2L),
  conflicts = ws45_status_df(n_inst, per, open, every = 10L, depth = 2L),
  resolve = date_family(),
  hash = ns$ledgr_facts_family(ledgr_facts(sessions, date_family()), "membership")[[1L]]
)
# Mean wall seconds per call: one call, repeated until the calls together
# take at least one second (the Windows clock ticks in about 10 ms), at most
# 200 times. A call slower than a second is timed once.
clock <- function(f) {
  invisible(gc())
  calls <- 0L
  start <- proc.time()[["elapsed"]]
  repeat {
    f()
    calls <- calls + 1L
    total <- proc.time()[["elapsed"]] - start
    if (total >= 1 || calls >= 200L) break
  }
  c(seconds = total / calls, calls = calls)
}
timed <- switch(stage,
  lineage = clock(function() ns$ledgr_status_lineage(input)),
  # The production trading-status validation sequence of each tree.
  conflicts = clock(function() {
    if (exists("ledgr_fact_validate_status_rows", envir = ns, inherits = FALSE)) {
      ns$ledgr_fact_validate_status_rows(input)
    } else {
      ns$ledgr_fact_validate_intervals(input$effective_from, input$effective_to, "trading status")
      ns$ledgr_fact_validate_status_supersession(input)
      ns$ledgr_fact_validate_source_conflicts(input)
    }
  }),
  resolve = clock(function() ledgr_facts(sessions, input)),
  hash = clock(function() ns$ledgr_fact_family_hash(
    input$family, input$scope_id, input$rows, input$headers, input$metadata
  ))
)
elapsed <- timed[["seconds"]]
fact_rows <- if (is.data.frame(input)) nrow(input) else nrow(input$rows)
line <- data.frame(
  arm = arm, stage = stage, target_rows = rows, fact_rows = fact_rows,
  elapsed_s = signif(elapsed, 4), calls = as.integer(timed[["calls"]]), pid = Sys.getpid(),
  time_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
)
utils::write.table(line, out_csv, sep = ",", row.names = FALSE,
  col.names = !file.exists(out_csv), append = file.exists(out_csv))
cat(sprintf("%s %s %d rows: %.4f s over %d calls\n", arm, stage, fact_rows, elapsed, as.integer(timed[["calls"]])))

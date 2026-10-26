# Measure schedule identity construction and reopen-validation separately from
# the H1 fold clock. The load and declaration setup are intentionally untimed.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: identity_cost.R <ledgr_src> <output.csv>", call. = FALSE)
ledgr_src <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
output <- args[[2L]]
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(ledgr_src, quiet = TRUE, compile = FALSE))

declaration <- unclass(ledgr::ledgr_schedule_from_param("when"))
params <- list(when = "month_start")
record <- ledgr:::ledgr_strategy_schedule_identity(declaration, params)
n <- 10000L
measure <- function(action) {
  elapsed <- system.time(for (i in seq_len(n)) action())[["elapsed"]]
  elapsed * 1e6 / n
}
rows <- do.call(rbind, lapply(seq_len(5L), function(repetition) {
  data.frame(
    repetition = repetition,
    build_us_per_candidate = measure(function() {
      ledgr:::ledgr_strategy_schedule_identity(declaration, params)
    }),
    validate_us_per_candidate = measure(function() {
      ledgr:::ledgr_strategy_schedule_identity_assert(
        record,
        declaration,
        params,
        context = "Benchmark candidate"
      )
    })
  )
}))
rows$n <- n
utils::write.csv(rows, output, row.names = FALSE)
cat(sprintf(
  "LEDGR_SCHEDULER_IDENTITY_OK build=%.1fus validate=%.1fus\n",
  stats::median(rows$build_us_per_candidate),
  stats::median(rows$validate_us_per_candidate)
))

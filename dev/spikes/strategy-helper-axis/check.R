# Rerun probe.R into a temporary file and diff it against observations.csv.
# Usage, from the repository root:
#
#   Rscript dev/spikes/strategy-helper-axis/check.R
#
# Prints every observation whose result changed. A fix is expected to change
# exactly the rows its ticket names; unchanged output prints "no change".

dir <- "dev/spikes/strategy-helper-axis"
fresh <- tempfile(fileext = ".csv")
status <- system2(file.path(R.home("bin"), "Rscript"), c(file.path(dir, "probe.R"), fresh))
if (!identical(status, 0L)) stop("probe.R failed")
recorded <- utils::read.csv(file.path(dir, "observations.csv"), stringsAsFactors = FALSE)
current <- utils::read.csv(fresh, stringsAsFactors = FALSE)
key <- function(x) paste(x$context, x$probe, sep = " | ")
joined <- merge(
  data.frame(key = key(recorded), recorded = recorded$result),
  data.frame(key = key(current), current = current$result),
  by = "key", all = TRUE
)
changed <- joined[is.na(joined$recorded) | is.na(joined$current) | joined$recorded != joined$current, ]
if (nrow(changed) == 0L) {
  cat("no change\n")
} else {
  for (i in seq_len(nrow(changed))) {
    cat(changed$key[[i]], "\n  was:", changed$recorded[[i]], "\n  now:", changed$current[[i]], "\n")
  }
}

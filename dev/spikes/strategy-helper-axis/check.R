# Rerun probe.R and compare it with the frozen baseline and the expected-delta
# manifest. Usage, from the repository root:
#
#   Rscript dev/spikes/strategy-helper-axis/check.R           # verify
#   Rscript dev/spikes/strategy-helper-axis/check.R --accept  # verify, then
#                                                             # replace the baseline
#
# observations.csv is the frozen Cut 22 input and stays unchanged until the
# workstream closes. expected_delta.csv lists every observation a Cut 22 ticket
# is expected to change (context, probe, was, now; "<absent>" marks an added or
# removed key). A ticket commits its manifest rows before its code change.
#
# The check fails unless: the fresh run has unique keys; every changed key is
# in the manifest with the same was and now; every manifest row is realized;
# every manifest `was` matches the frozen baseline; and the row count equals
# the baseline count plus added keys minus removed keys. --accept replaces the
# baseline and empties the manifest only after all of that passes.

dir <- "dev/spikes/strategy-helper-axis"
absent <- "<absent>"
fail <- function(...) { cat("FAIL:", ..., "\n"); quit(status = 1L) }

fresh_path <- tempfile(fileext = ".csv")
status <- system2(file.path(R.home("bin"), "Rscript"), c(file.path(dir, "probe.R"), fresh_path))
if (!identical(status, 0L)) fail("probe.R failed")

read <- function(path) utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character")
baseline <- read(file.path(dir, "observations.csv"))
fresh <- read(fresh_path)
manifest <- read(file.path(dir, "expected_delta.csv"))
key <- function(x) paste(x$context, x$probe, sep = " | ")

for (part in list(list("baseline", baseline), list("fresh run", fresh), list("manifest", manifest))) {
  k <- key(part[[2L]])
  if (anyDuplicated(k)) fail(part[[1L]], "has duplicate keys:", paste(unique(k[duplicated(k)]), collapse = "; "))
}

all_keys <- union(key(baseline), key(fresh))
was <- stats::setNames(rep(absent, length(all_keys)), all_keys)
now <- was
was[key(baseline)] <- baseline$result
now[key(fresh)] <- fresh$result
changed <- all_keys[was != now]

expected_was <- stats::setNames(manifest$was, key(manifest))
expected_now <- stats::setNames(manifest$now, key(manifest))
baseline_was <- stats::setNames(rep(absent, nrow(manifest)), key(manifest))
known <- key(manifest) %in% key(baseline)
baseline_was[known] <- was[key(manifest)[known]]

problems <- c(
  sprintf("unexpected change  %s\n    was: %s\n    now: %s", setdiff(changed, key(manifest)),
    was[setdiff(changed, key(manifest))], now[setdiff(changed, key(manifest))]),
  sprintf("manifest `was` does not match the frozen baseline  %s", key(manifest)[expected_was != baseline_was]),
  sprintf("expected change not realized  %s\n    expected: %s\n    now:      %s",
    key(manifest)[expected_now != now[key(manifest)] | is.na(now[key(manifest)])],
    expected_now[expected_now != now[key(manifest)] | is.na(now[key(manifest)])],
    now[key(manifest)][expected_now != now[key(manifest)] | is.na(now[key(manifest)])])
)
expected_rows <- nrow(baseline) + sum(manifest$was == absent) - sum(manifest$now == absent)
if (nrow(fresh) != expected_rows) {
  problems <- c(problems, sprintf("row count %d, expected %d (baseline %d + added %d - removed %d)",
    nrow(fresh), expected_rows, nrow(baseline), sum(manifest$was == absent), sum(manifest$now == absent)))
}

if (length(problems) > 0L) {
  cat(problems, sep = "\n")
  fail(length(problems), "problem(s)")
}
cat(sprintf("ok: %d observations, %d expected change(s), no other change\n", nrow(fresh), nrow(manifest)))

if ("--accept" %in% commandArgs(trailingOnly = TRUE)) {
  file.copy(fresh_path, file.path(dir, "observations.csv"), overwrite = TRUE)
  utils::write.csv(manifest[0L, , drop = FALSE], file.path(dir, "expected_delta.csv"), row.names = FALSE)
  cat("baseline replaced; manifest emptied\n")
}

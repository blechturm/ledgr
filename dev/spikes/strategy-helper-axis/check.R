# Rerun probe.R and compare it with the frozen baseline and the expected-delta
# manifest. Usage, from the repository root:
#
#   Rscript dev/spikes/strategy-helper-axis/check.R --through LDG-2908
#   Rscript dev/spikes/strategy-helper-axis/check.R            # all tickets
#   Rscript dev/spikes/strategy-helper-axis/check.R --accept   # all, then
#                                                              # replace the baseline
#
# observations.csv is the frozen Cut 22 input and stays unchanged until the
# workstream closes. expected_delta.csv, written by expected.R from the
# LDG-2906 model, lists every observation Cut 22 changes: context, probe,
# was, now, and the owning ticket. Tickets land in this order: LDG-2907,
# LDG-2908, LDG-2912, LDG-2909, LDG-2910. `--through none` checks the tree
# before any of them.
#
# The check fails unless: the fresh run has unique keys and the baseline's
# row count; every manifest `was` matches the frozen baseline; every row owned
# by a ticket up to --through shows its `now`; and every row outside the
# manifest is unchanged. Rows owned by later tickets are reported, not
# checked, because an intermediate state may legitimately differ from both
# ends. --accept requires the full check and then replaces the baseline and
# empties the manifest.

dir <- "dev/spikes/strategy-helper-axis"
tickets <- c("LDG-2907", "LDG-2908", "LDG-2912", "LDG-2909", "LDG-2910")
args <- commandArgs(trailingOnly = TRUE)
fail <- function(...) { cat("FAIL:", ..., "\n"); quit(status = 1L) }

through <- "all"
if ("--through" %in% args) through <- args[[match("--through", args) + 1L]]
if (!through %in% c("all", "none", tickets)) fail("--through must be none, all or one of", paste(tickets, collapse = ", "))
done <- switch(through, all = tickets, none = character(), tickets[seq_len(match(through, tickets))])
accept <- "--accept" %in% args
if (accept && !identical(through, "all")) fail("--accept requires the full check")

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
if (nrow(fresh) != nrow(baseline) || !setequal(key(fresh), key(baseline))) {
  fail(sprintf("fresh run has %d rows and %d keys outside the baseline; the baseline has %d rows",
    nrow(fresh), length(setdiff(key(fresh), key(baseline))), nrow(baseline)))
}
if (any(!manifest$ticket %in% tickets)) fail("manifest names an unknown ticket")

was <- stats::setNames(baseline$result, key(baseline))
now <- stats::setNames(fresh$result, key(fresh))[key(baseline)]
mkey <- key(manifest)
owned_done <- mkey[manifest$ticket %in% done]
expected_done <- stats::setNames(manifest$now, mkey)[owned_done]
pending <- mkey[!manifest$ticket %in% done]

outside <- setdiff(key(baseline), mkey)
unexpected <- outside[was[outside] != now[outside]]
bad_was <- mkey[!mkey %in% key(baseline) | manifest$was != was[mkey]]
unrealized <- owned_done[now[owned_done] != expected_done]

problems <- c(
  sprintf("unexpected change  %s\n    was: %s\n    now: %s", unexpected, was[unexpected], now[unexpected]),
  sprintf("manifest `was` does not match the frozen baseline  %s", bad_was),
  sprintf("expected change not realized  %s\n    expected: %s\n    now:      %s",
    unrealized, expected_done[unrealized], now[unrealized])
)
if (length(problems) > 0L) {
  cat(problems, sep = "\n")
  fail(length(problems), "problem(s)")
}
cat(sprintf("ok through %s: %d observations, %d expected change(s) realized, %d pending for later tickets (%d already at their final value)\n",
  through, nrow(fresh), length(owned_done), length(pending),
  sum(now[pending] == stats::setNames(manifest$now, mkey)[pending])))

if (accept) {
  file.copy(fresh_path, file.path(dir, "observations.csv"), overwrite = TRUE)
  utils::write.csv(manifest[0L, , drop = FALSE], file.path(dir, "expected_delta.csv"), row.names = FALSE)
  cat("baseline replaced; manifest emptied\n")
}

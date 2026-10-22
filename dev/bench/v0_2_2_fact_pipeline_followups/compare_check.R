# WS45 identity checker: Rscript compare_check.R <base.rds> <candidate.rds>
# Every observable must be identical except the declared intended
# differences, each of which must differ.
args <- commandArgs(trailingOnly = TRUE)
base <- readRDS(args[[1L]])
cand <- readRDS(args[[2L]])
intended <- c(
  "facts/diff_ca_supplied_knowledge",
  "facts/diff_ca_mixed_knowledge",
  "facts/diff_ca_posix_effective",
  "facts/diff_ca_false_accept",
  "facts/diff_ca_false_refusal",
  "facts/diff_membership_false_refusal",
  "facts/diff32_membership_assume",
  "facts/diff32_status_assume",
  "facts/diff32_lifetime_assume",
  "facts/diff32_snapshots_assume",
  "facts/diff34_snapshot_header_order",
  "snapshots/diff_d28_effective_only",
  "snapshots/diff_d33_dividend_effective_only"
)
leaves <- function(x, prefix) {
  if (is.list(x) && !is.data.frame(x) && !is.null(names(x)) && all(nzchar(names(x)))) {
    unlist(lapply(names(x), function(n) leaves(x[[n]], paste(prefix, n, sep = "/"))), recursive = FALSE)
  } else {
    stats::setNames(list(x), prefix)
  }
}
fail <- FALSE
for (section in c("facts", "snapshots")) {
  b <- leaves(base[[section]], section)
  c <- leaves(cand[[section]], section)
  keys <- union(names(b), names(c))
  same <- vapply(keys, function(k) identical(b[[k]], c[[k]]), logical(1))
  for (case in unique(sub("^([^/]+/[^/]+).*$", "\\1", keys))) {
    in_case <- startsWith(keys, paste0(case, "/")) | keys == case
    identical_case <- all(same[in_case])
    ok <- identical_case != (case %in% intended)
    if (!ok) fail <- TRUE
    differing <- sub(paste0(case, "/"), "", keys[in_case & !same], fixed = TRUE)
    line <- sprintf("%-40s %-9s %-10s %s", case,
      if (identical_case) "IDENTICAL" else "DIFFERS",
      if (ok) "ok" else "UNEXPECTED",
      if (length(differing)) paste0("[", paste(differing, collapse = ", "), "]") else "")
    cat(sub(" +$", "", line), "\n", sep = "")
  }
}
fmt <- function(x) ifelse(is.na(x), "NA", format(.POSIXct(x, tz = "UTC"), "%Y-%m-%d %H:%M"))
describe <- function(x) {
  if (!is.null(x$error)) return(paste("REFUSED", x$error))
  fams <- Filter(function(f) !identical(f$family, "sessions"), x$families)
  r <- fams[[1L]]$rows
  if ("effective_time" %in% names(r)) {
    sprintf("entitlement=%s effective=%s knowledge=%s",
      fmt(r$entitlement_time), fmt(r$effective_time), fmt(r$knowledge_time))
  } else {
    h <- fams[[1L]]$headers
    c(
      sprintf("from=%s to=%s knowledge=%s", fmt(r$effective_from), fmt(r$effective_to), fmt(r$knowledge_time)),
      if (!is.null(h) && nrow(h) > 0L) sprintf("header %s knowledge=%s", h$set_id, fmt(h$knowledge_time))
    )
  }
}
cat("\nIntended differences (UTC):\n")
for (name in sub("^facts/", "", grep("^facts/", intended, value = TRUE))) {
  cat(sprintf("  %s\n    BASE:      %s\n    candidate: %s\n", name,
    paste(describe(base$facts[[name]]), collapse = "; "),
    paste(describe(cand$facts[[name]]), collapse = "; ")))
}
for (arm in c("base", "cand")) {
cat(sprintf("\nSnapshot runs (%s):\n", arm))
for (name in names(cand$snapshots)) {
  x <- get(arm)$snapshots[[name]]
  run <- x$run
  run_text <- if (!is.null(run$error)) paste("REFUSED", run$error) else sprintf(
    "%d ledger rows, %d equity rows, %d corporate-action events",
    nrow(run$ledger), nrow(run$equity), sum(grepl("corporate_action", run$ledger$meta_json)))
  chain_text <- if (!is.null(x$chain$error)) paste("REFUSED", x$chain$error) else
    sprintf("%s with %d test runs", x$chain$status, length(x$chain$runs))
  cat(sprintf("  %s: hash=%s rule=%s; run: %s; walk-forward: %s\n", name,
    substr(x$snapshot_hash, 1, 16), x$hash_rule_version, run_text, chain_text))
}
}
cat(if (fail) "\nWS45_IDENTITY_FAIL\n" else "\nWS45_IDENTITY_OK\n")
if (fail) quit(status = 1L)

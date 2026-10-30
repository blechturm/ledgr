# Six bounded detectors on observed scratch output; never mutate expectations.
file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
source(file.path(dirname(normalizePath(file)), "native.R"))
pkg <- normalizePath(dense_arg("pkg", file.path(dense_home(), "../../../..")), winslash = "/")
records <- normalizePath(dense_arg("records", file.path(dense_home(), "oracles/20261030-pre-ws4")), winslash = "/")
out <- normalizePath(dense_arg("out", tempfile("dense-gut-")), winslash = "/", mustWork = FALSE)
if (identical(out, records) || startsWith(out, paste0(records, "/"))) stop("scratch overlaps freeze")
dense_load(pkg)
before <- dense_scope(pkg)
dense_record(out, pkg)
stopifnot(nrow(dense_compare(records, out)) == 0L)
cat("gut control: PASS, independent scratch rerun identical\n")
read <- function(label) readRDS(file.path(out, label, "native.rds"))
base <- read("transition")
# The next IEEE-754 positive double, by incrementing its little-endian bits.
next_double <- function(x) {
  stopifnot(is.finite(x), x > 0)
  bytes <- as.integer(writeBin(x, raw(), size = 8L, endian = "little"))
  carry <- which(bytes < 255L)[1L]
  if (carry > 1L) bytes[seq_len(carry - 1L)] <- 0L
  bytes[carry] <- bytes[carry] + 1L
  readBin(as.raw(bytes), "double", n = 1L, size = 8L, endian = "little")
}
results <- list()
check_mutation <- function(name, expected, actual, field) {
  d <- dense_diff(dense_projection(expected), dense_projection(actual))
  stopifnot(nrow(d) > 0L, any(grepl(field, d$field, fixed = TRUE)))
  d$corruption <- name
  results[[name]] <<- d
  cat("detected ", name, ": ", d$field[1L], " (", d$detail[1L], ")\n", sep = "")
}
r <- base
r$tables$fills$qty[1L] <- r$tables$fills$qty[1L] + 1
stopifnot(identical(r$tables$equity_curve, base$tables$equity_curve))
check_mutation("fill_quantity_equity_unchanged", base, r, "economic$fills$qty")
r <- base
old_cash <- r$tables$equity_curve$cash[1L]
r$tables$equity_curve$cash[1L] <- next_double(old_cash)
stopifnot(r$tables$equity_curve$cash[1L] > old_cash)
check_mutation("one_ulp_cash", base, r, "economic$equity$cash")
r <- base
r$tables$rebuilt_positions$qty[1L] <- r$tables$rebuilt_positions$qty[1L] + 1
stopifnot(identical(r$tables$equity_curve$positions_value, base$tables$equity_curve$positions_value))
check_mutation("asset_quantity_aggregate_unchanged", base, r, "economic$positions$qty")
r <- base
payload <- setdiff(names(r$tables$ledger_events), c("run_id", "event_id", "event_seq"))
r$tables$ledger_events[1:2, payload] <- r$tables$ledger_events[2:1, payload]
check_mutation("economic_event_order", base, r, "economic$ledger$instrument_id")
control <- read("cost_final")
r <- control
r$tables$conditions <- r$tables$conditions[FALSE, , drop = FALSE]
check_mutation("final_pulse_warning_suppressed", control, r, "representation$conditions")
# Remove prior usability in the executed strategy, not in a narrated timeline.
case <- dense_cases()$transition
fixture <- dense_fixture(case)
text <- paste(deparse(body(fixture$strategy)), collapse = "\n")
stopifnot(grepl("prior_usable & usable", text, fixed = TRUE))
body(fixture$strategy) <- parse(text = gsub("prior_usable & usable", "usable", text, fixed = TRUE))[[1L]]
r <- dense_run("transition", case, fixture, pkg)
stopifnot(!identical(base$tables$fills, r$tables$fills))
check_mutation("prior_usable_state_removed", base, r, "economic$fills")
utils::write.csv(do.call(rbind, results), file.path(out, "gut_differences.csv"), row.names = FALSE)
stopifnot(length(results) == 6L, identical(before, dense_scope(pkg)))
cat("gut: PASS; control reproduced, six native/rule corruptions detected; freeze unchanged\n")

# Derive expected_delta.csv from the LDG-2906 model. Usage, from the
# repository root:
#
#   Rscript dev/spikes/strategy-helper-axis/expected.R
#
# Runs probe.R against the package and against model.R. The package run must
# reproduce the frozen observations.csv. Every observation the model changes
# is written to expected_delta.csv with the ticket that owns it. A row that
# depends on several tickets belongs to the last of them in sequence. The
# script stops on a change no ticket owns, on any change to behaviour the
# decision keeps, and on any dense change outside an exact list of keys.

dir <- "dev/spikes/strategy-helper-axis"
tickets <- c("LDG-2907", "LDG-2908", "LDG-2912", "LDG-2909", "LDG-2910")
rscript <- file.path(R.home("bin"), "Rscript")
run_probe <- function(model = "") {
  out <- tempfile(fileext = ".csv")
  Sys.setenv(AXIS_PROBE_MODEL = model)
  on.exit(Sys.unsetenv("AXIS_PROBE_MODEL"))
  if (!identical(system2(rscript, c(file.path(dir, "probe.R"), out)), 0L)) stop("probe.R failed")
  utils::read.csv(out, stringsAsFactors = FALSE, colClasses = "character")
}
key <- function(x) paste(x$context, x$probe, sep = " | ")

baseline <- utils::read.csv(file.path(dir, "observations.csv"), stringsAsFactors = FALSE, colClasses = "character")
package <- run_probe()
model <- run_probe(file.path(dir, "model.R"))
if (!identical(key(package), key(baseline)) || !identical(package$result, baseline$result)) {
  stop("the package run does not reproduce observations.csv; freeze the baseline first")
}
if (!identical(key(model), key(baseline))) stop("the model run has different keys")

changed <- baseline$result != model$result
delta <- data.frame(context = baseline$context[changed], probe = baseline$probe[changed],
  was = baseline$result[changed], now = model$result[changed], stringsAsFactors = FALSE)

owner <- function(probe) {
  rules <- c(
    "LDG-2910" = "^warmup: passed_warmup\\(ctx, ",
    "LDG-2909" = "^wrapper: |^run: signal_strategy",
    "LDG-2912" = "^selection: |^pipeline: |^refusal: |^run: selection|^sweep: |^walk-forward: ",
    "LDG-2908" = "^signal: |\\[signal > threshold\\]|^warmup: passed_warmup\\(signal\\)|^run: hand-built",
    "LDG-2907" = "^context: ctx\\$members$|^context: eligibility planes|^context: ctx\\$vec\\$admissible$|^context: ctx\\$vec\\$target_restriction_reason$|\\[vec\\$(member|admissible) & "
  )
  out <- rep(NA_character_, length(probe))
  for (ticket in names(rules)) out[is.na(out) & grepl(rules[[ticket]], probe)] <- ticket
  out
}
delta$ticket <- owner(delta$probe)
if (anyNA(delta$ticket)) {
  stop("changes no ticket owns:\n", paste(key(delta)[is.na(delta$ticket)], collapse = "\n"))
}

# Behaviour the decision keeps must not change anywhere: context entrances and
# their condition classes, value mode, reads, constructors, views and the
# one-argument warmup form.
kept <- grepl(paste0("^entrance: |^value: |^read: |^view: |^constructor: |^context: universe$|",
  "^context: ctx\\$state_prev|^hand-built: flat\\(\\)\\[vec\\$feature|^warmup: passed_warmup\\(ctx\\$|",
  "^warmup: passed_warmup\\(numeric|^warmup: passed_warmup\\(c\\("), delta$probe)
if (any(kept)) stop("behaviour the decision keeps would change:\n", paste(key(delta)[kept], collapse = "\n"))

# In dense contexts only these probes may change: the eligibility planes, the
# masks that read them, the signal's eligibility attribute and the new warmup
# form. Every dense helper result stays as it is.
dense_allowed <- c(
  "context: ctx$members", "context: eligibility planes in ctx$vec", "context: ctx$vec$admissible",
  "context: ctx$vec$target_restriction_reason",
  "hand-built: flat()[vec$member & vec$feature > threshold] <- 10",
  "hand-built: flat()[vec$admissible & vec$feature > threshold] <- 10",
  "signal: attributes of ledgr_signal_return", "signal: attributes after arithmetic (-signal)",
  "warmup: passed_warmup(ctx, ctx$vec$feature)", "warmup: passed_warmup(ctx, signal)",
  "warmup: passed_warmup(ctx, named member-only feature)", "warmup: passed_warmup(ctx, character)"
)
dense <- grepl("^dense", delta$context) | delta$context %in% c("real_dense", "pulse_snapshot")
if (any(dense & !delta$probe %in% dense_allowed)) {
  stop("dense results the decision keeps would change:\n", paste(key(delta)[dense & !delta$probe %in% dense_allowed], collapse = "\n"))
}

delta <- delta[order(match(delta$ticket, tickets), delta$context, delta$probe), , drop = FALSE]
utils::write.csv(delta, file.path(dir, "expected_delta.csv"), row.names = FALSE)
cat(sprintf("wrote %d expected changes: %s\n", nrow(delta),
  paste(sprintf("%s %d", tickets, tabulate(match(delta$ticket, tickets), length(tickets))), collapse = ", ")))

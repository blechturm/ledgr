# Cut 20 decision 7 (cut review R2): the keep rule on the raw rows of
# loop_shortcuts.R --mode=compare (base 6e90a881 against the final
# candidate). No timing of its own.
#
# Refuses: shapes other than exactly 10x7200, 20x23400, 500x1260 and
# slice2_10x7200; a round count other than --rounds (7); a missing,
# duplicate or incomplete pair; a missing, non-finite or non-integral round;
# a missing, non-finite or non-positive clock.
#
# Per shape, with b and c the paired base and candidate pulse-loop seconds:
# median((b-c)/b), its minimum and all paired savings; the base and candidate
# medians of the pulse loop, the envelope and the whole run; the pulse ratio
# median(c)/median(b); and, by round, the change outside the loop,
# (candidate clock - candidate pulses) - (base clock - base pulses), for the
# envelope and the whole run, as outside_loop.R computes it, with the median
# and the count of rounds where the candidate was slower.
#
# Speed condition: median((b-c)/b) >= 0.02 on at least one shape. Pulse
# regression condition: median(c)/median(b) <= 1.05 on every shape.
# Displaced check (Cut 15), per shape and clock: "none" when the median
# change is at or below 0; "regression" when it is above 0 and the candidate
# was slower in at least rounds - 1 rounds; otherwise "unresolved". A
# regression or an unresolved result blocks: it goes to the maintainer and is
# not recorded as no regression. The verdict is "keep" only when both
# conditions hold and every displaced result is "none"; "revert" when the
# speed or the pulse-regression condition fails; otherwise "open".
#
#   Rscript dev/lean_core/parity/cut20_keep.R --raw=<compare_raw.csv> --out=<dir> [--rounds=7]

args <- commandArgs(TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default %||% stop("--", name, "= is required", call. = FALSE)
}
raw <- utils::read.csv(opt("raw"), stringsAsFactors = FALSE)
out <- opt("out")
rounds <- as.integer(opt("rounds", "7"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
shapes <- c("10x7200", "20x23400", "500x1260", "slice2_10x7200")
refuse <- function(...) stop("cut20_keep: ", ..., call. = FALSE)

if (!setequal(unique(raw$shape), shapes)) refuse("shapes are ", paste(sort(unique(raw$shape)), collapse = ", "))
if (!setequal(unique(raw$arm), c("base", "candidate"))) refuse("arms are ", paste(sort(unique(raw$arm)), collapse = ", "))
for (clock in c("pulses_s", "envelope_s", "whole_s")) {
  v <- raw[[clock]]
  if (is.null(v) || anyNA(v) || !all(is.finite(v)) || any(v <= 0)) refuse("missing, non-finite or non-positive ", clock)
}
# Round keys are checked before any coercion (close review round 1, F1): each
# must be present, finite and integral, and each arm must hold exactly the
# rounds 1..rounds, so both arms carry the same keys and rows pair on them.
if (!is.numeric(raw$round) || anyNA(raw$round) || !all(is.finite(raw$round)) || any(raw$round != round(raw$round)))
  refuse("round values must be present, finite and integral")
k <- paste(raw$shape, raw$arm, raw$round)
if (anyDuplicated(k)) refuse("duplicate rows: ", paste(unique(k[duplicated(k)]), collapse = "; "))
for (s in shapes) for (a in c("base", "candidate")) {
  r <- sort(raw$round[raw$shape == s & raw$arm == a])
  if (length(r) != rounds || any(r != seq_len(rounds))) refuse(s, " ", a, ": rounds ", paste(r, collapse = ","), ", expected 1..", rounds)
}

rows <- list()
displaced <- list()
for (s in shapes) {
  b <- raw[raw$shape == s & raw$arm == "base", ]
  c <- raw[raw$shape == s & raw$arm == "candidate", ]
  b <- b[match(seq_len(rounds), b$round), ]
  c <- c[match(seq_len(rounds), c$round), ]
  stopifnot(identical(b$round, c$round))
  saving <- (b$pulses_s - c$pulses_s) / b$pulses_s
  rows[[s]] <- data.frame(shape = s, rounds = rounds,
    saving_median = stats::median(saving), saving_min = min(saving),
    savings = paste(sprintf("%.4f", saving), collapse = " "),
    base_pulses_median = stats::median(b$pulses_s), candidate_pulses_median = stats::median(c$pulses_s),
    pulse_ratio = stats::median(c$pulses_s) / stats::median(b$pulses_s),
    base_envelope_median = stats::median(b$envelope_s), candidate_envelope_median = stats::median(c$envelope_s),
    base_whole_median = stats::median(b$whole_s), candidate_whole_median = stats::median(c$whole_s),
    stringsAsFactors = FALSE)
  for (clock in c("envelope", "whole")) {
    d <- (c[[paste0(clock, "_s")]] - c$pulses_s) - (b[[paste0(clock, "_s")]] - b$pulses_s)
    slower <- sum(d > 0)
    displaced[[paste(s, clock)]] <- data.frame(shape = s, outside_of = clock, rounds = rounds,
      base_outside_median_s = stats::median(b[[paste0(clock, "_s")]] - b$pulses_s),
      median_change_s = stats::median(d), rounds_slower = slower, min_change_s = min(d), max_change_s = max(d),
      changes_s = paste(sprintf("%.4f", d), collapse = " "),
      result = if (stats::median(d) <= 0) "none" else if (slower >= rounds - 1L) "regression" else "unresolved",
      stringsAsFactors = FALSE)
  }
}
paired <- do.call(rbind, rows)
outside <- do.call(rbind, displaced)
speed <- any(paired$saving_median >= 0.02)
pulse_ok <- all(paired$pulse_ratio <= 1.05)
outside_ok <- all(outside$result == "none")
verdict <- if (!speed || !pulse_ok) "revert" else if (outside_ok) "keep" else "open"
utils::write.csv(paired, file.path(out, "keep_paired.csv"), row.names = FALSE)
utils::write.csv(outside, file.path(out, "keep_outside.csv"), row.names = FALSE)
writeLines(c(sprintf("speed condition (median paired saving >= 0.02 on some shape): %s", speed),
             sprintf("pulse regression condition (median ratio <= 1.05 on every shape): %s", pulse_ok),
             sprintf("displaced check (every shape and clock 'none'): %s", outside_ok),
             sprintf("verdict: %s", verdict)), file.path(out, "keep_verdict.txt"))
print(paired[, c("shape", "saving_median", "saving_min", "base_pulses_median", "candidate_pulses_median", "pulse_ratio")], row.names = FALSE)
print(outside[, c("shape", "outside_of", "median_change_s", "rounds_slower", "result")], row.names = FALSE)
cat(readLines(file.path(out, "keep_verdict.txt")), sep = "\n")
quit(status = if (identical(verdict, "keep")) 0L else 1L)

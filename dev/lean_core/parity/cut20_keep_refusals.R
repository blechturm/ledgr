# Refusal checks for cut20_keep.R (close review round 1, F1). Each malformed
# copy of the committed raw rows must refuse with a "cut20_keep:" message and
# write no paired result; the unchanged rows must reproduce the committed
# verdict ("open"), and a synthetic complete control must return "keep".
#
#   Rscript dev/lean_core/parity/cut20_keep_refusals.R --out=<dir>

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
out <- sub("^--out=", "", grep("^--out=", commandArgs(TRUE), value = TRUE)[[1L]])
dir.create(out, recursive = TRUE, showWarnings = FALSE)
keep <- file.path(here, "cut20_keep.R")
raw <- utils::read.csv(file.path(here, "evidence/cut20/timing/compare_raw.csv"), stringsAsFactors = FALSE)
rscript <- file.path(R.home("bin"), "Rscript")
i <- which(raw$shape == "10x7200" & raw$arm == "candidate" & raw$round == 1)
with_round <- function(x, v) { x$round[i] <- v; x }
synthetic <- raw
synthetic$pulses_s <- ifelse(synthetic$arm == "base", 100, 90)
synthetic$envelope_s <- synthetic$pulses_s + 100
synthetic$whole_s <- synthetic$pulses_s + 200
cases <- list(
  original = list(raw, "verdict: open"),
  synthetic_complete = list(synthetic, "verdict: keep"),
  fractional_round = list(with_round(raw, 1.5), NA),
  fractional_round_synthetic = list(with_round(synthetic, 1.5), NA),
  replaced_round = list(with_round(raw, 8), NA),
  na_round = list(with_round(raw, NA), NA),
  missing_row = list(raw[-i, ], NA),
  duplicate_row = list(rbind(raw, raw[i, ]), NA),
  na_pulse = list(within(raw, pulses_s[i] <- NA), NA),
  zero_pulse = list(within(raw, pulses_s[i] <- 0), NA),
  no_round_column = list(raw[, names(raw) != "round"], NA))
res <- do.call(rbind, lapply(names(cases), function(label) {
  dest <- file.path(out, label)
  csv <- paste0(dest, ".csv")
  utils::write.csv(cases[[label]][[1L]], csv, row.names = FALSE)
  log <- suppressWarnings(system2(rscript, c(keep, paste0("--raw=", csv), paste0("--out=", dest)), stdout = TRUE, stderr = TRUE))
  writeLines(log, paste0(dest, ".log"))
  expected <- cases[[label]][[2L]]
  refused <- any(grepl("cut20_keep:", log)) && !file.exists(file.path(dest, "keep_paired.csv"))
  ok <- if (is.na(expected)) refused else any(log == expected)
  data.frame(case = label, expected = if (is.na(expected)) "refusal" else expected,
             outcome = paste(grep("cut20_keep:|verdict:", log, value = TRUE), collapse = " | "), ok = ok)
}))
utils::write.csv(res, file.path(out, "keep_refusals.csv"), row.names = FALSE)
print(res, row.names = FALSE)
cat(sprintf("%d of %d cases as expected\n", sum(res$ok), nrow(res)))
quit(status = if (all(res$ok)) 0L else 1L)

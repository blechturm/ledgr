# The clarity scan (Cut 27 decision 4, LDG-3277). Over the lean core's
# production files (the set cut19_lines.R counts as production), it reports:
# - every use of the symbols `s3` and `s4` (parsed tokens, so the workload
#   prefixes in strings and names such as s3_closes are not counted);
# - every comment line that cites a pin line number, a cut, a ticket or a
#   review.
#   Rscript clarity_scan.R [--out=<csv>]   exits 1 when anything is found
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
lean <- normalizePath(file.path(here, ".."), winslash = "/")
files <- c("loop.R", "plan.R", "checks.R", "fifo.R", "prepare.R", "loop_harness.R", "marks.R", "facts.R")
# A pin line (R/x.R:123 or a commit hash), a cut, a ticket, a review or a
# review finding by number.
citation <- paste0("R/[A-Za-z0-9_.-]+[.]R:[0-9]|\\b[0-9a-f]{8}\\b|\\bCut [0-9]+|\\bcut [0-9]+\\b|LDG-[0-9]+|",
                   "\\b(close |cut |re)?review\\b|\\bround [0-9]+\\b|\\b[RFS][0-9]+\\b|Workstream [0-9]+|\\bWS[0-9]+")
rows <- list()
for (f in files) {
  path <- file.path(lean, f)
  pd <- utils::getParseData(parse(path, keep.source = TRUE))
  sym <- pd[pd$token == "SYMBOL" & pd$text %in% c("s3", "s4"), ]
  if (nrow(sym)) rows[[length(rows) + 1L]] <- data.frame(file = f, line = sym$line1, kind = "symbol", text = sym$text)
  com <- pd[pd$token == "COMMENT", ]
  hit <- com[grepl(citation, com$text, perl = TRUE), ]
  if (nrow(hit)) rows[[length(rows) + 1L]] <- data.frame(file = f, line = hit$line1, kind = "citation", text = hit$text)
}
out <- if (length(rows)) do.call(rbind, rows) else data.frame(file = character(), line = integer(), kind = character(), text = character())
arg <- grep("^--out=", commandArgs(TRUE), value = TRUE)
if (length(arg)) utils::write.csv(out, sub("^--out=", "", arg), row.names = FALSE)
print(table(out$file, out$kind))
cat(nrow(out), "finding(s)\n")
quit(status = if (nrow(out)) 1L else 0L)

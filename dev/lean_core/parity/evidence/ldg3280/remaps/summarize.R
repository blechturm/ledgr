# LDG-3280: one row per remap directory (remaps/R*/): its outcome from
# result.csv, gate.md or finding.md, set against the inventory's b rows
# without a named Cut 28 gate (batch_A.csv, batch_B.csv). Writes summary.csv.
#   Rscript summarize.R
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
batch <- rbind(utils::read.csv(file.path(here, "batch_A.csv"), stringsAsFactors = FALSE),
               utils::read.csv(file.path(here, "batch_B.csv"), stringsAsFactors = FALSE))
dirs <- sort(list.dirs(here, recursive = FALSE, full.names = TRUE))
dirs <- dirs[grepl("^R[0-9]{3}$", basename(dirs))]
first_line <- function(f) {
  x <- readLines(f, warn = FALSE, encoding = "UTF-8")
  x <- x[nzchar(trimws(x)) & !startsWith(x, "#")]
  if (length(x)) substr(x[[1L]], 1L, 240L) else ""
}
rows <- lapply(dirs, function(d) {
  id <- basename(d)
  res <- file.path(d, "result.csv")
  outcome <- if (file.exists(res)) utils::read.csv(res, stringsAsFactors = FALSE)$verdict[[1L]] else ""
  extra <- c(if (file.exists(file.path(d, "gate.md"))) "CUT 28 GATE", if (file.exists(file.path(d, "finding.md"))) "FINDING")
  status <- paste(c(outcome, extra)[nzchar(c(outcome, extra))], collapse = " + ")
  detail <- if (file.exists(file.path(d, "gate.md"))) first_line(file.path(d, "gate.md")) else
    if (file.exists(file.path(d, "finding.md"))) first_line(file.path(d, "finding.md")) else ""
  data.frame(row_id = id, file = batch$file[match(id, batch$row_id)], status = status,
             patch = file.exists(file.path(d, "remap.patch")), mutation = file.exists(file.path(d, "mutation.csv")),
             detail = detail, stringsAsFactors = FALSE)
})
s <- do.call(rbind, rows)
missing <- setdiff(batch$row_id, s$row_id)
utils::write.csv(s, file.path(here, "summary.csv"), row.names = FALSE)
cat(sprintf("%d batch rows, %d row directories, %d batch rows without a directory\n", nrow(batch), nrow(s), length(missing)))
print(table(s$status))
if (length(missing)) cat("missing:", missing, "\n")
bad <- s[grepl("NOT DEMONSTRATED", s$status) | !nzchar(s$status), ]
if (nrow(bad)) print(bad[, c("row_id", "status")], row.names = FALSE)

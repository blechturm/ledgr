# Cut 19 (LDG-3240): the frozen-row moves of the cut, before and after.
# The effective freeze is loop_freeze.csv with loop_freeze_changes.csv
# applied in order (loop_parity.R); "before" applies the changes recorded at
# the base commit, "after" those in the working tree. Every row whose path
# differs, or that exists on one side only, is written with both sides.
#
# Usage: Rscript dev/lean_core/parity/cut19_moves.R --base=bdeea449 --out=<csv>
args <- commandArgs(TRUE)
opt <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), args, value = TRUE))
base <- opt("base")
out <- opt("out")
if (length(base) != 1L || length(out) != 1L) stop("usage: --base=<commit> --out=<csv>")
here <- "dev/lean_core/parity"
read_at <- function(file, commit) {
  text <- if (is.null(commit)) readLines(file.path(here, file)) else
    system2("git", c("show", paste0(commit, ":", here, "/", file)), stdout = TRUE)
  utils::read.csv(text = text, stringsAsFactors = FALSE, na.strings = character(), colClasses = "character")
}
effective <- function(commit) {
  frz <- read_at("loop_freeze.csv", commit)
  ch <- read_at("loop_freeze_changes.csv", commit)
  key <- function(x) paste(x$mode, x$workload, x$debug)
  cols <- c("lean_folds", "refused", "backstop")
  for (i in seq_len(nrow(ch))) {
    hit <- which(key(frz) == key(ch[i, ]))
    if (ch$action[[i]] == "update" && length(hit) == 1L) frz[hit, cols] <- ch[i, cols]
    else if (ch$action[[i]] == "add" && length(hit) == 0L) frz <- rbind(frz, ch[i, names(frz)])
    else stop("change ", i, " does not apply at ", if (is.null(commit)) "the working tree" else commit)
  }
  frz$path <- paste(frz$lean_folds, frz$refused, frz$backstop, sep = " | ")
  frz$key <- key(frz)
  frz
}
before <- effective(base)
after <- effective(NULL)
keys <- union(before$key, after$key)
b <- before$path[match(keys, before$key)]
a <- after$path[match(keys, after$key)]
moved <- is.na(b) | is.na(a) | b != a
row <- function(k) strsplit(k, " ", fixed = TRUE)[[1L]]
parts <- do.call(rbind, lapply(keys[moved], row))
res <- data.frame(mode = parts[, 1L], workload = parts[, 2L], debug = parts[, 3L],
  before = ifelse(is.na(b[moved]), "(absent)", b[moved]), after = ifelse(is.na(a[moved]), "(absent)", a[moved]),
  stringsAsFactors = FALSE)
res <- res[order(res$before == "(absent)", res$mode, res$workload, res$debug), ]
utils::write.csv(res, out, row.names = FALSE)
cat(sprintf("%d rows moved (%d changed, %d added, %d removed); paths are lean_folds | refused | backstop\n",
  nrow(res), sum(res$before != "(absent)" & res$after != "(absent)"), sum(res$before == "(absent)"),
  sum(res$after == "(absent)")))

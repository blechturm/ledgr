args <- commandArgs(TRUE)
lines <- readLines(args[[1]])[-1]
anchor <- args[[2]]
lines <- lines[grepl(paste0('"', anchor, '"'), lines, fixed = TRUE)]
cat("samples under", anchor, length(lines), "\n")
st <- lapply(strsplit(lines, " "), function(x) unique(gsub('"', "", x)))
# keep only frames inside anchor (frames listed innermost first)
st <- lapply(strsplit(lines, " "), function(x) { x <- gsub('"', "", x); k <- match(anchor, x); unique(x[seq_len(k - 1L)]) })
tab <- sort(table(unlist(st)), decreasing = TRUE)
options(width = 200)
print(head(round(100 * tab / length(lines), 1), as.integer(if (length(args) > 2) args[[3]] else 80)))

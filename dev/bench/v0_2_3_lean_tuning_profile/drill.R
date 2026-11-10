# Drill-down for profile.R: within samples whose stack contains `inside`
# (and, optionally, not `exclude`), tabulate the `depth` frames just below
# the first frame named `below` (leaf side), or the leaf frames when `below`
# is "<leaf>".
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/drill.R <rprof> <inside> <below> [depth] [exclude,...]

a <- commandArgs(TRUE)
lines <- readLines(a[[1L]])
lines <- lines[!grepl("^sample.interval|^#", lines)]
inside <- a[[2L]]; below <- a[[3L]]
depth <- if (length(a) > 3L) as.integer(a[[4L]]) else 1L
exclude <- if (length(a) > 4L) strsplit(a[[5L]], ",")[[1L]] else character()
stacks <- lapply(strsplit(lines, " ", fixed = TRUE), function(s) gsub('"', "", s))
keep <- vapply(stacks, function(s) inside %in% s && !any(exclude %in% s), logical(1L))
stacks <- stacks[keep]
key <- vapply(stacks, function(s) {
  if (identical(below, "<leaf>")) return(paste(rev(s[seq_len(min(depth, length(s)))]), collapse = " > "))
  j <- match(below, s)
  if (is.na(j) || j == 1L) return("<self>")
  paste(rev(s[max(1L, j - depth):(j - 1L)]), collapse = " > ")
}, character(1L))
tab <- sort(table(key), decreasing = TRUE)
cat(sprintf("%d samples contain %s\n", length(stacks), inside))
print(head(data.frame(samples = as.integer(tab), share = round(as.numeric(tab) / length(stacks), 3), row.names = names(tab)), 25))

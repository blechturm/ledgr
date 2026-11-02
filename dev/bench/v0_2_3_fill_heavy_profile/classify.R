# Attribute Rprof samples to fold stages and source files.
# Usage: Rscript classify.R <rprof.out> <R_source_dir> <out_dir>
args <- commandArgs(trailingOnly = TRUE)
prof <- args[[1]]; rdir <- args[[2]]; out <- args[[3]]

# function name -> source file, from top-level `name <- function` assignments
fmap <- character()
for (f in list.files(rdir, pattern = "[.]R$", full.names = TRUE)) {
  ex <- tryCatch(parse(f, keep.source = FALSE), error = function(e) expression())
  for (e in ex) {
    if (is.call(e) && as.character(e[[1]]) %in% c("<-", "=") && is.name(e[[2]]) &&
        is.call(e[[3]]) && identical(e[[3]][[1]], as.name("function"))) {
      fmap[as.character(e[[2]])] <- basename(f)
    }
  }
}

lines <- readLines(prof)
interval <- as.numeric(sub(".*sample.interval=([0-9]+).*", "\\1", lines[1])) / 1e6
lines <- lines[-1]
lines <- lines[!grepl("^#", lines) & nzchar(lines)]
stacks <- lapply(regmatches(lines, gregexpr('"[^"]*"', lines)), function(x) gsub('"', "", x))

stages <- c(ledgr_fold_stage_observe_settle = "E observe/settle",
  ledgr_fold_stage_decide = "P decide", ledgr_fold_stage_plan = "P plan",
  ledgr_fold_stage_apply = "P apply", ledgr_fold_stage_commit = "P commit")

region <- vapply(stacks, function(s) {
  if ("ledgr_results" %in% s) return("results read")
  hit <- s[s %in% names(stages)]
  if (length(hit)) return(stages[[hit[1]]])
  if ("ledgr_run" %in% s) return("run outside stages")
  "other"
}, character(1))
innermost_ledgr <- vapply(stacks, function(s) {
  k <- s[s %in% names(fmap)]
  if (length(k)) k[1] else "(none)"
}, character(1))
leaf <- vapply(stacks, function(s) s[1], character(1))
file <- ifelse(innermost_ledgr %in% names(fmap), fmap[innermost_ledgr], "(none)")

d <- data.frame(region, innermost_ledgr, file, leaf, stringsAsFactors = FALSE)
total <- nrow(d) * interval
agg <- function(by) {
  a <- aggregate(list(seconds = rep(interval, nrow(d))), d[by], sum)
  a$share <- round(a$seconds / total, 3)
  a[order(-a$seconds), ]
}
dir.create(out, showWarnings = FALSE, recursive = TRUE)
r <- agg("region"); write.csv(r, file.path(out, "regions.csv"), row.names = FALSE)
rf <- agg(c("region", "file")); write.csv(rf, file.path(out, "region_file.csv"), row.names = FALSE)
rfn <- agg(c("region", "innermost_ledgr")); write.csv(rfn, file.path(out, "region_function.csv"), row.names = FALSE)
lf <- agg(c("region", "leaf")); write.csv(lf, file.path(out, "region_leaf.csv"), row.names = FALSE)
cat(sprintf("samples %d, %.2f s profiled\n", nrow(d), total))
print(r, row.names = FALSE)
cat("\nTop region x file\n"); print(head(rf, 25), row.names = FALSE)
cat("\nTop region x innermost ledgr function\n"); print(head(rfn, 30), row.names = FALSE)
cat("\nTop region x leaf (self)\n"); print(head(lf, 25), row.names = FALSE)

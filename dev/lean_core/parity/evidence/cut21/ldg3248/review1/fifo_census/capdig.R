fs <- sort(list.files("fifo_tests", "^tests_[0-9]+[.]rds$", full.names = TRUE))
calls <- do.call(c, lapply(fs, readRDS))
calls <- calls[vapply(calls, function(x) is.null(x$input_args), logical(1))]
caller <- vapply(calls, function(x) paste(x$caller, collapse = "/"), "")
sel <- which(caller == "ledgr_fold_fill_candidate")
dg <- vapply(calls[sel], function(x) digest::digest(list(x$book, x$input), algo = "xxhash64"), "")
a <- read.csv("censusA.csv", stringsAsFactors = FALSE)
ad <- a[a$caller == "ledgr_fold_fill_candidate", ]
tc <- table(dg); ta <- table(ad$digest)
k <- union(names(tc), names(ta))
d <- data.frame(digest = k, capture = as.integer(tc[k]), census = as.integer(ta[k])); d[is.na(d)] <- 0L
dd <- d[d$capture != d$census, ]
print(dd, row.names = FALSE)
for (g in dd$digest) { m <- ad[ad$digest == g, c("file", "test")]; if (nrow(m)) print(unique(m)) }
# the position of the extra calls in the capture order and their neighbours' digests in the census
pos <- sel[dg %in% dd$digest]
cat("capture positions:", pos, "\n")
for (p in pos) {
  x <- calls[[p]]
  cat("pos", p, "error:", is.list(x$value) && !is.null(x$value$message) && is.null(x$value$book), "\n")
  str(x$input, max.level = 1, list.len = 6)
}
saveRDS(list(dd = dd, pos = pos), "capdig.rds")

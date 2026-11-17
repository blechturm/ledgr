setwd("C:/Users/maxth/ledgr-wt/ws40-scratch")
rng <- "test-rng-isolation.R"
a <- read.csv("censusA.csv", stringsAsFactors = FALSE, colClasses = "character")
b <- read.csv("censusB.csv", stringsAsFactors = FALSE, colClasses = "character")
fs <- sort(list.files("fifo_tests", "^tests_[0-9]+[.]rds$", full.names = TRUE))
chunk <- integer(); calls <- list()
for (i in seq_along(fs)) { x <- readRDS(fs[[i]]); calls <- c(calls, x); chunk <- c(chunk, rep(i, length(x))) }
keep <- vapply(calls, function(x) is.null(x$input_args), logical(1))
calls <- calls[keep]; chunk <- chunk[keep]
cdig <- vapply(calls, function(x) digest::digest(list(x$book, x$input), algo = "xxhash64"), "")
ccaller <- vapply(calls, function(x) paste(x$caller, collapse = "/"), "")
cat("capture record fields:", paste(names(calls[[1]]), collapse = ", "), "\n")
fa <- tapply(a$file, a$digest, function(f) if (length(unique(f)) == 1L) f[[1L]] else NA_character_)
pf <- unname(fa[cdig])
only <- which(!cdig %in% c(a$digest, b$digest))
near <- function(p, dir) { q <- p; repeat { q <- q + dir; if (q < 1L || q > length(pf)) return(NA); if (!is.na(pf[[q]])) return(paste(q, pf[[q]])) } }
for (p in only) cat(sprintf("capture-only pos %d chunk %d caller %s | before %s | after %s\n", p, chunk[[p]], ccaller[[p]], near(p, -1L), near(p, 1L)))
# file order in the capture: first and last position per attributed file
o <- tapply(seq_along(pf), pf, range)
ord <- order(vapply(o, `[`, 0, 1))
for (f in names(o)[ord]) cat(sprintf("%-45s %6d..%6d\n", f, o[[f]][1], o[[f]][2]))
# the keys seen both in the rng file and elsewhere
both <- intersect(unique(a$digest[a$file == rng]), unique(a$digest[a$file != rng]))
both <- union(both, intersect(unique(b$digest[b$file == rng]), unique(b$digest[b$file != rng])))
for (k in both) {
  cat("key", k, "\n")
  print(table(census = c(rep("A", sum(a$digest == k)), rep("B", sum(b$digest == k))), file = c(a$file[a$digest == k], b$file[b$digest == k])))
  cat("  capture", sum(cdig == k), "\n")
}
saveRDS(list(cdig = cdig, chunk = chunk, caller = ccaller), "f2_capture_keys.rds")

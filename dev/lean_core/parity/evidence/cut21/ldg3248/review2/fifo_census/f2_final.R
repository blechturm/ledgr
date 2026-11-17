# Workstream 40 close review round 2, F2: the two test-attributed censuses
# (censusA.csv, censusB.csv: fifo_census.R, every ledgr_lot_apply() call's
# xxhash64 digest of list(book, input) with its test file and test, in call
# order) against each other and against the fresh capture
# (fifo_tests/tests_00*.rds, the same calls in call order, no test identity).
#   Rscript f2_final.R <out dir>
out <- commandArgs(TRUE)[[1]]
setwd("C:/Users/maxth/ledgr-wt/ws40-scratch")
dir.create(out, showWarnings = FALSE, recursive = TRUE)
rng <- "test-rng-isolation.R"
a <- read.csv("censusA.csv", stringsAsFactors = FALSE, colClasses = "character")
b <- read.csv("censusB.csv", stringsAsFactors = FALSE, colClasses = "character")
ck <- readRDS("f2_capture_keys.rds")   # f2_diag.R: the capture's digests, same recipe, in order
cd <- ck$cdig
lines <- character()
say <- function(...) { s <- sprintf(...); cat(s, "\n"); lines <<- c(lines, s) }
say("calls: census A %d, census B %d, fresh capture %d; the committed capture population was 156571", nrow(a), nrow(b), length(cd))
stopifnot(identical(a$file, a$file[order(match(a$file, unique(a$file)))]))   # each file one contiguous block

# Step 1-2. Census A against census B, key = (test file, test, digest).
key <- function(x) paste(x$file, x$test, x$digest, sep = "\r")
ta <- table(key(a)); tb <- table(key(b)); k <- union(names(ta), names(tb))
m <- data.frame(key = k, A = as.integer(ta[k]), B = as.integer(tb[k]), stringsAsFactors = FALSE)
m[is.na(m)] <- 0L
m$file <- sub("\r.*$", "", m$key)
dab <- m[m$A != m$B, ]
say("A vs B, keyed by (file, test, digest): %d keys differ in multiplicity; files holding them: %s",
  nrow(dab), paste(unique(dab$file), collapse = ", "))
say("A vs B outside %s: %d keys, %d calls each; keys differing: %d; the two call sequences identical in order: %s",
  rng, sum(m$file != rng), sum(m$A[m$file != rng]), sum(m$A[m$file != rng] != m$B[m$file != rng]),
  identical(a$digest[a$file != rng], b$digest[b$file != rng]))
say("A vs B in %s: %d calls vs %d", rng, sum(a$file == rng), sum(b$file == rng))

# Step 2-3. The capture, aligned by call order: the files before the rng
# file (A's first n_pre calls) and after it (A's last n_post calls) against
# the capture's head and tail; what lies between is the rng file's block.
pre <- seq_len(min(which(a$file == rng)) - 1L)
post <- seq.int(max(which(a$file == rng)) + 1L, nrow(a))
n_pre <- length(pre); n_post <- length(post); L <- length(cd)
head_eq <- cd[seq_len(n_pre)] == a$digest[pre]
tail_eq <- cd[seq.int(L - n_post + 1L, L)] == a$digest[post]
say("capture head (files before %s, %d calls): %d equal to census A call for call, %d differ", rng, n_pre, sum(head_eq), sum(!head_eq))
say("capture tail (files after %s, %d calls): %d equal to census A call for call, %d differ", rng, n_post, sum(tail_eq), sum(!tail_eq))
if (any(!tail_eq)) {
  i <- post[!tail_eq]
  for (j in i) say("  differing tail call: census A row %d, %s :: %s, caller %s (census B digest %s, A digest %s, capture digest %s)",
    j, a$file[j], a$test[j], a$caller[j], b$digest[j], a$digest[j], cd[L - n_post + match(j, post)])
}
if (any(!head_eq)) say("  differing head calls at census A rows: %s", paste(pre[!head_eq], collapse = ","))
mid <- cd[seq.int(n_pre + 1L, L - n_post)]
say("capture block between them (the %s block): %d calls; census A has %d, census B %d there", rng, length(mid),
  sum(a$file == rng), sum(b$file == rng))
# the same alignment against census B (same file block sizes outside rng)
preb <- seq_len(min(which(b$file == rng)) - 1L); postb <- seq.int(max(which(b$file == rng)) + 1L, nrow(b))
say("against census B: head %d/%d equal, tail %d/%d equal", sum(cd[seq_along(preb)] == b$digest[preb]), length(preb),
  sum(cd[seq.int(L - length(postb) + 1L, L)] == b$digest[postb]), length(postb))

# Keys the capture alone holds, and where they sit.
only <- which(!cd %in% c(a$digest, b$digest))
blk <- ifelse(only <= n_pre, "head", ifelse(only > L - n_post, "tail", "rng block"))
say("capture-only keys: %d calls; in the rng block %d, in the head %d, in the tail %d", length(only), sum(blk == "rng block"),
  sum(blk == "head"), sum(blk == "tail"))
# Keys that differ in multiplicity between a census and the capture, by block.
mult <- function(x, k) { t <- table(x); v <- as.integer(t[k]); v[is.na(v)] <- 0L; v }
kk <- unique(c(a$digest, b$digest, cd))
dc <- data.frame(digest = kk, A = mult(a$digest, kk), B = mult(b$digest, kk), C = mult(cd, kk), stringsAsFactors = FALSE)
dc <- dc[dc$A != dc$C | dc$B != dc$C | dc$A != dc$B, ]
outside_a <- mult(a$digest[a$file != rng], dc$digest); outside_b <- mult(b$digest[b$file != rng], dc$digest)
outside_c <- mult(cd[-seq.int(n_pre + 1L, L - n_post)], dc$digest)
dc$outside_A <- outside_a; dc$outside_B <- outside_b; dc$outside_capture <- outside_c
dc$rng_A <- dc$A - outside_a; dc$rng_B <- dc$B - outside_b; dc$rng_capture <- dc$C - outside_c
say("digests whose multiplicity differs among A, B and the capture: %d; of them, differing outside the rng file (A, B, capture head+tail): %d",
  nrow(dc), sum(dc$outside_A != dc$outside_B | dc$outside_A != dc$outside_capture))
say("  those outside differences: %s", paste(dc$digest[dc$outside_A != dc$outside_B | dc$outside_A != dc$outside_capture], collapse = ", "))
say("Record: the committed population of 156,571 calls cannot be re-attributed: only its count was stored, never its calls' digests, test files or tests.")
writeLines(lines, file.path(out, "f2_keys.txt"))
utils::write.csv(dc, file.path(out, "differing_digests.csv"), row.names = FALSE)
utils::write.csv(dab[, c("file", "A", "B")], file.path(out, "census_ab_differing_keys.csv"), row.names = FALSE)

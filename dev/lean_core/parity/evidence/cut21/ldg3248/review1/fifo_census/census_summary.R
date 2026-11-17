out <- "C:/Users/maxth/ledgr-wt/ws40/dev/lean_core/parity/evidence/cut21/ldg3248/review1/fifo_census"
dir.create(out, showWarnings = FALSE)
a <- read.csv("censusA.csv", stringsAsFactors = FALSE); b <- read.csv("censusB.csv", stringsAsFactors = FALSE)
cap <- readRDS("capsum.rds")
per <- function(x) { t <- table(paste(x$file, x$test, x$caller, sep = " :: ")); t }
ta <- per(a); tb <- per(b); k <- union(names(ta), names(tb))
d <- data.frame(file_test_caller = k, census_a = as.integer(ta[k]), census_b = as.integer(tb[k])); d[is.na(d)] <- 0L
utils::write.csv(d[order(d$file_test_caller), ], file.path(out, "census_by_test_and_caller.csv"), row.names = FALSE)
f <- function(x) tapply(rep(1L, nrow(x)), x$file, sum)
fa <- f(a); fb <- f(b); ff <- union(names(fa), names(fb))
utils::write.csv(data.frame(file = ff, census_a = as.integer(fa[ff]), census_b = as.integer(fb[ff])),
  file.path(out, "census_by_file.csv"), row.names = FALSE)
cc <- table(cap$caller); ca <- table(a$caller); cb <- table(b$caller); kk <- union(union(names(cc), names(ca)), names(cb))
callers <- data.frame(caller = kk, capture = as.integer(cc[kk]), census_a = as.integer(ca[kk]), census_b = as.integer(cb[kk]))
callers[is.na(callers)] <- 0L
utils::write.csv(callers, file.path(out, "calls_by_caller.csv"), row.names = FALSE)
rng <- function(x) sum(x$file == "test-rng-isolation.R")
cat(sprintf("totals: capture %d (mocked %d), census A %d, census B %d; committed 156571\n", length(cap$caller), sum(cap$mocked), nrow(a), nrow(b)))
cat(sprintf("test-rng-isolation.R: census A %d, census B %d; without it: A %d, B %d\n", rng(a), rng(b), nrow(a) - rng(a), nrow(b) - rng(b)))
print(callers[callers$capture != callers$census_a | callers$census_a != callers$census_b, ], row.names = FALSE)
print(d[d$census_a != d$census_b, ], row.names = FALSE)

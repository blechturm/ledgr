# Base R vs collapse on hot-loop operations, at n = 500 and n = 5,000
# instruments. Each pair is checked for equal results before timing.
# Usage: Rscript pairs.R <out.csv> [--check]
# --check only prints whether each pair returns equal results.
args <- commandArgs(TRUE)
suppressPackageStartupMessages({
  library(collapse)
  library(microbenchmark)
})
set_collapse(nthreads = 1L)

pairs <- list(
  # group, operation, base, collapse, check
  # check: "value" = equal values ignoring attributes, "none" = in-place op
  list("reduce", "sum", quote(sum(x)), quote(fsum(x)), "value"),
  list("reduce", "sum, na.rm", quote(sum(xna, na.rm = TRUE)), quote(fsum(xna)), "value"),
  list("reduce", "mean", quote(mean(x)), quote(fmean(x)), "value"),
  list("reduce", "max", quote(max(x)), quote(fmax(x)), "value"),
  list("reduce", "median", quote(stats::median(x)), quote(fmedian(x)), "value"),
  list("reduce", "sd", quote(stats::sd(x)), quote(fsd(x)), "value"),
  list("reduce", "range", quote(range(x)), quote(frange(x)), "value"),
  list("reduce", "count non-NA", quote(sum(!is.na(xna))), quote(fnobs(xna)), "value"),
  list("reduce", "cumsum", quote(cumsum(x)), quote(fcumsum(x)), "value"),
  list("reduce", "lag by one", quote(c(NA, x[-length(x)])), quote(flag(x)), "value"),
  list("reduce", "first difference", quote(x - c(NA, x[-length(x)])), quote(fdiff(x)), "value"),

  list("match", "match ids", quote(match(ids_shuf, ids)), quote(fmatch(ids_shuf, ids)), "value"),
  list("match", "positions in set: which(a %in% b)", quote(which(ids %in% ids_half)), quote(ids %iin% ids_half), "value"),
  list("match", "not in set: !(a %in% b)", quote(!(ids %in% ids_half)), quote(ids %!in% ids_half), "value"),
  list("match", "set difference of unique ids", quote(setdiff(ids, ids_half)), quote(ids[ids %!iin% ids_half]), "value"),
  list("match", "unique", quote(unique(ids_dup)), quote(funique(ids_dup)), "value"),
  list("match", "number of unique", quote(length(unique(ids_dup))), quote(fnunique(ids_dup)), "value"),
  list("match", "duplicated", quote(duplicated(ids_dup)), quote(fduplicated(ids_dup)), "value"),
  list("match", "any duplicated", quote(anyDuplicated(ids_dup) > 0L), quote(any_duplicated(ids_dup)), "value"),

  list("search", "which(x == v)", quote(which(g == 3L)), quote(whichv(g, 3L)), "value"),
  list("search", "which(is.na(x))", quote(which(is.na(xna))), quote(whichNA(xna)), "value"),
  list("search", "any(x == v)", quote(any(g == 3L)), quote(anyv(g, 3L)), "value"),
  list("search", "all(x == v)", quote(all(g == 3L)), quote(allv(g, 3L)), "value"),
  list("search", "all(is.na(x))", quote(all(is.na(xna))), quote(allNA(xna)), "value"),
  list("search", "drop NA: x[!is.na(x)]", quote(xna[!is.na(xna)]), quote(na_rm(xna)), "value"),
  list("search", "logical subset x[lgl]", quote(x[lgl]), quote(fsubset(x, lgl)), "value"),

  list("build", "fill vector rep(NA, n)", quote(rep(NA_real_, n)), quote(alloc(NA_real_, n)), "value"),
  list("build", "replace NA by 0", quote({y <- xna; y[is.na(y)] <- 0; y}), quote(replace_na(xna, 0)), "value"),
  list("build", "list element lengths", quote(lengths(lst)), quote(vlengths(lst)), "value"),
  list("build", "order numeric", quote(order(x)), quote(radixorder(x)), "value"),
  list("build", "order ids (default vs radix)", quote(order(ids_shuf)), quote(radixorder(ids_shuf)), "value"),
  list("build", "order ids (both radix)", quote(order(ids_shuf, method = "radix")), quote(radixorder(ids_shuf)), "value"),

  list("write", "scatter x[idx] <- y (copy vs in place)", quote({y <- x; y[idx] <- x2; y}),
       quote(setv(scratch, idx, x2, vind1 = TRUE)), "none"),
  list("write", "logical write x[lgl] <- v", quote({y <- x; y[lgl] <- 0; y}),
       quote(setv(scratch, lgl, 0)), "none"),
  list("write", "add scalar x + 1 (new vs in place)", quote(x + 1), quote(setop(scratch, "+", 0)), "none"),
  list("write", "add vector x + y (new vs in place)", quote(x + x2), quote(scratch %+=% zero), "none"),

  list("frame", "build frame from list", quote(data.frame(cols, stringsAsFactors = FALSE)), quote(qDF(cols)), "value"),
  list("frame", "row subset by index", quote(df[rows, , drop = FALSE]), quote(ss(df, rows)), "value"),
  list("frame", "row subset by logical", quote(df[lgl, , drop = FALSE]), quote(ss(df, lgl)), "value"),
  list("frame", "select columns", quote(df[c("close", "volume")]), quote(get_vars(df, c("close", "volume"))), "value"),
  list("frame", "numeric frame to matrix", quote(as.matrix(dfn)), quote(qM(dfn)), "value"),
  list("frame", "bind 10 frames by row", quote(do.call(rbind, frames)), quote(rowbind(frames)), "value"),

  list("group", "group sum: tapply", quote(tapply(x, g, sum)), quote(fsum(x, g)), "value"),
  list("group", "group sum: rowsum", quote(rowsum(x, g)[, 1]), quote(fsum(x, g)), "value"),
  list("group", "group mean back to rows: ave", quote(ave(x, g)), quote(fbetween(x, g)), "value"),
  list("group", "demean within group", quote(x - ave(x, g)), quote(fwithin(x, g)), "value"),
  list("group", "split by group", quote(split(x, g)), quote(rsplit(x, g)), "value"),
  list("group", "factor of ids", quote(factor(ids_dup)), quote(qF(ids_dup)), "value"),

  list("matrix", "column sums", quote(colSums(mat)), quote(fsum(mat)), "value"),
  list("matrix", "column means", quote(colMeans(mat)), quote(fmean(mat)), "value"),
  list("matrix", "column max: apply", quote(apply(mat, 2L, max)), quote(fmax(mat)), "value"),
  list("matrix", "column cumsum: apply", quote(apply(mat, 2L, cumsum)), quote(fcumsum(mat)), "value"),
  list("matrix", "lag rows by one", quote(rbind(NA, mat[-nrow(mat), , drop = FALSE])), quote(flag(mat)), "value")
)

make_data <- function(n) {
  set.seed(1)
  e <- new.env()
  e$n <- n
  e$ids <- sprintf("P%05d", seq_len(n))
  e$ids_shuf <- sample(e$ids)
  e$ids_half <- sample(e$ids, n / 2)
  e$ids_dup <- sample(e$ids, n, replace = TRUE)
  e$x <- runif(n); e$x2 <- runif(n)
  e$xna <- e$x; e$xna[sample.int(n, n / 10)] <- NA
  e$lgl <- e$x > 0.5
  e$idx <- sample.int(n)
  e$g <- rep_len(1:10, n)
  e$lst <- lapply(seq_len(n), function(i) seq_len(i %% 7))
  e$scratch <- runif(n)
  e$zero <- numeric(n)
  e$cols <- list(open = runif(n), high = runif(n), low = runif(n), close = runif(n),
                 volume = runif(n), instrument_id = e$ids)
  e$df <- as.data.frame(e$cols, stringsAsFactors = FALSE)
  e$dfn <- e$df[1:5]
  e$rows <- sort(sample.int(n, n / 10))
  e$frames <- replicate(10, e$df[1:(n / 10), ], simplify = FALSE)
  # an instrument x pulse plane: one year of 252 pulses
  e$mat <- matrix(runif(n * 252), n, 252)
  e
}

same <- function(a, b) {
  strip <- function(v) {
    if (is.factor(v)) v <- as.character(v)
    if (is.data.frame(v)) { v <- as.list(v); rownames(v) <- NULL }
    if (is.list(v)) return(lapply(unname(v), strip))
    if (is.matrix(v)) return(unname(v))
    as.vector(unname(v))
  }
  isTRUE(all.equal(strip(a), strip(b), tolerance = 1e-10, check.attributes = FALSE))
}

time_expr <- function(expr, env) {
  f <- compiler::cmpfun(eval(call("function", as.pairlist(alist()), expr), env))
  for (i in 1:20) f()
  probe <- system.time(for (i in 1:200) f())[["elapsed"]] / 200
  inner <- if (probe < 20e-6) 100L else 1L
  if (inner > 1L) {
    f <- compiler::cmpfun(eval(call("function", as.pairlist(alist()),
                                    call("for", as.name(".k"), quote(seq_len(100L)), expr)), env))
    probe <- probe * inner
  }
  times <- as.integer(min(3000, max(50, 0.3 / max(probe, 1e-7))))
  stats::median(microbenchmark::microbenchmark(f(), times = times, unit = "ns")$time) / 1e3 / inner
}

rows <- list()
for (n in c(500L, 5000L)) {
  env <- make_data(n)
  for (p in pairs) {
    check <- tryCatch(
      if (p[[5]] == "none") "in place" else if (same(eval(p[[3]], env), eval(p[[4]], env))) "same" else "DIFFERS",
      error = function(e) paste("error:", conditionMessage(e)))
    if ("--check" %in% args) { cat(sprintf("%5d %-45s %s
", n, p[[2]], check)); next }
    base_us <- tryCatch(time_expr(p[[3]], env), error = function(e) NA_real_)
    col_us <- tryCatch(time_expr(p[[4]], env), error = function(e) NA_real_)
    rows[[length(rows) + 1L]] <- data.frame(
      group = p[[1]], operation = p[[2]], n = n,
      base = paste(deparse(p[[3]], width.cutoff = 500L), collapse = " "),
      collapse = paste(deparse(p[[4]], width.cutoff = 500L), collapse = " "),
      base_us = base_us, collapse_us = col_us, speedup = base_us / col_us, check = check)
  }
}
out <- do.call(rbind, rows)
write.csv(out, args[[1]], row.names = FALSE)
cat(sprintf("%d rows written; %d not same\n", nrow(out), sum(!out$check %in% c("same", "in place"))))

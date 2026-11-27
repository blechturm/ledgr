# LDG-3283: the integrated run (loop_parity.R --prepare=1) differs from the
# pin only in sweep_attrs. This compares a dumped pair of workloads in full
# and lists every differing cell, by table, attribute (sweep_attrs) and row.
#   Rscript integrated_diff.R --dump=<loop_parity --dump dir> --workloads=a,b
argv <- commandArgs(TRUE)
arg <- function(n) sub(paste0("^--", n, "="), "", grep(paste0("^--", n, "="), argv, value = TRUE)[[1L]])
dump <- arg("dump")
out <- list()
for (id in strsplit(arg("workloads"), ",")[[1L]]) {
  a <- readRDS(file.path(dump, paste0(id, ".rds")))
  b <- readRDS(file.path(dump, paste0(id, "_lean.rds")))
  for (p in union(names(a), names(b))) for (t in union(names(a[[p]]), names(b[[p]]))) {
    x <- a[[p]][[t]]; y <- b[[p]][[t]]
    if (identical(x, y)) next
    if (!identical(dim(x), dim(y)) || !identical(names(x), names(y))) {
      out[[length(out) + 1L]] <- data.frame(workload = id, path = p, table = t, row = NA, what = "shape", stringsAsFactors = FALSE)
      next
    }
    for (col in names(x)) {
      d <- which(!(x[[col]] == y[[col]] | (is.na(x[[col]]) & is.na(y[[col]]))) | xor(is.na(x[[col]]), is.na(y[[col]])))
      for (r in d) out[[length(out) + 1L]] <- data.frame(workload = id, path = p, table = t, row = r,
        what = if ("attribute" %in% names(x)) x$attribute[[r]] else col, stringsAsFactors = FALSE)
    }
    if (identical(unname(as.list(x)), unname(as.list(y)))) {
      out[[length(out) + 1L]] <- data.frame(workload = id, path = p, table = t, row = NA, what = "attributes only", stringsAsFactors = FALSE)
    }
  }
}
res <- if (length(out)) do.call(rbind, out) else data.frame()
print(res, row.names = FALSE)
cat(sprintf("%d differing cells; attributes: %s\n", nrow(res), paste(unique(res$what), collapse = ", ")))

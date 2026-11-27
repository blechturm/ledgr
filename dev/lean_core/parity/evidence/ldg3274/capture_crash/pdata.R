# Scratch (not committed): reads a PE DLL's .pdata (RUNTIME_FUNCTION
# triples: begin, end, unwind info RVA) and reports whether it is sorted.
pdata <- function(dll, off = 0xE5C00, size = 0xC768) {
  con <- file(dll, "rb"); on.exit(close(con))
  seek(con, off)
  x <- readBin(con, "integer", n = size %/% 4, size = 4, endian = "little")
  m <- matrix(x[seq_len(3 * (length(x) %/% 3))], ncol = 3, byrow = TRUE)
  m[m[, 1] != 0, , drop = FALSE]
}
for (d in commandArgs(TRUE)) {
  m <- pdata(d)
  bad <- which(diff(m[, 1]) <= 0)
  cat(d, ": entries", nrow(m), "| out of order", length(bad),
      "| same triples as sorted", identical(m[order(m[, 1]), ], m), "\n")
  if (length(bad)) {
    cat("  first out-of-order rows:\n")
    print(head(cbind(row = bad, begin = sprintf("%08X", m[bad, 1]), next_begin = sprintf("%08X", m[bad + 1, 1])), 8))
  }
  assign(basename(dirname(d)), m)
}
a <- pdata(commandArgs(TRUE)[1]); b <- pdata(commandArgs(TRUE)[2])
cat("same set of entries:", identical(a[order(a[, 1]), ], b[order(b[, 1]), ]), "\n")

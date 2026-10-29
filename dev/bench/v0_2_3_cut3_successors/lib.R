# Shared helpers for the v0.2.3 cut 4 (workstream 11) successor records
# (LDG-3161; ws2_rng_design.md Section 8). The original A0 records
# (dev/bench/v0_2_3_output_freeze/) and the RNG baseline
# (dev/bench/v0_2_3_rng_baseline/) and their harnesses are called, never
# edited. This file holds only what the successors add:
#
#   - sr_v2_ref(): an independent reference for pulse-seed rule v2, written
#     bit by bit from the fmix32 definition (no 16-bit splitting, no product
#     routine), self-tested against the Section 2.5 golden fixture;
#   - sr_archive(): a git archive of one commit into a scratch directory, used
#     for the base-tree models and for the source-copy guts;
#   - sr_read_csv(): an exact reader for the A0 canonical CSV form, keeping
#     every cell as its raw token (quoted text, or the unquoted NA).

sr_here <- function() {
  for (i in rev(seq_len(sys.nframe()))) {
    f <- sys.frame(i)$ofile
    if (is.character(f)) return(dirname(normalizePath(f, winslash = "/")))
  }
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg)) return(dirname(normalizePath(sub("^--file=", "", file_arg[[1L]]), winslash = "/")))
  normalizePath(getwd(), winslash = "/")
}

sr_arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(trailingOnly = TRUE), value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}

# The successors folder and the package root it lives in.
sr_dir <- local({
  d <- NULL
  for (i in rev(seq_len(sys.nframe()))) {
    f <- sys.frame(i)$ofile
    if (is.character(f)) { d <- dirname(normalizePath(f, winslash = "/")); break }
  }
  d
})
sr_root <- normalizePath(file.path(sr_dir, "..", "..", ".."), winslash = "/")

# ---------------------------------------------------------------------------
# Independent v2 reference (ws2_rng_design.md Section 2.1)
# ---------------------------------------------------------------------------

# A 32-bit word is a logical vector of 32 bits, least significant first.
sr_bits <- function(x) as.logical((x %/% 2^(0:31)) %% 2)
sr_word <- function(b) sum(2^(0:31)[b])
sr_shr <- function(b, k) c(b[(k + 1L):32L], rep(FALSE, k))
sr_shl <- function(b, k) if (k == 0L) b else c(rep(FALSE, k), b[seq_len(32L - k)])
# a * m mod 2^32 by shift-and-add over the set bits of m; every partial
# sum is below 2^38, exact in a double.
sr_mulc <- function(b, m) {
  acc <- 0
  for (i in which(sr_bits(m))) acc <- (acc + sr_word(sr_shl(b, i - 1L))) %% 4294967296
  sr_bits(acc)
}
sr_fmix32 <- function(b) {
  b <- xor(b, sr_shr(b, 16L))
  b <- sr_mulc(b, 0x85EBCA6B)
  b <- xor(b, sr_shr(b, 13L))
  b <- sr_mulc(b, 0xC2B2AE35)
  xor(b, sr_shr(b, 16L))
}
sr_v2_ref1 <- function(s, p) {
  h <- sr_fmix32(xor(sr_fmix32(sr_bits(as.numeric(s) %% 4294967296)), sr_bits(as.numeric(p) %% 4294967296)))
  as.integer(sr_word(h) %% 2147483647 + 1)
}
sr_v2_ref <- function(s, p) {
  n <- max(length(s), length(p))
  s <- rep_len(as.numeric(s), n); p <- rep_len(as.numeric(p), n)
  vapply(seq_len(n), function(i) sr_v2_ref1(s[[i]], p[[i]]), integer(1))
}

# The reference must reproduce all 63 golden values (Section 2.5) before any
# predicate uses it.
sr_ref_selftest <- function(root = sr_root) {
  g <- utils::read.csv(file.path(root, "tests", "testthat", "fixtures", "pulse-seed-v2-golden.csv"),
    colClasses = c("numeric", "numeric", "integer"))
  got <- sr_v2_ref(g$execution_seed, g$pulse_idx)
  bad <- which(got != g$pulse_seed)
  if (nrow(g) != 63L || length(bad)) {
    stop(sprintf("v2 reference self-test failed: %d rows, %d mismatches", nrow(g), length(bad)), call. = FALSE)
  }
  invisible(nrow(g))
}

# ---------------------------------------------------------------------------
# Trees
# ---------------------------------------------------------------------------

# The package paths a source copy or a base model needs.
sr_tree_paths <- c("DESCRIPTION", "NAMESPACE", "R", "src", "inst", "tests",
  "dev/bench/v0_2_3_output_freeze", "dev/bench/v0_2_3_rng_baseline", "dev/bench/v0_2_3_ws1_timing")

sr_archive <- function(commit, dest, repo = sr_root, paths = sr_tree_paths) {
  if (dir.exists(dest)) stop("sr_archive: destination exists: ", dest, call. = FALSE)
  dir.create(dest, recursive = TRUE)
  tar <- file.path(dest, "tree.tar")
  status <- system2("git", c("-C", shQuote(repo), "archive", "--format=tar", "-o", shQuote(tar), commit, "--", paths))
  if (!identical(as.integer(status), 0L)) stop("git archive failed for ", commit, call. = FALSE)
  utils::untar(tar, exdir = dest)
  unlink(tar)
  normalizePath(dest, winslash = "/")
}

# ---------------------------------------------------------------------------
# Canonical CSV (A0 writer form: every present cell quoted, NA unquoted)
# ---------------------------------------------------------------------------

sr_tokens <- function(line) regmatches(line, gregexpr('"(?:[^"]|"")*"|NA', line, perl = TRUE))[[1L]]

sr_read_csv <- function(file) {
  lines <- readLines(file, encoding = "UTF-8", warn = FALSE)
  header <- sr_tokens(lines[[1L]])
  body <- lapply(lines[-1L], sr_tokens)
  widths <- lengths(body)
  if (any(widths != length(header))) stop("sr_read_csv: ragged row in ", file, call. = FALSE)
  cells <- if (length(body) == 0L) matrix(character(), 0L, length(header)) else
    matrix(unlist(body, use.names = FALSE), ncol = length(header), byrow = TRUE)
  colnames(cells) <- sub(":[^:]*$", "", gsub('^"|"$', "", header))
  list(header = header, cells = cells, lines = lines)
}

# Raw token to value: NA stays NA, quoted text is unquoted.
sr_value <- function(tok) unname(ifelse(tok == "NA", NA_character_, gsub('""', '"', substr(tok, 2L, nchar(tok) - 1L), fixed = TRUE)))

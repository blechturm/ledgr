# LDG-3280 census, second pass: mocked binding names per block, and blocks
# that reach a pattern hit only through a file-level or helper function.
#   Rscript census_indirect.R <pin tests/testthat dir> <out dir>
args <- commandArgs(TRUE)
tdir <- args[[1L]]; odir <- args[[2L]]
b <- utils::read.csv(file.path(odir, "census_hits.csv"), stringsAsFactors = FALSE)
fams <- c("old_fold", "fold_internal", "mode", "debug_class", "flush", "compiled", "ctx_method", "seed", "merged", "source_text", "mock", "handler", "worker")
files <- list.files(tdir, pattern = "\\.R$", full.names = TRUE)
src <- lapply(stats::setNames(files, basename(files)), readLines, warn = FALSE)
pats <- NULL
eval(parse(text = paste(readLines(file.path(odir, "census_blocks.R"))[grep("^old_only <-", readLines(file.path(odir, "census_blocks.R"))):
  (grep("^is_tt <-", readLines(file.path(odir, "census_blocks.R"))) - 1L)], collapse = "\n")))

# top-level function definitions outside test blocks
defs <- list()
for (f in files) {
  ex <- parse(f, keep.source = TRUE)
  sr <- attr(ex, "srcref")
  for (i in seq_along(ex)) {
    e <- ex[[i]]
    if (is.call(e) && is.symbol(e[[1L]]) && as.character(e[[1L]]) %in% c("<-", "=") && is.symbol(e[[2L]]) &&
        is.call(e[[3L]]) && identical(as.character(e[[3L]][[1L]]), "function")) {
      defs[[length(defs) + 1L]] <- data.frame(file = basename(f), fn = as.character(e[[2L]]),
        first = sr[[i]][1L], last = sr[[i]][3L], stringsAsFactors = FALSE)
    }
  }
}
defs <- do.call(rbind, defs)
body_txt <- function(file, first, last) src[[file]][first:last]
for (nm in fams) defs[[nm]] <- vapply(seq_len(nrow(defs)), function(i)
  sum(grepl(pats[[nm]], body_txt(defs$file[i], defs$first[i], defs$last[i]), perl = TRUE)), 0L)
defs$helper <- grepl("^(helper|setup)", defs$file)
calls_fn <- function(lines, fn) any(grepl(paste0("\\b", fn, "\\b"), lines, perl = TRUE))
# transitive closure: a def inherits hits from defs it calls (same file or helper)
direct <- as.matrix(defs[fams]) > 0L
reach <- direct
for (iter in 1:6) {
  for (i in seq_len(nrow(defs))) {
    l <- body_txt(defs$file[i], defs$first[i], defs$last[i])
    cand <- which((defs$helper | defs$file == defs$file[i]) & seq_len(nrow(defs)) != i)
    for (j in cand) if (any(reach[j, ]) && calls_fn(l, defs$fn[j])) reach[i, ] <- reach[i, ] | reach[j, ]
  }
}
defs_hit <- defs[rowSums(reach) > 0L, c("file", "fn", "first", "last")]
defs_hit$families <- apply(reach[rowSums(reach) > 0L, , drop = FALSE], 1L, function(r) paste(fams[r], collapse = "+"))
utils::write.csv(defs_hit, file.path(odir, "census_helper_defs.csv"), row.names = FALSE)

# per block: indirect families and helper names used
b$via_helpers <- ""
b$indirect <- ""
for (i in seq_len(nrow(b))) {
  l <- src[[b$file[i]]][b$first[i]:b$last[i]]
  cand <- which((defs$helper | defs$file == b$file[i]) & rowSums(reach) > 0L)
  used <- cand[vapply(cand, function(j) calls_fn(l, defs$fn[j]), FALSE)]
  if (length(used)) {
    b$via_helpers[i] <- paste(unique(defs$fn[used]), collapse = ";")
    r <- apply(reach[used, , drop = FALSE], 2L, any)
    b$indirect[i] <- paste(fams[r], collapse = "+")
  }
}
# mocked binding names
mock_names <- function(lines) {
  txt <- paste(lines, collapse = "\n")
  pd <- tryCatch(utils::getParseData(parse(text = txt, keep.source = TRUE)), error = function(e) NULL)
  if (is.null(pd)) return("?")
  hits <- pd[pd$token == "SYMBOL_FUNCTION_CALL" & pd$text %in% c("with_mocked_bindings", "local_mocked_bindings"), ]
  out <- character()
  for (k in seq_len(nrow(hits))) {
    p <- pd$parent[pd$id == pd$parent[pd$id == hits$id[k]]]
    ce <- tryCatch(parse(text = utils::getParseText(pd, p))[[1L]], error = function(e) NULL)
    if (!is.null(ce)) out <- c(out, setdiff(names(as.list(ce))[-1L], c("", "code", ".package", ".env")))
  }
  paste(unique(out), collapse = ";")
}
b$mocked <- vapply(seq_len(nrow(b)), function(i) if (b$mock[i] > 0L) mock_names(src[[b$file[i]]][b$first[i]:b$last[i]]) else "", "")
utils::write.csv(b, file.path(odir, "census_hits.csv"), row.names = FALSE)
cat("helper/file defs with reach:", nrow(defs_hit), "\n")
print(defs_hit[, c("file", "fn", "families")], row.names = FALSE)
cat("blocks with indirect hits:", sum(nzchar(b$indirect)), "\n")
mk <- unlist(strsplit(b$mocked[nzchar(b$mocked)], ";"))
print(sort(table(mk), decreasing = TRUE))

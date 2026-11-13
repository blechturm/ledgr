# Cut 17 (LDG-3232): base versus collapse semantics on the operand classes
# the helper path sees (decision 3, measured_input). For each operand pair,
# compares base match()/%in% with collapse::fmatch() and the index operators
# %iin% / %!iin% (as positions), and base anyDuplicated()/unique() with
# collapse::any_duplicated()/funique().
#
#   Rscript dev/bench/v0_2_3_helper/collapse_semantics.R --out=<csv>

args <- commandArgs(trailingOnly = TRUE)
out <- sub("^--out=", "", grep("^--out=", args, value = TRUE)[[1L]])
u8 <- paste0("Z", intToUtf8(0xFCL), "rich")
l1 <- iconv(u8, "UTF-8", "latin1")
operands <- list(
  plain = list(x = c("CCC", "AAA", "EEE"), table = c("AAA", "BBB", "CCC")),
  empty_x = list(x = character(), table = c("AAA", "BBB")),
  empty_table = list(x = c("AAA"), table = character()),
  na_and_empty = list(x = c(NA, "", "AAA"), table = c("AAA", "", NA)),
  cross_encoding = list(x = c(l1, "AAA"), table = c("AAA", u8)),
  matrix_x = list(x = matrix(c("AAA", "BBB", "AAA", "CCC"), 2L), table = c("CCC", "AAA")),
  classed_x = list(x = structure(c("BBB", "AAA"), class = "ids"), table = c("AAA")),
  factor_x = list(x = factor(c("BBB", "AAA")), table = c("AAA", "BBB")),
  named_x = list(x = c(a = "BBB", b = "DDD"), table = c("BBB")))
`%iin%` <- collapse::`%iin%`
`%!iin%` <- collapse::`%!iin%`
same0 <- function(a, b) identical(a, b) && identical(Encoding(as.character(a)), Encoding(as.character(b)))
same <- function(a, b) tryCatch(as.character(same0(a, b)), error = function(e) paste("error:", conditionMessage(e)))
rows <- list()
for (n in names(operands)) {
  x <- operands[[n]]$x; tb <- operands[[n]]$table
  pos_in <- which(match(x, tb, 0L) > 0L); pos_out <- which(match(x, tb, 0L) == 0L)
  rows[[n]] <- data.frame(operands = n,
    fmatch_equals_match = same(collapse::fmatch(x, tb), match(x, tb)),
    fmatch_nomatch0_equals = same(collapse::fmatch(x, tb, nomatch = 0L), match(x, tb, nomatch = 0L)),
    iin_equals_which_in = same(as.integer(x %iin% tb), pos_in),
    not_iin_equals_which_out = same(as.integer(x %!iin% tb), pos_out),
    iin_is_logical_mask = tryCatch(as.character(is.logical(x %iin% tb)), error = function(e) paste("error:", conditionMessage(e))),
    any_duplicated_equals = tryCatch(as.character(identical(collapse::any_duplicated(x), anyDuplicated(x) > 0L)), error = function(e) paste("error:", conditionMessage(e))),
    funique_equals_unique = same(as.vector(collapse::funique(x)), as.vector(unique(x))),
    stringsAsFactors = FALSE)
}
dups <- c(u8, l1)
rows$cross_encoding_duplicates <- data.frame(operands = "cross_encoding_duplicates", fmatch_equals_match = NA,
  fmatch_nomatch0_equals = NA, iin_equals_which_in = NA, not_iin_equals_which_out = NA, iin_is_logical_mask = NA,
  any_duplicated_equals = identical(collapse::any_duplicated(dups), anyDuplicated(dups) > 0L),
  funique_equals_unique = identical(length(collapse::funique(dups)), length(unique(dups))), stringsAsFactors = FALSE)
res <- do.call(rbind, rows)
utils::write.csv(res, out, row.names = FALSE)
print(res, row.names = FALSE)
cat("collapse", as.character(utils::packageVersion("collapse")), "\n")

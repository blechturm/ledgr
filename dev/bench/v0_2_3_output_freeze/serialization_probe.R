# Unit-style probe of the canonical encoding: every pair below is a distinct
# value and must serialize to distinct bytes. Exits non-zero on a collision.
#
# Usage: Rscript serialization_probe.R

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  source(file.path(here, "lib.R"))
})

cell <- function(x) a0_csv_text(a0_canon(data.frame(k = 1L, v = I(list(x))), "probe", "k"))
atom <- function(x) a0_csv_text(a0_canon(data.frame(k = 1L, v = x, stringsAsFactors = FALSE), "probe", "k"))
pairs <- list(
  "nested list vs slash-joined name" = list(cell(list(a = list(b = 1))), cell(list("a/b" = 1))),
  "positional vs name '[1]'" = list(cell(list(1)), cell(list("[1]" = 1))),
  "unnamed vs empty name" = list(cell(list(1)), cell(stats::setNames(list(1), ""))),
  "NA name vs 'NA' name" = list(cell(stats::setNames(list(1), NA)), cell(list("NA" = 1))),
  "NULL vs empty list" = list(cell(NULL), cell(list())),
  "empty list vs empty vector" = list(cell(list()), cell(character())),
  "NA vs 'NA' nested" = list(cell(NA_character_), cell("NA")),
  "NA vs 'NA' top level" = list(atom(NA_character_), atom("NA")),
  "integer vs double nested" = list(cell(1L), cell(1)),
  "number vs text nested" = list(cell(1), cell("1")),
  "named vector vs list" = list(cell(c(a = 1)), cell(list(a = 1))),
  "two strings vs one with comma" = list(cell(c("a", "b")), cell("a,b")),
  "delimiter text in a name" = list(cell(list(a = 1, b = 2)), cell(list("a)#" = 1))),
  "newline vs escaped text" = list(atom("a\nb"), atom("a\\nb")),
  "length prefix lookalike" = list(cell(c("1:a", "b")), cell(c("1", "a", "b")))
)
same <- vapply(pairs, function(p) identical(p[[1L]], p[[2L]]), logical(1))
for (n in names(pairs)) cat(sprintf("%-34s %s\n", n, if (same[[n]]) "COLLISION" else "distinct"))
if (any(same)) quit(status = 1L)
cat("a0 serialization probe: PASS, no collisions\n")

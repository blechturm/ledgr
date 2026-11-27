# LDG-3282: checks coverage_matrix.md against the recorded workloads. Every
# workload name the family tables cite (a name, or a prefix ending in `*`)
# must match a recorded workload; every recorded workload must be cited by
# at least one family row. Exit 1 otherwise.
#   Rscript matrix_check.R
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
md <- readLines(file.path(here, "coverage_matrix.md"), warn = FALSE, encoding = "UTF-8")
rec <- utils::read.csv(file.path(here, "oracle_records.csv"), stringsAsFactors = FALSE)
ids <- rec$key[rec$kind == "gate"]
# The "Section 5 families" table only: rows between its heading and the next.
s <- which(md == "## Section 5 families"); e <- which(startsWith(md, "## ") & seq_along(md) > s)[[1L]]
rows <- md[s:e][startsWith(md[s:e], "| ") & !startsWith(md[s:e], "| Family") & !startsWith(md[s:e], "| ---")]
cells <- vapply(strsplit(rows, "|", fixed = TRUE), function(x) trimws(x[[3L]]), "")
tokens <- unique(unlist(regmatches(cells, gregexpr("[a-z][a-z0-9_.]*[0-9a-z](_?[*])?", cells))))
tokens <- tokens[grepl("_", tokens) | tokens %in% ids]
match_one <- function(t) if (endsWith(t, "*")) ids[startsWith(ids, sub("[*]$", "", t))] else ids[ids == t]
unknown <- tokens[vapply(tokens, function(t) length(match_one(t)) == 0L, logical(1))]
cited <- unique(unlist(lapply(tokens, match_one)))
uncited <- setdiff(ids, cited)
cat(sprintf("%d recorded workloads; %d cited names or prefixes; %d unknown; %d workloads cited by no family row\n",
            length(ids), length(tokens), length(unknown), length(uncited)))
if (length(unknown)) cat("unknown:", unknown, "\n")
if (length(uncited)) cat("uncited:", uncited, "\n")
quit(save = "no", status = if (length(unknown) || length(uncited)) 1L else 0L)

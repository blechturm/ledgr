# Stage-2 input (CHARTER.md): every line of R/ that names TTR, with its file,
# line and enclosing function, so the RFC can say which certification,
# dispatch, source, registry and provenance sites an adapter description
# would replace. Static; reads the source tree, loads no package.
#
#   Rscript ttr_inventory.R --tree=<source tree> --out=results/ttr_inventory.csv
arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
tree <- normalizePath(arg("tree"), winslash = "/")
files <- sort(list.files(file.path(tree, "R"), pattern = "\\.R$", full.names = TRUE))
# Lines that name TTR or the "ttr" kind, and lines that call an adapter helper
# (ledgr_ind_ttr*, ledgr_ttr_*), which matter outside the adapter's own file.
pattern <- "\\bTTR\\b|\\bttr\\b|\\bttr_|\"ttr\""
adapter_pattern <- "ledgr_ind_ttr|ledgr_ttr_[a-z_]+"
rows <- list()
for (f in files) {
  x <- readLines(f, warn = FALSE, encoding = "UTF-8")
  starts <- grep("^[A-Za-z.][A-Za-z0-9._]* <- function", x)
  names_at <- sub(" <- function.*$", "", x[starts])
  names_ttr <- grepl(pattern, x, perl = TRUE)
  calls_adapter <- grepl(adapter_pattern, x, perl = TRUE)
  hit <- which(names_ttr | calls_adapter)
  if (!length(hit)) next
  owner <- vapply(hit, function(h) { s <- starts[starts <= h]; if (length(s)) names_at[[length(s)]] else "(file scope)" }, "")
  comment <- grepl("^\\s*#", x[hit])
  rows[[f]] <- data.frame(file = sub(paste0(tree, "/"), "", f, fixed = TRUE), line = hit, function_name = owner,
                          kind = ifelse(names_ttr[hit], "names TTR", "calls adapter helper"),
                          comment = comment, text = trimws(substr(x[hit], 1L, 160L)), stringsAsFactors = FALSE)
}
out <- do.call(rbind, rows); rownames(out) <- NULL
utils::write.csv(out, arg("out"), row.names = FALSE)
code <- out[!out$comment, ]
by_fn <- aggregate(line ~ file + function_name + kind, code, length)
names(by_fn)[4] <- "code_lines"
by_fn$adapter_file <- by_fn$file == "R/indicator-ttr.R"
by_fn <- by_fn[order(by_fn$adapter_file, by_fn$file, -by_fn$code_lines), ]
utils::write.csv(by_fn, sub("\\.csv$", "_by_function.csv", arg("out")), row.names = FALSE)
cat(sprintf("TTR-naming code lines: %d in %d functions; outside R/indicator-ttr.R: %d lines in %d functions\n",
            nrow(code), nrow(by_fn), sum(!code$file %in% "R/indicator-ttr.R"), sum(!by_fn$adapter_file)))

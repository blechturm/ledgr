# Cut 18 (LDG-3234 acceptance, R2): the frozen census against a later
# commit. Statements are matched by file, function and the hash of their
# whole normalized text (the census keeps 120 characters for reading):
# unchanged, removed (in the frozen census only) or introduced (in the later
# commit only); an edited statement shows as one removed and one introduced
# row. The later census also parses checks.R, the lean-owned checks.
#
#   Rscript dev/lean_core/parity/cut18_crossref.R --commit=<later commit> [--out=<csv>]

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(here, "loop_edits.R"))
source(file.path(here, "cut18_census.R"))
ev <- file.path(here, "evidence", "cut18")
commit <- opt("commit")
src <- function(f) suppressWarnings(system2("git", c("-C", repo, "show", paste0(commit, ":dev/lean_core/", f)), stdout = TRUE, stderr = FALSE))
later <- attr(cut18_census(src("loop.R"), src("plan.R"), src("checks.R")), "statements")
frozen <- utils::read.csv(file.path(ev, "census_statements.csv"), stringsAsFactors = FALSE)
key <- function(d) paste(sub("\\|.*", "", d$statement), d$fn, d$hash, sep = " :: ")   # the full text's hash
fk <- key(frozen); lk <- key(later)
x <- rbind(
  data.frame(status = ifelse(fk %in% lk, "unchanged", "removed"), file = sub("\\|.*", "", frozen$statement), fn = frozen$fn,
             line = frozen$line, text = frozen$text, debug_fn = frozen$debug_fn),
  data.frame(status = "introduced", file = sub("\\|.*", "", later$statement[!lk %in% fk]), fn = later$fn[!lk %in% fk],
             line = later$line[!lk %in% fk], text = later$text[!lk %in% fk], debug_fn = later$debug_fn[!lk %in% fk]))
out <- opt("out", file.path(ev, "crossref.csv"))
utils::write.csv(x, out, row.names = FALSE)
print(table(x$status, x$file))
cat("functions with removed or introduced statements:\n")
print(table(x$fn[x$status != "unchanged"]))

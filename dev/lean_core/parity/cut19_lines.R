# Cut 19 (decision 9; adapted from cut18_lines.R): production and debug
# code lines of the lean execution sources at two commits, by the role count
# of LDG-3219: code lines are non-blank and non-comment; debug lines are the
# debug-only functions (only debug code calls them) and the lines of an
# `if (.lean_debug ...)` branch. For an if/else whose else is production,
# only the debug branch's own lines count as debug (its first line when it
# starts on the `if` line, and its last when the `else` follows on it, carry
# production code and stay production).
#
#   Rscript dev/lean_core/parity/cut18_lines.R --base=<commit> --final=<commit> [--out=<csv>]

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(here, "loop_edits.R"))
debug_functions <- c("lean_loop_debug_packet", "lean_loop_pin_ctx", "lean_loop_debug_ctx", "lean_debug_same")
files <- c("loop.R", "plan.R", "checks.R", "fifo.R", "prepare.R", "loop_harness.R", "marks.R")

count <- function(x) {
  pd <- utils::getParseData(parse(text = x, keep.source = TRUE))
  dbg <- integer()
  a <- lean_assigned_ranges(x)
  for (f in intersect(debug_functions, a$name[a$is_function])) { r <- lean_fn_range(x, f); dbg <- c(dbg, r[[1L]]:r[[2L]]) }
  for (id in pd$parent[pd$token == "IF"]) {
    kids <- pd[pd$parent == id, ]; kids <- kids[order(kids$line1, kids$col1), ]
    if (!grepl("^\\.lean_debug($|[^A-Za-z0-9_.])", utils::getParseText(pd, kids$id[[3L]]))) next
    row <- pd[pd$id == id, ]
    if (!"ELSE" %in% kids$token) { dbg <- c(dbg, row$line1:row$line2); next }
    cons <- kids[5L, ]; els <- kids[kids$token == "ELSE", ]
    from <- cons$line1 + (cons$line1 == row$line1); to <- cons$line2 - (cons$line2 == els$line1)
    if (from <= to) dbg <- c(dbg, from:to)
  }
  code <- which(nzchar(trimws(x)) & !grepl("^\\s*#", x))
  c(production = sum(!code %in% dbg), debug = sum(code %in% dbg))
}
at <- function(commit, f) {
  if (identical(commit, "WORKTREE")) { p <- file.path(repo, "dev/lean_core", f); return(if (file.exists(p)) readLines(p) else character()) }
  suppressWarnings(system2("git", c("-C", repo, "show", paste0(commit, ":dev/lean_core/", f)), stdout = TRUE, stderr = FALSE))
}
rows <- list()
for (cm in c(base = opt("base"), final = opt("final"))) for (f in files) {
  x <- at(cm, f)
  n <- if (length(x) && is.null(attr(x, "status"))) count(x) else c(production = 0L, debug = 0L)
  rows[[length(rows) + 1L]] <- data.frame(commit = cm, file = f, production = n[["production"]], debug = n[["debug"]])
}
res <- do.call(rbind, rows)
res$arm <- ifelse(res$commit == opt("base"), "base", "final")
w <- reshape(res[c("file", "arm", "production", "debug")], idvar = "file", timevar = "arm", direction = "wide")
w$production_change <- w$production.final - w$production.base
w$debug_change <- w$debug.final - w$debug.base
print(w, row.names = FALSE)
cat(sprintf("total production %d -> %d (%+d); debug %d -> %d (%+d)\n", sum(w$production.base), sum(w$production.final),
            sum(w$production_change), sum(w$debug.base), sum(w$debug.final), sum(w$debug_change)))
if (!is.null(opt("out"))) utils::write.csv(w, opt("out"), row.names = FALSE)

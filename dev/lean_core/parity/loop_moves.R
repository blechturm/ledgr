# Where each debug check and each hooks call of loop.R sits, before
# (4a3e08b8) and after the LDG-3220 restructure (Cut 14 R1): the innermost
# named function holding every `.lean_debug` test and every `hooks$` call.
#
#   Rscript dev/lean_core/parity/loop_moves.R [--base=4a3e08b8] --out=<csv>

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
base <- arg("base", "4a3e08b8")

sites <- function(x) {
  pd <- utils::getParseData(parse(text = x, keep.source = TRUE))
  fns <- list()
  for (p in pd$parent[pd$token == "LEFT_ASSIGN"]) {
    kids <- pd[pd$parent == p, ]
    kids <- kids[order(kids$line1, kids$col1), ]
    if (nrow(kids) != 3L) next
    lhs <- pd[pd$parent == kids$id[[1L]], ]
    rhs <- pd[pd$parent == kids$id[[3L]], ]
    if (nrow(lhs) == 1L && identical(lhs$token, "SYMBOL") && "FUNCTION" %in% rhs$token) {
      fns[[length(fns) + 1L]] <- data.frame(fn = lhs$text, from = kids$line1[[3L]], to = kids$line2[[3L]])
    }
  }
  fns <- do.call(rbind, fns)
  hit <- pd[(pd$token == "SYMBOL" & pd$text == ".lean_debug") | (pd$token == "SYMBOL" & pd$text == "hooks" &
    pd$line1 %in% grep("hooks\\$", x)), ]
  hit <- unique(hit[, c("line1", "text")])
  site <- vapply(hit$line1, function(l) {
    inside <- fns[fns$from <= l & fns$to >= l, ]
    if (!nrow(inside)) return("<top level>")
    inside$fn[which.min(inside$to - inside$from)]
  }, character(1L))
  kind <- ifelse(hit$text == ".lean_debug", "debug check", "hooks call")
  what <- vapply(seq_along(kind), function(j) {
    line <- x[hit$line1[[j]]]
    if (kind[[j]] == "hooks call") regmatches(line, regexpr("hooks\\$[a-z_]+", line)) else substr(trimws(line), 1L, 70L)
  }, character(1L))
  data.frame(kind = kind, what = what, fn = site, stringsAsFactors = FALSE)
}
before <- sites(system2("git", c("-C", repo, "show", paste0(base, ":dev/lean_core/loop.R")), stdout = TRUE))
after <- sites(readLines(file.path(repo, "dev/lean_core/loop.R")))
before$seq <- stats::ave(seq_len(nrow(before)), before$kind, before$what, FUN = seq_along)
after$seq <- stats::ave(seq_len(nrow(after)), after$kind, after$what, FUN = seq_along)
moves <- merge(before, after, by = c("kind", "what", "seq"), all = TRUE, suffixes = c("_before", "_after"))
moves$seq <- NULL
moves[is.na(moves)] <- "<absent>"
utils::write.csv(moves, arg("out"), row.names = FALSE)
print(moves, row.names = FALSE)
cat(sprintf("%d sites before, %d after\n", nrow(before), nrow(after)))

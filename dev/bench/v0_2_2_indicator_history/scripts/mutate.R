# Usage: Rscript mutate.R <spec.R> <mutation-name|all> <outfile> [worktree]
# spec.R defines `mutations`: list(name = list(file, old, new, filter, blocks))
# or list(name = list(edits = list(list(file, old, new), ...), filter, blocks)).
# Each mutation runs in a fresh source copy of the worktree (tracked plus
# untracked-but-not-ignored files) so worker daemons load the mutated source.
args <- commandArgs(TRUE)
`%||%` <- function(a, b) if (is.null(a)) b else a
spec_path <- args[[1]]
which <- args[[2]]
out_file <- args[[3]]
worktree <- if (length(args) >= 4) args[[4]] else "."
scratch <- Sys.getenv("LEDGR_MUTATION_SCRATCH", tempdir())
source(spec_path, local = TRUE)
names_to_run <- if (identical(which, "all")) names(mutations) else strsplit(which, ",")[[1]]
results <- list()
for (name in names_to_run) {
  m <- mutations[[name]]
  copy <- file.path(scratch, "mutcopy", name)
  unlink(copy, recursive = TRUE, force = TRUE)
  dir.create(copy, recursive = TRUE)
  files <- system2("git", c("-C", worktree, "ls-files", "--cached", "--others", "--exclude-standard"), stdout = TRUE)
  for (d in unique(dirname(files))) dir.create(file.path(copy, d), recursive = TRUE, showWarnings = FALSE)
  ok <- file.copy(file.path(worktree, files), file.path(copy, files), overwrite = TRUE)
  stopifnot(all(ok))
  edits <- m$edits %||% list(m[c("file", "old", "new")])
  hits <- integer()
  for (edit in edits) {
    target <- file.path(copy, edit$file)
    text <- paste(readLines(target, warn = FALSE), collapse = "\n")
    h <- lengths(regmatches(text, gregexpr(edit$old, text, fixed = TRUE)))
    hits <- c(hits, h)
    if (h == 1L) {
      text <- sub(edit$old, edit$new, text, fixed = TRUE)
      writeLines(strsplit(text, "\n", fixed = TRUE)[[1]], target)
    }
  }
  if (any(hits != 1L)) {
    results[[name]] <- data.frame(mutation = name, applied = FALSE, hits = paste(hits, collapse = "+"),
      blocks = paste(m$blocks, collapse = " "), failed_blocks = NA_character_, stringsAsFactors = FALSE)
    cat(name, ": NOT APPLIED", paste(hits, collapse = "+"), "\n")
    next
  }
  runner <- file.path(scratch, "mutcopy", paste0(name, "_run.R"))
  writeLines(c(
    sprintf("setwd(%s)", deparse(copy)),
    "options(testthat.progress.max_fails = 100000)",
    "pkgload::load_all('.', quiet = TRUE)",
    sprintf("res <- testthat::test_local('.', filter = %s, reporter = 'silent', stop_on_failure = FALSE, load_package = 'none')", deparse(m$filter)),
    "df <- as.data.frame(res)",
    "bad <- df$test[df$failed > 0 | df$error]",
    "cat('MUTRESULT', paste(bad, collapse = ' || '), '\\n')"
  ), runner)
  out <- system2("Rscript", runner, stdout = TRUE, stderr = TRUE)
  line <- grep("^MUTRESULT", out, value = TRUE)
  failed <- if (length(line)) sub("^MUTRESULT ", "", line[[length(line)]]) else paste("NO RESULT:", paste(utils::tail(out, 5), collapse = " | "))
  results[[name]] <- data.frame(mutation = name, applied = TRUE, hits = paste(hits, collapse = "+"),
    blocks = paste(m$blocks, collapse = " "), failed_blocks = trimws(failed), stringsAsFactors = FALSE)
  unlink(copy, recursive = TRUE, force = TRUE)
  cat(name, ":", trimws(failed), "\n")
}
res <- do.call(rbind, results)
res$detected <- vapply(seq_len(nrow(res)), function(i) {
  all(vapply(strsplit(res$blocks[[i]], " ")[[1]], function(b) grepl(b, res$failed_blocks[[i]], fixed = TRUE), logical(1)))
}, logical(1))
utils::write.csv(res, out_file, row.names = FALSE)
print(res[, c("mutation", "applied", "detected")])

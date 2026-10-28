args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default = NULL) {
  at <- match(flag, args)
  if (is.na(at) || at >= length(args)) default else args[[at + 1L]]
}
repo <- normalizePath(arg_value("--repo", "."), winslash = "/")
record <- normalizePath(
  arg_value("--record", file.path(
    repo, "dev", "spikes", "pulse-first-batch", "results", "windows-r4.6.1"
  )),
  winslash = "/"
)
scratch <- tempfile("pulse-first-check-")
dir.create(scratch, recursive = TRUE)
runner <- file.path(repo, "dev", "spikes", "pulse-first-batch", "spike_runner.R")
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
status <- system2(
  rscript,
  c(runner, "--preset", "smoke", "--output", scratch, "--repo", repo),
  stdout = TRUE, stderr = TRUE
)
if (!identical(attr(status, "status"), NULL)) {
  stop(paste(status, collapse = "\n"), call. = FALSE)
}
for (name in c("correctness.csv", "gutted_correctness.csv")) {
  expected <- utils::read.csv(file.path(record, name), stringsAsFactors = FALSE)
  actual <- utils::read.csv(file.path(scratch, name), stringsAsFactors = FALSE)
  if (!identical(expected, actual)) stop(sprintf("Evidence differs: %s", name), call. = FALSE)
}

protected <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
git_config <- file.path(scratch, "gitconfig")
writeLines(c("[safe]", "\tdirectory = *"), git_config, useBytes = TRUE)
old_git_config <- Sys.getenv("GIT_CONFIG_GLOBAL", unset = NA_character_)
on.exit({
  if (is.na(old_git_config)) Sys.unsetenv("GIT_CONFIG_GLOBAL") else
    Sys.setenv(GIT_CONFIG_GLOBAL = old_git_config)
}, add = TRUE)
Sys.setenv(GIT_CONFIG_GLOBAL = git_config)
git_command <- sprintf(
  'git -C "%s" status --porcelain --untracked-files=all',
  repo
)
changed <- system(git_command, intern = TRUE)
if (!identical(attr(changed, "status"), NULL)) {
  stop("Could not inspect repository scope with git status.", call. = FALSE)
}
paths <- sub("^.. ", "", changed)
paths <- sub("^.* -> ", "", paths)
bad <- paths[vapply(paths, function(path) {
  any(path == protected | startsWith(path, paste0(protected, "/")))
}, logical(1))]
if (length(bad) > 0L) {
  stop(sprintf("Protected package scope changed: %s", paste(bad, collapse = ", ")), call. = FALSE)
}
cat("PASS: smoke evidence reproduced, gut detected, package scope untouched\n")

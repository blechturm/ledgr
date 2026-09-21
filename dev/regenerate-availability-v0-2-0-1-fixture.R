args <- commandArgs(trailingOnly = TRUE)
prefix <- "--file="
selected <- args[startsWith(args, prefix)]
if (length(selected) != 1L) {
  stop("Usage: Rscript dev/regenerate-availability-v0-2-0-1-fixture.R --file=<fixture.csv>")
}

name <- substring(selected, nchar(prefix) + 1L)
allowed <- c(
  "completion.csv",
  "diagnostics.csv",
  "equity.csv",
  "events.csv",
  "identity.csv",
  "scenario-summary.csv",
  "state.csv"
)
if (!(name %in% allowed)) {
  stop("Unknown availability v0.2.0.1 fixture: ", name)
}

path <- file.path(
  "tests", "testthat", "fixtures", "availability-v0-2-0-1", name
)
release_closeout <- "3f1605dcb3c5081742a87f7197aef1916bea65a4"
object <- paste0(release_closeout, ":", gsub("\\\\", "/", path))
scratch <- tempfile(fileext = ".csv")
on.exit(unlink(scratch), add = TRUE)
prior_git_config <- Sys.getenv("GIT_CONFIG_GLOBAL", unset = NA_character_)
Sys.setenv(GIT_CONFIG_GLOBAL = file.path(Sys.getenv("USERPROFILE"), ".gitconfig"))
on.exit({
  if (is.na(prior_git_config)) {
    Sys.unsetenv("GIT_CONFIG_GLOBAL")
  } else {
    Sys.setenv(GIT_CONFIG_GLOBAL = prior_git_config)
  }
}, add = TRUE)
result <- system2(
  "git",
  c("show", object),
  stdout = scratch,
  stderr = TRUE
)
status <- attr(result, "status", exact = TRUE)
if (!is.null(status) && !identical(status, 0L)) {
  stop("Could not read frozen fixture from ", object)
}
if (!file.copy(scratch, path, overwrite = TRUE)) {
  stop("Could not write regenerated fixture: ", path)
}
message("Regenerated ", path, " from ", object)

if (!requireNamespace("lintr", quietly = TRUE)) {
  stop("The semantic-lint self-check requires lintr.", call. = FALSE)
}

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
root <- normalizePath(file.path(dirname(script), ".."), winslash = "/")
config <- file.path(root, ".lintr-semantic")
linters <- as.list(lintr:::read_config_file(config))$linters
expected <- c(
  "object_usage_linter",
  "commented_code_linter",
  "seq_linter",
  "T_and_F_symbol_linter",
  "duplicate_argument_linter",
  "unreachable_code_linter",
  "redundant_ifelse_linter",
  "undesirable_function_linter"
)
if (!identical(names(linters), expected)) {
  stop("The semantic-lint configuration is not the accepted eight-rule set.", call. = FALSE)
}

examples <- c(
  object_usage_linter = "f <- function() missing_object",
  commented_code_linter = "# x <- 1",
  seq_linter = "f <- function(x) 1:length(x)",
  T_and_F_symbol_linter = "x <- T",
  duplicate_argument_linter = "mean(1, na.rm = TRUE, na.rm = FALSE)",
  unreachable_code_linter = "f <- function() { return(1); 2 }",
  redundant_ifelse_linter = "f <- function(x) ifelse(x, TRUE, FALSE)",
  undesirable_function_linter = "f <- function(x) sapply(x, identity)"
)
observed <- lapply(names(examples), function(name) {
  path <- tempfile(fileext = ".R")
  writeLines(examples[[name]], path, useBytes = TRUE)
  findings <- lintr::lint(path, linters = linters, cache = FALSE)
  unique(vapply(findings, `[[`, character(1), "linter"))
})
names(observed) <- names(examples)
missing <- names(observed)[!vapply(
  names(observed),
  function(name) name %in% observed[[name]],
  logical(1)
)]
if (length(missing) > 0L) {
  stop(
    sprintf("Semantic-lint self-check missed: %s", paste(missing, collapse = ", ")),
    call. = FALSE
  )
}

cat("LEDGR_SEMANTIC_LINT_CONFIG_OK rules=8 injected=8\n")

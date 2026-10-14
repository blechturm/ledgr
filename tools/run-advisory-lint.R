args <- commandArgs(trailingOnly = TRUE)

value_arg <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0L) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

logical_arg <- function(name, default = FALSE) {
  value <- tolower(value_arg(name, as.character(default)))
  if (!value %in% c("true", "false")) {
    stop(sprintf("--%s must be true or false.", name), call. = FALSE)
  }
  identical(value, "true")
}

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
default_root <- normalizePath(file.path(dirname(script), ".."), winslash = "/")
root <- normalizePath(value_arg("root", default_root), winslash = "/", mustWork = TRUE)
output_arg <- value_arg(
  "output",
  file.path(root, "dev", "bench", "v0_2_2_pre_cran_removal", "lint")
)
output <- normalizePath(output_arg, winslash = "/", mustWork = FALSE)
source_commit <- value_arg("source-commit", "working-tree")
fail_on_findings <- logical_arg("fail-on-findings", FALSE)
config_name <- value_arg("config", ".lintr")
lint_name <- value_arg(
  "name",
  if (identical(config_name, ".lintr-semantic")) "semantic" else "formatting"
)

if (!requireNamespace("lintr", quietly = TRUE)) {
  stop("The advisory lint runner requires the lintr package.", call. = FALSE)
}
if (!requireNamespace("styler", quietly = TRUE)) {
  stop("The advisory lint record requires the styler package version.", call. = FALSE)
}

config <- file.path(root, config_name)
if (!file.exists(config)) {
  stop(sprintf("The repository lint config `%s` is missing.", config_name), call. = FALSE)
}

if (!identical(source_commit, "working-tree")) {
  git <- Sys.which("git")
  if (!nzchar(git)) stop("Cannot verify --source-commit without git.", call. = FALSE)
  git_output <- function(...) {
    result <- system2(git, c("-C", root, ...), stdout = TRUE, stderr = TRUE)
    status <- attr(result, "status")
    if (!is.null(status) && status != 0L) {
      stop(paste(result, collapse = "\n"), call. = FALSE)
    }
    result
  }
  expected <- git_output("rev-parse", source_commit)[[1L]]
  head <- git_output("rev-parse", "HEAD")[[1L]]
  if (!identical(expected, head)) {
    stop("--source-commit does not resolve to HEAD.", call. = FALSE)
  }
  dirty <- git_output("status", "--porcelain=v1", "--untracked-files=all")
  if (length(dirty) > 0L) {
    stop("--source-commit requires a clean working tree.", call. = FALSE)
  }
}

dir.create(output, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(output)) stop("Cannot create the lint output directory.", call. = FALSE)

relative_path <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  prefix <- paste0(root, "/")
  ifelse(startsWith(path, prefix), substring(path, nchar(prefix) + 1L), path)
}

included_roots <- c("R", "tests", "tools")
lint_settings <- as.list(lintr:::read_config_file(config))
excluded_paths <- unlist(lint_settings$exclusions, use.names = FALSE)
excluded_paths <- gsub("\\\\", "/", excluded_paths)

is_excluded <- function(path) {
  any(path == excluded_paths | startsWith(path, paste0(excluded_paths, "/")))
}

files <- unlist(lapply(included_roots, function(path) {
  full <- file.path(root, path)
  if (!dir.exists(full)) return(character())
  list.files(full, pattern = "\\.[Rr]$", recursive = TRUE, full.names = TRUE)
}), use.names = FALSE)
files <- files[!vapply(relative_path(files), is_excluded, logical(1))]
files <- files[order(relative_path(files), method = "radix")]

if (length(files) == 0L) stop("The advisory lint source set is empty.", call. = FALSE)

old_dir <- setwd(root)
on.exit(setwd(old_dir), add = TRUE)
lints <- unlist(lapply(files, function(file) {
  lintr::lint(relative_path(file), cache = FALSE)
}), recursive = FALSE)

if (length(lints) == 0L) {
  findings <- data.frame(
    file = character(), line = integer(), column = integer(),
    linter = character(), type = character(), message = character(),
    stringsAsFactors = FALSE
  )
} else {
  findings <- do.call(rbind, lapply(lints, function(lint) {
    data.frame(
      file = relative_path(lint$filename),
      line = as.integer(lint$line_number),
      column = as.integer(lint$column_number),
      linter = as.character(lint$linter),
      type = as.character(lint$type),
      message = as.character(lint$message),
      stringsAsFactors = FALSE
    )
  }))
  findings <- findings[
    order(
      findings$file, findings$line, findings$column, findings$linter,
      findings$message, method = "radix"
    ),
    , drop = FALSE
  ]
  rownames(findings) <- NULL
}

if (nrow(findings) == 0L) {
  summary <- data.frame(linter = character(), findings = integer())
} else {
  summary <- as.data.frame(table(findings$linter), stringsAsFactors = FALSE)
  names(summary) <- c("linter", "findings")
  summary <- summary[order(summary$linter, method = "radix"), , drop = FALSE]
  summary$findings <- as.integer(summary$findings)
}

metadata <- data.frame(
  key = c(
    "source_commit", "lintr_version", "styler_version", "included_roots",
    "excluded_paths", "source_files", "config", "lint_name", "mode"
  ),
  value = c(
    source_commit,
    as.character(utils::packageVersion("lintr")),
    as.character(utils::packageVersion("styler")),
    paste(included_roots, collapse = ";"),
    paste(excluded_paths, collapse = ";"),
    as.character(length(files)),
    config_name,
    lint_name,
    if (fail_on_findings) "blocking" else "advisory"
  ),
  stringsAsFactors = FALSE
)
metadata <- metadata[order(metadata$key, method = "radix"), , drop = FALSE]

utils::write.csv(
  findings,
  file.path(output, "findings.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8",
  eol = "\n"
)
utils::write.csv(
  summary,
  file.path(output, "summary.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8",
  eol = "\n"
)
utils::write.csv(
  metadata,
  file.path(output, "metadata.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8",
  eol = "\n"
)

cat(sprintf(
  "LEDGR_LINT name=%s files=%d findings=%d mode=%s output=%s\n",
  lint_name, length(files), nrow(findings),
  if (fail_on_findings) "blocking" else "advisory",
  relative_path(output)
))

if (fail_on_findings && nrow(findings) > 0L) quit(status = 1L)

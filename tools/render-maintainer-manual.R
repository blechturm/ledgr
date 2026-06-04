# Render the internal maintainer manual Quarto sources to sibling GFM Markdown.
#
# Quarto's directory render skips README.qmd in this project layout, so the
# README is rendered explicitly. Pandoc emits "``` mermaid" info strings for
# GFM; normalize them to GitHub's documented "```mermaid" form.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grepl("^--file=", args)]
repo_root <- if (length(file_arg) > 0L) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1L]])), ".."),
                winslash = "/", mustWork = TRUE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}
setwd(repo_root)

manual_dir <- file.path("inst", "design", "manual")
quarto <- Sys.which("quarto")
if (!nzchar(quarto)) {
  candidate <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe"
  if (file.exists(candidate)) {
    quarto <- candidate
  }
}
if (!nzchar(quarto)) {
  stop("Quarto executable not found on PATH or at the RStudio bundled path.")
}

run_quarto <- function(render_args) {
  status <- system2(quarto, render_args)
  if (!identical(status, 0L)) {
    stop("quarto failed: ", paste(render_args, collapse = " "))
  }
}

run_quarto(c("render", manual_dir))
run_quarto(c("render", file.path(manual_dir, "README.qmd"), "--to", "gfm"))

md_files <- list.files(manual_dir, pattern = "[.]md$", full.names = TRUE)
for (path in md_files) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- sub("^``` mermaid$", "```mermaid", lines)
  writeLines(lines, path, useBytes = TRUE)
}

message("Rendered maintainer manual Markdown: ", paste(md_files, collapse = ", "))

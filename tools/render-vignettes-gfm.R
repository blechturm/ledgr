# Render selected public vignette Quarto sources to sibling GFM Markdown.
#
# Public vignette sources use custom ledgr callout divs because pkgdown styles
# those classes reliably. Quarto emits those divs literally for GFM, so normalize
# the generated Markdown siblings to GitHub admonitions for repository browsing.

args <- commandArgs(trailingOnly = TRUE)
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

if (length(args) == 0L) {
  stop("Pass one or more vignette .qmd files to render.")
}

qmd_files <- normalizePath(args, winslash = "/", mustWork = TRUE)
repo_prefix <- paste0(repo_root, "/")
outside_repo <- !startsWith(qmd_files, repo_prefix)
if (any(outside_repo)) {
  stop("Refusing to render files outside repository root: ",
       paste(qmd_files[outside_repo], collapse = ", "))
}

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

run_quarto <- function(path) {
  status <- system2(quarto, c("render", path, "--to", "gfm"))
  if (!identical(status, 0L)) {
    stop("quarto failed: ", path)
  }
}

callout_label <- function(kind) {
  switch(kind,
         note = "NOTE",
         warning = "WARNING",
         tip = "TIP",
         important = "IMPORTANT",
         toupper(kind))
}

normalize_callouts <- function(lines) {
  out <- character()
  i <- 1L
  n <- length(lines)
  open_re <- '^<div class="ledgr-callout ledgr-callout-(note|warning|tip|important)">$'

  while (i <= n) {
    match <- regexec(open_re, lines[[i]])
    parts <- regmatches(lines[[i]], match)[[1L]]

    if (length(parts) == 2L) {
      kind <- parts[[2L]]
      i <- i + 1L

      while (i <= n && lines[[i]] == "") {
        i <- i + 1L
      }

      block <- character()
      while (i <= n && lines[[i]] != "</div>") {
        block <- c(block, lines[[i]])
        i <- i + 1L
      }
      if (i <= n && lines[[i]] == "</div>") {
        i <- i + 1L
      }

      while (length(block) > 0L && block[[length(block)]] == "") {
        block <- block[-length(block)]
      }
      if (length(block) > 0L &&
          grepl("^\\*\\*[^*]+\\*\\*$", block[[1L]])) {
        block[[1L]] <- sub("^\\*\\*([^*]+)\\*\\*$", "### \\1", block[[1L]])
      }

      out <- c(out, paste0("> [!", callout_label(kind), "]"), ">")
      for (line in block) {
        out <- c(out, if (line == "") ">" else paste0("> ", line))
      }
      out <- c(out, "")
    } else {
      out <- c(out, lines[[i]])
      i <- i + 1L
    }
  }

  out
}

postprocess_markdown <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- sub("^``` mermaid$", "```mermaid", lines)
  lines <- normalize_callouts(lines)
  lines <- sub("[[:space:]]+$", "", lines)
  writeLines(lines, path, useBytes = TRUE)
}

for (qmd in qmd_files) {
  rel <- sub(paste0("^", gsub("([\\.^$*+?()[{\\\\|])", "\\\\\\1", repo_prefix)),
             "", qmd)
  run_quarto(rel)
  md <- sub("[.]qmd$", ".md", rel)
  if (file.exists(md)) {
    postprocess_markdown(md)
  }
}

message("Rendered vignette Markdown: ",
        paste(sub(paste0("^", repo_prefix), "", qmd_files), collapse = ", "))

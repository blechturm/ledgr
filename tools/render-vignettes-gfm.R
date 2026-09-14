# Render selected public vignette Quarto sources to sibling GFM Markdown.
#
# Public vignette sources use custom ledgr callout divs because pkgdown styles
# those classes reliably. Quarto emits those divs literally for GFM, so normalize
# the generated Markdown siblings to GitHub admonitions for repository browsing.

args <- commandArgs(trailingOnly = TRUE)
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

check_only <- "--check" %in% args
render_all <- "--all" %in% args
path_args <- setdiff(args, c("--check", "--all"))

if (render_all && length(path_args) > 0L) {
  stop("Pass either --all or explicit vignette .qmd files, not both.")
}
if (render_all) {
  path_args <- list.files(
    file.path(repo_root, "vignettes"),
    pattern = "[.]qmd$",
    full.names = TRUE,
    recursive = FALSE
  )
}
if (length(path_args) == 0L) {
  stop("Pass --all or one or more vignette .qmd files to render.")
}

qmd_files <- normalizePath(path_args, winslash = "/", mustWork = TRUE)
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

run_quarto <- function(path, execute_dir = NULL) {
  quarto_args <- c("render", path, "--to", "gfm")
  if (!is.null(execute_dir)) {
    quarto_args <- c(quarto_args, "--execute-dir", execute_dir)
  }
  status <- system2(quarto, quarto_args)
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

normalize_for_freshness <- function(lines) {
  lines <- gsub("\\bsweep_[0-9a-f]{16}\\b", "sweep_<generated>", lines, perl = TRUE)
  lines <- sub(
    "(Elapsed Sec:[[:space:]]+)[0-9]+(?:[.][0-9]+)?",
    "\\1<elapsed>",
    lines,
    perl = TRUE
  )
  lines <- sub(
    "(Created At:[[:space:]]+)[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+",
    "\\1<created-at>",
    lines,
    perl = TRUE
  )
  sweep_rows <- grepl(
    "^[[:space:]]*[0-9]+[[:space:]]+[^[:space:]]*sweep[[:space:]]+[0-9]{4}-",
    lines,
    perl = TRUE
  )
  lines[sweep_rows] <- sub(
    "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+",
    "<created-at>",
    lines[sweep_rows],
    perl = TRUE
  )
  lines
}

check_root <- NULL
if (check_only) {
  temp_root <- file.path(repo_root, ".tmp")
  dir.create(temp_root, recursive = TRUE, showWarnings = FALSE)
  check_root <- tempfile("vignette-render-check-", tmpdir = temp_root)
  dir.create(check_root, recursive = TRUE)
  project_config <- file.path(repo_root, "_quarto.yml")
  if (file.exists(project_config) &&
      !file.copy(project_config, file.path(check_root, "_quarto.yml"))) {
    stop("Could not copy the Quarto project configuration for the freshness check.")
  }
  on.exit({
    resolved_check <- normalizePath(check_root, winslash = "/", mustWork = FALSE)
    resolved_temp <- paste0(normalizePath(temp_root, winslash = "/", mustWork = TRUE), "/")
    if (startsWith(paste0(resolved_check, "/"), resolved_temp)) {
      unlink(check_root, recursive = TRUE, force = TRUE)
    }
  }, add = TRUE)
}

stale <- character()
for (qmd in qmd_files) {
  rel <- sub(paste0("^", gsub("([\\.^$*+?()[{\\\\|])", "\\\\\\1", repo_prefix)),
             "", qmd)
  rel_md <- sub("[.]qmd$", ".md", rel)
  source_md <- file.path(repo_root, rel_md)
  if (check_only) {
    if (!file.exists(source_md)) {
      stale <- c(stale, paste0(rel_md, " (missing sibling)"))
      next
    }
    rendered_qmd <- file.path(check_root, rel)
    dir.create(dirname(rendered_qmd), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(qmd, rendered_qmd, overwrite = TRUE)) {
      stop("Could not copy vignette source for freshness check: ", rel)
    }
    run_quarto(rendered_qmd, repo_root)
    rendered_md <- file.path(check_root, rel_md)
    if (!file.exists(rendered_md)) {
      stop("Quarto did not produce the expected Markdown: ", rendered_md)
    }
    postprocess_markdown(rendered_md)
    current <- normalize_for_freshness(
      readLines(source_md, warn = FALSE, encoding = "UTF-8")
    )
    rendered <- normalize_for_freshness(
      readLines(rendered_md, warn = FALSE, encoding = "UTF-8")
    )
    if (!identical(current, rendered)) {
      stale <- c(stale, rel_md)
      common <- min(length(current), length(rendered))
      first <- which(current[seq_len(common)] != rendered[seq_len(common)])[1L]
      if (is.na(first)) {
        first <- common + 1L
      }
      current_line <- if (first <= length(current)) current[[first]] else "<end of file>"
      rendered_line <- if (first <= length(rendered)) rendered[[first]] else "<end of file>"
      message(
        rel_md, ":", first, " differs\n",
        "  committed: ", current_line, "\n",
        "  rendered:  ", rendered_line
      )
    }
  } else {
    run_quarto(rel)
    if (file.exists(source_md)) {
      postprocess_markdown(source_md)
    }
  }
}

if (check_only && length(stale) > 0L) {
  stop(
    "Rendered vignette Markdown is stale:\n- ",
    paste(stale, collapse = "\n- ")
  )
}

verb <- if (check_only) "Verified" else "Rendered"
message(
  verb, " vignette Markdown: ",
  paste(sub(paste0("^", repo_prefix), "", qmd_files), collapse = ", ")
)

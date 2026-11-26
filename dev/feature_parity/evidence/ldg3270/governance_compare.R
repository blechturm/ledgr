# LDG-3270 (close review F3): the governance report on the cut base and on the
# final commit, compared. Adapted from the close reviewer's governance_probe.R:
# the report runs once on the working tree, and once with every changed
# markdown/quarto/yaml input replaced by its bytes at the base and the base's
# tracked manifest, so both arms use the same report code. Finding sets are
# compared with line numbers removed (lines shift when text is added above).
#
#   Rscript governance_compare.R --repo=<tree> --base=<commit> --final=<commit> --out=<dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  repo <- normalizePath(arg("repo"), winslash = "/")
  base <- arg("base")
  final <- arg("final")
  out <- arg("out")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  git <- function(...) system2("git", c("-C", repo, ...), stdout = TRUE)
  stopifnot(identical(git("rev-parse", "HEAD"), git("rev-parse", final)))
  source(file.path(repo, "tools", "governance-report.R"))
  tracked <- git("ls-tree", "-r", "--name-only", base)
  changed <- git("diff", "--name-only", base, final)
  deleted <- git("diff", "--name-only", "--diff-filter=D", base, final)
  stopifnot(length(deleted) == 0L)
  inputs <- changed[changed %in% tracked & grepl("[.](md|qmd|yml|yaml)$", changed)]
  scratch <- file.path(tempdir(), "governance_base_inputs")
  mapped <- stats::setNames(file.path(scratch, inputs), file.path(repo, inputs))
  for (i in seq_along(mapped)) {
    dir.create(dirname(mapped[[i]]), recursive = TRUE, showWarnings = FALSE)
    stopifnot(system2("git", c("-C", repo, "show", paste0(base, ":", inputs[[i]])), stdout = mapped[[i]]) == 0L)
  }
  manifest <- file.path(scratch, "base_tracked.yml")
  yaml::write_yaml(list(tracked = tracked), manifest)
  args <- list(root = repo, baseline_path = file.path(repo, "dev/governance_guard/baseline.yml"),
               claims_path = file.path(repo, "tests/claims.yml"),
               current_packet = "inst/design/ledgr_v0_2_3_spec_packet")
  final_report <- do.call(governance_report, args)
  writeLines(final_report, file.path(out, "governance_final.txt"))
  read_lines <- governance_read_lines
  read_yaml <- governance_read_yaml
  sha <- governance_sha256_file
  swap <- function(path) if (path %in% names(mapped)) unname(mapped[[path]]) else path
  governance_read_lines <- function(path) read_lines(swap(path))
  governance_read_yaml <- function(path) read_yaml(swap(path))
  governance_sha256_file <- function(path) sha(swap(path))
  base_report <- do.call(governance_report, c(args, list(tracked_path = manifest)))
  writeLines(base_report, file.path(out, "governance_base.txt"))
  findings <- function(x) sort(gsub("\tline=[0-9]+", "", grep("^FINDING\t", x, value = TRUE)))
  added <- setdiff(findings(final_report), findings(base_report))
  removed <- setdiff(findings(base_report), findings(final_report))
  cat("base", base, "final", final, "changed inputs substituted", length(inputs), "\n")
  cat("findings base", length(findings(base_report)), "final", length(findings(final_report)), "\n")
  cat("added", length(added), "removed", length(removed), "\n")
  if (length(added)) cat("ADDED:", added, sep = "\n  ")
  if (length(removed)) cat("REMOVED:", removed, sep = "\n  ")
  cat(if (!length(added)) "GOVERNANCE COMPARE PASS (no finding added)\n" else "GOVERNANCE COMPARE FAIL\n")
})

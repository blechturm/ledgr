# Runs the variant manifest (LDG-3220, Cut 14 R2): every row of the frozen
# 4a3e08b8 manifest (loop_variants.csv), less the retirements and plus the
# additions recorded in loop_variant_changes.csv, each with its workloads,
# debug setting and batch bound. One loop_parity.R subprocess per variant,
# debug setting and bound. Fails (status 1) when any manifest row is
# missing from the results or is not CAUGHT, when a subprocess fails, or
# when a change row names nothing in the manifest.
#
#   Rscript dev/lean_core/parity/loop_variants.R --lib=<pinned library>
#     --out=<dir> [--debug=0|1]
#
# Writes <dir>/variant_<name>_debug<d>_b<rows>.csv per run and
# <dir>/loop_mutations_debug<d>.csv combined.

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
lib <- arg("lib")
out <- arg("out")
only_debug <- arg("debug", "")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
read <- function(f) utils::read.csv(file.path(here, f), stringsAsFactors = FALSE, na.strings = character())
key <- function(x) paste(x$mutation, x$workload, x$debug, x$batch_rows, sep = "|")
manifest <- read("loop_variants.csv")
changes <- read("loop_variant_changes.csv")
retire <- changes[changes$action == "retire", ]
unknown <- setdiff(key(retire), key(manifest))
if (length(unknown)) stop("retirements not in the manifest: ", paste(unknown, collapse = ", "), call. = FALSE)
manifest <- manifest[!key(manifest) %in% key(retire), ]
add <- changes[changes$action == "add", names(manifest)]
# Cut 18: a re-anchored variant keeps its manifest row; its change row must
# name one, and an unknown action refuses.
reanchor <- changes[changes$action == "reanchor", ]
unknown <- setdiff(key(reanchor), c(key(manifest), key(add)))
if (length(unknown)) stop("re-anchors not in the manifest: ", paste(unknown, collapse = ", "), call. = FALSE)
if (length(bad <- setdiff(changes$action, c("add", "retire", "reanchor")))) stop("unknown change action: ", bad[[1L]], call. = FALSE)
manifest <- rbind(manifest, add)
if (nzchar(only_debug)) manifest <- manifest[manifest$debug == as.integer(only_debug), ]

rscript <- file.path(R.home("bin"), "Rscript.exe")
groups <- split(manifest, paste(manifest$mutation, manifest$debug, manifest$batch_rows, sep = "|"))
results <- list()
failures <- character()
# Runs one loop_parity.R subprocess; returns its exit status, last line and
# result rows (NULL when it wrote none).
run_parity <- function(m, d, b, workloads, csv) {
  if (file.exists(csv)) file.remove(csv)
  log <- suppressWarnings(system2(rscript, c(file.path(here, "loop_parity.R"), paste0("--lib=", lib),
    paste0("--debug=", d), paste0("--batch-rows=", b), paste0("--mutation=", m),
    paste0("--workloads=", paste(workloads, collapse = ",")), paste0("--out=", csv)), stdout = TRUE, stderr = TRUE))
  status <- attr(log, "status") %||% 0L
  rows <- if (file.exists(csv)) utils::read.csv(csv, stringsAsFactors = FALSE, na.strings = character()) else NULL
  list(status = as.integer(status), last = utils::tail(log, 1L), rows = rows)
}
`%||%` <- function(a, b) if (is.null(a)) b else a
for (g in groups) {
  m <- g$mutation[[1L]]; d <- g$debug[[1L]]; b <- g$batch_rows[[1L]]
  r <- run_parity(m, d, b, g$workload, file.path(out, sprintf("variant_%s_debug%d_b%d.csv", m, d, b)))
  cat(sprintf("debug %d %s (bound %d): status %d, %s\n", d, m, b, r$status, r$last))
  if (r$status != 0L) failures <- c(failures, sprintf("%s debug %d: subprocess status %d (%s)", m, d, r$status, r$last))
  if (is.null(r$rows)) {
    failures <- c(failures, sprintf("%s debug %d: no result", m, d))
    next
  }
  results[[length(results) + 1L]] <- r$rows
  # Every requested manifest row, by its full key and expected signal.
  got <- unique(r$rows[, c("mutation", "workload", "debug", "batch_rows", "expect", "verdict")])
  for (i in seq_len(nrow(g))) {
    hit <- got[got$mutation == g$mutation[[i]] & got$workload == g$workload[[i]] & got$debug == g$debug[[i]] &
               got$batch_rows == g$batch_rows[[i]] & got$expect == g$expect[[i]], ]
    v <- if (nrow(hit) == 1L) hit$verdict else if (nrow(hit) == 0L) "missing" else "duplicated"
    if (!identical(v, "CAUGHT")) failures <- c(failures, sprintf("%s / %s debug %d: %s", m, g$workload[[i]], d, v))
  }
  # any result row whose full key was not requested (close review round 2)
  key <- function(x) paste(x$mutation, x$workload, x$debug, x$batch_rows, x$expect, sep = "|")
  extra <- setdiff(key(got), key(g))
  if (length(extra)) failures <- c(failures, sprintf("%s debug %d: unrequested rows %s", m, d, paste(extra, collapse = ",")))
}
# Negative controls: an unrelated error, an unreached patch and a store
# variant that writes through a path other than the one it declares must not
# be CAUGHT; each must exit 1 with its declared verdict.
controls <- c(control_unrelated = "UNRELATED", control_unreached = "UNREACHED", control_wrong_store_path = "MISSED")
if (!nzchar(only_debug) || identical(only_debug, "0")) for (m in names(controls)) {
  b <- if (identical(m, "control_wrong_store_path")) 8L else 65536L
  r <- run_parity(m, 0L, b, "crossover_3x40", file.path(out, sprintf("control_%s.csv", m)))
  v <- if (is.null(r$rows)) "missing" else unique(r$rows$verdict)
  cat(sprintf("control %s: %s, status %d (expected %s, status 1)\n", m, paste(v, collapse = ","), r$status, controls[[m]]))
  if (!identical(v, controls[[m]]) || r$status != 1L) {
    failures <- c(failures, sprintf("control %s: %s status %d, expected %s status 1", m, paste(v, collapse = ","), r$status, controls[[m]]))
  }
  if (!is.null(r$rows)) results[[length(results) + 1L]] <- r$rows
}
all_rows <- do.call(rbind, results)
for (d in unique(manifest$debug)) {
  utils::write.csv(all_rows[all_rows$debug == d, ], file.path(out, sprintf("loop_mutations_debug%d.csv", d)), row.names = FALSE)
}
cat(sprintf("%d manifest rows, %d variants, %d failures\n", nrow(manifest), length(unique(manifest$mutation)),
            length(failures)))
if (length(failures)) {
  cat(paste0("  ", failures, collapse = "\n"), "\n")
  quit(status = 1L)
}

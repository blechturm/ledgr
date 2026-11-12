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
manifest <- rbind(manifest, add)
if (nzchar(only_debug)) manifest <- manifest[manifest$debug == as.integer(only_debug), ]

rscript <- file.path(R.home("bin"), "Rscript.exe")
groups <- split(manifest, paste(manifest$mutation, manifest$debug, manifest$batch_rows, sep = "|"))
results <- list()
failures <- character()
for (g in groups) {
  m <- g$mutation[[1L]]; d <- g$debug[[1L]]; b <- g$batch_rows[[1L]]
  csv <- file.path(out, sprintf("variant_%s_debug%d_b%d.csv", m, d, b))
  if (file.exists(csv)) file.remove(csv)
  log <- system2(rscript, c(file.path(here, "loop_parity.R"), paste0("--lib=", lib), paste0("--debug=", d),
    paste0("--batch-rows=", b), paste0("--mutation=", m), paste0("--workloads=", paste(g$workload, collapse = ",")),
    paste0("--out=", csv)), stdout = TRUE, stderr = TRUE)
  cat(sprintf("debug %d %s (bound %d): %s\n", d, m, b, utils::tail(log, 1L)))
  if (!file.exists(csv)) {
    failures <- c(failures, sprintf("%s debug %d: no result (%s)", m, d, utils::tail(log, 1L)))
    next
  }
  r <- utils::read.csv(csv, stringsAsFactors = FALSE, na.strings = character())
  results[[length(results) + 1L]] <- r
  got <- unique(r[, c("workload", "verdict")])
  for (w in g$workload) {
    v <- got$verdict[got$workload == w]
    if (!identical(v, "CAUGHT")) failures <- c(failures, sprintf("%s / %s debug %d: %s", m, w, d,
                                                               if (length(v)) v else "missing"))
  }
}
# Negative controls: an unrelated error and an unreached patch must not be
# CAUGHT, so the gate is shown to fail closed.
controls <- c(control_unrelated = "UNRELATED", control_unreached = "UNREACHED")
if (!nzchar(only_debug) || identical(only_debug, "0")) for (m in names(controls)) {
  csv <- file.path(out, sprintf("control_%s.csv", m))
  if (file.exists(csv)) file.remove(csv)
  log <- system2(rscript, c(file.path(here, "loop_parity.R"), paste0("--lib=", lib), "--debug=0",
    paste0("--mutation=", m), "--workloads=crossover_3x40", paste0("--out=", csv)), stdout = TRUE, stderr = TRUE)
  v <- if (file.exists(csv)) unique(utils::read.csv(csv, stringsAsFactors = FALSE)$verdict) else "missing"
  cat(sprintf("control %s: %s (expected %s)\n", m, paste(v, collapse = ","), controls[[m]]))
  if (!identical(v, controls[[m]])) failures <- c(failures, sprintf("control %s: %s, expected %s", m, paste(v, collapse = ","), controls[[m]]))
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

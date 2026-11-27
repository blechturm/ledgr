# The recorded oracle's manifest (Cut 27 decision 7, LDG-3282): one row per
# record file and one per recorded table or case, written from the pin's
# records under <records> (kept outside the tree):
# - gate/<workload>.rds: loop_parity.R --dump's pin arm, run_tables() in A0
#   canonical form (dev/bench/v0_2_3_output_freeze/lib.R): a list of paths,
#   each a list of tables; every cell a string or NA (doubles %.17g), rows in
#   the declared key order, the column classes in attribute a0_types, the
#   enumerated clock and version fields dropped (a0_exclusions); an error
#   escaping a workload is the table escaped/error (class, message);
# - cut18/cut18_pin.rds: cut18_witness.R --dump's pin outcomes, a list named
#   "<replacement>|<case>" of list(value = ...) or list(error = <normalized
#   condition: class, fields without trace, parent recursively>).
#
#   Rscript oracle_manifest.R --records=<dir> --out=<dir>
#
# Writes <out>/oracle_records.csv (kind, key, file, bytes, sha256) and
# <out>/oracle_tables.csv (kind, key, path, table, rows, columns, types,
# sha256; for cut18: the case, its outcome and condition class).
local({
  argv <- commandArgs(TRUE)
  arg <- function(n) sub(paste0("^--", n, "="), "", grep(paste0("^--", n, "="), argv, value = TRUE)[[1L]])
  assign("records", normalizePath(arg("records"), winslash = "/", mustWork = TRUE), globalenv())
  assign("out", arg("out"), globalenv())
})
sha <- function(x) digest::digest(x, algo = "sha256")
sha_file <- function(f) digest::digest(file = f, algo = "sha256")
files <- sort(list.files(records, recursive = TRUE), method = "radix")
kind_of <- function(f) sub("/.*", "", f)
rec <- data.frame(kind = kind_of(files), key = sub("[.]rds$", "", basename(files)), file = files,
                  bytes = file.size(file.path(records, files)),
                  sha256 = vapply(file.path(records, files), sha_file, ""), stringsAsFactors = FALSE)
if (!all(rec$kind %in% c("gate", "cut18"))) stop("unexpected record kind: ", paste(setdiff(rec$kind, c("gate", "cut18")), collapse = ", "))
if (any(grepl("_lean$|_workers$", rec$key))) stop("candidate dumps found among the pin records")
rows <- list()
for (i in seq_len(nrow(rec))) {
  x <- readRDS(file.path(records, rec$file[[i]]))
  if (rec$kind[[i]] == "gate") {
    for (p in names(x)) for (t in names(x[[p]])) {
      d <- x[[p]][[t]]
      rows[[length(rows) + 1L]] <- data.frame(kind = "gate", key = rec$key[[i]], path = p, table = t,
        rows = if (is.data.frame(d)) nrow(d) else NA_integer_,
        columns = if (is.data.frame(d)) paste(names(d), collapse = " ") else class(d)[[1L]],
        types = paste(attr(d, "a0_types") %||% "", collapse = " "), sha256 = sha(d), stringsAsFactors = FALSE)
    }
  } else {
    for (k in names(x)) {
      o <- x[[k]]
      rows[[length(rows) + 1L]] <- data.frame(kind = "cut18", key = rec$key[[i]], path = k,
        table = if (is.null(o$error)) "value" else "refusal", rows = NA_integer_,
        columns = if (is.null(o$error)) class(o$value)[[1L]] else o$error$class[[1L]],
        types = "", sha256 = sha(o), stringsAsFactors = FALSE)
    }
  }
}
tab <- do.call(rbind, rows)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(rec, file.path(out, "oracle_records.csv"), row.names = FALSE)
utils::write.csv(tab, file.path(out, "oracle_tables.csv"), row.names = FALSE)
cat(sprintf("%d record files (%s), %d tables or cases\n", nrow(rec),
            paste(names(table(rec$kind)), table(rec$kind), collapse = ", "), nrow(tab)))

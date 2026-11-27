# Controls for the recorded oracle's checker (Cut 27, LDG-3282): each
# scenario runs oracle_check.R in a child process on scratch copies of the
# records and the candidate outputs and requires its exit status and a
# message. The pin records are only read.
#
#   Rscript oracle_controls.R --records=<dir> --manifest=<dir> --candidate=<dir>
#     --scratch=<empty dir> --out=<csv> [--mutated=<candidate dir>]
#
# Scenarios:
# - full: the candidate's outputs on the whole corpus (PASS);
# - missing_record, extra_record, corrupt_record (one byte changed);
# - missing_output (a workload's candidate output removed);
# - changed_gate (one cell of one candidate table changed by one ulp in its
#   last printed digit), changed_cut18 (one case's value changed);
# - accepted (changed_gate listed in --accepted with its authority and the
#   candidate's digest: PASS, ACCEPTED), accepted_wrong_digest,
#   accepted_unused (a listed difference no comparison shows);
# - mutated (with --mutated: the outputs of a real candidate run under a registered
#   lean-core mutation, loop_parity.R --mutation --dump-lean, laid over a
#   copy of the candidate's outputs).
local({
  argv <- commandArgs(TRUE)
  arg <- function(n, d = NULL) { v <- grep(paste0("^--", n, "="), argv, value = TRUE); if (length(v)) sub(paste0("^--", n, "="), "", v[[1L]]) else d }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  assign("oc", list(here = here, records = normalizePath(arg("records"), winslash = "/", mustWork = TRUE),
                    manifest = normalizePath(arg("manifest"), winslash = "/", mustWork = TRUE),
                    candidate = normalizePath(arg("candidate"), winslash = "/", mustWork = TRUE),
                    scratch = arg("scratch"), out = arg("out"), mutated = arg("mutated", "")), globalenv())
})
rscript <- file.path(R.home("bin"), "Rscript.exe")
sha <- function(x) digest::digest(x, algo = "sha256")
dir.create(oc$scratch, recursive = TRUE, showWarnings = FALSE)
copy_tree <- function(from, to) {
  dir.create(to, recursive = TRUE, showWarnings = FALSE)
  for (d in list.dirs(from, recursive = FALSE, full.names = FALSE)) {
    dir.create(file.path(to, d), showWarnings = FALSE)
    invisible(file.copy(list.files(file.path(from, d), full.names = TRUE), file.path(to, d)))
  }
  to
}
check <- function(name, records, candidate, accepted = "") {
  log <- file.path(oc$scratch, paste0(name, ".log"))
  args <- c(shQuote(file.path(oc$here, "oracle_check.R")), paste0("--records=", records), paste0("--manifest=", oc$manifest),
            paste0("--candidate=", candidate), paste0("--out=", file.path(oc$scratch, paste0(name, ".csv"))))
  if (nzchar(accepted)) args <- c(args, paste0("--accepted=", accepted))
  status <- system2(rscript, args, stdout = log, stderr = log)
  list(status = status, text = paste(readLines(log, warn = FALSE), collapse = "\n"))
}
rows <- list()
expect <- function(name, r, status, pattern) {
  ok <- identical(as.integer(r$status), as.integer(status)) && grepl(pattern, r$text, fixed = TRUE)
  rows[[length(rows) + 1L]] <<- data.frame(scenario = name, exit = r$status, expected_exit = status, expected_text = pattern,
                                            result = if (ok) "OK" else "WRONG", stringsAsFactors = FALSE)
  cat(sprintf("%-22s exit %d (expected %d, '%s'): %s\n", name, r$status, status, pattern, if (ok) "OK" else "WRONG"))
}
rec <- utils::read.csv(file.path(oc$manifest, "oracle_records.csv"), stringsAsFactors = FALSE)
gate_rec <- rec$file[rec$kind == "gate"][[1L]]
gate_key <- rec$key[rec$kind == "gate"][[1L]]

expect("full", check("full", oc$records, oc$candidate), 0L, "ORACLE CHECK PASS")

r <- copy_tree(oc$records, file.path(oc$scratch, "rec_missing"))
unlink(file.path(r, gate_rec))
expect("missing_record", check("missing_record", r, oc$candidate), 1L, "missing record file")

r <- copy_tree(oc$records, file.path(oc$scratch, "rec_extra"))
saveRDS(list(), file.path(r, "gate", "unlisted.rds"))
expect("extra_record", check("extra_record", r, oc$candidate), 1L, "extra record file")

r <- copy_tree(oc$records, file.path(oc$scratch, "rec_corrupt"))
p <- file.path(r, gate_rec)
b <- readBin(p, "raw", file.size(p)); k <- length(b) %/% 2L; b[[k]] <- as.raw(bitwXor(as.integer(b[[k]]), 1L))
writeBin(b, p)
expect("corrupt_record", check("corrupt_record", r, oc$candidate), 1L, "corrupt")

c1 <- copy_tree(oc$candidate, file.path(oc$scratch, "cand_missing"))
unlink(file.path(c1, "gate", paste0(gate_key, "_lean.rds")))
expect("missing_output", check("missing_output", oc$records, c1), 1L, "candidate output missing")

# One cell of the first non-empty table: its last digit moved by one.
c2 <- copy_tree(oc$candidate, file.path(oc$scratch, "cand_changed"))
cf <- file.path(c2, "gate", paste0(gate_key, "_lean.rds"))
x <- readRDS(cf)
hit <- NULL
for (pth in names(x)) for (t in names(x[[pth]])) {
  d <- x[[pth]][[t]]
  if (is.null(hit) && is.data.frame(d) && nrow(d) > 0L) {
    for (col in names(d)) if (is.null(hit) && is.character(d[[col]]) && !is.na(d[[col]][[1L]]) && grepl("[0-9]$", d[[col]][[1L]])) {
      v <- d[[col]][[1L]]; last <- as.integer(substring(v, nchar(v)))
      d[[col]][[1L]] <- paste0(substring(v, 1L, nchar(v) - 1L), (last + 1L) %% 10L)
      x[[pth]][[t]] <- d
      hit <- list(path = pth, table = t, column = col)
    }
  }
}
if (is.null(hit)) stop("no numeric cell to change in ", gate_key)
saveRDS(x, cf)
expect("changed_gate", check("changed_gate", oc$records, c2), 1L, "not an accepted difference")

c3 <- copy_tree(oc$candidate, file.path(oc$scratch, "cand_cut18"))
cf3 <- file.path(c3, "cut18", "cut18_lean_d0.rds")
y <- readRDS(cf3)
k1 <- names(y)[vapply(y, function(o) !is.null(o$value) && is.numeric(o$value) && length(o$value) > 0L, logical(1))][[1L]]
y[[k1]]$value[[1L]] <- y[[k1]]$value[[1L]] + 1
saveRDS(y, cf3)
expect("changed_cut18", check("changed_cut18", oc$records, c3), 1L, "not an accepted difference")

acc <- data.frame(kind = "gate", key = gate_key, path = hit$path, table = hit$table,
                  authority = "control: a listed difference", candidate_sha256 = sha(x[[hit$path]][[hit$table]]))
af <- file.path(oc$scratch, "accepted.csv"); utils::write.csv(acc, af, row.names = FALSE)
expect("accepted", check("accepted", oc$records, c2, af), 0L, "ACCEPTED 1")
acc_bad <- acc; acc_bad$candidate_sha256 <- strrep("0", 64L)
af2 <- file.path(oc$scratch, "accepted_wrong.csv"); utils::write.csv(acc_bad, af2, row.names = FALSE)
expect("accepted_wrong_digest", check("accepted_wrong_digest", oc$records, c2, af2), 1L, "digest differs")
expect("accepted_unused", check("accepted_unused", oc$records, oc$candidate, af), 1L, "accepted difference not observed")

if (nzchar(oc$mutated)) {
  # The mutated run's outputs (some workloads) over a copy of the candidate's.
  c4 <- copy_tree(oc$candidate, file.path(oc$scratch, "cand_mutated"))
  m <- list.files(file.path(oc$mutated, "gate"), pattern = "_lean[.]rds$", full.names = TRUE)
  if (!length(m)) stop("--mutated holds no gate/<workload>_lean.rds")
  invisible(file.copy(m, file.path(c4, "gate"), overwrite = TRUE))
  expect("mutated", check("mutated", oc$records, c4), 1L, "not an accepted difference")
}
res <- do.call(rbind, rows)
utils::write.csv(res, oc$out, row.names = FALSE)
cat(if (all(res$result == "OK")) "CONTROLS PASS\n" else "CONTROLS FAIL\n")
quit(save = "no", status = if (all(res$result == "OK")) 0L else 1L)

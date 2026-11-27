# The recorded oracle's checker (Cut 27 decision 7, LDG-3282): compares a
# candidate's outputs with the pin's records without loading the pin, or
# ledgr at all (asserted at the end).
#
#   Rscript oracle_check.R --records=<dir> --manifest=<dir> --candidate=<dir>
#     --out=<csv> [--accepted=<csv>]
#
# Records: as oracle_manifest.R describes, under --records; the manifest
# (oracle_records.csv, oracle_tables.csv) under --manifest. Candidate: the
# same layout with the candidate's outputs, gate/<workload>_lean.rds
# (loop_parity.R --dump-lean) and cut18/cut18_lean_d0.rds and
# cut18_lean_d1.rds (cut18_witness.R --dump).
#
# Fails (exit 1) on:
# - a record the manifest lists that is missing, or whose sha256 differs
#   (corrupt); a file under --records the manifest does not list (extra);
#   a loaded record whose tables disagree with oracle_tables.csv;
# - a candidate output missing for a recorded workload or case;
# - a path, table or case present on one side only;
# - a table or case not identical() to the record, unless --accepted lists
#   it (kind, key, path, table, authority, candidate_sha256): an accepted
#   difference must name its authority (a ledger entry or format/identity
#   change) and the candidate's exact table digest; an accepted row that no
#   comparison uses also fails.
local({
  argv <- commandArgs(TRUE)
  arg <- function(n, d = NULL) { v <- grep(paste0("^--", n, "="), argv, value = TRUE); if (length(v)) sub(paste0("^--", n, "="), "", v[[1L]]) else d }
  assign("ck", list(records = arg("records"), manifest = arg("manifest"), candidate = arg("candidate"),
                    out = arg("out"), accepted = arg("accepted", "")), globalenv())
})
sha <- function(x) digest::digest(x, algo = "sha256")
sha_file <- function(f) digest::digest(file = f, algo = "sha256")
rec <- utils::read.csv(file.path(ck$manifest, "oracle_records.csv"), stringsAsFactors = FALSE)
tab <- utils::read.csv(file.path(ck$manifest, "oracle_tables.csv"), stringsAsFactors = FALSE, na.strings = "NA")
acc <- if (nzchar(ck$accepted)) utils::read.csv(ck$accepted, stringsAsFactors = FALSE) else
  data.frame(kind = character(), key = character(), path = character(), table = character(),
             authority = character(), candidate_sha256 = character())
acc$used <- rep(FALSE, nrow(acc))
out <- list()
note <- function(kind, key, path, table, status, detail = "") {
  out[[length(out) + 1L]] <<- data.frame(kind = kind, key = key, path = path, table = table, status = status,
                                          detail = detail, stringsAsFactors = FALSE)
}

# 1. the records against the manifest
present <- sort(list.files(ck$records, recursive = TRUE), method = "radix")
for (f in setdiff(present, rec$file)) note("record", f, "", "", "FAIL", "extra record file not in the manifest")
ok_rec <- logical(nrow(rec))
for (i in seq_len(nrow(rec))) {
  p <- file.path(ck$records, rec$file[[i]])
  if (!file.exists(p)) { note("record", rec$file[[i]], "", "", "FAIL", "missing record file"); next }
  if (!identical(sha_file(p), rec$sha256[[i]])) { note("record", rec$file[[i]], "", "", "FAIL", "record sha256 differs from the manifest (corrupt)"); next }
  ok_rec[[i]] <- TRUE
}

# 2. each record against its candidate output
accept <- function(kind, key, path, table, cand) {
  j <- which(acc$kind == kind & acc$key == key & acc$path == path & acc$table == table)
  if (length(j) != 1L) return("")
  acc$used[[j]] <<- TRUE
  if (identical(acc$candidate_sha256[[j]], sha(cand))) acc$authority[[j]] else NA_character_
}
compare <- function(kind, key, path, table, a, b) {
  if (identical(a, b)) return(note(kind, key, path, table, "IDENTICAL"))
  auth <- accept(kind, key, path, table, b)
  if (is.na(auth)) note(kind, key, path, table, "FAIL", "accepted difference listed, but the candidate's table digest differs")
  else if (nzchar(auth)) note(kind, key, path, table, "ACCEPTED", auth)
  else note(kind, key, path, table, "FAIL", "different, not an accepted difference")
}
for (i in which(ok_rec)) {
  r <- rec[i, ]
  pin <- readRDS(file.path(ck$records, r$file))
  expect <- tab[tab$kind == r$kind & tab$key == r$key, ]
  if (r$kind == "gate") {
    got <- do.call(rbind, lapply(names(pin), function(p) do.call(rbind, lapply(names(pin[[p]]), function(t)
      data.frame(path = p, table = t, sha256 = sha(pin[[p]][[t]]), stringsAsFactors = FALSE)))))
    if (!identical(paste(got$path, got$table, got$sha256), paste(expect$path, expect$table, expect$sha256))) {
      note("gate", r$key, "", "", "FAIL", "record tables disagree with oracle_tables.csv"); next
    }
    cf <- file.path(ck$candidate, "gate", paste0(r$key, "_lean.rds"))
    if (!file.exists(cf)) { note("gate", r$key, "", "", "FAIL", "candidate output missing"); next }
    cand <- readRDS(cf)
    for (p in union(names(pin), names(cand))) for (t in union(names(pin[[p]]), names(cand[[p]]))) {
      a <- pin[[p]][[t]]; b <- cand[[p]][[t]]
      if (is.null(a) || is.null(b)) note("gate", r$key, p, t, "FAIL", if (is.null(a)) "table only in the candidate" else "table only in the record")
      else compare("gate", r$key, p, t, a, b)
    }
  } else {
    if (!identical(sort(names(pin)), sort(expect$path)) ||
        !identical(vapply(names(pin), function(k) sha(pin[[k]]), ""), stats::setNames(expect$sha256, expect$path)[names(pin)])) {
      note("cut18", r$key, "", "", "FAIL", "record cases disagree with oracle_tables.csv"); next
    }
    for (d in c("d0", "d1")) {
      cf <- file.path(ck$candidate, "cut18", paste0("cut18_lean_", d, ".rds"))
      if (!file.exists(cf)) { note("cut18", d, "", "", "FAIL", "candidate output missing"); next }
      cand <- readRDS(cf)
      for (k in union(names(pin), names(cand))) {
        if (is.null(pin[[k]]) || is.null(cand[[k]])) note("cut18", d, k, "", "FAIL", if (is.null(pin[[k]])) "case only in the candidate" else "case only in the record")
        else compare("cut18", d, k, "", pin[[k]], cand[[k]])
      }
    }
  }
}
for (j in which(!acc$used)) note(acc$kind[[j]], acc$key[[j]], acc$path[[j]], acc$table[[j]], "FAIL", "accepted difference not observed")
res <- do.call(rbind, out)
if ("ledgr" %in% loadedNamespaces()) stop("oracle_check.R loaded ledgr")
utils::write.csv(res, ck$out, row.names = FALSE)
cat(sprintf("%s\n", paste(names(table(res$status)), table(res$status), sep = " ", collapse = ", ")))
bad <- res[res$status == "FAIL", ]
if (nrow(bad)) print(utils::head(bad, 20), row.names = FALSE)
cat(if (nrow(bad)) "ORACLE CHECK FAIL\n" else "ORACLE CHECK PASS\n")
quit(save = "no", status = if (nrow(bad)) 1L else 0L)

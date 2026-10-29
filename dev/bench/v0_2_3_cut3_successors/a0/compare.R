# A0 successor comparator (LDG-3161; ws2_rng_design.md Section 8.1 and
# maintainer decision (17)).
#
# Reads the unchanged original A0 records and a successor record field by
# field. For every file it builds the expected successor cells from the
# original by applying only the frozen change predicates, then requires the
# successor to equal that expectation exactly:
#
#   D17  excluded_fields.csv gains exactly the row (wf_folds, selected_at_utc)
#        and nothing else; walk_forward/walk_forward/wf_folds.csv loses
#        exactly that column. This is the test that decision (17) adds one
#        field to the wall-clock exclusions and no other.
#   A1   sweep_attrs.csv, all 14 sweep dirs: only the seed_contract row,
#        ledgr_seed_v1 -> ledgr_seed_v2.
#   A2   sweep.csv, all 14 sweep dirs: only the seed_contract element of
#        provenance, v1 -> v2.
#   A3   runs.csv, the 11 seeded run dirs: config_json gains exactly
#        engine.pulse_seed_rule = 2 and config_hash equals config_hash() of
#        the new JSON; the two unseeded run dirs are identical.
#   A4   dense_risk_features run/ and sweep_w1/: equal the pulse-rule model
#        (model.R, the base tree with the independent v2 reference), with the
#        A1-A3 markers applied; changed-row counts equal the note's.
#   A5   dense_risk_features sweep_w2/: every cell on which the original w2
#        agreed with the original w1 equals the successor w1 cell; every
#        other cell follows A1/A2.
#   identical  every other file, byte for byte.
#   manifest   both manifests match their files on disk; the file list is
#        unchanged.
#
# Usage: Rscript compare.R [--original=<dir>] [--successor=<dir>] [--model=<dir>]
#                          [--result=<csv>] [--workloads=<id,id>] [--pkg=<root>]
#   --workloads restricts the comparison to some workloads (guts.R only).
# Exit status 0 when every predicate holds, 1 otherwise.

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  source(file.path(here, "..", "lib.R"))
})
suppressMessages(pkgload::load_all(sr_arg("pkg", sr_root), quiet = TRUE))
ns <- asNamespace("ledgr")
sr_ref_selftest()

orig_dir <- sr_arg("original", file.path(sr_root, "dev", "bench", "v0_2_3_output_freeze", "records"))
succ_dir <- sr_arg("successor", file.path(sr_dir, "a0", "records"))
model_dir <- sr_arg("model", file.path(sr_dir, "a0", "model"))
result_file <- sr_arg("result", NULL)
workloads <- sr_arg("workloads")
workloads <- if (is.null(workloads)) NULL else strsplit(workloads, ",", fixed = TRUE)[[1L]]

rows <- list()
add <- function(file, predicate, ok, detail = "") {
  rows[[length(rows) + 1L]] <<- data.frame(file = file, predicate = predicate,
    status = if (isTRUE(ok)) "PASS" else "FAIL", detail = detail, stringsAsFactors = FALSE)
}

# A4 changed-row counts measured on the model and frozen in Section 8.1.
a4_expected <- c("run/ledger_events.csv" = 5L, "run/fills.csv" = 5L, "run/equity_curve.csv" = 6L,
  "run/trades.csv" = 2L, "run/metrics.csv" = 7L, "sweep_w1/memory_events.csv" = 6L,
  "sweep_w1/memory_fills.csv" = 5L, "sweep_w1/memory_equity.csv" = 6L, "sweep_w1/sweep.csv" = 1L,
  "sweep_w1/sweep_returns.csv" = 6L, "sweep_w1/sweep_trades.csv" = 2L)
d17_row <- c(table = '"wf_folds"', column = '"selected_at_utc"')

# ---------------------------------------------------------------------------
# Manifests
# ---------------------------------------------------------------------------

manifest_ok <- function(d) {
  m <- utils::read.csv(file.path(d, "manifest.csv"), colClasses = "character")
  sha <- vapply(file.path(d, m$file), function(f) digest::digest(file = f, algo = "sha256"), character(1))
  bad <- m$file[sha != m$sha256]
  list(m = m, bad = bad)
}
mo <- manifest_ok(orig_dir); ms <- manifest_ok(succ_dir)
in_scope <- function(f) is.null(workloads) || f == "excluded_fields.csv" || sub("/.*", "", f) %in% workloads
orig_files <- Filter(in_scope, mo$m$file); succ_files <- Filter(in_scope, ms$m$file)
add("manifest.csv", "manifest", length(mo$bad) == 0L && length(ms$bad) == 0L &&
  identical(sort(orig_files), sort(succ_files)),
  sprintf("original files off-manifest: %d; successor off-manifest: %d; missing: %s; new: %s",
    length(mo$bad), length(ms$bad), paste(setdiff(orig_files, succ_files), collapse = ","),
    paste(setdiff(succ_files, orig_files), collapse = ",")))
if (file.exists(file.path(model_dir, "manifest.csv"))) {
  mm <- manifest_ok(model_dir)
  add("model/manifest.csv", "manifest", length(mm$bad) == 0L, sprintf("model files off-manifest: %d", length(mm$bad)))
}

# ---------------------------------------------------------------------------
# Transforms: the expected successor cells from a base table
# ---------------------------------------------------------------------------

v1 <- "13:ledgr_seed_v1"; v2 <- "13:ledgr_seed_v2"
a1 <- function(t) { # sweep_attrs
  at <- which(t$cells[, "attribute"] == '"seed_contract"')
  if (length(at) != 1L || !grepl(v1, t$cells[at, "value"], fixed = TRUE)) stop("A1: no single v1 seed_contract row")
  t$cells[at, "value"] <- sub(v1, v2, t$cells[at, "value"], fixed = TRUE)
  t
}
a2 <- function(t) { # sweep provenance
  p <- t$cells[, "provenance"]
  pat <- "@13:seed_contractA9:character[1](13:ledgr_seed_v1)"
  hits <- lengths(regmatches(p, gregexpr(pat, p, fixed = TRUE)))
  if (any(hits != 1L) || any(lengths(regmatches(p, gregexpr(v1, p, fixed = TRUE))) != 1L)) {
    stop("A2: provenance does not hold exactly one v1 seed_contract element per row")
  }
  t$cells[, "provenance"] <- sub(pat, sub(v1, v2, pat, fixed = TRUE), p, fixed = TRUE)
  t
}
a0_unescape <- function(x) {
  x <- gsub("\\\\", "\001", x, fixed = TRUE)
  x <- gsub("\\n", "\n", x, fixed = TRUE); x <- gsub("\\r", "\r", x, fixed = TRUE)
  gsub("\001", "\\", x, fixed = TRUE)
}
a3_check <- function(o, s) { # runs.csv, seeded: returns NULL when the predicate holds
  if (nrow(o$cells) != nrow(s$cells) || !identical(o$header, s$header)) return("shape or header changed")
  other <- setdiff(colnames(o$cells), c("config_json", "config_hash"))
  if (!identical(o$cells[, other, drop = FALSE], s$cells[, other, drop = FALSE])) return("a column other than config_json/config_hash changed")
  for (i in seq_len(nrow(o$cells))) {
    oj <- a0_unescape(sr_value(o$cells[i, "config_json"])); sj <- a0_unescape(sr_value(s$cells[i, "config_json"]))
    op <- jsonlite::fromJSON(oj, simplifyVector = FALSE); sp <- jsonlite::fromJSON(sj, simplifyVector = FALSE)
    if (!is.null(op$engine$pulse_seed_rule)) return(sprintf("row %d: original already has pulse_seed_rule", i))
    if (!identical(sp$engine$pulse_seed_rule, 2L)) return(sprintf("row %d: engine.pulse_seed_rule is not 2", i))
    sp$engine$pulse_seed_rule <- NULL
    if (!identical(op, sp)) return(sprintf("row %d: config_json differs beyond engine.pulse_seed_rule", i))
    if (is.null(op$engine$seed)) return(sprintf("row %d: unseeded configuration in a seeded dir", i))
    oh <- sr_value(o$cells[i, "config_hash"]); sh <- sr_value(s$cells[i, "config_hash"])
    if (!identical(ns$config_hash(ns$ledgr_json_read_config(oj)), oh)) return(sprintf("row %d: original hash is not config_hash() of its JSON", i))
    if (!identical(ns$config_hash(ns$ledgr_json_read_config(sj)), sh)) return(sprintf("row %d: successor hash is not config_hash() of its JSON", i))
    if (identical(oh, sh)) return(sprintf("row %d: config_hash unchanged", i))
  }
  NULL
}
same_table <- function(e, s) identical(e$header, s$header) && identical(e$cells, s$cells)
changed_rows <- function(base, s) { # successor rows absent from the (marker-adjusted) base
  key <- function(t) apply(t$cells, 1L, paste, collapse = ",")
  if (nrow(s$cells) == 0L) return(0L)
  sum(!(key(s) %in% key(base)))
}

# ---------------------------------------------------------------------------
# Per-file predicates
# ---------------------------------------------------------------------------

files <- setdiff(intersect(orig_files, succ_files), "manifest.csv")
seeded_paths <- c("run", "run_interrupted", "run_resumed", "walk_forward")
a1_n <- 0L; a2_n <- 0L; a3_n <- 0L; unseeded_runs <- 0L
for (f in files) {
  parts <- strsplit(f, "/", fixed = TRUE)[[1L]]
  o <- sr_read_csv(file.path(orig_dir, f)); s <- sr_read_csv(file.path(succ_dir, f))
  table <- sub("[.]csv$", "", parts[[length(parts)]])
  if (f == "excluded_fields.csv") {
    ok <- identical(o$header, s$header) && nrow(s$cells) == nrow(o$cells) + 1L
    orow <- apply(o$cells[, c("table", "column"), drop = FALSE], 1L, paste, collapse = "|")
    srow <- apply(s$cells[, c("table", "column"), drop = FALSE], 1L, paste, collapse = "|")
    added <- setdiff(srow, orow); kept <- all(orow %in% srow)
    orig_kept <- all(apply(o$cells, 1L, paste, collapse = "|") %in% apply(s$cells, 1L, paste, collapse = "|"))
    ok <- ok && kept && orig_kept && identical(added, paste(d17_row, collapse = "|")) && !(paste(d17_row, collapse = "|") %in% orow)
    add(f, "D17", ok, sprintf("rows %d -> %d; added: %s; original rows kept unchanged: %s", nrow(o$cells), nrow(s$cells),
      paste(added, collapse = " "), orig_kept))
    next
  }
  if (length(parts) != 3L) { add(f, "identical", identical(o$lines, s$lines)); next }
  w <- parts[[1L]]; p <- parts[[2L]]
  if (w == "walk_forward" && p == "walk_forward" && table == "wf_folds") {
    col <- which(colnames(o$cells) == "selected_at_utc")
    e <- o; e$header <- o$header[-col]; e$cells <- o$cells[, -col, drop = FALSE]
    add(f, "D17", length(col) == 1L && same_table(e, s), sprintf("original selected_at_utc values: %s; dropped column only",
      paste(unique(sr_value(o$cells[, col])), collapse = ",")))
    next
  }
  res <- tryCatch({
    if (w == "dense_risk_features" && p == "sweep_w2") {
      # A5: cells where the original w2 agreed with the original w1 follow the successor w1.
      f1 <- file.path(w, "sweep_w1", parts[[3L]])
      o1 <- sr_read_csv(file.path(orig_dir, f1)); s1 <- sr_read_csv(file.path(succ_dir, f1))
      e <- o
      if (table == "sweep_attrs") { e <- a1(e); a1_n <- a1_n + 1L }
      if (table == "sweep") { e <- a2(e); a2_n <- a2_n + 1L }
      if (!identical(dim(o$cells), dim(o1$cells)) || !identical(dim(s1$cells), dim(o1$cells))) {
        list(pred = "A5", ok = same_table(s, s1), detail = "shapes differ; successor w2 must equal successor w1")
      } else {
        agree <- o$cells == o1$cells
        e$cells[agree] <- s1$cells[agree]
        moved <- sum(agree & o1$cells != s1$cells)
        list(pred = "A5", ok = same_table(e, s), detail = sprintf("%d cells follow the successor sweep_w1 change; rows changed %d",
          moved, changed_rows(if (table == "sweep") a2(o) else if (table == "sweep_attrs") a1(o) else o, s)))
      }
    } else if (w == "dense_risk_features" && p %in% c("run", "sweep_w1")) {
      # A4: equal the pulse-rule model with the A1-A3 markers applied.
      m <- sr_read_csv(file.path(model_dir, f))
      key <- paste(p, parts[[3L]], sep = "/")
      if (table == "runs") {
        msg <- a3_check(m, s); a3_n <- a3_n + 1L
        list(pred = "A4+A3", ok = is.null(msg) && same_table(m, o), detail = msg %||% "model runs.csv equals the original; A3 holds")
      } else {
        e <- if (table == "sweep_attrs") a1(m) else if (table == "sweep") a2(m) else m
        if (table == "sweep_attrs") a1_n <- a1_n + 1L
        if (table == "sweep") a2_n <- a2_n + 1L
        base <- if (table == "sweep_attrs") a1(o) else if (table == "sweep") a2(o) else o
        n <- changed_rows(base, s)
        want <- if (key %in% names(a4_expected)) a4_expected[[key]] else 0L
        changed <- if (nrow(s$cells)) s$cells[!(apply(s$cells, 1L, paste, collapse = ",") %in% apply(base$cells, 1L, paste, collapse = ",")), , drop = FALSE] else s$cells
        only_tight <- all(apply(changed, 1L, function(r) any(grepl("tight", r, fixed = TRUE)) && !any(grepl("loose", r, fixed = TRUE))))
        list(pred = if (table %in% c("sweep_attrs", "sweep")) paste0("A4+", if (table == "sweep") "A2" else "A1") else "A4",
          ok = same_table(e, s) && n == want && only_tight,
          detail = sprintf("equals model: %s; rows changed %d (note: %d); changed rows all candidate tight: %s",
            same_table(e, s), n, want, only_tight))
      }
    } else if (table == "sweep_attrs") {
      a1_n <- a1_n + 1L
      list(pred = "A1", ok = same_table(a1(o), s), detail = "seed_contract row v1 -> v2 only")
    } else if (table == "sweep") {
      a2_n <- a2_n + 1L
      list(pred = "A2", ok = same_table(a2(o), s), detail = "provenance seed_contract element v1 -> v2 only")
    } else if (table == "runs" && p %in% seeded_paths) {
      a3_n <- a3_n + 1L
      msg <- a3_check(o, s)
      list(pred = "A3", ok = is.null(msg), detail = msg %||% "engine gains pulse_seed_rule = 2; hash = config_hash(new JSON)")
    } else if (table == "runs") {
      unseeded_runs <- unseeded_runs + 1L
      list(pred = "A3 unseeded identical", ok = identical(o$lines, s$lines), detail = "")
    } else {
      list(pred = "identical", ok = identical(o$lines, s$lines), detail = "")
    }
  }, error = function(e) list(pred = "ERROR", ok = FALSE, detail = conditionMessage(e)))
  add(f, res$pred, res$ok, res$detail)
}

# Coverage of the predicates over the full record (skipped for a partial run).
if (is.null(workloads)) {
  add("<coverage>", "A1", a1_n == 14L, sprintf("sweep_attrs files checked under A1: %d of 14", a1_n))
  add("<coverage>", "A2", a2_n == 14L, sprintf("sweep files checked under A2: %d of 14", a2_n))
  add("<coverage>", "A3", a3_n == 11L && unseeded_runs == 2L, sprintf("seeded run dirs %d of 11; unseeded identical dirs %d of 2", a3_n, unseeded_runs))
}

rep <- do.call(rbind, rows)
if (!is.null(result_file)) {
  utils::write.csv(rep, result_file, row.names = FALSE)
}
cat(sprintf("a0 successor comparison: %d files, original %s, successor %s\n", length(files), orig_dir, succ_dir))
print(table(rep$predicate, rep$status))
nonid <- rep[rep$predicate != "identical" | rep$status != "PASS", ]
cat("\nChanged or failing files:\n")
for (i in seq_len(nrow(nonid))) cat(sprintf("  %-4s %-14s %s  %s\n", nonid$status[[i]], nonid$predicate[[i]], nonid$file[[i]], nonid$detail[[i]]))
fails <- sum(rep$status == "FAIL")
cat(sprintf("\na0 successor comparison: %s (%d checks, %d fail)\n", if (fails) "FAIL" else "PASS", nrow(rep), fails))
quit(status = if (fails) 1L else 0L)

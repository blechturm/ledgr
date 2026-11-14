# Cut 17 (LDG-3232, LDG-3233): runs the differential oracle and its
# failure demonstrations.
#
#   Rscript dev/bench/v0_2_3_helper/oracle_check.R --pin-lib=<lib> --pin-source=<commit>
#     --cand-lib=<lib> --cand-source=<commit> --out=<dir> [--wrong-source=<commit>]
#
# 1. pin arm and candidate arm; the comparison must pass (exit 0).
# 2. each mutation of oracle_mutations.R on the candidate arm: the comparison
#    must exit 1 and report the mutation's signal on its named case.
# 3. an omitted case and a missing comparison surface: exit 2.
# 4. arm controls: an arm claiming another library, and an arm whose loaded
#    functions differ from the claimed source (--wrong-source, a commit whose
#    helper files differ), must refuse (exit 3).
# Writes <out>/oracle_check.csv and the clean comparison's diffs; exits 1 if
# any check does not behave as required.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
rscript <- file.path(R.home("bin"), "Rscript.exe")
out <- opt("out"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
pin_lib <- opt("pin-lib"); pin_src <- opt("pin-source"); cand_lib <- opt("cand-lib"); cand_src <- opt("cand-source")
wrong_src <- opt("wrong-source", "")
run <- function(script, ...) {
  log <- tempfile(fileext = ".log")
  status <- system2(rscript, c(file.path(here, script), ...), stdout = log, stderr = log)
  list(status = status, log = readLines(log, warn = FALSE))
}
arm <- function(lib, src, file, ...) run("oracle_run.R", paste0("--lib=", lib), paste0("--source=", src), paste0("--out=", file), ...)
compare <- function(cand_file, ...) run("oracle_compare.R", paste0("--pin=", file.path(out, "pin.rds")), paste0("--candidate=", cand_file), ...)
rows <- list()
record <- function(check, expected_status, got, want_text = "", required = TRUE) {
  ok <- isTRUE(required) && identical(as.integer(got$status), as.integer(expected_status)) &&
    (!nzchar(want_text) || any(grepl(want_text, got$log, fixed = TRUE)))
  line <- grep("^oracle:|REFUSED|^  [a-z_]+:", got$log, value = TRUE)
  rows[[length(rows) + 1L]] <<- data.frame(check = check, expected_exit = expected_status, exit = got$status, expected_text = want_text,
    ok = ok, output = substr(paste(trimws(line), collapse = " | "), 1L, 300L), stringsAsFactors = FALSE)
  cat(sprintf("%-34s exit %s (want %s) %s\n", check, got$status, expected_status, if (ok) "ok" else "WRONG"))
}

p <- arm(pin_lib, pin_src, file.path(out, "pin.rds"))
if (p$status != 0L) { cat(p$log, sep = "\n"); stop("pin arm failed", call. = FALSE) }
c0 <- arm(cand_lib, cand_src, file.path(out, "candidate.rds"))
if (c0$status != 0L) { cat(c0$log, sep = "\n"); stop("candidate arm failed", call. = FALSE) }
record("pin_vs_candidate", 0L, compare(file.path(out, "candidate.rds"), paste0("--out=", file.path(out, "diffs_clean.csv"))))

sys.source(file.path(here, "oracle_mutations.R"), envir = globalenv())
for (i in seq_len(nrow(oracle_mutation_table))) {
  m <- oracle_mutation_table[i, ]
  f <- file.path(out, paste0("mut_", m$id, ".rds"))
  a <- arm(cand_lib, cand_src, f, paste0("--mutation=", m$id))
  if (a$status != 0L) { record(paste0("mutation_", m$id), 1L, a, "arm failed"); next }
  dcsv <- file.path(out, paste0("diffs_mut_", m$id, ".csv"))
  got <- compare(f, paste0("--out=", dcsv))
  d <- if (file.exists(dcsv)) utils::read.csv(dcsv, stringsAsFactors = FALSE) else data.frame(case = character(), signal = character())
  hit <- any(d$signal == m$signal & d$case == m$case)
  got$log <- c(got$log, if (hit) sprintf("signal %s on %s", m$signal, m$case) else sprintf("MISSING signal %s on %s", m$signal, m$case))
  # the named signal on the named case is required, not only a difference
  record(paste0("mutation_", m$id), 1L, got, sprintf("signal %s on %s", m$signal, m$case), required = hit)
}
# Comparator controls on synthetic records (the package emits no parent
# condition or signal payload on these paths): the two arms' records of one
# refusal case differ only in a parent's payload field, then in a warning's
# call and payload field. Each must be reported (exit 1, its own signal).
synthetic <- function(name, edit_pin, edit_cand, signal) {
  pr <- readRDS(file.path(out, "pin.rds")); cr <- readRDS(file.path(out, "candidate.rds"))
  pr$results <- edit_pin(pr$results); cr$results <- edit_cand(cr$results)
  pf <- file.path(out, paste0(name, "_pin.rds")); cf <- file.path(out, paste0(name, "_cand.rds"))
  saveRDS(pr, pf); saveRDS(cr, cf)
  dcsv <- file.path(out, paste0("diffs_", name, ".csv"))
  got <- run("oracle_compare.R", paste0("--pin=", pf), paste0("--candidate=", cf), paste0("--out=", dcsv))
  d <- if (file.exists(dcsv)) utils::read.csv(dcsv, stringsAsFactors = FALSE) else data.frame(signal = character())
  record(name, 1L, got, required = any(d$signal == signal))
}
with_parent <- function(id) function(res) {
  res$reb_skip_held_unmarked$error$parent <- list(class = c("rlang_error", "error", "condition"), message = "inner",
    call = NULL, parent = NULL, fields = list(instrument_id = id), field_names = c("message", "instrument_id"))
  res
}
with_warning <- function(call, id) function(res) {
  res$reb_subset_nonlexical$signals <- list(list(type = "warning", class = c("simpleWarning", "warning", "condition"),
    message = "w", call = call, parent = NULL, fields = list(instrument_id = id), field_names = c("message", "call", "instrument_id")))
  res
}
synthetic("control_parent_payload", with_parent("AAA"), with_parent("BBB"), "parent")
synthetic("control_warning_call", with_warning(quote(alpha()), "AAA"), with_warning(quote(beta()), "AAA"), "warning")
synthetic("control_warning_field", with_warning(quote(alpha()), "AAA"), with_warning(quote(alpha()), "BBB"), "warning")
dropped <- file.path(out, "drop_case.rds")
invisible(arm(cand_lib, cand_src, dropped, "--drop-case=reb_subset_nonlexical"))
record("omitted_case", 2L, compare(dropped), "missing_case")
record("missing_surface", 2L, compare(file.path(out, "candidate.rds"), "--demo-drop-surface=signals"), "missing_surface")
record("control_claimed_library", 3L, arm(pin_lib, cand_src, file.path(out, "ctl1.rds"), paste0("--expect-lib=", cand_lib)), "CONTROL REFUSED")
if (nzchar(wrong_src)) record("control_wrong_source", 3L, arm(cand_lib, wrong_src, file.path(out, "ctl2.rds")), "ARM REFUSED")
# an arm whose ledgr_target_size() resolves ledgr_target_named_amount() from
# another build (the pin's source) must refuse
record("control_mixed_resolution", 3L, arm(cand_lib, cand_src, file.path(out, "ctl3.rds"), paste0("--mixed-from=", pin_src)),
       "not enclosed by the arm's namespace")
res <- do.call(rbind, rows)
utils::write.csv(res, file.path(out, "oracle_check.csv"), row.names = FALSE)
cat(sprintf("%d checks, %d as required\n", nrow(res), sum(res$ok)))
if (!all(res$ok)) quit(status = 1L)

# R-floor stage 2b checker (spike protocol section 6).
#
#   Rscript dev/spikes/r_floor/stage2b/check.R --lib=<pin library> --scratch=<empty dir> [--evidence=<dir name>]
#
# --evidence names the recorded folder beside this file (default evidence,
# the 5c3f9c4a record; evidence_cut18 is Cut 18's rerun, LDG-3236).
# 4. (Cut 18, cut review 18 R6) The clocked arm computes what the plain arm
#    computes: parity.csv's clocked_equals_plain must hold, and a rerun with
#    a corrupted clocked record must fail it; the clock anchors match exactly
#    once (a missing anchor refuses), and crosswalk.csv names exactly the
#    clocked cells (a misassigned cell refuses).
#
# 1. Reruns run.R with one round into <scratch>/rerun and diffs its
#    parity.csv and contract.csv against the recorded ones, and the timing
#    tables' rows (shape, configuration) against the recorded rows.
# 2. Gutted path: the full reference with the affordability stop forced
#    (gut = "reconciliation") must fail economic parity on both workloads.
# 3. Package scope: the commits that touch stage2b change nothing outside
#    dev/spikes/r_floor, and the package directories carry no uncommitted
#    content change (line endings ignored).

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
scratch <- opt("scratch"); dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
recorded <- file.path(here, opt("evidence", "evidence"))
rscript <- file.path(R.home("bin"), "Rscript.exe")
fail <- character()

rerun <- file.path(scratch, "rerun")
st <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", lib), paste0("--out=", rerun), "--rounds=1"), stdout = FALSE, stderr = FALSE)
if (st != 0L) fail <- c(fail, "rerun exited nonzero")
for (f in c("parity.csv", "contract.csv")) {
  a <- utils::read.csv(file.path(recorded, f), stringsAsFactors = FALSE); b <- utils::read.csv(file.path(rerun, f), stringsAsFactors = FALSE)
  if (!identical(a, b)) fail <- c(fail, paste(f, "differs from the recorded one"))
}
for (f in c("summary.csv", "attribution.csv")) {
  key <- if (f == "summary.csv") c("shape", "config") else c("shape", "part")
  a <- utils::read.csv(file.path(recorded, f), stringsAsFactors = FALSE)[key]; b <- utils::read.csv(file.path(rerun, f), stringsAsFactors = FALSE)[key]
  if (!identical(a, b)) fail <- c(fail, paste(f, "rows differ from the recorded rows"))
}

gut <- file.path(scratch, "gut")
for (s in c("10x7200", "slice2_10x7200")) {
  dir.create(gut, showWarnings = FALSE)
  file.copy(file.path(rerun, sprintf("records_%s_lean.rds", s)), gut, overwrite = TRUE)
  row <- tempfile(fileext = ".csv")
  st <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", lib), "--mode=arm", "--arm=ref", paste0("--shape=", s),
                           paste0("--row=", row), paste0("--records=", file.path(gut, sprintf("records_%s_ref.rds", s))),
                           "--gut=reconciliation"), stdout = FALSE, stderr = FALSE)
  a <- readRDS(file.path(gut, sprintf("records_%s_ref.rds", s))); b <- readRDS(file.path(gut, sprintf("records_%s_lean.rds", s)))
  economic <- identical(unname(a$fills$qty), unname(b$fills$qty)) && identical(a$equity, b$equity[names(a$equity)]) && identical(a$status, b$status)
  cat(sprintf("gutted %s: status %s, fills %d (lean %d), economic parity %s\n", s, a$status, length(a$fills$qty), length(b$fills$qty), economic))
  if (st != 0L || economic) fail <- c(fail, paste("gutted path did not fail parity on", s))
}

## 4. the clocked arm (Cut 18, R6)
p <- utils::read.csv(file.path(rerun, "parity.csv"))
if (!is.null(p$clocked_equals_plain) && !all(p$clocked_equals_plain)) fail <- c(fail, "the clocked arm's records differ from the plain arm's")
corrupt <- file.path(scratch, "corrupt")
st <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", lib), paste0("--out=", corrupt), "--rounds=1", "--shapes=10x7200",
                         "--corrupt=1"), stdout = FALSE, stderr = FALSE)
pc <- utils::read.csv(file.path(corrupt, "parity.csv"))
cat(sprintf("corrupted clocked record: exit %d, clocked_equals_plain %s\n", st, paste(pc$clocked_equals_plain, collapse = ",")))
if (st == 0L || isTRUE(all(pc$clocked_equals_plain))) fail <- c(fail, "a corrupted clocked record was not refused")
source(file.path(here, "lean_clocks.R"))
loop_text <- readLines(file.path(repo, "dev/lean_core/loop.R"), warn = FALSE)
if (inherits(tryCatch(spk_loop_source(repo, TRUE, loop_text), error = function(e) e), "error")) fail <- c(fail, "the clock anchors do not apply")
missing <- tryCatch(spk_loop_source(repo, TRUE, sub("lean_sizing_evidence(sizing_evidence, targets, ids, pos, close)",
                                                    "lean_sizing_evidence(sizing_evidence, targets, ids, pos, mark = close)",
                                                    loop_text, fixed = TRUE)), error = function(e) e)
cat("missing anchor:", if (inherits(missing, "error")) conditionMessage(missing) else "NOT refused", "\n")
if (!inherits(missing, "error")) fail <- c(fail, "a missing clock anchor was not refused")
cw <- utils::read.csv(file.path(here, "crosswalk.csv"), stringsAsFactors = FALSE)
cw_ok <- function(cells) setequal(cells, spk_cells) && !anyDuplicated(cells)
if (!cw_ok(cw$cell)) fail <- c(fail, "crosswalk.csv does not name exactly the clocked cells")
misassigned <- cw$cell; misassigned[misassigned == "p2_risk"] <- "p2_riskplan"
cat("misassigned crosswalk cell refused:", !cw_ok(misassigned), "\n")
if (cw_ok(misassigned)) fail <- c(fail, "a misassigned crosswalk cell was not refused")

git <- function(...) system2("git", c("-C", repo, ...), stdout = TRUE)
commits <- git("log", "--format=%H", "--", "dev/spikes/r_floor/stage2b")
outside <- unique(unlist(lapply(commits, function(h) {
  files <- git("show", "--name-only", "--format=", h)
  files[nzchar(files) & !startsWith(files, "dev/spikes/r_floor/")]
})))
if (length(outside)) fail <- c(fail, paste("stage 2b commits touch:", paste(outside, collapse = ", ")))
dirty <- suppressWarnings(git("diff", "--ignore-cr-at-eol", "--name-only", "--", "R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design"))
if (length(dirty)) fail <- c(fail, paste("package scope changed:", paste(dirty, collapse = ", ")))

if (length(fail)) { cat("CHECK FAILED\n", paste0("- ", fail, "\n"), sep = ""); quit(status = 1L) }
cat("CHECK PASSED\n")

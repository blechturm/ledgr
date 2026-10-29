# Shared timing harness (LDG-3155): the paired base/candidate runner.
#
# Runs one per-cut protocol (see protocol.R for the folder layout) against
# two arms installed from pinned commits. Every slot is one fresh R process
# (measure.R); within each cell the arms run back to back, base first in odd
# pairs and candidate first in even pairs. Nothing is retried.
#
# Launch it from one PowerShell call that pins the affinity first, so every
# child inherits it (a bare `& Rscript` does not resolve in PowerShell here;
# use the full path):
#
#   [System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF; `
#   & "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/timing/runner.R `
#     --protocol=<protocol folder> --base=<commit> --candidate=<commit> --label=<name>
#
# Options:
#   --out=<dir>            label directory (default dev/bench/timing/records/<protocol id>/<label>)
#   --disposition=<text>   required for a second or later attempt under one label:
#                          the maintainer's recorded disposition of the earlier attempt
#   --host-policy=record   record host problems without refusing or invalidating
#                          (smoke and demonstrations only; the checker refuses the record)
#   --test-kill-slot=<n>   interruption demonstration: slot n's process kills itself
#
# Host rule: before provisioning and again before the window, the runner
# refuses to start unless the power plan is High performance, its own
# affinity is 0xFFFF and no foreign R process runs; a refusal writes no
# attempt, because nothing was measured. Once the window starts, every attempt
# is persisted under <label>/attempt-<n>/: session.csv, plan.csv (every slot,
# written before the first one runs), raw.csv, host.csv and the protocol
# copy. A host problem before a slot or inside a measured process, a failed
# process or an interruption stops the window: the attempt is marked invalid
# and every unrun slot is written to raw.csv as not_run.

here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])),
  winslash = "/")
source(file.path(here, "host.R"))
source(file.path(here, "protocol.R"))
opt <- timing_args()
refuse <- function(...) {
  message("runner.R refused: ", ...)
  quit(save = "no", status = 2L)
}
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
git <- function(...) {
  out <- suppressWarnings(system2("git", c("-C", shQuote(repo), ...), stdout = TRUE, stderr = TRUE))
  if (!is.null(attr(out, "status"))) stop("git ", paste(c(...), collapse = " "), " failed: ", paste(out, collapse = " "))
  out
}
utc <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

# ---------------------------------------------------------------------------
# Arguments, protocol and attempt number
# ---------------------------------------------------------------------------

for (name in c("protocol", "base", "candidate", "label")) {
  if (!is.character(opt(name))) refuse("--", name, "=<value> is required")
}
policy <- opt("host-policy", "enforce")
if (!policy %in% c("enforce", "record")) refuse("--host-policy must be enforce or record")
kill_slot <- suppressWarnings(as.integer(opt("test-kill-slot", NA)))
protocol <- timing_read_protocol(opt("protocol"))
if (length(protocol$problems)) refuse("invalid protocol: ", paste(protocol$problems, collapse = "; "))

shas <- c(base = git("rev-parse", "--verify", paste0(opt("base"), "^{commit}")),
  candidate = git("rev-parse", "--verify", paste0(opt("candidate"), "^{commit}")))
mode <- if (identical(shas[["base"]], shas[["candidate"]])) "aa" else "gate"

label_dir <- opt("out", file.path(here, "records", protocol$id, opt("label")))
previous <- list.files(label_dir, pattern = "^attempt-[0-9]+$")
disposition <- opt("disposition", "")
if (length(previous) && (!is.character(disposition) || !nzchar(trimws(disposition)))) {
  refuse(sprintf("%s already holds %d attempt(s); another attempt needs --disposition=<the maintainer's disposition>",
    label_dir, length(previous)))
}
attempt_dir <- file.path(label_dir, sprintf("attempt-%d", length(previous) + 1L))

# ---------------------------------------------------------------------------
# Host check, then arms
# ---------------------------------------------------------------------------

check_root <- function(when) {
  probe <- timing_host_probe(here)
  problems <- timing_root_problems(probe, Sys.getpid())
  if (length(problems) && policy == "enforce") {
    refuse(when, ": ", paste(sprintf("%s (%s)", names(problems), problems), collapse = "; "))
  }
  probe
}
check_root("host check before provisioning")

install_arm <- function(arm, sha) {
  dir <- file.path(tempdir(), paste0("arm_", arm))
  dir.create(file.path(dir, "lib"), recursive = TRUE)
  git("archive", "--format=zip", "-o", shQuote(file.path(dir, "tree.zip")), sha)
  utils::unzip(file.path(dir, "tree.zip"), exdir = file.path(dir, "src"))
  log <- file.path(dir, "install.log")
  status <- system2(file.path(R.home("bin"), "R"), c("CMD", "INSTALL", "--no-docs", "--no-html",
    paste0("--library=", shQuote(file.path(dir, "lib"))), shQuote(file.path(dir, "src"))), stdout = log, stderr = log)
  if (!identical(as.integer(status), 0L)) refuse(sprintf("R CMD INSTALL failed for the %s arm; see %s", arm, log))
  writeLines(sha, file.path(dir, "lib", "timing_arm.txt"))
  normalizePath(file.path(dir, "lib"), winslash = "/")
}
libs <- c(base = "", candidate = "")
for (arm in timing_arms) {
  message(utc(), " installing ", arm, " ", shas[[arm]])
  libs[[arm]] <- install_arm(arm, shas[[arm]])
}
probe <- check_root("host check before the window")

# ---------------------------------------------------------------------------
# The attempt record
# ---------------------------------------------------------------------------

dir.create(file.path(attempt_dir, "protocol"), recursive = TRUE)
file.copy(file.path(protocol$dir, timing_protocol_files), file.path(attempt_dir, "protocol"))
root <- timing_parse_chain(timing_chain(probe$procs, Sys.getpid()))[1L, ]
imports <- trimws(sub("\\(.*", "", strsplit(utils::packageDescription("ledgr", lib.loc = libs[["base"]])$Imports,
  ",", fixed = TRUE)[[1L]]))
product <- function(sha) paste(git("rev-parse", paste0(sha, ":", c("R", "src", "DESCRIPTION", "NAMESPACE"))), collapse = ";")
session <- list(
  protocol = protocol$id, label = basename(label_dir), attempt = as.character(length(previous) + 1L), mode = mode,
  host_policy = policy, test_hook = if (is.na(kill_slot)) "none" else sprintf("kill slot %d", kill_slot),
  disposition = if (nzchar(disposition)) disposition else "none",
  status = "running", status_reason = "", started_utc = utc(), finished_utc = "",
  harness_commit = git("rev-parse", "HEAD")[[1L]],
  harness_clean = as.character(!length(git("status", "--porcelain", "--",
    shQuote(file.path(here, c("host.ps1", "host.R", "protocol.R", "measure.R", "runner.R", "check.R"))),
    shQuote(file.path(protocol$dir, timing_protocol_files))))),
  base_commit = shas[["base"]], base_product = product(shas[["base"]]), base_lib = libs[["base"]],
  candidate_commit = shas[["candidate"]], candidate_product = product(shas[["candidate"]]),
  candidate_lib = libs[["candidate"]],
  root_id = root$id, root_affinity = sprintf("%.0f", root$affinity), plan_guid = probe$plan_guid,
  cpu = probe$cpu_name, logical_cores = as.character(parallel::detectCores()), R_version = R.version.string,
  os = paste(Sys.info()[c("sysname", "release", "version")], collapse = " "),
  dependencies = paste(sprintf("%s %s", imports, vapply(imports, function(p) as.character(utils::packageVersion(p)), "")),
    collapse = "; ")
)
session_path <- file.path(attempt_dir, "session.csv")
raw_path <- file.path(attempt_dir, "raw.csv")
host_path <- file.path(attempt_dir, "host.csv")
timing_write_kv(session, session_path)
plan <- timing_plan(protocol)
utils::write.csv(plan, file.path(attempt_dir, "plan.csv"), row.names = FALSE, fileEncoding = "UTF-8")

host_row <- function(phase, slot, probe) {
  chain <- timing_chain(probe$procs, Sys.getpid())
  data.frame(phase = phase, slot = slot, at = sprintf("%.6f", probe$at), plan_guid = probe$plan_guid,
    cpu_percent = probe$cpu_percent, root_chain = chain, foreign_r = timing_foreign_r(probe$procs, chain),
    stringsAsFactors = FALSE)
}
timing_append_csv(host_row("before", NA, probe), host_path)

# ---------------------------------------------------------------------------
# The window
# ---------------------------------------------------------------------------

rscript <- file.path(R.home("bin"), "Rscript")
work_dir <- file.path(tempdir(), "work")
dir.create(work_dir)
clock_of <- stats::setNames(protocol$cells$clock, protocol$cells$cell)

blank_row <- function(s, outcome, error) {
  row <- as.list(stats::setNames(rep(NA_character_, length(timing_raw_fields)), timing_raw_fields))
  row[c("slot", "pair", "cell", "arm", "clock", "outcome", "error")] <-
    list(s$slot, s$pair, s$cell, s$arm, clock_of[[s$cell]], outcome, error)
  as.data.frame(row, stringsAsFactors = FALSE)
}

run_slot <- function(s, seq_no) {
  out <- file.path(work_dir, sprintf("row_%04d.csv", s$slot))
  log <- file.path(work_dir, sprintf("slot_%04d.log", s$slot))
  cmd <- c("--no-init-file", shQuote(file.path(here, "measure.R")), shQuote(paste0("--protocol=", protocol$dir)),
    shQuote(paste0("--lib=", libs[[s$arm]])), paste0("--slot=", s$slot), paste0("--pair=", s$pair),
    paste0("--arm=", s$arm), shQuote(paste0("--cell=", s$cell)), shQuote(paste0("--work=", work_dir)),
    shQuote(paste0("--out=", out)), if (identical(s$slot, kill_slot)) "--test-kill")
  launched <- as.double(Sys.time())
  status <- system2(rscript, cmd, stdout = log, stderr = log)
  row <- if (file.exists(out)) timing_read_csv(out) else
    blank_row(s, "process_failed", sprintf("measure.R exited with status %s without writing a row", status))
  row$seq <- seq_no
  row$launched <- sprintf("%.6f", launched)
  row$exit_status <- status
  if (!identical(row$outcome, "ok")) {
    dir.create(file.path(attempt_dir, "logs"), showWarnings = FALSE)
    file.copy(log, file.path(attempt_dir, "logs", basename(log)))
  }
  row[timing_raw_fields]
}

row_problems <- function(row) {
  chain <- timing_chain_problem(row$chain, root$id)
  c(if (!identical(row$plan_guid, timing_plan_guid)) sprintf("power plan %s", row$plan_guid),
    if (nzchar(chain)) chain,
    if (!is.na(row$foreign_r) && nzchar(row$foreign_r)) sprintf("foreign R %s", row$foreign_r))
}

stop_reason <- ""
done <- integer()
current <- NA_integer_
tryCatch({
  for (i in seq_len(nrow(plan))) {
    s <- plan[i, ]
    probe <- timing_host_probe(here)
    timing_append_csv(host_row("during", s$slot, probe), host_path)
    problems <- timing_root_problems(probe, Sys.getpid())
    if (length(problems) && policy == "enforce") {
      stop_reason <- sprintf("host before slot %d: %s", s$slot, paste(names(problems), problems, collapse = "; "))
      break
    }
    current <- s$slot
    row <- run_slot(s, length(done) + 1L)
    timing_append_csv(row, raw_path)
    done <- c(done, s$slot)
    message(sprintf("%s slot %d/%d pair %d %s %s %s %s", utc(), s$slot, nrow(plan), s$pair, s$cell, s$arm,
      row$outcome, row$seconds))
    if (!identical(row$outcome, "ok")) {
      stop_reason <- sprintf("slot %d %s: %s", s$slot, row$outcome, row$error)
      break
    }
    problems <- row_problems(row)
    if (length(problems) && policy == "enforce") {
      stop_reason <- sprintf("host inside slot %d: %s", s$slot, paste(problems, collapse = "; "))
      break
    }
  }
}, interrupt = function(e) {
  stop_reason <<- "interrupted"
}, error = function(e) {
  stop_reason <<- paste("runner error:", conditionMessage(e))
})

# Every slot that did not run is persisted, so an invalid attempt shows
# exactly what is missing.
unrun <- plan[!plan$slot %in% done, , drop = FALSE]
for (i in seq_len(nrow(unrun))) {
  s <- unrun[i, ]
  outcome <- if (identical(s$slot, current)) "interrupted" else "not_run"
  timing_append_csv(blank_row(s, outcome, stop_reason)[timing_raw_fields], raw_path)
}
timing_append_csv(host_row("after", NA, timing_host_probe(here)), host_path)
session$status <- if (nzchar(stop_reason)) "invalid" else "complete"
session$status_reason <- stop_reason
session$finished_utc <- utc()
timing_write_kv(session, session_path)
message(sprintf("attempt %s: %s %s", attempt_dir, session$status, stop_reason))
message("check: Rscript dev/bench/timing/check.R --protocol=", protocol$dir, " --record=", attempt_dir,
  if (mode == "aa") " --aa")
quit(save = "no", status = if (nzchar(stop_reason)) 1L else 0L)

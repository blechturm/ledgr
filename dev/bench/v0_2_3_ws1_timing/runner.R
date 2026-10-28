# WS1 timing protocol (LDG-3127): the paired base/candidate runner.
#
# Installs each arm from a git commit (git archive, then R CMD INSTALL into
# its own library), verifies the host, then runs every workload x path cell
# once per arm per pair, each measurement in a fresh R process (measure.R).
# Pair k runs base first when k is odd and candidate first when k is even.
# Raw seconds are kept at full precision; nothing is retried. check.R
# evaluates the record. protocol.md is the human statement of this protocol.
#
# Launch from PowerShell so the pinned affinity is inherited by every child:
#   [System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF
#   & "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/v0_2_3_ws1_timing/runner.R `
#     --base=<commit> --candidate=<commit> --label=<name>
#
# Options: --pairs=<n> (smoke only; gate records use 8), --out=<dir> (default
# dev/bench/v0_2_3_ws1_timing/records/<label>), --smoke (allows an unpinned
# host, fewer pairs and --workloads=<a,b>; the record is marked smoke and
# check.R refuses it as gate evidence).

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  assign("ws1_here", normalizePath(here, winslash = "/"), envir = globalenv())
})
root <- normalizePath(file.path(ws1_here, "..", "..", ".."), winslash = "/")
source(file.path(ws1_here, "matrix.R"))

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
smoke <- "--smoke" %in% args
base_ref <- opt("base"); candidate_ref <- opt("candidate"); label <- opt("label")
if (is.null(base_ref) || is.null(candidate_ref) || is.null(label)) {
  stop("runner.R: --base, --candidate and --label are required", call. = FALSE)
}
pairs <- as.integer(opt("pairs", as.character(ws1_timing_pairs)))
out_dir <- opt("out", file.path(ws1_here, "records", label))
cells <- ws1_timing_cells()
workload_filter <- opt("workloads")
if (!is.null(workload_filter)) {
  if (!smoke) stop("runner.R: --workloads is allowed only with --smoke", call. = FALSE)
  cells <- cells[cells$workload %in% strsplit(workload_filter, ",", fixed = TRUE)[[1L]], , drop = FALSE]
}
if (!smoke && !identical(pairs, ws1_timing_pairs)) {
  stop(sprintf("runner.R: gate records use exactly %d pairs", ws1_timing_pairs), call. = FALSE)
}
if (dir.exists(out_dir) && length(list.files(out_dir))) {
  stop(sprintf("runner.R: %s already exists and is not empty; records are never overwritten", out_dir), call. = FALSE)
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

capture <- function(cmd, cmd_args) {
  out <- tryCatch(suppressWarnings(system2(cmd, cmd_args, stdout = TRUE, stderr = TRUE)),
    error = function(e) conditionMessage(e))
  trimws(out[nzchar(trimws(out))])
}
git <- function(...) capture("git", c("-C", shQuote(root), ...))
ps <- function(script) capture("powershell", c("-NoProfile", "-Command", shQuote(script, type = "cmd")))
utc <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

# ---------------------------------------------------------------------------
# Host verification
# ---------------------------------------------------------------------------

plan_text <- paste(capture("powercfg", "/getactivescheme"), collapse = " ")
plan_guid <- regmatches(plan_text, regexpr("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", plan_text))
plan_guid <- if (length(plan_guid)) plan_guid[[1L]] else NA_character_
runner_affinity <- suppressWarnings(as.numeric(ps(sprintf(
  "(Get-Process -Id %d).ProcessorAffinity.ToInt64()", Sys.getpid()))[1L]))
host_ok <- identical(plan_guid, ws1_timing_power_plan_guid) && isTRUE(runner_affinity == ws1_timing_affinity)
if (!host_ok && !smoke) {
  stop(sprintf(paste0("runner.R: host is not registered for gate timing (power plan %s, affinity %s); ",
    "set High performance and affinity 0xFFFF before starting R"), plan_guid, runner_affinity), call. = FALSE)
}

# ---------------------------------------------------------------------------
# Arms: install each commit into its own library
# ---------------------------------------------------------------------------

resolve <- function(ref) {
  sha <- git("rev-parse", "--verify", paste0(ref, "^{commit}"))
  if (length(sha) != 1L || !grepl("^[0-9a-f]{40}$", sha)) stop("runner.R: cannot resolve ", ref, call. = FALSE)
  sha
}
product_digest <- function(sha) {
  parts <- c("R", "src", "DESCRIPTION", "NAMESPACE")
  paste(sprintf("%s=%s", parts, vapply(parts, function(p) git("rev-parse", paste0(sha, ":", p))[[1L]], character(1L))),
    collapse = ";")
}
arm_dir <- file.path(tempdir(), "ws1_timing_arms")
dir.create(arm_dir, showWarnings = FALSE)
install_arm <- function(arm, sha) {
  src <- file.path(arm_dir, paste0(arm, "_src"))
  lib <- file.path(arm_dir, paste0(arm, "_lib"))
  zip <- file.path(arm_dir, paste0(arm, ".zip"))
  dir.create(src); dir.create(lib)
  status <- system2("git", c("-C", shQuote(root), "archive", "--format=zip", "-o", shQuote(zip), sha))
  if (!identical(as.integer(status), 0L)) stop("runner.R: git archive failed for ", arm, call. = FALSE)
  utils::unzip(zip, exdir = src)
  log <- file.path(arm_dir, paste0(arm, "_install.log"))
  status <- system2(file.path(R.home("bin"), "R"), c("CMD", "INSTALL", "--no-docs", "--no-html",
    paste0("--library=", shQuote(lib)), shQuote(src)), stdout = log, stderr = log)
  if (!identical(as.integer(status), 0L) || !dir.exists(file.path(lib, "ledgr"))) {
    stop(sprintf("runner.R: R CMD INSTALL failed for %s; see %s", arm, log), call. = FALSE)
  }
  normalizePath(lib, winslash = "/")
}
shas <- c(base = resolve(base_ref), candidate = resolve(candidate_ref))
cat("installing base", shas[["base"]], "\n")
libs <- c(base = install_arm("base", shas[["base"]]))
cat("installing candidate", shas[["candidate"]], "\n")
libs[["candidate"]] <- install_arm("candidate", shas[["candidate"]])

# ---------------------------------------------------------------------------
# Record metadata
# ---------------------------------------------------------------------------

dep_versions <- vapply(c("duckdb", "DBI", "collapse", "mirai", "cpp11", "digest"), function(p) {
  tryCatch(sprintf("%s %s", p, utils::packageVersion(p)), error = function(e) sprintf("%s absent", p))
}, character(1L))
cxx <- capture(file.path(R.home("bin"), "R"), c("CMD", "config", "CXX"))
gxx <- Sys.which("g++")
meta <- c(
  protocol_version = ws1_timing_protocol_version,
  label = label,
  smoke = as.character(smoke),
  started_utc = utc(),
  runner_commit = git("rev-parse", "HEAD")[[1L]],
  runner_worktree_clean_protocol = as.character(!length(git("status", "--porcelain", "--", "dev/bench/v0_2_3_ws1_timing",
    "dev/bench/v0_2_3_output_freeze/fixtures.R", "dev/bench/v0_2_3_output_freeze/timing.R"))),
  base_commit = shas[["base"]],
  base_tree = git("rev-parse", paste0(shas[["base"]], "^{tree}"))[[1L]],
  base_product = product_digest(shas[["base"]]),
  candidate_commit = shas[["candidate"]],
  candidate_tree = git("rev-parse", paste0(shas[["candidate"]], "^{tree}"))[[1L]],
  candidate_product = product_digest(shas[["candidate"]]),
  pairs = as.character(pairs),
  cells = as.character(nrow(cells)),
  workloads = paste(unique(cells$workload), collapse = ","),
  R_version = R.version.string,
  cxx = paste(cxx, collapse = " "),
  gxx_version = if (nzchar(gxx)) capture(gxx, "--version")[[1L]] else "g++ not on PATH",
  dependencies = paste(dep_versions, collapse = "; "),
  library_paths = paste(.libPaths(), collapse = ";"),
  cpu = paste(ps("(Get-CimInstance Win32_Processor).Name"), collapse = " "),
  logical_cores = as.character(parallel::detectCores()),
  power_plan = plan_text,
  power_plan_guid = plan_guid,
  runner_affinity = sprintf("%.0f", runner_affinity),
  base_lib = libs[["base"]],
  candidate_lib = libs[["candidate"]],
  retain_sha256 = digest::digest(ws1_timing_retain_text(root), algo = "sha256", serialize = FALSE),
  cpu_load_before = paste(ps("[int](Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average"), collapse = " "),
  top_processes_before = paste(ps(paste0("Get-Process | Sort-Object CPU -Descending | Select-Object -First 8 ",
    "Name,CPU | ForEach-Object { $_.Name + '=' + [int]$_.CPU }")), collapse = "; ")
)
protocol_digests <- vapply(ws1_timing_protocol_files, function(f) ws1_timing_file_digest(file.path(root, f)), character(1L))
meta <- c(meta, stats::setNames(protocol_digests, paste0("sha256:", ws1_timing_protocol_files)))
write_meta <- function(meta) {
  utils::write.csv(data.frame(key = names(meta), value = unname(meta), stringsAsFactors = FALSE),
    file.path(out_dir, "meta.csv"), row.names = FALSE, fileEncoding = "UTF-8")
}
write_meta(meta)

# ---------------------------------------------------------------------------
# Paired measurements
# ---------------------------------------------------------------------------

rscript <- file.path(R.home("bin"), "Rscript")
work_dir <- file.path(tempdir(), "ws1_timing_work")
dir.create(work_dir, showWarnings = FALSE)
raw_path <- file.path(out_dir, "raw.csv")
row_tmp <- file.path(tempdir(), "ws1_row.csv")
seq_no <- 0L
for (pair in seq_len(pairs)) {
  order <- if (pair %% 2L == 1L) ws1_timing_arms else rev(ws1_timing_arms)
  for (k in seq_len(nrow(cells))) {
    for (arm in order) {
      seq_no <- seq_no + 1L
      if (file.exists(row_tmp)) unlink(row_tmp)
      log <- file.path(tempdir(), sprintf("ws1_measure_%04d.log", seq_no))
      status <- system2(rscript, c("--no-init-file", shQuote(file.path(ws1_here, "measure.R")),
        shQuote(paste0("--root=", root)), shQuote(paste0("--lib=", libs[[arm]])),
        paste0("--arm=", arm), paste0("--pair=", pair), paste0("--seq=", seq_no),
        paste0("--workload=", cells$workload[[k]]), paste0("--path=", cells$path[[k]]),
        shQuote(paste0("--work=", work_dir)), shQuote(paste0("--out=", row_tmp))),
        stdout = log, stderr = log)
      row <- if (file.exists(row_tmp)) {
        utils::read.csv(row_tmp, colClasses = "character", na.strings = "NA")
      } else {
        data.frame(seq = as.character(seq_no), pair = as.character(pair), arm = arm,
          workload = cells$workload[[k]], path = cells$path[[k]], seconds = NA, outcome = "process_failed",
          error = sprintf("measure.R exited %s without a row; log %s", status, log), stringsAsFactors = FALSE)
      }
      row$exit_status <- as.character(status)
      for (f in setdiff(ws1_timing_raw_fields, names(row))) row[[f]] <- NA_character_
      row <- row[ws1_timing_raw_fields]
      if (!identical(row$outcome, "ok") && file.exists(log)) {
        dir.create(file.path(out_dir, "logs"), showWarnings = FALSE)
        file.copy(log, file.path(out_dir, "logs", basename(log)))
      }
      utils::write.table(row, raw_path, sep = ",", row.names = FALSE, col.names = !file.exists(raw_path),
        append = file.exists(raw_path), qmethod = "double", fileEncoding = "UTF-8")
      cat(sprintf("%s pair %d %-22s %-5s %-9s %s %s\n", utc(), pair, cells$workload[[k]], cells$path[[k]],
        arm, row$outcome, if (is.null(row$seconds)) "NA" else row$seconds))
    }
  }
}

meta[["finished_utc"]] <- utc()
meta[["cpu_load_after"]] <- paste(ps("[int](Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average"),
  collapse = " ")
write_meta(meta)
cat("record written to ", out_dir, "\nnext: Rscript dev/bench/v0_2_3_ws1_timing/check.R --record=", out_dir, "\n", sep = "")

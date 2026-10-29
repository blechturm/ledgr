# Shared timing harness (LDG-3155): checker demonstrations.
#
# Builds one clean synthetic gate record for protocol smoke-1 (two cells,
# eight pairs, distinct base and candidate commits, every host field on the
# registered settings), then one corrupted copy per case. Each record is
# checked by a fresh `Rscript check.R` process, and its real exit status and
# failure reasons are compared with the case's expectation. The clean record
# and the A/A record under --aa are the controls that must exit 0, so the
# failing cases are not vacuous. The interrupted record that runner.R wrote
# for the interruption demonstration is checked as well.
#
# Writes demo/check_demo_results.csv. Exits 1 if any case behaves otherwise.
#
# Usage: Rscript dev/bench/timing/demo/check_demo.R

here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])),
  winslash = "/")
harness <- dirname(here)
source(file.path(harness, "host.R"))
source(file.path(harness, "protocol.R"))
protocol_dir <- file.path(harness, "protocols", "smoke-1")
protocol <- timing_read_protocol(protocol_dir)
work <- file.path(tempdir(), "check_demo")
interrupted <- file.path(harness, "records", "smoke-1", "interrupt-demo", "attempt-1")

root_id <- "1000@1700000000000"
commit <- c(base = strrep("b", 40), candidate = strrep("c", 40))
lib <- c(base = "C:/demo/arm_base/lib", candidate = "C:/demo/arm_candidate/lib")

# A clean gate record. `ratio` sets each cell's candidate/base median ratio;
# `alternate = FALSE` runs base first in every pair, as a runner that never
# alternated would, with every self-report consistent with that order.
make_record <- function(dir, ratio = c(small_cold = 1.02, small_warm = 0.96), alternate = TRUE) {
  dir.create(file.path(dir, "protocol"), recursive = TRUE)
  file.copy(file.path(protocol_dir, timing_protocol_files), file.path(dir, "protocol"))
  timing_write_kv(list(protocol = protocol$id, label = "demo", attempt = "1", mode = "gate", host_policy = "enforce",
    test_hook = "none", disposition = "none", status = "complete", status_reason = "",
    started_utc = "2026-10-29T10:00:00Z", finished_utc = "2026-10-29T10:10:00Z", harness_commit = strrep("a", 40),
    harness_clean = "TRUE", base_commit = commit[["base"]], base_product = "R=1;src=1;DESCRIPTION=1;NAMESPACE=1",
    base_lib = lib[["base"]], candidate_commit = commit[["candidate"]],
    candidate_product = "R=2;src=1;DESCRIPTION=1;NAMESPACE=1", candidate_lib = lib[["candidate"]],
    root_id = root_id, root_affinity = "65535", plan_guid = timing_plan_guid, cpu = "demo", logical_cores = "24",
    R_version = R.version.string, os = "demo", dependencies = "demo"), file.path(dir, "session.csv"))
  plan <- timing_plan(protocol)
  utils::write.csv(plan, file.path(dir, "plan.csv"), row.names = FALSE)

  run <- plan
  if (!alternate) {
    even <- which(run$pair %% 2L == 0L)
    swap <- even + ifelse(seq_along(even) %% 2L == 1L, 1L, -1L)
    run <- plan[replace(seq_len(nrow(plan)), even, swap), ]
  }
  n <- nrow(run)
  created <- 1700000000000 + 1000 * seq_len(n)
  pid <- 2000 + seq_len(n)
  base_secs <- 1 + 0.01 * (run$pair %% 3L)
  secs <- ifelse(run$arm == "base", base_secs, base_secs * ratio[run$cell])
  raw <- data.frame(seq = seq_len(n), slot = run$slot, pair = run$pair, cell = run$cell, arm = run$arm,
    clock = protocol$cells$clock[match(run$cell, protocol$cells$cell)], seconds = sprintf("%.17g", secs),
    outcome = "ok", error = NA, work = "1240;1240", launched = sprintf("%.6f", created / 1000 - 0.05), pid = pid,
    created = sprintf("%.0f", created), affinity = "65535",
    chain = sprintf("%d@%.0f=65535;%s=65535", pid, created, root_id), foreign_r = "", plan_guid = timing_plan_guid,
    ledgr_path = paste0(lib[run$arm], "/ledgr"), ledgr_commit = commit[run$arm], exit_status = "0")
  utils::write.csv(raw, file.path(dir, "raw.csv"), row.names = FALSE)
  host <- data.frame(phase = c("before", rep("during", n), "after"), slot = c(NA, run$slot, NA),
    at = sprintf("%.6f", 1700000000 + seq_len(n + 2L)), plan_guid = timing_plan_guid, cpu_percent = 3,
    root_chain = paste0(root_id, "=65535;900@1699999990000=65535"), foreign_r = "")
  utils::write.csv(host, file.path(dir, "host.csv"), row.names = FALSE)
}

# Edits one record file in place.
edit <- function(dir, file, f) {
  path <- file.path(dir, file)
  d <- if (file == "session.csv") timing_read_kv(path) else timing_read_csv(path)
  d <- f(d)
  if (file == "session.csv") timing_write_kv(d, path) else utils::write.csv(d, path, row.names = FALSE)
}

# A protocol folder variant in the work directory, named like the original.
variant <- function(name, file, f) {
  dir <- file.path(work, "protocols", name, protocol$id)
  dir.create(dir, recursive = TRUE)
  file.copy(file.path(protocol_dir, timing_protocol_files), dir)
  utils::write.csv(f(timing_read_csv(file.path(dir, file))), file.path(dir, file), row.names = FALSE)
  dir
}

cases <- list(
  list(case = "control", shows = "a clean gate record passes", exit = 0L),
  list(case = "ratio_0.98_on_0.97", shows = "0.98 on a 0.97 cell", exit = 1L, reason = "ratio above bound",
    ratio = c(small_cold = 1.02, small_warm = 0.98)),
  list(case = "ratio_1.031_on_1.03", shows = "1.031 on a 1.03 cell", exit = 1L, reason = "ratio above bound",
    ratio = c(small_cold = 1.031, small_warm = 0.96)),
  list(case = "missing_cell", shows = "a missing cell", exit = 1L, reason = "missing cell",
    edit = list("raw.csv", function(d) d[d$cell != "small_warm", ])),
  list(case = "duplicate_row", shows = "a duplicate row", exit = 1L, reason = "duplicate row",
    edit = list("raw.csv", function(d) rbind(d, d[5L, ]))),
  list(case = "fewer_pairs", shows = "fewer pairs than the protocol states", exit = 1L, reason = "fewer pairs",
    edit = list("raw.csv", function(d) d[d$pair != "8", ])),
  list(case = "non_alternating", shows = "a non-alternating executed order", exit = 1L, reason = "executed order",
    alternate = FALSE),
  list(case = "wrong_power_plan", shows = "a wrong power plan in one measured process", exit = 1L,
    reason = "power plan",
    edit = list("raw.csv", function(d) { d$plan_guid[7L] <- "381b4222-f694-41f0-9685-ff5bb260df2e"; d })),
  list(case = "descendant_affinity", shows = "wrong affinity on a descendant between a measured process and the root",
    exit = 1L, reason = "affinity",
    edit = list("raw.csv", function(d) {
      d$chain[9L] <- sub(";", ";1500@1700000000500=16777215;", d$chain[9L], fixed = TRUE)
      d
    })),
  list(case = "foreign_r", shows = "a foreign R process seen by a measured process", exit = 1L, reason = "foreign R",
    edit = list("raw.csv", function(d) { d$foreign_r[11L] <- "ark.exe:27816@1792959389346"; d })),
  list(case = "aa_as_gate", shows = "an A/A record presented as a gate", exit = 1L,
    reason = "A/A record presented as a gate", same_commit = TRUE),
  list(case = "aa_control", shows = "the same A/A record checked with --aa is valid", exit = 0L, same_commit = TRUE,
    aa = TRUE),
  list(case = "protocol_pairs_7", shows = "a protocol stating fewer than eight pairs", exit = 1L, reason = "protocol",
    protocol = function() variant("pairs_7", "matrix.csv", function(d) { d$pairs <- "7"; d })),
  list(case = "threshold_map_omits_cell", shows = "a threshold map that omits a cell", exit = 1L, reason = "protocol",
    protocol = function() variant("omits_cell", "thresholds.csv", function(d) d[d$cell != "small_warm", ])),
  list(case = "interrupted_record", shows = "the runner's interrupted attempt (killed child, unrun slots)", exit = 1L,
    reason = "unrun slot", record = interrupted, aa = TRUE)
)

rscript <- file.path(R.home("bin"), "Rscript")
results <- do.call(rbind, lapply(cases, function(x) {
  record <- if (is.null(x$record)) file.path(work, x$case) else x$record
  if (is.null(x$record)) {
    make_record(record, ratio = if (is.null(x$ratio)) c(small_cold = 1.02, small_warm = 0.96) else x$ratio,
      alternate = !identical(x$alternate, FALSE))
    if (isTRUE(x[["same_commit"]])) {
      edit(record, "session.csv", function(s) {
        s[c("mode", "candidate_commit", "candidate_product")] <- list("aa", s$base_commit, s$base_product)
        s
      })
      edit(record, "raw.csv", function(d) { d$ledgr_commit <- commit[["base"]]; d })
    }
    if (!is.null(x$edit)) edit(record, x$edit[[1L]], x$edit[[2L]])
  }
  proto <- if (is.null(x$protocol)) protocol_dir else x$protocol()
  out <- suppressWarnings(system2(rscript, c("--no-init-file", shQuote(file.path(harness, "check.R")),
    shQuote(paste0("--protocol=", proto)), shQuote(paste0("--record=", record)), if (isTRUE(x[["aa"]])) "--aa"),
    stdout = TRUE, stderr = TRUE))
  status <- if (is.null(attr(out, "status"))) 0L else as.integer(attr(out, "status"))
  found <- unique(sub("^  ([^:]+):.*$", "\\1", grep("^  [^ :][^:]*:", out, value = TRUE)))
  want <- if (is.null(x$reason)) "" else x$reason
  data.frame(case = x$case, demonstrates = x$shows, expected_exit = x$exit, exit = status, expected_reason = want,
    reasons_found = paste(found, collapse = "; "),
    as_expected = status == x$exit && (!nzchar(want) || want %in% found), stringsAsFactors = FALSE)
}))

utils::write.csv(results, file.path(here, "check_demo_results.csv"), row.names = FALSE, fileEncoding = "UTF-8")
print(results[c("case", "exit", "expected_exit", "reasons_found", "as_expected")], row.names = FALSE, right = FALSE)
quit(save = "no", status = if (all(results$as_expected)) 0L else 1L)

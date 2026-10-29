# Protocol ws2-timing-1 (LDG-3156): the shared checker's rejections on this
# protocol, shown on synthetic gate records (not timing evidence).
#
# Builds one clean ten-cell, eight-pair gate record for ws2-timing-1 in the
# same form as demo/check_demo.R (a real harness commit, frozen copies from
# git show at that commit, alternating creation-ordered processes, every
# host field on the registered settings), with each cell's ratio just inside
# its bound. Then: 0.98 on a 0.97 cell, 1.031 on a 1.03 cell, a missing
# seed-state cell, a missing seed-state row and a duplicate row. Each record
# is checked by a fresh `Rscript check.R`; the clean record must exit 0 and
# every corruption 1 with its reason. Writes demo/ws2_timing_1_demo_results.csv.
#
# Usage: Rscript dev/bench/timing/demo/ws2_timing_1_demo.R

here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])),
  winslash = "/")
harness <- dirname(here)
source(file.path(harness, "host.R"))
source(file.path(harness, "protocol.R"))
repo <- normalizePath(file.path(harness, "..", "..", ".."), winslash = "/")
git <- function(...) system2("git", c("-C", shQuote(repo), ...), stdout = TRUE)
protocol_source <- "dev/bench/timing/protocols/ws2-timing-1"
protocol_dir <- file.path(repo, protocol_source)
protocol <- timing_read_protocol(protocol_dir)
stopifnot(!length(protocol$problems))
harness_commit <- git("rev-parse", "HEAD")
work <- file.path(tempdir(), "ws2_demo")
root_id <- "1000@1700000000000"
commit <- c(base = strrep("b", 40), candidate = strrep("c", 40))
lib <- c(base = "C:/demo/arm_base/lib", candidate = "C:/demo/arm_candidate/lib")

make_record <- function(dir, ratio) {
  dir.create(file.path(dir, "protocol"), recursive = TRUE)
  dir.create(file.path(dir, "harness"))
  for (f in timing_protocol_files) writeLines(git("show", paste0(harness_commit, ":", protocol_source, "/", f)), file.path(dir, "protocol", f))
  for (f in timing_harness_files) writeLines(git("show", paste0(harness_commit, ":dev/bench/timing/", f)), file.path(dir, "harness", f))
  timing_write_kv(list(protocol = protocol$id, label = "demo", attempt = "1", mode = "gate", host_policy = "enforce",
    test_hook = "none", disposition = "none", disposition_role = "none", disposition_ref = "none", status = "complete",
    status_reason = "", harness_commit = harness_commit, harness_source = "dev/bench/timing",
    protocol_source = protocol_source, inputs_start = "verified", inputs_end = "verified",
    base_commit = commit[["base"]], base_product = "R=1", base_lib = lib[["base"]], candidate_commit = commit[["candidate"]],
    candidate_product = "R=2", candidate_lib = lib[["candidate"]], root_id = root_id, root_affinity = "65535",
    plan_guid = timing_plan_guid), file.path(dir, "session.csv"))
  plan <- timing_plan(protocol)
  utils::write.csv(plan, file.path(dir, "plan.csv"), row.names = FALSE)
  n <- nrow(plan)
  launched <- 1700000000 + 10 * seq_len(n)
  created <- launched * 1000 + 50
  pid <- 2000 + seq_len(n)
  base_secs <- 10 + 0.1 * (plan$pair %% 3L)
  secs <- ifelse(plan$arm == "base", base_secs, base_secs * ratio[plan$cell])
  raw <- data.frame(seq = seq_len(n), slot = plan$slot, pair = plan$pair, cell = plan$cell, arm = plan$arm,
    clock = protocol$cells$clock[match(plan$cell, protocol$cells$cell)], seconds = sprintf("%.17g", secs),
    outcome = "ok", error = NA, work = paste0("DONE;DONE|", match(plan$cell, protocol$cells$cell)),
    launched = sprintf("%.6f", launched), pid = pid, created = sprintf("%.0f", created), affinity = "65535",
    chain = sprintf("%d@%.0f=65535;%s=65535", pid, created, root_id), foreign_r = "", plan_guid = timing_plan_guid,
    ledgr_path = paste0(lib[plan$arm], "/ledgr"), ledgr_commit = commit[plan$arm], exit_status = "0")
  utils::write.csv(raw, file.path(dir, "raw.csv"), row.names = FALSE)
  host <- data.frame(phase = c("before", rep("during", n), "after"), slot = c(NA, plan$slot, NA),
    at = sprintf("%.6f", c(1700000000, launched - 1, launched[n] + 10)), plan_guid = timing_plan_guid,
    cpu_percent = 3, root_chain = paste0(root_id, "=65535;900@1699999990000=65535"), foreign_r = "",
    cpu_max_ms = c(NA, rep(0, n + 1L)), cpu_top = "", cpu_unreadable = c(NA, rep(0, n + 1L)))
  utils::write.csv(host, file.path(dir, "host.csv"), row.names = FALSE)
}

inside <- stats::setNames(protocol$cells$bound - 0.01, protocol$cells$cell)
with_ratio <- function(cell, value) replace(inside, cell, value)
drop_rows <- function(f) function(dir) {
  raw <- timing_read_csv(file.path(dir, "raw.csv"))
  utils::write.csv(f(raw), file.path(dir, "raw.csv"), row.names = FALSE)
}
cases <- list(
  list(case = "control", exit = 0L, reason = "", ratio = inside),
  list(case = "ratio_0.98_on_0.97", exit = 1L, reason = "ratio above bound", ratio = with_ratio("dense_run_seeded", 0.98)),
  list(case = "ratio_1.031_on_1.03", exit = 1L, reason = "ratio above bound",
    ratio = with_ratio("timing_sweep_unseeded", 1.031)),
  list(case = "missing_seed_state_cell", exit = 1L, reason = "missing cell", ratio = inside,
    change = drop_rows(function(d) d[d$cell != "dense_run_unseeded", ])),
  list(case = "missing_seed_state_row", exit = 1L, reason = "missing row", ratio = inside,
    change = drop_rows(function(d) d[!(d$cell == "timing_sweep_unseeded" & d$pair == "3" & d$arm == "base"), ])),
  list(case = "duplicate_row", exit = 1L, reason = "duplicate row", ratio = inside,
    change = drop_rows(function(d) rbind(d, d[d$cell == "stochastic_run_seeded" & d$pair == "2", ][1L, ])))
)

rscript <- file.path(R.home("bin"), "Rscript")
results <- do.call(rbind, lapply(cases, function(x) {
  record <- file.path(work, x$case)
  make_record(record, x$ratio)
  if (!is.null(x$change)) x$change(record)
  out <- suppressWarnings(system2(rscript, c("--no-init-file", shQuote(file.path(harness, "check.R")),
    shQuote(paste0("--protocol=", protocol_dir)), shQuote(paste0("--record=", record))), stdout = TRUE, stderr = TRUE))
  status <- if (is.null(attr(out, "status"))) 0L else as.integer(attr(out, "status"))
  found <- unique(sub("^  ([^:]+):.*$", "\\1", grep("^  [^ :][^:]*:", out, value = TRUE)))
  data.frame(case = x$case, expected_exit = x$exit, exit = status, expected_reason = x$reason,
    reasons_found = paste(found, collapse = "; "),
    as_expected = status == x$exit && (!nzchar(x$reason) || x$reason %in% found), stringsAsFactors = FALSE)
}))
utils::write.csv(results, file.path(here, "ws2_timing_1_demo_results.csv"), row.names = FALSE, fileEncoding = "UTF-8")
print(results, row.names = FALSE, right = FALSE)
quit(save = "no", status = if (all(results$as_expected)) 0L else 1L)

# Identity declarations and the store-binding comparison (LDG-3161;
# ws2_rng_design.md Section 7, decision (7)).
#
# Archives the base and the candidate commits, runs identity_probe.R on each
# as a fresh R process, and checks:
#
#   bindings     ledgr_store_format_bindings() of the candidate equals the
#                base plus exactly ledgr_pulse_seed_rule_version = 2L
#   fingerprint  the store format fingerprint changes (through that binding)
#   snapshot     identical canonical input keeps its snapshot hash; content
#                hash rule and identity rule versions unchanged
#   seeded       config hash and generated run id change; the engine gains
#                exactly pulse_seed_rule = 2
#   unseeded     config hash, run id and engine unchanged
#   markers      sweep seed_contract ledgr_seed_v1 -> ledgr_seed_v2; candidate
#                execution seed unchanged
#   old store    a store written by the base is refused when the candidate
#                opens it (ledgr_store_rebuild_required, the one constant)
#   old candidate  a base sweep candidate is refused by the candidate's
#                ledgr_promote (ledgr_seed_rule_mismatch) and creates no run
#
# Usage: Rscript identity.R [--base=3a67db60] [--candidate=HEAD] [--work=<dir>] [--result=<csv>]

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  source(file.path(here, "lib.R"))
})
base <- sr_arg("base", "3a67db60"); candidate <- sr_arg("candidate", "HEAD")
work <- sr_arg("work", file.path(tempdir(), "ldg3161_identity"))
result_file <- sr_arg("result", NULL)
rscript <- file.path(R.home("bin"), "Rscript")
probe <- file.path(sr_dir, "identity_probe.R")
store <- file.path(work, "store")
sha <- function(x) system2("git", c("-C", shQuote(sr_root), "rev-parse", "--short=8", paste0(x, "^{commit}")), stdout = TRUE)
res <- list()
for (arm in c("base", "candidate")) {
  commit <- if (arm == "base") base else candidate
  tree <- sr_archive(commit, file.path(work, arm), paths = c("DESCRIPTION", "NAMESPACE", "R", "src", "inst"))
  built <- list.files(file.path(sr_root, "src"), pattern = "[.](o|dll|so)$", full.names = TRUE)
  file.copy(built, file.path(tree, "src"), overwrite = TRUE) # src/ is identical in both arms
  out <- file.path(work, paste0(arm, ".rds"))
  status <- system2(rscript, c(shQuote(probe), paste0("--root=", shQuote(tree)), paste0("--out=", shQuote(out)),
    paste0("--store=", shQuote(store)), paste0("--mode=", arm)), stdout = file.path(work, paste0(arm, ".log")),
    stderr = file.path(work, paste0(arm, ".log")))
  if (!identical(as.integer(status), 0L)) stop(sprintf("identity probe failed on %s; see %s.log", arm, arm), call. = FALSE)
  res[[arm]] <- readRDS(out)
}
b <- res$base; c <- res$candidate
rows <- list()
add <- function(field, base_value, cand_value, expectation, ok) {
  rows[[length(rows) + 1L]] <<- data.frame(field = field, base = paste(base_value, collapse = ","),
    candidate = paste(cand_value, collapse = ","), expectation = expectation, status = if (isTRUE(ok)) "PASS" else "FAIL",
    stringsAsFactors = FALSE)
}
only_c <- setdiff(names(c$bindings), names(b$bindings)); only_b <- setdiff(names(b$bindings), names(c$bindings))
common <- intersect(names(b$bindings), names(c$bindings))
differ <- common[!mapply(identical, b$bindings[common], c$bindings[common])]
add("store bindings added", only_b, only_c, "exactly ledgr_pulse_seed_rule_version, none removed",
  identical(only_c, "ledgr_pulse_seed_rule_version") && length(only_b) == 0L)
add("store bindings changed", "", differ, "none of the common bindings changes", length(differ) == 0L)
add("ledgr_pulse_seed_rule_version", "<absent>", sprintf("%s (%s)", c$bindings$ledgr_pulse_seed_rule_version,
  typeof(c$bindings$ledgr_pulse_seed_rule_version)), "2 (integer)", identical(c$bindings$ledgr_pulse_seed_rule_version, 2L))
add("binding count", length(b$bindings), length(c$bindings), "base + 1", length(c$bindings) == length(b$bindings) + 1L)
add("store format fingerprint sha256", b$fingerprint_sha256, c$fingerprint_sha256, "changes", !identical(b$fingerprint_sha256, c$fingerprint_sha256))
add("snapshot hash (identical canonical input)", b$snapshot_hash, c$snapshot_hash, "unchanged", identical(b$snapshot_hash, c$snapshot_hash))
add("snapshot content hash rule", b$content_hash_rule, c$content_hash_rule, "unchanged", identical(b$content_hash_rule, c$content_hash_rule))
add("identity rule version", b$identity_rule_version, c$identity_rule_version, "unchanged", identical(b$identity_rule_version, c$identity_rule_version))
add("seeded config hash", b$seeded_config_hash, c$seeded_config_hash, "changes", !identical(b$seeded_config_hash, c$seeded_config_hash))
add("seeded generated run id", b$seeded_run_id, c$seeded_run_id, "changes", !identical(b$seeded_run_id, c$seeded_run_id))
be <- jsonlite::fromJSON(b$seeded_engine, simplifyVector = FALSE); ce <- jsonlite::fromJSON(c$seeded_engine, simplifyVector = FALSE)
ce_minus <- ce; ce_minus$pulse_seed_rule <- NULL
add("seeded engine", b$seeded_engine, c$seeded_engine, "gains exactly pulse_seed_rule = 2",
  identical(ce$pulse_seed_rule, 2L) && is.null(be$pulse_seed_rule) && identical(be[order(names(be))], ce_minus[order(names(ce_minus))]))
add("unseeded config hash", b$unseeded_config_hash, c$unseeded_config_hash, "unchanged", identical(b$unseeded_config_hash, c$unseeded_config_hash))
add("unseeded generated run id", b$unseeded_run_id, c$unseeded_run_id, "unchanged", identical(b$unseeded_run_id, c$unseeded_run_id))
add("unseeded engine", b$unseeded_engine, c$unseeded_engine, "unchanged", identical(b$unseeded_engine, c$unseeded_engine))
add("sweep seed_contract", b$sweep_seed_contract, c$sweep_seed_contract, "ledgr_seed_v1 -> ledgr_seed_v2",
  identical(b$sweep_seed_contract, "ledgr_seed_v1") && identical(c$sweep_seed_contract, "ledgr_seed_v2"))
add("candidate seed_contract", b$candidate_seed_contract, c$candidate_seed_contract, "ledgr_seed_v1 -> ledgr_seed_v2",
  identical(b$candidate_seed_contract, "ledgr_seed_v1") && identical(c$candidate_seed_contract, "ledgr_seed_v2"))
add("candidate execution_seed", b$candidate_execution_seed, c$candidate_execution_seed, "unchanged",
  identical(b$candidate_execution_seed, c$candidate_execution_seed))
add("base store opened by the candidate", "", c$old_store_open,
  "refused: ledgr_store_rebuild_required, fingerprint_mismatch, ledgr_pulse_seed_rule_version",
  identical(c$old_store_open, "refused: class ledgr_store_rebuild_required; cause fingerprint_mismatch; differing_constants ledgr_pulse_seed_rule_version"))
add("base candidate promoted by the candidate", "", sprintf("%s; run rows %d", c$old_candidate_promote, c$old_candidate_run_row),
  "refused: ledgr_seed_rule_mismatch, no run row",
  grepl("^refused: classes ledgr_seed_rule_mismatch/", c$old_candidate_promote) && c$old_candidate_run_row == 0L)
rep <- do.call(rbind, rows)
rep <- rbind(data.frame(field = "commit", base = sha(base), candidate = sha(candidate), expectation = "", status = "",
  stringsAsFactors = FALSE), rep)
if (!is.null(result_file)) utils::write.csv(rep, result_file, row.names = FALSE)
for (i in seq_len(nrow(rep))) cat(sprintf("%-5s %-42s base=%s | candidate=%s\n", rep$status[[i]], rep$field[[i]],
  substr(rep$base[[i]], 1L, 90L), substr(rep$candidate[[i]], 1L, 90L)))
fails <- sum(rep$status == "FAIL")
cat(sprintf("identity: %s (%d checks, %d fail)\n", if (fails) "FAIL" else "PASS", sum(rep$status != ""), fails))
quit(status = if (fails) 1L else 0L)

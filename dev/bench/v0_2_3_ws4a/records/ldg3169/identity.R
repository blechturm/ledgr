# Identity declarations of cut 5 decision (3) (LDG-3169): snapshot content,
# run configuration and store format fingerprint are all unchanged.
# Archives the base and the candidate (R, src, inst, DESCRIPTION, NAMESPACE),
# runs the unchanged cut 4 probe (v0_2_3_cut3_successors/identity_probe.R) on
# each in a fresh process, and requires every recorded value to be equal; the
# candidate also opens the base's store and promotes the base's sweep
# candidate. src/ is identical in both arms, so the worktree's built objects
# are copied into both trees.
#
# Usage: Rscript identity.R [--base=953338df] [--candidate=HEAD] --work=<new dir> [--result=<csv>]
local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  source(file.path(dirname(sub("^--file=", "", file_arg[[1L]])), "../../../v0_2_3_cut3_successors/lib.R"))
})
base <- sr_arg("base", "953338df"); candidate <- sr_arg("candidate", "HEAD")
work <- sr_arg("work"); if (is.null(work)) stop("--work is required")
store <- file.path(work, "store"); res <- list()
for (arm in c("base", "candidate")) {
  tree <- sr_archive(if (arm == "base") base else candidate, file.path(work, arm),
    paths = c("DESCRIPTION", "NAMESPACE", "R", "src", "inst"))
  file.copy(list.files(file.path(sr_root, "src"), "[.](o|dll|so)$", full.names = TRUE), file.path(tree, "src"), overwrite = TRUE)
  out <- file.path(work, paste0(arm, ".rds")); log <- file.path(work, paste0(arm, ".log"))
  status <- system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(sr_dir, "identity_probe.R")),
    paste0("--root=", shQuote(tree)), paste0("--out=", shQuote(out)), paste0("--store=", shQuote(store)),
    paste0("--mode=", arm)), stdout = log, stderr = log)
  if (status != 0L) stop("identity probe failed on ", arm, "; see ", log)
  res[[arm]] <- readRDS(out)
}
b <- res$base; c <- res$candidate
same <- c("bindings", "fingerprint_sha256", "content_hash_rule", "identity_rule_version", "snapshot_hash",
  "seeded_config_hash", "seeded_run_id", "seeded_engine", "unseeded_config_hash", "unseeded_run_id",
  "unseeded_engine", "sweep_seed_contract", "candidate_seed_contract", "candidate_execution_seed")
show <- function(v) if (is.list(v)) paste(names(v), unlist(v), sep = "=", collapse = ",") else paste(v, collapse = ",")
rep <- data.frame(field = same, base = vapply(b[same], show, ""), candidate = vapply(c[same], show, ""),
  expectation = "unchanged", status = ifelse(mapply(identical, b[same], c[same]), "PASS", "FAIL"))
rep <- rbind(rep,
  data.frame(field = "base store opened by the candidate", base = "", candidate = c$old_store_open,
    expectation = "opened", status = if (identical(c$old_store_open, "opened")) "PASS" else "FAIL"),
  data.frame(field = "base sweep candidate promoted by the candidate", base = "",
    candidate = sprintf("%s; run rows %d", c$old_candidate_promote, c$old_candidate_run_row),
    expectation = "promoted; run rows 1",
    status = if (identical(c$old_candidate_promote, "promoted") && c$old_candidate_run_row == 1L) "PASS" else "FAIL"))
sha <- function(x) system2("git", c("-C", shQuote(sr_root), "rev-parse", "--short=8", paste0(x, "^{commit}")), stdout = TRUE)
rep <- rbind(data.frame(field = "commit", base = sha(base), candidate = sha(candidate), expectation = "", status = ""), rep)
if (!is.null(sr_arg("result"))) utils::write.csv(rep, sr_arg("result"), row.names = FALSE)
for (i in seq_len(nrow(rep))) cat(sprintf("%-5s %-46s base=%s | candidate=%s\n", rep$status[[i]], rep$field[[i]],
  substr(rep$base[[i]], 1L, 70L), substr(rep$candidate[[i]], 1L, 70L)))
fails <- sum(rep$status == "FAIL")
cat(sprintf("identity: %s (%d checks, %d fail)\n", if (fails) "FAIL" else "PASS", sum(rep$status != ""), fails))
quit(status = as.integer(fails > 0L))

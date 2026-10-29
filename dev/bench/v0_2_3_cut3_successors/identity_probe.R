# Identity probe for one package tree (LDG-3161; ws2_rng_design.md Section 7).
# Run by identity.R once on the base tree and once on the candidate tree;
# uses only functions both trees have.
#
# Usage: Rscript identity_probe.R --root=<tree> --out=<rds> --store=<dir> --mode=<base|candidate>
#   base       also writes a store with a seeded run (<store>/old.duckdb) and
#              saves one sweep candidate (<store>/old_candidate.rds)
#   candidate  also opens that store and promotes that candidate, recording
#              the refusal conditions

arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), commandArgs(trailingOnly = TRUE), value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else stop("--", name, " is required")
}
root <- arg("root"); out <- arg("out"); store <- arg("store"); mode <- arg("mode")
suppressMessages(pkgload::load_all(root, quiet = TRUE))
ns <- asNamespace("ledgr")
bars_fn <- function(ids = "AAA", n = 30L) {
  ts <- as.POSIXct("2021-01-01", tz = "UTC") + 86400 * (seq_len(n) - 1L)
  do.call(rbind, lapply(seq_along(ids), function(j) {
    close <- 50 + j + 0.5 * sin(seq_len(n) / (j + 1))
    data.frame(instrument_id = ids[[j]], ts_utc = ts, open = close, high = close + 1, low = close - 1,
      close = close, volume = 1e5, stringsAsFactors = FALSE)
  }))
}
strategy <- function(ctx, params) { targets <- ctx$flat(); targets[[1L]] <- params$qty; targets }
res <- list()
res$bindings <- ns$ledgr_store_format_bindings()
res$fingerprint_sha256 <- digest::digest(as.character(ns$ledgr_store_format_json()), algo = "sha256", serialize = FALSE)
res$content_hash_rule <- ns$ledgr_snapshot_content_hash_rule_version
res$identity_rule_version <- ns$ledgr_identity_rule_version
snap <- ledgr_snapshot_from_df(bars_fn("AAA", 10L), db_path = tempfile(fileext = ".duckdb"), snapshot_id = "id_hash")
res$snapshot_hash <- ledgr_snapshot_info(snap)$snapshot_hash[[1L]]
ledgr_snapshot_close(snap)
snap2 <- ledgr_snapshot_from_df(bars_fn("AAA", 12L), db_path = tempfile(fileext = ".duckdb"), snapshot_id = "id_cfg")
exp <- ledgr_experiment(snap2, strategy, opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
seeded <- suppressWarnings(ledgr_run(exp, params = list(qty = 1), seed = 7L))
unseeded <- suppressWarnings(ledgr_run(exp, params = list(qty = 1)))
res$seeded_run_id <- seeded$run_id; res$unseeded_run_id <- unseeded$run_id
res$seeded_config_hash <- ledgr_run_info(snap2, seeded$run_id)$config_hash
res$unseeded_config_hash <- ledgr_run_info(snap2, unseeded$run_id)$config_hash
res$seeded_engine <- as.character(ns$canonical_json(seeded$config$engine))
res$unseeded_engine <- as.character(ns$canonical_json(unseeded$config$engine))
close(seeded); close(unseeded)
sw <- suppressWarnings(ledgr_sweep(exp, ledgr_grid_named(a = list(strategy = list(qty = 1))), seed = 7L))
res$sweep_seed_contract <- attr(sw, "seed_contract")
cand <- ledgr_candidate(sw, "a")
res$candidate_seed_contract <- cand$provenance$seed_contract
res$candidate_execution_seed <- cand$execution_seed

if (mode == "base") {
  dir.create(store, recursive = TRUE, showWarnings = FALSE)
  saveRDS(cand, file.path(store, "old_candidate.rds"))
  old <- ledgr_snapshot_from_df(bars_fn("AAA", 12L), db_path = file.path(store, "old.duckdb"), snapshot_id = "id_old")
  old_exp <- ledgr_experiment(old, strategy, opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  close(suppressWarnings(ledgr_run(old_exp, params = list(qty = 1), run_id = "id-old-run", seed = 7L)))
  ledgr_snapshot_close(old)
} else {
  opened <- tryCatch(ledgr_snapshot_open(file.path(store, "old.duckdb")), error = function(e) e)
  res$old_store_open <- if (inherits(opened, "error")) {
    sprintf("refused: class %s; cause %s; differing_constants %s", class(opened)[[1L]], format(opened$cause %||% NA),
      paste(opened$differing_constants, collapse = ","))
  } else "opened"
  old_cand <- readRDS(file.path(store, "old_candidate.rds"))
  promoted <- tryCatch(ledgr_promote(exp, old_cand, run_id = "id-old-candidate"), error = function(e) e)
  res$old_candidate_promote <- if (inherits(promoted, "error")) {
    sprintf("refused: classes %s", paste(class(promoted), collapse = "/"))
  } else "promoted"
  res$old_candidate_run_row <- nrow(ledgr_run_list(snap2)[ledgr_run_list(snap2)$run_id == "id-old-candidate", , drop = FALSE])
}
ledgr_snapshot_close(snap2)
saveRDS(res, out)
cat("identity probe", mode, "done:", root, "\n")

# A0 pulse-rule model (LDG-3161; ws2_rng_design.md Section 8, "Pulse-rule
# model"): the base tree run sequentially with ledgr_derive_pulse_seed
# replaced in memory by the independent v2 reference of ../lib.R. No other
# change is made. It is an oracle for causal attribution of A4, not a gut.
# Only dense_risk_features draws from ctx$pulse_seed, so only its run and
# sweep_w1 paths are modelled.
#
# Usage: Rscript model.R [--base=<commit>] [--out=<dir>] [--work=<scratch dir>]
#   --base  defaults to aa2931e9 (the note's base; R/ and src/ equal 3a67db60)
#   --out   defaults to model/ next to this script

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  source(file.path(here, "..", "lib.R"))
})
sr_ref_selftest()
base <- sr_arg("base", "aa2931e9")
out_dir <- sr_arg("out", file.path(sr_dir, "a0", "model"))
work <- sr_arg("work", file.path(tempdir(), "a0_model"))
tree <- sr_archive(base, file.path(work, "base"))
suppressMessages(pkgload::load_all(tree, quiet = TRUE))
source(file.path(tree, "dev", "bench", "v0_2_3_output_freeze", "lib.R"))
stopifnot(exists("ledgr_derive_pulse_seed", envir = asNamespace("ledgr"), inherits = FALSE))

gut <- list(workload = "dense_risk_features", what = "pulse-rule model",
  patch = list(ledgr_derive_pulse_seed = function(orig) function(execution_seed, pulse_idx) {
    if (is.null(execution_seed)) NULL else sr_v2_ref(execution_seed, pulse_idx)
  }),
  patch_paths = c("sweep_w1", "run"))
res <- a0_run_all(file.path(work, "run"), gut = gut, ids = "dense_risk_features")
res$tables$dense_risk_features$sweep_w2 <- NULL # workers load the unpatched base; not part of the model
if (dir.exists(out_dir)) invisible(file.remove(list.files(out_dir, recursive = TRUE, full.names = TRUE)))
manifest <- a0_write_records(res$tables, out_dir)
cat(sprintf("a0 model (base %s): %d files in %s\n", base, nrow(manifest), out_dir))

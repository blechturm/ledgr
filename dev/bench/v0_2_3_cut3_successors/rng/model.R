# RNG baseline pulse-rule model (LDG-3161; ws2_rng_design.md Section 8,
# "Pulse-rule model"): the base tree's own probe, run with
# ledgr_derive_pulse_seed replaced in memory by the independent v2 reference
# of ../lib.R. No other change is made. Only the stochastic tables are
# modelled; their sequential rows (run, sweep_w1) are the oracle. The model
# cannot patch mirai workers, so its sweep_w2 rows are not used.
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
sr_model_out <- sr_arg("out", file.path(sr_dir, "rng", "model"))
sr_base <- sr_arg("base", "aa2931e9")
work <- sr_arg("work", file.path(tempdir(), "rng_model"))
tree <- sr_archive(sr_base, file.path(work, "base"))
source(file.path(tree, "dev", "bench", "v0_2_3_rng_baseline", "probe.R")) # loads the base tree
stopifnot(identical(rp_root, tree), exists("ledgr_derive_pulse_seed", envir = rp_ns, inherits = FALSE))

model <- list(ledgr_derive_pulse_seed = function(orig) function(execution_seed, pulse_idx) {
  if (is.null(execution_seed)) NULL else sr_v2_ref(execution_seed, pulse_idx)
})
dir.create(file.path(work, "run"), showWarnings = FALSE)
tables <- a0_with_patches(model, rp_stochastic(file.path(work, "run")))
if (dir.exists(sr_model_out)) invisible(file.remove(list.files(sr_model_out, recursive = TRUE, full.names = TRUE)))
manifest <- rp_write_records(tables, sr_model_out)
cat(sprintf("rng model (base %s): %d tables -> %s\n", sr_base, nrow(manifest), sr_model_out))

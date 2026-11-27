# Witness file: the gutted path of the take-and-return stage. P5 writes
# hd_recon[i, ] to a local copy, so that write is left out of its returned state.
es_set <- "p5"
es_gut <- list(fn = "lean_p5_commit", name = "hd_recon")
sys.source(file.path(.lean_home, "..", "spikes", "explicit_state", "install.R"), envir = environment(), keep.source = FALSE)

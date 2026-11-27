# Witness file: the gutted path. The prerequisite fork with one write,
# P5's hd_recon[i, ] <<- recon, left unrewritten (a transform bug).
es_set <- "commit"
es_gut <- list(fn = "lean_p5_commit", name = "hd_recon")
sys.source(file.path(.lean_home, "..", "spikes", "explicit_state", "install.R"), envir = environment(), keep.source = FALSE)

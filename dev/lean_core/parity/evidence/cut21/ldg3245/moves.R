# LDG-3245: workstream 39's frozen-row moves against the effective freeze at
# 381c0d0c, by cut19_moves.R run from the repository root (it reads paths
# relative to it). Arguments pass through.
#   Rscript dev/lean_core/parity/evidence/cut21/ldg3245/moves.R --base=381c0d0c --out=<csv>
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
setwd(normalizePath(file.path(here, "..", "..", "..", "..", "..", ".."), winslash = "/"))
source("dev/lean_core/parity/cut19_moves.R")

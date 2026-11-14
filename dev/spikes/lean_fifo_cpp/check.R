# Spike lean_fifo_cpp, checker (spike protocol section 6): reruns the
# equivalence into a scratch directory and diffs it against the recorded
# results/equivalence.csv; guards package scope (nothing under R, src,
# tests, NAMESPACE, DESCRIPTION, man or inst/design changed by the spike's
# commits); and shows one gutted path failing: the kernel with its
# compensated (Kahan) realized step removed must produce differences.
#
#   Rscript dev/spikes/lean_fifo_cpp/check.R --lib=<pin library> --captures=<dir> --scratch=<dir>
#     --spike-base=<commit before the spike>
# Timings (runs_*.csv) are host observations and are not diffed.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), args, value = TRUE)[[1L]])
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
scratch <- opt("scratch"); dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home("bin"), "Rscript.exe")
ok <- TRUE
say <- function(what, pass) { cat(sprintf("%-46s %s\n", what, if (pass) "ok" else "FAILED")); if (!pass) ok <<- FALSE }

st <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", opt("lib")), paste0("--out=", file.path(scratch, "rerun")),
                         "--mode=equivalence", paste0("--captures=", opt("captures"))), stdout = FALSE, stderr = FALSE)
say("equivalence rerun exits 0", st == 0L)
rec <- utils::read.csv(file.path(here, "results", "equivalence.csv"), stringsAsFactors = FALSE)
new <- utils::read.csv(file.path(scratch, "rerun", "equivalence.csv"), stringsAsFactors = FALSE)
say("equivalence rerun equals the recorded CSV", identical(rec, new))

scope <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
# only the spike's own commits (those touching this folder) since the base
spike_dir <- sub(paste0("^", repo, "/"), "", here)
mine <- system2("git", c("-C", repo, "log", "--format=%H", paste0(opt("spike-base"), "..HEAD"), "--", spike_dir), stdout = TRUE)
changed <- unlist(lapply(mine, function(h) system2("git", c("-C", repo, "show", "--name-only", "--format=", h, "--", scope), stdout = TRUE)))
say(sprintf("package scope untouched by the spike's %d commits", length(mine)), length(changed) == 0L)

gut <- file.path(scratch, "kernel_gutted.cpp")
src <- readLines(file.path(here, "kernel.cpp"))
line <- grep("comp = (t - realized) - y;", src, fixed = TRUE)
say("gut target found once in kernel.cpp", length(line) == 1L)
src[line] <- sub("comp = (t - realized) - y;", "comp = 0.0;", src[line], fixed = TRUE)
writeLines(src, gut)
st_gut <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", opt("lib")), paste0("--out=", file.path(scratch, "gutted")),
                             "--mode=equivalence", paste0("--captures=", opt("captures")), paste0("--kernel=", gut)),
                  stdout = FALSE, stderr = FALSE)
g <- utils::read.csv(file.path(scratch, "gutted", "equivalence.csv"), stringsAsFactors = FALSE)
say("gutted kernel (no Kahan step) exits 1", st_gut == 1L)
say(sprintf("gutted kernel differs on %d calls", sum(g$different)), sum(g$different) > 0L)
utils::write.csv(g, file.path(here, "results", "equivalence_gutted.csv"), row.names = FALSE)
cat(if (ok) "CHECK PASSED\n" else "CHECK FAILED\n")
if (!ok) quit(status = 1L)

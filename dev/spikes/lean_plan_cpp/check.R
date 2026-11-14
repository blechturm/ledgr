# Spike lean_plan_cpp, checker (spike protocol section 6): reruns the
# equivalence and the fuzz into a scratch directory and diffs them against
# the recorded results/plan_equivalence.csv and results/plan_fuzz.csv;
# guards package scope against the spike's base commit; and guts one path:
# the affordability order without its stable-ID tie-break must produce
# differences in the fuzz.
#
#   Rscript dev/spikes/lean_plan_cpp/check.R --lib=<pin library> --scratch=<dir> --spike-base=<commit>
# Timings (runs_*.csv) are host observations and are not diffed.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), args, value = TRUE)[[1L]])
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
scratch <- opt("scratch"); dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home("bin"), "Rscript.exe")
ok <- TRUE
say <- function(what, pass) { cat(sprintf("%-50s %s\n", what, if (pass) "ok" else "FAILED")); if (!pass) ok <<- FALSE }
run <- function(mode, out, ...) system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", opt("lib")), paste0("--out=", out),
                                                   paste0("--mode=", mode), ...), stdout = FALSE, stderr = FALSE)
rd <- function(f) utils::read.csv(f, stringsAsFactors = FALSE)

say("equivalence rerun exits 0", run("equivalence", file.path(scratch, "rerun")) == 0L)
say("equivalence rerun equals the recorded CSV",
    identical(rd(file.path(here, "results", "plan_equivalence.csv")), rd(file.path(scratch, "rerun", "plan_equivalence.csv"))))
say("fuzz rerun exits 0", run("fuzz", file.path(scratch, "rerun")) == 0L)
say("fuzz rerun equals the recorded CSV",
    identical(rd(file.path(here, "results", "plan_fuzz.csv")), rd(file.path(scratch, "rerun", "plan_fuzz.csv"))))

scope <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
changed <- system2("git", c("-C", repo, "diff", "--name-only", opt("spike-base"), "HEAD", "--", scope), stdout = TRUE)
say("package scope untouched by the spike's commits", length(changed) == 0L)

src <- readLines(file.path(here, "kernel.cpp"))
line <- grep("return id_rank[pos[cand[a] - 1] - 1] < id_rank[pos[cand[b] - 1] - 1];", src, fixed = TRUE)
say("gut target found once in kernel.cpp", length(line) == 1L)
src[line] <- "      return false;  // gutted: no stable-ID tie-break"
gut <- file.path(scratch, "kernel_gutted.cpp")
writeLines(src, gut)
st <- run("fuzz", file.path(scratch, "gutted"), paste0("--kernel=", gut))
g <- rd(file.path(scratch, "gutted", "plan_fuzz.csv"))
say("gutted planner (no tie-break) exits 1", st == 1L)
say(sprintf("gutted planner differs on %d fuzzed calls", sum(g$different)), sum(g$different) > 0L)
utils::write.csv(g, file.path(here, "results", "plan_fuzz_gutted.csv"), row.names = FALSE)
cat(if (ok) "CHECK PASSED\n" else "CHECK FAILED\n")
if (!ok) quit(status = 1L)

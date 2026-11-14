# Spike ephemeral_lane, checker (spike protocol section 6): reruns one
# round of each lane on each workload into a scratch directory and diffs the
# non-timing outputs (final equity, the nine metrics, write-call counts)
# against results/lanes_raw.csv; guards package scope over the spike's own
# commits; and guts one path: the ephemeral crossover with its averages
# swapped (run.R --gut=1) must produce metrics that differ from the record.
#
#   Rscript dev/spikes/ephemeral_lane/check.R --lib=<pin library> --scratch=<dir> --spike-base=<commit>

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), args, value = TRUE)[[1L]])
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
scratch <- opt("scratch"); dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home("bin"), "Rscript.exe")
ok <- TRUE
say <- function(what, pass) { cat(sprintf("%-52s %s\n", what, if (pass) "ok" else "FAILED")); if (!pass) ok <<- FALSE }
rd <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, colClasses = c(final_equity = "character", metrics = "character"))

st <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", opt("lib")), paste0("--out=", scratch), "--rounds=1"),
              stdout = FALSE, stderr = FALSE)
say("one-round rerun exits 0 (parity held)", st == 0L)
rec <- rd(file.path(here, "results", "lanes_raw.csv")); new <- rd(file.path(scratch, "lanes_raw.csv"))
key <- c("shape", "lane", "final_equity", "metrics", "write_calls")
strip <- function(d) { rownames(d) <- NULL; d }
same <- identical(strip(unique(rec[order(rec$shape, rec$lane), key])), strip(new[order(new$shape, new$lane), key]))
say("non-timing outputs equal the recorded ones", isTRUE(same))

scope <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
spike_dir <- sub(paste0("^", repo, "/"), "", here)
mine <- system2("git", c("-C", repo, "log", "--format=%H", paste0(opt("spike-base"), "..HEAD"), "--", spike_dir), stdout = TRUE)
changed <- unlist(lapply(mine, function(h) system2("git", c("-C", repo, "show", "--name-only", "--format=", h, "--", scope), stdout = TRUE)))
say(sprintf("package scope untouched by the spike's %d commits", length(mine)), length(changed) == 0L)

# Gut: the ephemeral crossover with its averages swapped (run.R --gut=1)
# must produce metrics that differ from the recorded ones.
row <- file.path(scratch, "gut_row.csv")
st_g <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", opt("lib")), "--mode=arm", "--lane=ephemeral",
                           "--shape=10x7200", "--gut=1", paste0("--row=", row)), stdout = FALSE, stderr = FALSE)
g <- if (file.exists(row)) rd(row) else NULL
recorded <- unique(rec$metrics[rec$shape == "10x7200"])
say("gutted strategy runs", st_g == 0L && !is.null(g))
say("gutted strategy's metrics differ from the recorded ones", !is.null(g) && !identical(g$metrics, recorded))
cat(if (ok) "CHECK PASSED\n" else "CHECK FAILED\n")
if (!ok) quit(status = 1L)

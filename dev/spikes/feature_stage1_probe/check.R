# Checker (spike protocol section 6). Exits 1 on any failure.
#  1. reruns probe.R into a scratch directory and diffs every deterministic
#     CSV against the recorded one in results/;
#  2. diffs each candidate arm (c2, c3, c23) against the pin, case by case,
#     and requires the gutted arm (c2naive: narrowing custom callbacks to
#     their required fields, seed review F3) to differ;
#  3. requires raw TTR calls to be identical across arms (raw sharing kept);
#  4. reruns census_check.R (walked helpers all classified; the engine-version
#     column proved by mutation);
#  5. guards package scope: nothing under R, src, tests, NAMESPACE,
#     DESCRIPTION, man or inst/design differs from HEAD.
#
#   Rscript check.R --lib=<pinned library> --scratch=<dir outside the repo>
arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
lib <- arg("lib")
scratch <- arg("scratch")
recorded <- file.path(here, "results")
rscript <- file.path(R.home("bin"), "Rscript.exe")
bad <- 0L

# 1. rerun and diff
status <- system2(rscript, c(file.path(here, "probe.R"), paste0("--lib=", lib), paste0("--out=", scratch)))
if (!identical(as.integer(status), 0L)) stop("probe.R failed", call. = FALSE)
for (f in c("census_walk.csv", "check_c23.csv", "check_c23_counts.csv", "check_c23_unions.csv")) {
  same <- identical(readLines(file.path(recorded, f)), readLines(file.path(scratch, f)))
  cat(sprintf("rerun %-22s %s\n", f, if (same) "identical" else "DIFFERS"))
  if (!same) bad <- bad + 1L
}

# 2. arms against the pin
x <- read.csv(file.path(recorded, "check_c23.csv"), stringsAsFactors = FALSE)
key <- paste(x$substrate, x$start, x$set, sep = " | ")
cols <- c("values", "planes", "proj", "reads", "refusal", "refusal_class", "rng")
pin <- x[x$arm == "pin", ]
pin_key <- key[x$arm == "pin"]
for (arm in c("c2", "c3", "c23", "c2naive")) {
  cand <- x[x$arm == arm, ]
  stopifnot(identical(key[x$arm == arm], pin_key))
  diff <- vapply(cols, function(cc) is.na(cand[[cc]]) != is.na(pin[[cc]]) |
                   (!is.na(pin[[cc]]) & !is.na(cand[[cc]]) & cand[[cc]] != pin[[cc]]), logical(nrow(pin)))
  hit <- which(rowSums(diff) > 0L)
  cat(sprintf("%-7s %d cases, %d differ from the pin\n", arm, nrow(pin), length(hit)))
  if (arm == "c2naive") {
    sets <- sort(unique(pin$set[hit]))
    cat("        gutted arm differs on sets:", paste(sets, collapse = ", "), "\n")
    if (length(hit) == 0L) { cat("        negative control NOT detected\n"); bad <- bad + 1L }
  } else {
    for (i in hit) cat("   ", pin_key[[i]], ":", paste(cols[diff[i, ]], collapse = ","), "\n")
    bad <- bad + length(hit)
  }
}
cat("pin refusal cases:", sum(nzchar(pin$refusal_class)), "classes:",
    paste(unique(pin$refusal_class[nzchar(pin$refusal_class)]), collapse = ", "), "\n")
if (!all(x$rng)) { cat("RNG changed in some row\n"); bad <- bad + 1L }

# 3. raw-call sharing
k <- read.csv(file.path(recorded, "check_c23_counts.csv"), stringsAsFactors = FALSE)
k <- k[k$arm != "c2naive", ]
by_case <- split(k$raw_calls, paste(k$substrate, k$set))
shared <- vapply(by_case, function(v) length(unique(v)) == 1L, TRUE)
cat("raw TTR calls identical across arms:", all(shared), "\n")
if (!all(shared)) bad <- bad + 1L

# 4. census
status <- system2(rscript, c(file.path(here, "census_check.R"), paste0("--lib=", lib), paste0("--dir=", recorded)))
if (!identical(as.integer(status), 0L)) { cat("census_check.R failed\n"); bad <- bad + 1L }

# 5. package scope
changed <- system2("git", c("-C", repo, "status", "--porcelain", "--", "R", "src", "tests", "NAMESPACE",
                            "DESCRIPTION", "man", "inst/design"), stdout = TRUE)
cat("package-scope changes:", length(changed), "\n")
if (length(changed) > 0L) { print(changed); bad <- bad + 1L }

if (bad > 0L) { cat("CHECK FAIL:", bad, "\n"); quit(status = 1L) }
cat("CHECK PASS\n")

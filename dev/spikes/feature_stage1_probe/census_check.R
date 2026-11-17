# Candidate 6, step 2: checks census.csv against the walked call graph and
# proves the "engine version" column by mutation. For every census helper
# that is a namespace function, a copy of ledgr_feature_engine_version() is
# evaluated with that one helper replaced; the version must move exactly for
# the rows classified "engine version".
#   Rscript census_check.R --lib=<pinned library> --dir=<results dir>
arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
.libPaths(c(arg("lib"), .libPaths()))
library(ledgr)
ns <- asNamespace("ledgr")
dir <- arg("dir")
walk <- read.csv(file.path(dir, "census_walk.csv"), stringsAsFactors = FALSE)
census <- read.csv(file.path(dir, "census.csv"), stringsAsFactors = FALSE)
missing <- setdiff(walk$helper, census$helper)
cat("walked helpers missing from census.csv:", length(missing), paste(missing, collapse = ", "), "\n")
added <- setdiff(census$helper, walk$helper)
cat("census rows added by hand (not reached from the roots):", paste(added, collapse = ", "), "\n")

base <- ns$ledgr_feature_engine_version()
moves <- vapply(census$helper, function(h) {
  if (identical(h, "ledgr_feature_engine_version") || !exists(h, envir = ns, inherits = FALSE)) return(NA)
  local_env <- new.env(parent = ns)
  assign(h, function(...) stop("mutated helper"), envir = local_env)
  f <- ns$ledgr_feature_engine_version
  environment(f) <- local_env
  # A helper the version computation itself calls (the fingerprint
  # machinery) cannot be replaced by a stub: NA.
  tryCatch(!identical(f(), base), error = function(e) NA)
}, NA)
expected <- startsWith(census$bound_by, "engine version")
wrong <- which(!is.na(moves) & moves != expected)
cat("mutation: helpers whose replacement moves the engine version:", sum(moves, na.rm = TRUE), "\n")
cat("rows where the census column disagrees with the mutation:", length(wrong),
    paste(census$helper[wrong], collapse = ", "), "\n")
counts <- table(ifelse(grepl("^excluded|^identity", census$category), "excluded or identity infrastructure",
  ifelse(expected, "bound: engine version",
    ifelse(grepl("^unbound", census$bound_by), "unbound", "bound by another identity"))))
print(counts)
utils::write.csv(as.data.frame(counts), file.path(dir, "census_counts.csv"), row.names = FALSE)
if (length(missing) > 0L || length(wrong) > 0L) quit(status = 1L)
cat("CENSUS CHECK PASS\n")

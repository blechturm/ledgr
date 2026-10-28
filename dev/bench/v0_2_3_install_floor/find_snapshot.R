# M4: find the earliest Posit Package Manager (P3M) CRAN snapshot, on or after
# the R 4.6.0 release date, in which every version floor that ledgr's
# DESCRIPTION declares on Imports and LinkingTo is satisfied.
#
# Usage (from anywhere):
#   Rscript --vanilla dev/bench/v0_2_3_install_floor/find_snapshot.R \
#     [--root=<ledgr checkout>] [--out=<snapshot_search.csv>]
#
# Method: list P3M's snapshot dates, then binary-search each floor separately
# over the dates on or after the R release (a CRAN version floor, once met,
# stays met unless the package is archived). The joint minimum is the latest
# per-floor minimum; it is then evaluated directly together with the snapshot
# before it, which must fail. Every evaluated snapshot is a row in the CSV.

args <- commandArgs(trailingOnly = TRUE)
value_arg <- function(name, default) {
  hit <- args[startsWith(args, paste0("--", name, "="))]
  if (length(hit) == 0L) default else sub(paste0("^--", name, "="), "", hit[[length(hit)]])
}
file_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
here <- normalizePath(dirname(file_arg), winslash = "/")
root <- value_arg("root", normalizePath(file.path(here, "..", "..", ".."), winslash = "/"))
out <- value_arg("out", file.path(here, "snapshot_search.csv"))

p3m <- "https://packagemanager.posit.co/cran"
# R 4.6.0 release: R-4.6.0.tar.gz is dated 2026-04-24 in
# https://cran.r-project.org/src/base/R-4/ (read 2026-10-28).
r_release <- as.Date(value_arg("r-release", "2026-04-24"))

# Declared floors on hard dependencies (Imports, LinkingTo).
desc <- read.dcf(file.path(root, "DESCRIPTION"), fields = c("Imports", "LinkingTo"))
deps <- trimws(unlist(strsplit(paste(desc[1L, ], collapse = ","), ",")))
deps <- deps[nzchar(deps) & !is.na(deps) & deps != "NA"]
has_floor <- grepl("\\(>=", deps)
floors <- setNames(
  sub("^.*\\(>=[[:space:]]*([^)[:space:]]+)[[:space:]]*\\)$", "\\1", deps[has_floor]),
  sub("[[:space:]]*\\(.*$", "", deps[has_floor])
)
if (any(grepl("\\(", deps[!has_floor]))) stop("Only >= constraints are handled.")
cat("Declared floors:", paste(names(floors), floors, sep = " >= ", collapse = "; "), "\n")

# Snapshot dates published by P3M.
json <- paste(readLines(paste0(
  "https://packagemanager.posit.co/__api__/repos/cran/transaction-dates"
), warn = FALSE), collapse = "")
aliases <- regmatches(json, gregexpr('"alias":"[0-9]{4}-[0-9]{2}-[0-9]{2}"', json))[[1L]]
dates <- sort(unique(as.Date(sub('^"alias":"(.*)"$', "\\1", aliases))))
candidates <- dates[dates >= r_release]
cat(sprintf("P3M snapshots on or after %s: %d (%s .. %s)\n",
            r_release, length(candidates), min(candidates), max(candidates)))

cache <- new.env()
snapshot_versions <- function(date) {
  key <- format(date)
  if (!is.null(cache[[key]])) return(cache[[key]])
  tmp <- tempfile(fileext = ".gz")
  utils::download.file(sprintf("%s/%s/src/contrib/PACKAGES.gz", p3m, key), tmp,
                       quiet = TRUE, mode = "wb")
  db <- read.dcf(gzfile(tmp), fields = c("Package", "Version"))
  unlink(tmp)
  v <- setNames(db[, "Version"], db[, "Package"])
  # Keep the highest version if a package is listed twice.
  v <- tapply(v, names(v), function(x) as.character(max(package_version(x))))
  cache[[key]] <- v
  v
}
meets <- function(date, pkg) {
  v <- snapshot_versions(date)[pkg]
  !is.na(v) && package_version(v) >= package_version(floors[[pkg]])
}

rows <- list()
record <- function(date, purpose) {
  v <- snapshot_versions(date)
  ok <- vapply(names(floors), function(p) meets(date, p), logical(1))
  rows[[length(rows) + 1L]] <<- data.frame(
    snapshot = format(date), purpose = purpose,
    package = names(floors), floor = unname(floors),
    snapshot_version = unname(v[names(floors)]), meets_floor = unname(ok),
    stringsAsFactors = FALSE
  )
  all(ok)
}

# Per-floor earliest snapshot by binary search.
per_floor <- vapply(names(floors), function(pkg) {
  lo <- 1L
  hi <- length(candidates)
  if (!meets(candidates[[hi]], pkg)) stop("No snapshot satisfies ", pkg, " >= ", floors[[pkg]])
  while (lo < hi) {
    mid <- (lo + hi) %/% 2L
    if (meets(candidates[[mid]], pkg)) hi <- mid else lo <- mid + 1L
  }
  lo
}, integer(1))

joint <- max(per_floor)
joint_ok <- record(candidates[[joint]], "joint_minimum")
if (!joint_ok) stop("Joint minimum candidate fails a floor; floors are not monotone.")
if (joint > 1L) {
  prev_ok <- record(candidates[[joint - 1L]], "predecessor_of_joint_minimum")
  if (prev_ok) stop("Predecessor also passes; search is wrong.")
}
for (pkg in names(floors)) {
  i <- per_floor[[pkg]]
  record(candidates[[i]], paste0("earliest_meeting_", pkg))
  if (i > 1L) record(candidates[[i - 1L]], paste0("predecessor_of_earliest_meeting_", pkg))
}
search <- unique(do.call(rbind, rows))
utils::write.csv(search, out, row.names = FALSE)

cat("\nPer-floor earliest snapshot:\n")
for (pkg in names(floors)) {
  cat(sprintf("  %-10s >= %-8s first met %s (version %s)\n", pkg, floors[[pkg]],
              candidates[[per_floor[[pkg]]]],
              snapshot_versions(candidates[[per_floor[[pkg]]]])[[pkg]]))
}
cat(sprintf("\nMINIMUM_SNAPSHOT=%s (predecessor %s fails)\n",
            candidates[[joint]], if (joint > 1L) format(candidates[[joint - 1L]]) else "none"))
cat("Wrote", out, "\n")

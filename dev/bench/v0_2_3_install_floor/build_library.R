# M4: resolve ledgr's minimum environment from one P3M CRAN snapshot, write
# the manifest, and install exactly those versions into a separate library.
#
# Usage:
#   Rscript --vanilla dev/bench/v0_2_3_install_floor/build_library.R \
#     --snapshot=2026-10-24 --lib=C:/Users/maxth/ledgr-wt/m4-libs/lib \
#     [--root=<ledgr checkout>] [--manifest=<manifest.csv>] [--resolve-only]
#
# Roles in the manifest:
#   import      ledgr Imports
#   linking_to  ledgr LinkingTo
#   transitive  recursive Depends/Imports/LinkingTo of the two above
#   check_only  ledgr Suggests and their recursive closure, not already above;
#               the ordinary fast profile runs with the declared Suggests
#               present, as CI's ordinary lane installs them.
# Base-priority packages ship with R and are not listed. Recommended packages
# in the closure are pinned from the snapshot like any other package.
#
# The script also checks coherence: every Depends/Imports/LinkingTo version
# constraint of every manifest package is met by the manifest version, and
# every R (>= x) requirement is met by R 4.6.0, the DESCRIPTION floor.

args <- commandArgs(trailingOnly = TRUE)
value_arg <- function(name, default = NULL) {
  hit <- args[startsWith(args, paste0("--", name, "="))]
  if (length(hit) == 0L) default else sub(paste0("^--", name, "="), "", hit[[length(hit)]])
}
file_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
here <- normalizePath(dirname(file_arg), winslash = "/")
root <- value_arg("root", normalizePath(file.path(here, "..", "..", ".."), winslash = "/"))
snapshot <- value_arg("snapshot")
lib <- value_arg("lib")
manifest_path <- value_arg("manifest", file.path(here, "manifest.csv"))
coherence_path <- file.path(dirname(manifest_path), "coherence.csv")
resolve_only <- "--resolve-only" %in% args
if (is.null(snapshot)) stop("--snapshot=YYYY-MM-DD is required.")
r_floor <- "4.6.0"

repo <- sprintf("https://packagemanager.posit.co/cran/%s", snapshot)
fields <- c("Package", "Version", "Depends", "Imports", "LinkingTo", "Suggests")
ap <- utils::available.packages(
  contriburl = utils::contrib.url(repo, "source"),
  filters = c("R_version", "OS_type", "duplicates"),
  fields = fields
)
base_pkgs <- rownames(utils::installed.packages(.Library, priority = "base"))

split_deps <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0L) return(character())
  d <- trimws(unlist(strsplit(paste(x, collapse = ","), ",")))
  d[nzchar(d)]
}
dep_names <- function(x) sub("[[:space:]]*\\(.*$", "", split_deps(x))

desc <- read.dcf(file.path(root, "DESCRIPTION"), fields = c("Imports", "LinkingTo", "Suggests"))
imports <- setdiff(dep_names(desc[, "Imports"]), base_pkgs)
linking_to <- setdiff(dep_names(desc[, "LinkingTo"]), base_pkgs)
suggests <- setdiff(dep_names(desc[, "Suggests"]), base_pkgs)

closure <- function(pkgs) {
  missing <- setdiff(pkgs, rownames(ap))
  if (length(missing) > 0L) stop("Not in snapshot: ", paste(missing, collapse = ", "))
  deps <- tools::package_dependencies(
    pkgs, db = ap, which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE
  )
  all <- setdiff(unique(c(pkgs, unlist(deps, use.names = FALSE))), c(base_pkgs, "R"))
  missing <- setdiff(all, rownames(ap))
  if (length(missing) > 0L) stop("Unresolvable in snapshot: ", paste(missing, collapse = ", "))
  all
}

hard <- closure(c(imports, linking_to))
check <- setdiff(closure(suggests), hard)
role <- c(
  setNames(rep("import", length(imports)), imports),
  setNames(rep("linking_to", length(linking_to)), linking_to),
  setNames(rep("transitive", length(setdiff(hard, c(imports, linking_to)))),
           setdiff(hard, c(imports, linking_to))),
  setNames(rep("check_only", length(check)), check)
)
role_order <- c(import = 1L, linking_to = 2L, transitive = 3L, check_only = 4L)
pkgs <- names(role)
manifest <- data.frame(
  package = pkgs,
  version = unname(ap[pkgs, "Version"]),
  role = unname(role),
  snapshot_repo = repo,
  source_url = sprintf("%s/src/contrib/%s_%s.tar.gz", repo, pkgs, ap[pkgs, "Version"]),
  stringsAsFactors = FALSE
)
manifest <- manifest[order(role_order[manifest$role], tolower(manifest$package)), ]
rownames(manifest) <- NULL

# Coherence: every declared constraint inside the set is met.
parse_constraints <- function(field_value) {
  d <- split_deps(field_value)
  d <- d[grepl("\\(", d)]
  if (length(d) == 0L) return(NULL)
  data.frame(
    dep = sub("[[:space:]]*\\(.*$", "", d),
    op = sub("^.*\\([[:space:]]*([<>=!]+).*$", "\\1", d),
    required = sub("^.*\\([[:space:]]*[<>=!]+[[:space:]]*([^)[:space:]]+)[[:space:]]*\\)$", "\\1", d),
    stringsAsFactors = FALSE
  )
}
avail <- setNames(manifest$version, manifest$package)
coh <- list()
for (p in manifest$package) {
  for (f in c("Depends", "Imports", "LinkingTo")) {
    cons <- parse_constraints(ap[p, f])
    if (is.null(cons)) next
    for (i in seq_len(nrow(cons))) {
      dep <- cons$dep[[i]]
      have <- if (identical(dep, "R")) r_floor else if (dep %in% base_pkgs) {
        as.character(getRversion())
      } else unname(avail[dep])
      ok <- !is.na(have) && do.call(cons$op[[i]], list(package_version(have), package_version(cons$required[[i]])))
      coh[[length(coh) + 1L]] <- data.frame(
        package = p, field = f, dependency = dep, constraint = paste(cons$op[[i]], cons$required[[i]]),
        manifest_version = if (identical(dep, "R")) paste0("R ", r_floor) else have,
        satisfied = ok, stringsAsFactors = FALSE
      )
    }
  }
}
coh <- do.call(rbind, coh)
coh <- coh[order(coh$package, coh$field, coh$dependency), ]
utils::write.csv(manifest, manifest_path, row.names = FALSE)
utils::write.csv(coh, coherence_path, row.names = FALSE)
cat(sprintf("Snapshot %s: %d packages (%s)\n", snapshot, nrow(manifest),
            paste(names(table(manifest$role)), table(manifest$role), sep = "=", collapse = ", ")))
cat(sprintf("Coherence: %d constraints, %d unmet\n", nrow(coh), sum(!coh$satisfied)))
if (any(!coh$satisfied)) {
  print(coh[!coh$satisfied, ], row.names = FALSE)
  stop("Manifest is not coherent.")
}
if (resolve_only) quit(save = "no", status = 0L)

# Install into the separate library only. Nothing outside `lib` is visible to
# this process or to the R CMD INSTALL children it starts.
if (is.null(lib)) stop("--lib=<path> is required to install.")
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
lib <- normalizePath(lib, winslash = "/")
no_lib <- file.path(dirname(lib), "no-such-library")
Sys.setenv(R_LIBS = lib, R_LIBS_USER = no_lib, R_LIBS_SITE = no_lib)
.libPaths(c(lib, .Library))
cat("Library paths:", paste(.libPaths(), collapse = " | "), "\n")

bin_type <- if (.Platform$OS.type == "windows") "win.binary" else "source"
bin <- utils::available.packages(contriburl = utils::contrib.url(repo, bin_type),
                                 filters = list(), fields = "Path")
bin_row <- match(manifest$package, bin[, "Package"])
bin_version <- bin[bin_row, "Version"]
# P3M lists Windows binaries of recommended packages under a `Path`
# subdirectory (4.6.2/Recommended) that returns 404 for this snapshot; those
# packages are installed from the snapshot's source tarball instead.
bin_path <- bin[bin_row, "Path"]
use_binary <- !is.na(bin_version) & bin_version == manifest$version & is.na(bin_path)
cat(sprintf("Binary (%s) at manifest version: %d of %d\n", bin_type, sum(use_binary), nrow(manifest)))
if (any(!use_binary)) {
  cat("Source installs:", paste(manifest$package[!use_binary], collapse = ", "), "\n")
}
options(install.packages.compile.from.source = "always")
if (any(use_binary)) {
  utils::install.packages(manifest$package[use_binary], lib = lib,
                          contriburl = utils::contrib.url(repo, bin_type),
                          type = bin_type, dependencies = FALSE, quiet = TRUE)
}
if (any(!use_binary)) {
  # Source installs need their dependencies first; install in closure order.
  src <- manifest$package[!use_binary]
  deps <- tools::package_dependencies(src, db = ap, which = c("Depends", "Imports", "LinkingTo"))
  ordered <- character()
  while (length(src) > 0L) {
    ready <- src[vapply(src, function(p) !any(deps[[p]] %in% src), logical(1))]
    if (length(ready) == 0L) stop("Dependency cycle among source installs.")
    ordered <- c(ordered, ready)
    src <- setdiff(src, ready)
  }
  for (p in ordered) {
    utils::install.packages(p, lib = lib, type = "source",
                            dependencies = FALSE, quiet = TRUE,
                            contriburl = utils::contrib.url(repo, "source"))
  }
}
manifest$installed_type <- ifelse(use_binary, bin_type, "source")
utils::write.csv(manifest, manifest_path, row.names = FALSE)
got <- utils::installed.packages(lib.loc = lib, noCache = TRUE)[, "Version"]
short <- manifest$package[is.na(got[manifest$package]) | got[manifest$package] != manifest$version]
if (length(short) > 0L) stop("Not installed at the manifest version: ", paste(short, collapse = ", "))
cat("Installed into", lib, "\n")

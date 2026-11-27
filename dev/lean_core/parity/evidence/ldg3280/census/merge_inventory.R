# LDG-3280: merge the slice files into inventory.csv, fill seed/probe status
# from census_hits.csv, check seed coverage, and list the claims registry
# entries whose detecting blocks are inventoried.
#   Rscript merge_inventory.R <out dir> <pin tests dir> <probe dir>
args <- commandArgs(TRUE)
odir <- args[[1L]]; tests <- args[[2L]]; pdir <- args[[3L]]
parts <- c("part_parent.csv", "part_ws4a.csv", "part_controls.csv", "part_handler.csv", "part_strategy.csv")
x <- do.call(rbind, lapply(parts, function(p) {
  d <- utils::read.csv(file.path(odir, p), stringsAsFactors = FALSE, colClasses = "character", encoding = "UTF-8")
  d$slice <- sub("^part_(.*)\\.csv$", "\\1", p)
  d
}))
b <- utils::read.csv(file.path(odir, "census_hits.csv"), stringsAsFactors = FALSE)
seed <- utils::read.csv(file.path(pdir, "e_suite_classification.csv"), stringsAsFactors = FALSE)
key <- function(f, t) paste(f, t, sep = "\r")
m <- match(key(x$file, x$test), key(b$file, b$test))
is_block <- !is.na(m)
x$in_seed <- ifelse(is_block, ifelse(b$in_seed[m], "yes", "no"), "no")
x$probe_status <- ifelse(is_block,
  ifelse(b$probe_error[m], "error", ifelse(b$probe_failed[m] > 0L, "fail", ifelse(b$probe_skipped[m], "skip", "pass"))),
  "n/a (helper/detector/registry)")
x$first <- ifelse(is_block, b$first[m], NA_integer_)
x$kind <- ifelse(is_block, "block", ifelse(x$file == "tests/claims.yml", "registry",
  ifelse(grepl("^tools/", x$file), "detector", "helper")))
# merge rows that name the same block (a block split across slices)
k <- key(x$file, x$test)
dup <- unique(k[duplicated(k)])
for (d in dup) {
  w <- which(k == d)
  hs <- unique(x$handling[w])
  keep <- w[[1L]]
  for (col in c("asserts", "depends_on", "target_or_authority", "justification", "slice")) {
    x[[col]][keep] <- paste(unique(x[[col]][w]), collapse = " || ")
  }
  if (length(hs) > 1L) {
    x$handling[keep] <- if ("f" %in% hs) "f" else hs[[1L]]
    x$justification[keep] <- paste0(x$justification[keep], " || MERGED ROWS HAD HANDLING ", paste(hs, collapse = "/"))
  }
  x <- x[-w[-1L], ]
  k <- key(x$file, x$test)
}
x$handling <- trimws(x$handling)
stopifnot(all(x$handling %in% c("a", "b", "c", "d", "e", "f")))
miss <- seed[!(key(seed$file, seed$test) %in% key(x$file, x$test)), c("file", "test")]
cat("seed rows covered:", nrow(seed) - nrow(miss), "of", nrow(seed), "\n")
if (nrow(miss)) print(miss)
ord <- order(x$kind != "block", x$file, x$first, x$test)
x <- x[ord, ]
cols <- c("file", "test", "claim", "asserts", "depends_on", "in_seed", "probe_status", "handling",
          "target_or_authority", "justification")
utils::write.csv(x[cols], file.path(odir, "inventory.csv"), row.names = FALSE, fileEncoding = "UTF-8")
cat("rows", nrow(x), "blocks", sum(x$kind == "block"), "helpers", sum(x$kind == "helper"),
    "detectors", sum(x$kind == "detector"), "registry", sum(x$kind == "registry"), "\n")
cat("blocks per handling:\n"); print(table(x$handling[x$kind == "block"]))
cat("all rows per handling:\n"); print(table(x$handling))
cat("blocks from seed:", sum(x$kind == "block" & x$in_seed == "yes"), " from census:", sum(x$kind == "block" & x$in_seed == "no"), "\n")
cat("census blocks by probe status:\n"); print(table(x$probe_status[x$kind == "block" & x$in_seed == "no"]))
cat("per file (blocks):\n"); print(sort(table(x$file[x$kind == "block"]), decreasing = TRUE))
# claims registry: LCL entries whose detecting blocks are inventoried
cl <- yaml::read_yaml(file.path(tests, "claims.yml"))
claims <- if (!is.null(cl$claims)) cl$claims else cl
ltb <- unique(unlist(regmatches(x$claim[x$kind == "block"], gregexpr("LTB-[0-9]{4}", x$claim[x$kind == "block"]))))
hit <- Filter(function(e) any(unlist(e$detecting_blocks) %in% ltb), claims)
reg <- data.frame(lcl = vapply(hit, function(e) e$id, ""),
  blocks = vapply(hit, function(e) paste(unlist(e$detecting_blocks), collapse = " "), ""),
  stringsAsFactors = FALSE)
reg$inventory_handling <- vapply(reg$blocks, function(bl) {
  ids <- strsplit(bl, " ")[[1L]]
  h <- vapply(ids, function(id) {
    w <- grep(id, x$claim[x$kind == "block"], fixed = TRUE); w <- which(x$kind == "block")[w]
    if (length(w)) paste(sort(unique(x$handling[w])), collapse = "") else "-"
  }, "")
  paste(paste0(ids, ":", h), collapse = " ")
}, "")
utils::write.csv(reg, file.path(odir, "claims_registry_affected.csv"), row.names = FALSE)
cat("claims.yml entries with an inventoried detecting block:", nrow(reg), "\n")
print(reg, row.names = FALSE)

# LDG-3271 (Cut 26 decision 2): the earlier committed records whose worker
# sweeps (A0's sweep_w2 path) may have loaded a source package instead of
# the pin, and their demonstrated launch directories. No record is changed.
#
# A lean-harness record (loop_parity.R, plan_parity.R, the feature oracle's
# lean gate) compares the installed pin with the lean loop over it; run from
# a ledgr source package root, its worker sweeps loaded that source in both
# arms (ledgr_parallel_ledgr_source_path()), so those tables were not a pin
# comparison of the worker path. An A0 harness record loads the source tree
# with pkgload by design (dev/bench/v0_2_3_output_freeze/lib.R a0_load), so
# its workers always ran that source: not affected in this sense.
#
# The launch directory is "repository root" when the committed commands in
# the record's folder (or a parent up to the evidence root) start the runner
# with a relative script path (Rscript dev/...), which only resolves from the
# repository root; otherwise "unknown". Only the notes (.md, .txt) inside the
# evidence tree count.
#
#   Rscript dev/lean_core/parity/evidence/ldg3271/inventory.R --repo=<tree> --out=<csv>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  repo <- normalizePath(arg("repo"), winslash = "/")
  files <- system2("git", c("-C", repo, "ls-files", "*.csv"), stdout = TRUE)
  has_w2 <- vapply(files, function(f) {
    x <- readLines(file.path(repo, f), warn = FALSE)
    any(grepl("sweep_w2", x, fixed = TRUE, useBytes = TRUE))
  }, logical(1))
  files <- files[has_w2]
  harness <- ifelse(grepl("^dev/lean_core/", files) | grepl("/lean/gate", files), "lean harness", "A0 harness")
  runner_pattern <- "loop_parity\\.R|plan_parity\\.R|lean_gate\\.R|recorder/run\\.R|loop_variants\\.R"
  launch <- vapply(seq_along(files), function(i) {
    if (harness[[i]] != "lean harness") return("not applicable (A0 loads the source tree by design)")
    dir <- dirname(file.path(repo, files[[i]]))
    # Only the record's own notes count, up to its evidence root; a runner's
    # usage comment is not a record of how a run was started.
    while (grepl("/evidence(/|$)", substring(dir, nchar(repo) + 1L))) {
      docs <- list.files(dir, pattern = "[.](md|txt)$", full.names = TRUE)
      for (d in docs) {
        x <- readLines(d, warn = FALSE)
        hit <- grep(runner_pattern, x, value = TRUE)
        if (any(grepl("Rscript +dev/", hit))) return(paste0("repository root (", substring(d, nchar(repo) + 2L), ")"))
        if (any(grepl("Rscript +[A-Za-z]:/", hit))) return(paste0("absolute script path, directory not recorded (",
                                                                    substring(d, nchar(repo) + 2L), ")"))
      }
      dir <- dirname(dir)
    }
    "unknown"
  }, "")
  rows <- vapply(files, function(f) {
    x <- utils::read.csv(file.path(repo, f), stringsAsFactors = FALSE, colClasses = "character")
    cols <- intersect(c("path", "workload", "case", "table"), names(x))
    sum(vapply(cols, function(cl) sum(x[[cl]] == "sweep_w2" | grepl("sweep_w2", x[[cl]], fixed = TRUE)), 0))
  }, 0)
  out <- data.frame(record = files, harness = harness, sweep_w2_rows = as.integer(rows), launch_directory = launch,
                    stringsAsFactors = FALSE)
  out <- out[order(out$harness, out$record, method = "radix"), ]
  utils::write.csv(out, arg("out"), row.names = FALSE)
  print(table(out$harness))
  print(table(sub(" \\(.*$", "", out$launch_directory[out$harness == "lean harness"])))
})

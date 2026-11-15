# Per-stage time per pulse of the lean loop, two commits, alternating runs.
# Rscript stages.R <shape> <rounds> <commitA> <commitB>
a <- commandArgs(TRUE)
lib <- "C:/Users/maxth/AppData/Local/Temp/claude/a337d437c6e22de3/78383ced-ac83-4579-b480-65f39660106d/scratchpad/ws16/lib-d5b3a151"
.libPaths(c(lib, .libPaths()))
root <- "C:/Users/maxth/Documents/GitHub/ledgr"
ns <- asNamespace("ledgr")
load_arm <- function(commit) {
  listed <- system2("git", c("-C", root, "ls-tree", "--name-only", sub("[+]dummytop$", "", commit), "dev/lean_core/"), stdout = TRUE)
  files <- setdiff(basename(listed[grepl("[.]R$", listed)]), c("load.R", "prepare.R"))
  lean <- new.env(parent = ns)
  lean$.lean_debug <- FALSE
  lean$.clk <- new.env()
  dummies <- grepl("[+]dummytop$", commit)
  commit <- sub("[+]dummytop$", "", commit)
  for (f in files) {
    x <- system2("git", c("-C", root, "show", paste0(commit, ":dev/lean_core/", f)), stdout = TRUE)
    if (f == "loop.R") {
      if (dummies) {
        j <- grep("^lean_fold_envelope <- function", x)
        stopifnot(length(j) == 1L)
        x <- append(x, sprintf("  dummy_%02d <- NULL", 1:12), after = j)
      }
      wrap <- function(x, pat, name) {
        k <- grep(pat, x)
        if (length(k) != 1L) stop("anchor ", pat, " matched ", length(k))
        lhs <- sub("^(\\s*)(.*?<- )?(.*)$", "\\1\\2", x[[k]], perl = TRUE)
        rhs <- sub("^(\\s*)(.*?<- )?(.*)$", "\\3", x[[k]], perl = TRUE)
        x[[k]] <- paste0(lhs, "{ .t0 <- as.numeric(Sys.time()); .r <- ", rhs, "; .clk$", name, " <- .clk$", name,
                         " + (as.numeric(Sys.time()) - .t0); .r }")
        x
      }
      x <- wrap(x, "^      v1 <- lean_p1_value\\(i\\)$", "p1")
      x <- wrap(x, "^      v2 <- .*lean_p2_decide\\(i, v1\\)", "p2")
      x <- wrap(x, "^      v3 <- lean_p3_plan\\(i, v1, v2\\)$", "p3")
      x <- wrap(x, "^      n_fill <- lean_p4_apply\\(", "p4")
      x <- wrap(x, "^      lean_p5_commit\\(", "p5")
    }
    exprs <- parse(text = x, keep.source = FALSE)
    for (e in exprs) eval(e, lean)
  }
  for (f in ls(lean, all.names = TRUE)) if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
  lean
}
arms <- list(A = load_arm(a[[3L]]), B = load_arm(a[[4L]]))
defs <- new.env(parent = ns)
sys.source(file.path(root, "dev/spikes/r_floor/fixture.R"), envir = defs, keep.source = FALSE)
sys.source(file.path(root, "dev/bench/v0_2_3_lean_tuning_profile/descriptors.R"), envir = defs, keep.source = FALSE)
desc <- defs$bench_descriptor(a[[1L]])
store <- file.path(tempdir(), "s.duckdb")
ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "p", price_basis = "split_adjusted"))
snapshot <- ledgr::ledgr_snapshot_open(store, "p", verify = TRUE)
exp <- desc$experiment(snapshot)
res <- list()
run_arm <- function(nm, r) {
  lean <- arms[[nm]]
  for (s in c("p1", "p2", "p3", "p4", "p5")) assign(s, 0, envir = lean$.clk)
  restore <- lean$lean_loop_install()
  on.exit(restore())
  t0 <- as.numeric(Sys.time())
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = paste0(nm, r), seed = 20260530L))
  whole <- as.numeric(Sys.time()) - t0
  close(bt)
  c(unlist(mget(c("p1", "p2", "p3", "p4", "p5"), envir = lean$.clk)), whole = whole)
}
run_arm("A", 0); run_arm("B", 0)
n <- as.integer(a[[2L]])
for (r in seq_len(n)) for (nm in if (r %% 2L) c("A", "B") else c("B", "A")) res[[length(res) + 1L]] <- c(arm = nm, run_arm(nm, r))
m <- as.data.frame(do.call(rbind, res), stringsAsFactors = FALSE)
for (k in 2:ncol(m)) m[[k]] <- as.numeric(m[[k]])
med <- aggregate(. ~ arm, m, median)
print(med)
pulses <- c("10x7200" = 7200, "20x23400" = 23400, "slice2_10x7200" = 7200, "500x1260" = 1260)[[a[[1L]]]]
d <- unlist(med[med$arm == "B", -1]) - unlist(med[med$arm == "A", -1])
print(round(1e6 * d / pulses, 2))

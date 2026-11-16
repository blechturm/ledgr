# Store-write drill (macro WS16 "Order after Cut 20", item a): where the
# write after the pulse loop spends its time. Profiles the lean arm (debug
# off, byte-compiled, production hooks, as stage_drill.R) and, within the
# samples under lean_loop_publish (in Rprof: fn under hooks$publish),
# writes aggregate shares only:
#
#   callees.csv  each direct callee of lean_loop_publish ("<self>" for its own
#                body) and, within it, the share by layer: "duckdb native"
#                (a .Call or .External leaf under a DBI or duckdb frame),
#                "DBI/duckdb R" (R code of DBI or duckdb), "ledgr R" (the rest)
#   layers.csv   the same layers over the whole publish
#   owners.csv   the deepest ledgr-owned frame of each publish sample (a
#                package or lean function, or a handler or writer method), top 30
#   leaves.csv   the leaf frames of the publish samples, top 25 per shape
#   share.csv    the publish's share of the profiled samples per shape
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/store_drill.R --lib=<pinned library> --out=<dir>
#     [--runs=500x1260:10,1166x252:40,20x23400:1,10x7200:3]
#
# Rprof estimates at 2 ms; the cost map (cost_map.R) holds the clocks.

arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
out <- arg("out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(arg("lib"), debug = FALSE)
for (f in ls(lean, all.names = TRUE)) {
  g <- get(f, envir = lean)
  if (is.function(g) && identical(environment(g), lean)) assign(f, compiler::cmpfun(g), envir = lean)
}
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
source(file.path(here, "descriptors.R"))
kv <- strsplit(strsplit(arg("runs", "500x1260:10,1166x252:40,20x23400:1,10x7200:3"), ",")[[1L]], ":")
runs <- stats::setNames(as.integer(vapply(kv, `[[`, "", 2L)), vapply(kv, `[[`, "", 1L))
work <- file.path(tempdir(), "store_drill")
dir.create(work, showWarnings = FALSE)

db_frames <- setdiff(c(ls(asNamespace("DBI")), ls(asNamespace("duckdb"), all.names = TRUE)),
                     c(ls(baseenv(), all.names = TRUE), ls(asNamespace("ledgr"), all.names = TRUE), "fn", "FUN"))
layer_of <- function(s) {   # s: one stack, leaf first
  # Only frames below the publish count: the run transaction holds DBI frames above it.
  s <- s[seq_len(match("hooks$publish", s) - 1L)]
  in_db <- any(s %in% db_frames | grepl("^(DBI|duckdb)::", s) | grepl("^rapi_", s))
  if (!in_db) return("ledgr R")
  if (s[[1L]] %in% c(".Call", ".External", ".External2") || grepl("^rapi_", s[[1L]])) "duckdb native" else "DBI/duckdb R"
}
tab <- function(x) { t <- sort(table(x), decreasing = TRUE); data.frame(key = names(t), samples = as.integer(t), stringsAsFactors = FALSE) }

restore <- lean$lean_loop_install(hooks = FALSE)
res <- list(callees = list(), layers = list(), owners = list(), leaves = list(), share = list())
ledgr_names <- ls(asNamespace("ledgr"), all.names = TRUE)
for (s in names(runs)) {
  dsc <- bench_descriptor(s)
  sealed <- file.path(work, paste0(s, ".duckdb"))
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(dsc$bars(),
    db_path = sealed, snapshot_id = paste0("sw_", s), price_basis = "split_adjusted"))
  stacks <- list()
  for (r in 0:runs[[s]]) {                # run 0 warms up and is not profiled
    db <- file.path(work, "run.duckdb")
    if (file.exists(db)) unlink(db)
    file.copy(sealed, db)
    snap <- ledgr::ledgr_snapshot_open(db, paste0("sw_", s), verify = TRUE)
    prof <- file.path(work, "run.rprof")
    invisible(gc())
    if (r > 0L) Rprof(prof, interval = 0.002)
    bt <- ledgr::ledgr_run(dsc$experiment(snap), run_id = "sw", seed = 20260530L)
    if (r > 0L) {
      Rprof(NULL)
      l <- readLines(prof)
      l <- l[!grepl("^sample.interval|^#", l)]
      stacks <- c(stacks, lapply(strsplit(l, " ", fixed = TRUE), function(x) gsub('"', "", x)))
    }
    close(bt)
    ledgr::ledgr_snapshot_close(snap)
  }
  # Under the production hooks the publish runs as fn() inside hooks$publish.
  pub <- Filter(function(x) "hooks$publish" %in% x, stacks)
  res$share[[s]] <- data.frame(shape = s, runs = runs[[s]], samples = length(stacks), publish = length(pub),
                               share = round(length(pub) / length(stacks), 3))
  callee <- vapply(pub, function(x) { j <- match("hooks$publish", x) - 1L; if (j <= 1L) "<self>" else x[[j - 1L]] }, "")
  layer <- vapply(pub, layer_of, "")
  ct <- as.data.frame.matrix(table(callee, layer))
  ct <- cbind(shape = s, callee = rownames(ct), total = rowSums(ct), ct, stringsAsFactors = FALSE)
  res$callees[[s]] <- ct[order(-ct$total), ]
  res$layers[[s]] <- cbind(shape = s, tab(layer), share = round(tab(layer)$samples / length(pub), 3))
  # The deepest ledgr-owned frame (package function, lean function or a
  # handler or writer method) of each sample: which ledgr call owns the time.
  owner <- vapply(pub, function(x) {
    hit <- which(x %in% ledgr_names | grepl("^(lean_|ledgr_)|\\$", x))
    if (length(hit)) x[[hit[[1L]]]] else "<none>"
  }, "")
  ow <- tab(owner)
  res$owners[[s]] <- cbind(shape = s, utils::head(ow, 30L), share = round(utils::head(ow, 30L)$samples / length(pub), 3))
  lv <- tab(vapply(pub, `[[`, "", 1L))
  res$leaves[[s]] <- cbind(shape = s, utils::head(lv, 25L), share = round(utils::head(lv, 25L)$samples / length(pub), 3))
}
restore()
bind <- function(x) { cols <- unique(unlist(lapply(x, names))); do.call(rbind, lapply(x, function(d) { d[setdiff(cols, names(d))] <- 0L; d[cols] })) }
for (k in names(res)) utils::write.csv(bind(res[[k]]), file.path(out, paste0(k, ".csv")), row.names = FALSE)
print(bind(res$share), row.names = FALSE)
print(bind(res$layers), row.names = FALSE)
print(bind(res$callees), row.names = FALSE)

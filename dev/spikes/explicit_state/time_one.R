# One timed run in a fresh process (LDG-3278 timing): the lean loop as is or
# the explicit-state fork (set "all"), debug off, inert hooks with a clock on
# fold_end, on one descriptor shape; one untimed warm-up run first, then the
# timed run. Appends one row to --out.
#   Rscript time_one.R --lib=<pinned library> --shape=10x7200 --arm=asis|fork|p5 --pair=<k> --out=<csv>
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) stop("--", name, "= is required", call. = FALSE)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
shape <- arg("shape"); arm <- arg("arm"); out <- arg("out")
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev", "lean_core", "load.R"))
lean <- lean_core_load(arg("lib"), debug = FALSE)
if (arm %in% c("fork", "p5")) {   # fork: every concern in shared environments; p5: P5 takes and returns its state
  sys.source(file.path(here, "transform.R"), envir = lean, keep.source = FALSE)
  sys.source(file.path(here, "take_return.R"), envir = lean, keep.source = FALSE)
  lean$es_install(lean, if (identical(arm, "fork")) "all" else "p5")
} else if (!identical(arm, "asis")) stop("--arm must be asis, fork or p5", call. = FALSE)
ns <- asNamespace("ledgr")
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
source(file.path(repo, "dev/bench/v0_2_3_lean_tuning_profile/descriptors.R"))
desc <- bench_descriptor(shape)
work <- tempfile("es_time_")
dir.create(work)
sealed <- file.path(work, "sealed.duckdb")
ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = sealed,
  snapshot_id = paste0("es_", shape), price_basis = "split_adjusted"))
now <- function() proc.time()[["elapsed"]]
run <- function(label) {
  db <- file.path(work, paste0("run_", label, ".duckdb"))
  file.copy(sealed, db)
  snapshot <- ledgr::ledgr_snapshot_open(db, paste0("es_", shape), verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- desc$experiment(snapshot)
  clock <- new.env(parent = emptyenv())
  restore <- lean$lean_loop_install(hooks = FALSE)
  on.exit(restore(), add = TRUE)
  lean$lean_hooks <- utils::modifyList(lean$lean_hooks_inert(), list(fold_end = function(stats) clock$pulses <- stats$pulses))
  invisible(gc())
  t0 <- now()
  bt <- ledgr::ledgr_run(exp, run_id = "es-run", seed = 20260530L)
  whole <- now() - t0
  digest <- rlang::hash(list(ledgr::ledgr_results(bt, "fills"), ledgr::ledgr_results(bt, "equity")))
  close(bt)
  if (is.null(clock$pulses)) stop("the lean fold did not run", call. = FALSE)
  list(pulses = as.numeric(clock$pulses), whole = whole, digest = digest)
}
invisible(run("warm"))
x <- run("timed")
row <- data.frame(shape = shape, arm = arm, pair = as.integer(arg("pair")), pulses_s = x$pulses, whole_s = x$whole,
                  digest = x$digest, pid = Sys.getpid(), stringsAsFactors = FALSE)
utils::write.table(row, out, sep = ",", row.names = FALSE, col.names = !file.exists(out), append = file.exists(out))
cat(sprintf("%s %s pair %s: pulses %.3f s, whole %.3f s\n", shape, arm, arg("pair"), x$pulses, x$whole))

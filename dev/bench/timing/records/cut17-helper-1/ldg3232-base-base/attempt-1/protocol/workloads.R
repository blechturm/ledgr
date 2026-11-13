# Cut 17 (LDG-3232, LDG-3233): the sizing helpers timed per call, base
# against candidate, each arm its own installed package; and one descriptive
# whole run of slice2_10x7200 through ledgr_run(). The runner is launched with
#   --candidate-overlay=dev/bench/v0_2_3_helper/views.R,dev/bench/v0_2_3_lean_tuning_profile/descriptors.R,dev/spikes/r_floor/fixture.R
# so both arms read the view capture, the helper arguments, the slice2
# descriptor and the bars from the same exported files. Neither arm
# installs the lean core.
#
#   call  wall time of `reps` helper calls on one warmed genuine pulse view
#         (cached context: the view's columns were read by a warm-up call),
#         after a full gc(); the view is captured from an 8-pulse run
#         outside the clock
#   run   wall time of the ledgr_run() call on slice2_10x7200
# The work string pins the helper's result (a digest of the serialized
# value) or, for the run, fills, final equity, the fills digest, the sizing
# diagnostics digest and the reach counts, so both arms of a record must
# return identical results.

cut17_defs <- function(args) {
  if (!is.character(args$.overlay)) stop("cut17-helper-1: run with --candidate-overlay (the shared definitions)")
  if (!isTRUE(args$.arm %in% c("base", "candidate"))) stop("cut17-helper-1: unknown arm ", args$.arm)
  defs <- new.env(parent = asNamespace("ledgr"))
  for (f in c("dev/spikes/r_floor/fixture.R", "dev/bench/v0_2_3_helper/views.R", "dev/bench/v0_2_3_lean_tuning_profile/descriptors.R")) {
    sys.source(file.path(args$.overlay, f), envir = defs, keep.source = FALSE)
  }
  defs
}
cut17_sha <- function(x) substr(digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE), 1L, 16L)

cut17_helper <- function(args, work_dir) {
  defs <- cut17_defs(args)
  n <- as.integer(args$n)
  reps <- as.integer(args$reps)
  verb <- args$verb
  cap <- defs$helper_capture_views(n, keep = 4L, db_path = file.path(work_dir, "store.duckdb"))
  a <- defs$helper_view_args(cap$views[[1L]], verb)
  value <- defs$helper_call(verb, a)        # warm-up: reads the view's columns
  invisible(gc(FALSE))
  t0 <- as.numeric(Sys.time())
  for (i in seq_len(reps)) defs$helper_call(verb, a)
  call_s <- as.numeric(Sys.time()) - t0
  list(seconds = c(call = call_s), work = paste(verb, n, reps, cut17_sha(value), cap$provenance$inputs_digest, sep = "|"),
       overlay_arm = args$.arm)
}

cut17_slice2 <- function(args, work_dir) {
  defs <- cut17_defs(args)
  desc <- defs$bench_descriptor(args$shape)
  store <- file.path(work_dir, "store.duckdb")
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "cut17",
    price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(store, "cut17", verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- desc$experiment(snapshot)
  t0 <- as.numeric(Sys.time())
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "cut17-slice2", seed = 20260530L))
  run_s <- as.numeric(Sys.time()) - t0
  reach <- desc$reach(bt)
  if (!defs$bench_reach_ok(reach)) stop("cut17-helper-1: slice2 reach not established: ", paste(names(reach), reach, collapse = ", "))
  fills <- as.data.frame(ledgr::ledgr_results(bt, "fills"))
  eq <- ledgr::ledgr_results(bt, "equity")
  diag <- as.data.frame(ledgr::ledgr_results(bt, "diagnostics"))
  sizing <- diag[!is.na(diag$stage) & diag$stage == "sizing", , drop = FALSE]
  close(bt)
  work <- paste(args$shape, nrow(fills), format(eq$equity[nrow(eq)], digits = 17), cut17_sha(fills), nrow(sizing), cut17_sha(sizing),
                paste(names(reach), reach, sep = "=", collapse = ","), sep = "|")
  list(seconds = c(run = run_s), work = work, overlay_arm = args$.arm)
}

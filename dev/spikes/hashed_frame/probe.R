# Prerequisite probe (README): the fork loads, its frame is hashed, its stage
# functions are byte-compiled, and one run returns the current lean loop's
# tables. Rscript dev/spikes/hashed_frame/probe.R --lib=<pinned library> [--shape=10x7200]
args <- commandArgs(TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
root <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(root, "dev", "lean_core", "load.R"))
lean <- lean_core_load(opt("lib"))
for (f in ls(lean, all.names = TRUE)) if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
plain <- lean$lean_fold_envelope
sys.source(file.path(here, "hashed.R"), envir = lean, keep.source = FALSE)
hashed <- lean$lean_fold_envelope
# Probe hook: the fork, keeping the environment it evaluates in.
seen <- new.env()
lean$lean_fold_envelope <- compiler::cmpfun(function(execution, output_handler) {
  E <- new.env(hash = TRUE, parent = environment())
  seen$E <- E
  eval(lean_envelope_code, E)
})
environment(lean$lean_fold_envelope) <- lean

ns <- asNamespace("ledgr")
defs <- new.env(parent = ns)
sys.source(file.path(root, "dev/spikes/r_floor/fixture.R"), envir = defs, keep.source = FALSE)
sys.source(file.path(root, "dev/bench/v0_2_3_lean_tuning_profile/descriptors.R"), envir = defs, keep.source = FALSE)
desc <- defs$bench_descriptor(opt("shape", "10x7200"))
store <- file.path(tempdir(), "probe.duckdb")
ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "p",
  price_basis = "split_adjusted"))
snapshot <- ledgr::ledgr_snapshot_open(store, "p", verify = TRUE)
exp <- desc$experiment(snapshot)
tables <- function(envelope, id) {
  lean$lean_fold_envelope <- envelope
  restore <- lean$lean_loop_install()
  on.exit(restore())
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = id, seed = 20260530L))
  on.exit(close(bt), add = TRUE)
  lapply(c(fills = "fills", equity = "equity", trades = "trades"), function(w) as.data.frame(ledgr::ledgr_results(bt, w)))
}
probe_fork <- lean$lean_fold_envelope
a <- tables(plain, "plain")
b <- tables(probe_fork, "fork")
E <- seen$E
compiled <- function(f) identical(typeof(.Internal(bodyCode(f))), "bytecode")
stages <- c("lean_p1_value", "lean_p2_decide", "lean_p3_plan", "lean_p4_apply", "lean_p5_commit", "run_loop",
            "lean_loop_publish", "lean_loop_expand")
res <- data.frame(
  check = c("frame hashed", "names bound in the frame", "body code compiled", paste("compiled", stages),
            "fills identical", "equity identical", "trades identical", "hashed.R envelope compiled"),
  value = c(!is.null(env.profile(E)), length(ls(E, all.names = TRUE)), identical(typeof(lean$lean_envelope_code), "bytecode"),
            vapply(stages, function(s) compiled(get(s, envir = E)), logical(1L)),
            identical(a$fills, b$fills), identical(a$equity, b$equity), identical(a$trades, b$trades), compiled(hashed)),
  stringsAsFactors = FALSE)
print(res, row.names = FALSE)
dir.create(file.path(here, "evidence"), showWarnings = FALSE)
utils::write.csv(res, file.path(here, "evidence", "probe.csv"), row.names = FALSE)

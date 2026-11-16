# Runner (README): the current lean loop ("plain") against the fork
# ("hashed"), alternating arms in one process per shape, each arm's functions
# cmpfun-compiled as in the timing harness. Pass "stages" times P1-P5 per pulse
# with clocks around the five calls in run_loop (the same edit on both arms);
# pass "loop" has no stage clocks and reads the pulse loop and publish times
# the loop records (live$t_pulses, live$t_publish) and the whole ledgr_run().
#   Rscript dev/spikes/hashed_frame/run.R --lib=<pin> [--rounds=7]
#     [--shapes=10x7200,20x23400,500x1260,slice2_10x7200] [--out=<dir>]
args <- commandArgs(TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
root <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
out <- opt("out", file.path(here, "evidence"))
dir.create(out, showWarnings = FALSE, recursive = TRUE)
rounds <- as.integer(opt("rounds", "7"))
shapes <- strsplit(opt("shapes", "10x7200,20x23400,500x1260,slice2_10x7200"), ",", fixed = TRUE)[[1L]]
source(file.path(root, "dev", "lean_core", "load.R"))
base <- lean_core_load(opt("lib"))   # loads the pin; its lean env is unused
ns <- asNamespace("ledgr")
home <- file.path(root, "dev", "lean_core")
files <- sort(setdiff(list.files(home, pattern = "[.]R$"), "load.R"), method = "radix")

# One arm: the lean sources (loop.R with stage clocks when `clocks`), plus
# hashed.R for the fork, every function compiled.
make_arm <- function(hashed, clocks) {
  lean <- new.env(parent = ns)
  lean$.lean_debug <- FALSE
  lean$.clk <- new.env()
  for (f in files) {
    x <- readLines(file.path(home, f))
    if (f == "loop.R" && clocks) {
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
      x <- wrap(x, "^      v2 <- lean_p2_decide\\(i, v1\\)$", "p2")
      x <- wrap(x, "^      v3 <- lean_p3_plan\\(i, v1, v2\\)$", "p3")
      x <- wrap(x, "^      n_fill <- lean_p4_apply\\(", "p4")
      x <- wrap(x, "^      lean_p5_commit\\(", "p5")
    }
    for (e in parse(text = x, keep.source = FALSE)) eval(e, lean)
  }
  if (hashed) sys.source(file.path(here, "hashed.R"), envir = lean, keep.source = FALSE)
  for (f in ls(lean, all.names = TRUE)) if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
  lean
}

defs <- new.env(parent = ns)
sys.source(file.path(root, "dev/spikes/r_floor/fixture.R"), envir = defs, keep.source = FALSE)
sys.source(file.path(root, "dev/bench/v0_2_3_lean_tuning_profile/descriptors.R"), envir = defs, keep.source = FALSE)
pulses_of <- c("10x7200" = 7200, "20x23400" = 23400, "500x1260" = 1260, "1166x252" = 252, "slice2_10x7200" = 7200)

rows <- list()
for (pass in c("stages", "loop")) {
  arms <- list(plain = make_arm(FALSE, pass == "stages"), hashed = make_arm(TRUE, pass == "stages"))
  for (shape in shapes) {
    desc <- defs$bench_descriptor(shape)
    store <- file.path(tempdir(), paste0(shape, ".duckdb"))
    if (!file.exists(store)) {
      ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "s",
        price_basis = "split_adjusted"))
    }
    snapshot <- ledgr::ledgr_snapshot_open(store, "s", verify = TRUE)
    exp <- desc$experiment(snapshot)
    one <- function(arm, r) {
      lean <- arms[[arm]]
      for (s in c("p1", "p2", "p3", "p4", "p5")) assign(s, 0, envir = lean$.clk)
      restore <- lean$lean_loop_install()
      on.exit(restore())
      t0 <- as.numeric(Sys.time())
      bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = paste(pass, arm, r, sep = "-"), seed = 20260530L))
      whole <- as.numeric(Sys.time()) - t0
      fills <- nrow(as.data.frame(ledgr::ledgr_results(bt, "fills")))
      close(bt)
      times <- lean$lean_loop_last_times
      data.frame(pass = pass, shape = shape, round = r, arm = arm, p1 = lean$.clk$p1, p2 = lean$.clk$p2,
        p3 = lean$.clk$p3, p4 = lean$.clk$p4, p5 = lean$.clk$p5, pulses = times$pulses %||% NA_real_,
        publish = times$publish %||% NA_real_, whole = whole, fills = fills, stringsAsFactors = FALSE)
    }
    one("plain", 0L); one("hashed", 0L)   # warm-up, not recorded
    for (r in seq_len(rounds)) for (arm in if (r %% 2L) c("plain", "hashed") else c("hashed", "plain")) {
      rows[[length(rows) + 1L]] <- one(arm, r)
    }
    ledgr::ledgr_snapshot_close(snapshot)
    cat(pass, shape, "done\n")
  }
}
raw <- do.call(rbind, rows)
utils::write.csv(raw, file.path(out, "stages.csv"), row.names = FALSE)
if (any(tapply(raw$fills, paste(raw$pass, raw$shape), function(v) length(unique(v))) != 1L)) stop("fill counts differ between arms")
# Per pulse: median over rounds of each arm, hashed minus plain, and the share of the plain pulse loop.
cols <- c("p1", "p2", "p3", "p4", "p5", "pulses", "publish", "whole")
summ <- do.call(rbind, lapply(split(raw, paste(raw$pass, raw$shape)), function(d) {
  m <- function(a, k) stats::median(d[[k]][d$arm == a])
  np <- pulses_of[[d$shape[[1L]]]]
  do.call(rbind, lapply(cols, function(k) {
    if (all(is.na(d[[k]])) || (d$pass[[1L]] == "loop" && k %in% cols[1:5])) return(NULL)
    paired <- d[[k]][d$arm == "hashed"][order(d$round[d$arm == "hashed"])] - d[[k]][d$arm == "plain"][order(d$round[d$arm == "plain"])]
    data.frame(pass = d$pass[[1L]], shape = d$shape[[1L]], clock = k, plain_us = 1e6 * m("plain", k) / np,
      hashed_us = 1e6 * m("hashed", k) / np, diff_us = 1e6 * stats::median(paired) / np,
      share = stats::median(paired) / m("plain", k), hashed_faster = sum(paired < 0), rounds = length(paired),
      stringsAsFactors = FALSE)
  }))
}))
utils::write.csv(summ, file.path(out, "summary.csv"), row.names = FALSE)
print(format(summ, digits = 3), row.names = FALSE)

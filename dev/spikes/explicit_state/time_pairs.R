# Paired timing driver (LDG-3278): for each pair and shape, the two arms in
# alternating order, each a fresh Rscript (time_one.R) on the P-cores
# (pcore.ps1, affinity 0xFFFF), on the High performance plan, restored to
# Balanced on exit (also on failure). Writes <evidence>/timing_raw.csv and
# <evidence>/timing_summary.csv (median fork/as-is ratios per shape).
#   Rscript time_pairs.R --lib=<pinned library> [--pairs=5] [--shapes=10x7200,20x23400,500x1260]
#     [--evidence=<dir>] [--scratch=<dir>]
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
lib <- normalizePath(arg("lib"), winslash = "/")
pairs <- as.integer(arg("pairs", "5"))
shapes <- strsplit(arg("shapes", "10x7200,20x23400,500x1260"), ",")[[1L]]
evidence <- normalizePath(arg("evidence", file.path(here, "evidence")), winslash = "/", mustWork = FALSE)
scratch <- normalizePath(arg("scratch", "C:/Users/maxth/ledgr-wt/cut27-scratch/spike"), winslash = "/", mustWork = FALSE)
dir.create(file.path(scratch, "timing"), recursive = TRUE, showWarnings = FALSE)
dir.create(evidence, recursive = TRUE, showWarnings = FALSE)
pcore <- normalizePath(file.path(here, "..", "..", "bench", "v0_2_3_lean_tuning_profile", "pcore.ps1"), winslash = "\\")
raw <- file.path(scratch, "timing", "timing_raw.csv")
if (file.exists(raw)) file.rename(raw, paste0(raw, ".", format(Sys.time(), "%Y%m%d%H%M%S")))
high <- "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
balanced <- "381b4222-f694-41f0-9685-ff5bb260df2e"
system2("powercfg", c("/setactive", high))
host <- c(paste("power plan:", paste(system2("powercfg", "/getactivescheme", stdout = TRUE), collapse = " ")),
          paste("started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
writeLines(host, file.path(evidence, "timing_host.txt"))
setwd(file.path(scratch, "timing"))
tryCatch(for (p in seq_len(pairs)) for (s in shapes) {
  order <- if (p %% 2L == 1L) c("asis", "fork") else c("fork", "asis")
  for (a in order) {
    log <- file.path(scratch, "timing", sprintf("%s_%s_%d.log", s, a, p))
    st <- system2("powershell", c("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", pcore, log,
      file.path(here, "time_one.R"), paste0("--lib=", lib), paste0("--shape=", s), paste0("--arm=", a),
      paste0("--pair=", p), paste0("--out=", raw)))
    cat(sprintf("pair %d %s %s: exit %d  %s\n", p, s, a, st, paste(tail(readLines(log, warn = FALSE), 1L), collapse = "")))
    if (st != 0L) stop("timing run failed: ", log, call. = FALSE)
  }
}, finally = system2("powercfg", c("/setactive", balanced)))   # Balanced restored, also on failure
writeLines(c(host, paste("affinity: pcore.ps1 0xFFFF;", "finished:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))),
           file.path(evidence, "timing_host.txt"))
x <- utils::read.csv(raw, stringsAsFactors = FALSE)
utils::write.csv(x, file.path(evidence, "timing_raw.csv"), row.names = FALSE)
bad <- unlist(lapply(split(x, x$shape), function(d) length(unique(d$digest)) != 1L))
summary <- do.call(rbind, lapply(shapes, function(s) {
  d <- x[x$shape == s, ]
  m <- merge(d[d$arm == "asis", c("pair", "pulses_s", "whole_s")], d[d$arm == "fork", c("pair", "pulses_s", "whole_s")],
             by = "pair", suffixes = c("_asis", "_fork"))
  data.frame(shape = s, pairs = nrow(m), asis_pulses_median = stats::median(m$pulses_s_asis),
             fork_pulses_median = stats::median(m$pulses_s_fork),
             pulses_ratio_median = stats::median(m$pulses_s_fork / m$pulses_s_asis),
             pulses_ratio_min = min(m$pulses_s_fork / m$pulses_s_asis), pulses_ratio_max = max(m$pulses_s_fork / m$pulses_s_asis),
             asis_whole_median = stats::median(m$whole_s_asis), fork_whole_median = stats::median(m$whole_s_fork),
             whole_ratio_median = stats::median(m$whole_s_fork / m$whole_s_asis),
             same_fills_equity = !isTRUE(bad[[s]]), stringsAsFactors = FALSE)
}))
utils::write.csv(summary, file.path(evidence, "timing_summary.csv"), row.names = FALSE)
print(summary, row.names = FALSE)

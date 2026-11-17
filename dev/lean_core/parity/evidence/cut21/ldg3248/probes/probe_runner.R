# LDG-3248 probes (unregistered): runs loop_parity.R's machinery with the unregistered probe
# workloads added (no freeze, no registered workload or oracle changed).
#   Rscript probe_runner.R --lib=<pin> --debug=0|1 --workloads=... --out=<csv> [--batch-rows=1]
x <- readLines("C:/Users/maxth/ledgr-wt/ws40/dev/lean_core/parity/loop_parity.R")
x[grep("^here <- ", x)] <- 'here <- "C:/Users/maxth/ledgr-wt/ws40/dev/lean_core/parity"'
at <- grep("^extra <- c\\(list\\(", x)
x <- c(x[seq_len(at - 1L)], 'source("C:/Users/maxth/ledgr-wt/ws40/dev/lean_core/parity/evidence/cut21/ldg3248/probes/probe_workloads.R")', x[at:length(x)])
x <- sub("loop_slice3, loop_slice4)$", "loop_slice3, loop_slice4, probe_slice4)", x)
stopifnot(any(grepl("probe_slice4)$", x)))
eval(parse(text = x), envir = globalenv())

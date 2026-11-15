# Shows that each slice-3 branch predicate (loop_reach in
# loop_workloads_slice3.R) holds on its own workload and can fail (Cut 19
# decision 7, cut review R3): every predicate is evaluated on the pin tables
# of every slice-3 workload, saved by loop_parity.R --dump. Unlike
# slice2_reach_cross.R it refuses a slice-3 workload without a predicate and
# a slice-3 workload without a dump. A constant-read control replaces the
# values each history workload read with constants; its predicate must
# reject them.
#
#   Rscript dev/lean_core/parity/slice3_reach_cross.R --lib=<pinned library> --dump=<dir> --out=<csv>
# The workload builders are not called here; only the predicates are.

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) stop("--", name, "= is required", call. = FALSE)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
.libPaths(c(arg("lib"), .libPaths()))
loadNamespace("ledgr")
ns <- asNamespace("ledgr")
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
# lw_bars is evaluated by a predicate (the bar-native fixture's closes); the
# other builders are never called.
src <- readLines(file.path(here, "loop_workloads.R"))
from <- grep("^lw_bars <- function", src)
eval(parse(text = src[from:(from + grep("^}", src[from:length(src)])[[1L]] - 1L)]))
lw_snapshot <- lw_schedule_strategy <- build <- collect <- function(...) NULL
lw_days <- function(n) character(n)
source(file.path(here, "loop_workloads_slice2.R"))
source(file.path(here, "loop_workloads_slice3.R"))
dump <- arg("dump")
required <- names(loop_slice3)
problems <- character()
no_pred <- setdiff(required, names(loop_reach))
if (length(no_pred)) problems <- c(problems, paste("no predicate:", paste(no_pred, collapse = ", ")))
have <- sub("[.]rds$", "", list.files(dump, pattern = "[.]rds$"))
no_dump <- setdiff(required, have)
if (length(no_dump)) problems <- c(problems, paste("no pin dump:", paste(no_dump, collapse = ", ")))
ids <- intersect(required, have)
tables <- stats::setNames(lapply(ids, function(id) readRDS(file.path(dump, paste0(id, ".rds")))), ids)
holds <- function(p, t) tryCatch(isTRUE(loop_reach[[p]](t)), error = function(e) FALSE)
rows <- list()
for (p in intersect(required, names(loop_reach))) {
  if (!p %in% ids) next
  value <- vapply(ids, function(id) holds(p, tables[[id]]), logical(1L))
  rows[[p]] <- data.frame(predicate = p, own = value[[p]], fails_elsewhere = sum(!value[names(value) != p]),
                          holds_elsewhere = sum(value[names(value) != p]),
                          holds_on = paste(setdiff(names(value)[value], p), collapse = " "), stringsAsFactors = FALSE)
}
out <- do.call(rbind, rows)
out$ok <- out$own & out$fails_elsewhere > 0L
# Constant-read control: the history workloads' recorded reads set to 1.
for (p in intersect(c("s3_hist_bar_native", "s3_hist_declared", "s3_hist_offset_bar", "s3_hist_offset_feature"), ids)) {
  t <- tables[[p]]
  d <- t$run$run_diagnostics
  i <- which(d$reason_code == "strategy_intent" & d$reasons != "empty")
  d$reasons[i] <- vapply(strsplit(d$reasons[i], ",", fixed = TRUE), function(s) paste(rep("1", length(s)), collapse = ","), "")
  t$run$run_diagnostics <- d
  rejects <- !holds(p, t)
  out <- rbind(out, data.frame(predicate = paste(p, "on constant reads"), own = rejects, fails_elsewhere = length(i),
                               holds_elsewhere = 0L, holds_on = sprintf("%d reads set to 1", length(i)),
                               ok = rejects && length(i) > 0L, stringsAsFactors = FALSE))
}
utils::write.csv(out, arg("out"), row.names = FALSE)
print(out[, c("predicate", "own", "fails_elsewhere", "holds_elsewhere", "ok")], row.names = FALSE)
cat(sprintf("%d checks over %d of %d slice-3 workloads; %d ok\n", nrow(out), length(ids), length(required), sum(out$ok)))
if (length(problems)) cat(paste0("REFUSED: ", problems, "\n"), sep = "")
if (length(problems) || !all(out$ok)) quit(status = 1L)

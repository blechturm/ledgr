# Shows that each slice-2 branch predicate (loop_reach in
# loop_workloads_slice2.R) can fail (Cut 16 decision 4): every predicate is
# evaluated on the pin tables of every slice-2 workload, saved by
# loop_parity.R --dump. A predicate must hold on its own workload and fail on
# at least one other. One extra row checks that the cost-chain predicate
# rejects fees computed on the rounded fill price.
#
#   Rscript dev/lean_core/parity/slice2_reach_cross.R --lib=<pinned library> --dump=<dir> --out=<csv>

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
.libPaths(c(arg("lib"), .libPaths()))
loadNamespace("ledgr")
ns <- asNamespace("ledgr")
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
# The workload builders are not called here; only the predicates are.
lw_bars <- lw_snapshot <- lw_schedule_strategy <- build <- collect <- function(...) NULL
lw_days <- function(n) character(n)
source(file.path(here, "loop_workloads_slice2.R"))
dump <- arg("dump")
ids <- intersect(names(loop_slice2), sub("[.]rds$", "", list.files(dump, pattern = "[.]rds$")))
tables <- stats::setNames(lapply(ids, function(id) readRDS(file.path(dump, paste0(id, ".rds")))), ids)
rows <- list()
for (p in names(loop_reach)) {
  if (!p %in% ids) next
  value <- vapply(ids, function(id) tryCatch(isTRUE(loop_reach[[p]](tables[[id]])), error = function(e) FALSE),
                  logical(1L))
  rows[[p]] <- data.frame(predicate = p, own = value[[p]], fails_elsewhere = sum(!value[names(value) != p]),
                          holds_elsewhere = sum(value[names(value) != p]),
                          holds_on = paste(setdiff(names(value)[value], p), collapse = " "), stringsAsFactors = FALSE)
}
out <- do.call(rbind, rows)
out$ok <- out$own & out$fails_elsewhere > 0L
# The cost-chain predicate must also reject the rounded-price fee basis on
# its own workload: fees recomputed from the rounded fill price (close
# review round 1, finding 1).
if ("s2_cost_chain" %in% ids) {
  t <- tables[["s2_cost_chain"]]
  f <- s2_fills(t)
  t$run$fills$fee <- sprintf("%.17g", 1 + abs(f$qty * f$price) * 5 / 10000)
  changed <- sum(as.numeric(t$run$fills$fee) != f$fee)
  rejects <- !isTRUE(loop_reach$s2_cost_chain(t))
  out <- rbind(out, data.frame(predicate = "s2_cost_chain on rounded-price fees", own = rejects,
                               fails_elsewhere = changed, holds_elsewhere = 0L,
                               holds_on = sprintf("%d of %d fees changed", changed, nrow(f)),
                               ok = rejects && changed > 0L, stringsAsFactors = FALSE))
}
utils::write.csv(out, arg("out"), row.names = FALSE)
print(out[, c("predicate", "own", "fails_elsewhere", "holds_elsewhere", "ok")], row.names = FALSE)
cat(sprintf("%d checks over %d workloads; %d ok (a predicate holds on its own workload and fails on another; the basis control rejects rounded-price fees)\n",
            nrow(out), length(ids), sum(out$ok)))
if (!all(out$ok)) quit(status = 1L)

# Shows that each slice-4 branch predicate (loop_reach in
# loop_workloads_slice4.R) holds on its own workload and can fail (Cut 21
# decision 10, cut review R8): every predicate of the required list is
# evaluated on the pin tables of every workload of that list, saved by
# loop_parity.R --dump. It refuses a required workload without a predicate
# or without a dump; a predicate must hold on its own workload and fail on
# at least one other. The lists are explicit: workstream 39's (LDG-3243 and
# LDG-3244: openings, carried windows, corporate actions, the capture's
# growth and ordering, committed prefixes) and, from LDG-3248, the whole
# slice.
#
#   Rscript dev/lean_core/parity/slice4_reach_cross.R --lib=<pinned library> --dump=<dir>
#     --set=ws39|slice4 --out=<csv>
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
src <- readLines(file.path(here, "loop_workloads.R"))
from <- grep("^lw_bars <- function", src)
eval(parse(text = src[from:(from + grep("^}", src[from:length(src)])[[1L]] - 1L)]))
lw_snapshot <- lw_schedule_strategy <- build <- collect <- function(...) NULL
lw_days <- function(n) character(n)
loop_expect_refused <- list()
source(file.path(here, "loop_workloads_slice2.R"))
source(file.path(here, "loop_workloads_slice3.R"))
source(file.path(here, "loop_workloads_slice4.R"))
sets <- list(
  ws39 = c("s4_opening", "s4_opening_sessions", "s4_carried", "s4_carried_lots", "s4_basis_unknown", "s4_basis_known",
           "s4_prefix_opening_sweep", "s4_prefix_opening_run",
           "s4_dividend", "s4_dividend_bought", "s4_dividend_sessions", "s4_dividend_skip", "s4_dividend_next_open",
           "s4_dividend_late", "s4_dividend_unheld", "s4_cash_refused", "s4_quantity_refused", "s4_cash_quantity_refused",
           "s4_quantity_reported", "s4_clock_missing", "s4_entitlement_missing", "s4_dividend_mixed", "s4_cash_overflow",
           "s4_prefix_dividend_sweep", "s4_prefix_dividend_bought", "s4_prefix_dividend_run", "s4_prefix_dividend_stop",
           # close review round 1, F1: the retaining handler's room
           "s4_capacity_block", "s4_capacity_prefix", "s4_capacity_after_fill", "s4_capacity_fill",
           "s4_capacity_after_fill_run", "s4_capacity_fill_run"))
# LDG-3248: the whole slice, workstream 40's facts, context, disposition,
# precedence, prefix and growth cases added to workstream 39's list.
sets$slice4 <- c(sets$ws39,
  "s4_halt", "s4_v201_default", "s4_membership", "s4_nonmember_increase", "s4_restricted_target", "s4_restrictions",
  "s4_state_context", "s4_no_members_held", "s4_subset", "s4_stale_facts", "s4_facts_sweep",
  "s4_cash_acquisition", "s4_terminal", "s4_v201_refuse", "s4_acq_held", "s4_acq_unheld", "s4_acq_fills",
  "s4_terminal_choices", "s4_terminal_refuse", "s4_terminal_unlabeled", "s4_terminal_no_mark", "s4_frozen_writeoff",
  "s4_frozen_lastmark", "s4_frozen_refuse", "s4_blocked_scheduled", "s4_blocked_group", "s4_p1_then_stop",
  "s4_p1_complete", "s4_reread_nonmember", "s4_bound_dispose", "s4_prefix_dispose_sweep", "s4_prefix_terminal_sweep",
  "s4_prefix_dispose_stop", "s4_moves_growth",
  # workstream 40 close review round 1, F1: lifetime-only capacity
  "s4_life_capacity_p1", "s4_life_capacity_p1_ok", "s4_life_capacity_p5", "s4_life_capacity_p5_ok",
  "s4_life_capacity_p1_run", "s4_life_capacity_p1_ok_run", "s4_life_capacity_p5_run", "s4_life_capacity_p5_ok_run",
  # workstream 40 close review round 2, F3: a wrapped append method
  paste0("s4_wrap_", rep(c("plan_p1", "plan_p1_eq", "plan_p5", "plan_p5_eq", "life_p1", "life_p1_eq", "life_p5",
    "life_p5_eq"), 2L), rep(c("", "_run"), each = 8L)), "s4_wrap_drain_run")
set <- arg("set")
if (is.null(sets[[set]])) stop("unknown --set: ", set, call. = FALSE)
required <- sets[[set]]
dump <- arg("dump")
problems <- character()
no_builder <- setdiff(required, names(loop_slice4))
if (length(no_builder)) problems <- c(problems, paste("no workload:", paste(no_builder, collapse = ", ")))
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
utils::write.csv(out, arg("out"), row.names = FALSE)
print(out[, c("predicate", "own", "fails_elsewhere", "holds_elsewhere", "ok")], row.names = FALSE)
cat(sprintf("%d predicates over %d of %d required workloads (set %s); %d ok\n", nrow(out), length(ids), length(required),
            set, sum(out$ok)))
if (length(problems)) cat(paste0("REFUSED: ", problems, "\n"), sep = "")
if (length(problems) || !all(out$ok)) quit(status = 1L)

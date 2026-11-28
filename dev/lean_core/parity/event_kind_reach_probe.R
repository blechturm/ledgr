# Inventory row review F6 (row R028, LTB-0026): can a public input reach the
# pulse plan's unsupported-event-kind refusal? The pin refuses it in
# production (ledgr_fold_plan_event_kinds() in ledgr_fold_stage_plan(),
# R/fold-engine.R); the lean core checks it only in debug (plan.R
# lean_stage_plan). Two parts:
#
# 1. Structure. Every plan both planners build takes its kinds from a
#    literal: `none` (integer()) or `if (length(fills) > 0L) 1L else none`.
#    The probe parses the pin's ledgr_fold_build_availability_pulse_plan()
#    and lean_plan_pulse() and lists the kinds argument of every plan they
#    return. Any other expression is a finding.
# 2. Corpus. Every gate workload runs on the pin with
#    ledgr_fold_plan_event_kinds() wrapped; the probe records the kinds each
#    workload's plans declared and whether any plan's kinds disagreed with
#    its fills. Evidence, not proof; the structure is the proof.
#
#   Rscript event_kind_reach_probe.R --lib=<pin library> --lean=<dev/lean_core>
#     --out=<dir> [--workloads=a,b]
local({
  argv <- commandArgs(TRUE)
  arg <- function(n, d = NULL) { v <- grep(paste0("^--", n, "="), argv, value = TRUE); if (length(v)) sub(paste0("^--", n, "="), "", v[[1L]]) else d }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  assign("probe_out", arg("out"), globalenv())
  assign("probe_lean", arg("lean"), globalenv())
  assign("probe_only", arg("workloads", ""), globalenv())
  assign("probe_here", here, globalenv())
})
dir.create(probe_out, showWarnings = FALSE, recursive = TRUE)
# loop_parity.R's definitions (its workloads and helpers), without its run loop.
exprs <- parse(file.path(probe_here, "loop_parity.R"), keep.source = FALSE)
stop_at <- which(vapply(exprs, function(e) is.call(e) && identical(e[[1L]], as.name("for")), logical(1)))
stop_at <- stop_at[stop_at > 50L][[1L]]
for (e in exprs[seq_len(stop_at - 1L)]) eval(e, globalenv())
ns <- asNamespace("ledgr")

# Part 1: the kinds argument of every plan each planner returns.
kinds_args <- function(fn, builder, kinds_at) {
  out <- character()
  walk <- function(e) {
    if (is.call(e)) {
      if (identical(e[[1L]], as.name(builder))) out <<- c(out, paste(deparse(e[[kinds_at]]), collapse = " "))
      for (a in as.list(e)[-1L]) if (!missing(a)) walk(a)
    }
  }
  walk(body(fn))
  out
}
lean_env <- new.env(parent = ns)
sys.source(file.path(probe_lean, "plan.R"), envir = lean_env, keep.source = FALSE)
allowed <- c("none", "if (length(fills) > 0L) 1L else none")
structure <- rbind(
  data.frame(planner = "pin ledgr_fold_build_availability_pulse_plan",
    kinds = kinds_args(get("ledgr_fold_build_availability_pulse_plan", envir = ns), "plan", 3L)),
  data.frame(planner = "lean lean_plan_pulse",
    kinds = kinds_args(get("lean_plan_pulse", envir = lean_env), "lean_plan_result", 3L))
)
structure$allowed <- structure$kinds %in% allowed
utils::write.csv(structure, file.path(probe_out, "structure.csv"), row.names = FALSE)
print(structure)
stopifnot(nrow(structure) >= 4L)

# Part 2: the corpus on the pin.
seen <- new.env()
inner <- get("ledgr_fold_plan_event_kinds", envir = ns)
unlockBinding("ledgr_fold_plan_event_kinds", ns)
assign("ledgr_fold_plan_event_kinds", function(plan, canonical_event_kinds = NULL) {
  kinds <- unique(plan$economic_event_kinds)
  has_fill <- length(plan$fill$k) > 0L
  seen$plans <- seen$plans + 1L
  seen$kinds <- union(seen$kinds, kinds)
  if (!identical(as.integer(kinds), if (has_fill) 1L else integer())) seen$mismatch <- seen$mismatch + 1L
  inner(plan, canonical_event_kinds)
}, envir = ns)
lockBinding("ledgr_fold_plan_event_kinds", ns)
ids <- all_ids
if (nzchar(probe_only)) ids <- intersect(ids, strsplit(probe_only, ",")[[1L]])
rows <- list()
for (id in ids) {
  seen$plans <- 0L
  seen$kinds <- integer()
  seen$mismatch <- 0L
  (loop_entry_rng[[id]] %||% function() NULL)()
  err <- tryCatch({ run_tables(id); "" }, error = function(e) paste(class(e)[[1L]], conditionMessage(e)))
  rows[[id]] <- data.frame(workload = id, plans = seen$plans, kinds = paste(sort(seen$kinds), collapse = ";"),
                           mismatch = seen$mismatch, refused = grepl("cannot execute pulse-plan", err), error = err,
                           stringsAsFactors = FALSE)
  cat(sprintf("%-36s plans %6d kinds {%s} mismatch %d %s\n", id, seen$plans, rows[[id]]$kinds, seen$mismatch, err))
}
out <- do.call(rbind, rows)
utils::write.csv(out, file.path(probe_out, "corpus.csv"), row.names = FALSE)
cat(sprintf("structure: %d plan returns, %d not a literal; corpus: %d workloads, %d plans, kinds seen {%s}, mismatches %d, refusals %d\n",
            nrow(structure), sum(!structure$allowed), nrow(out), sum(out$plans),
            paste(sort(unique(unlist(strsplit(out$kinds[nzchar(out$kinds)], ";")))), collapse = ";"),
            sum(out$mismatch), sum(out$refused)))

# WS4a detector baselines (LDG-3163 scope f; design note Section 6); static parse of <root>/R, runtime on <lib>.
# Rscript detectors.R --lib=<installed ledgr> [--root=<checkout>] [--out=<dir>] [--freeze=1]
a <- commandArgs(TRUE)
arg <- function(key, default = NULL) {
  z <- grep(paste0("^--", key, "="), a, value = TRUE)
  if (length(z)) sub(paste0("^--", key, "="), "", z[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
root <- normalizePath(arg("root", file.path(here, "../../..")), winslash = "/")
out <- arg("out", file.path(here, "records", "detectors"))
.libPaths(c(normalizePath(arg("lib"), winslash = "/"), .libPaths()))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
files <- list.files(file.path(root, "R"), "\\.R$", full.names = TRUE)
source(file.path(root, "tools/check-fold-phase-contract.R")) # reuse its parser and phase findings
D <- ledgr_fold_phase_function_sources(files)
calls <- function(e) if (is.call(e)) c(list(e), unlist(lapply(as.list(e), calls), recursive = FALSE))
head_of <- function(e) {
  h <- if (is.call(e[[1L]]) && as.character(e[[1L]][[1L]]) %in% c("::", ":::")) e[[1L]][[3L]] else e[[1L]]
  if (is.symbol(h)) as.character(h) else ""
}
heads <- function(e) vapply(calls(e), head_of, "")
txt <- function(e) paste(deparse(e, width.cutoff = 500L), collapse = " ")
fun_args <- function(x) Filter(function(y) is.call(y) && identical(y[[1L]], as.name("function")), as.list(x)[-1L])
loop_bodies <- function(e) unlist(lapply(calls(e), function(x) switch(head_of(x),
  `for` = list(x[[4L]]), `while` = list(x[[3L]]), `repeat` = list(x[[2L]]),
  lapply = , vapply = , sapply = , Map = , mapply = fun_args(x), NULL)), recursive = FALSE)
assigns <- function(e) Filter(function(x) head_of(x) %in% c("<-", "<<-", "="), calls(e))
pick <- function(names) D[intersect(names, names(D))]
inject <- function(e, stmt) { e[[3L]] <- as.call(c(as.list(e[[3L]])[1L], list(str2lang(stmt)), as.list(e[[3L]])[-1L])); e } # add a violation
rows <- list()
record <- function(id, predicate, examined, hits, expected, why, control, ctl_pass, ctl_fail) {
  rows[[length(rows) + 1L]] <<- data.frame(id, predicate, examined = paste(examined, collapse = " "),
    base_outcome = if (length(hits)) "FAIL" else "PASS", expected_base_outcome = expected, why,
    base_hits = paste(head(hits, 4L), collapse = " | "), n_hits = length(hits), control,
    control_compliant_passes = ctl_pass, control_violation_fails = ctl_fail)
}
static <- function(id, predicate, check, examined, expected, why, control, good, bad) {
  run <- function(fns) unlist(Map(function(nm, e) { h <- unique(check(e, nm)); if (length(h)) paste0(nm, ": ", h) }, names(fns), fns))
  record(id, predicate, names(examined), run(examined), expected, why, control,
    !length(run(list(control = good))), length(run(list(control = bad))) > 0L)
}
stages <- paste0("ledgr_fold_stage_", c("observe_settle", "decide", "plan", "apply", "commit"))
kernel <- names(D)[grepl("^ledgr_(lot_|position_from_lots)", names(D))]
lot_ops <- c("ledgr_lot_apply_fill", "ledgr_lot_apply_opening", "ledgr_lot_apply_event", "ledgr_lot_append_vectors",
  "ledgr_lot_compact", "ledgr_lot_ensure_instrument", "ledgr_lot_kernel") # add the typed operation names at LDG-3164
per_fill <- c("ledgr_fill_event_payload", "ledgr_fill_event_row")
sinks <- c("ledgr_output_handler", "ledgr_output_sink_memory", "ledgr_output_sink_duckdb")
old <- "targets the old named-list / per-fill representation; a base failure is expected evidence"
P4 <- D$ledgr_fold_stage_apply; K <- D$ledgr_lot_apply_fill
static("D1", "no list, S3 object or POSIXct conversion per fill (in loops; anywhere in per-fill helpers)",
  function(e, nm) { b <- if (nm %in% per_fill) list(e[[3L]]) else loop_bodies(e)
    c(unlist(lapply(b, function(x) intersect(heads(x), c("list", "structure", "as.POSIXct", "class<-", "ledgr_ts_utc_posix")))),
      if (any(grepl('vector\\("list"', vapply(b, txt, "")))) "vector(\"list\")") },
  pick(c("ledgr_fold_build_pulse_plan", "ledgr_fold_build_availability_pulse_plan", "ledgr_fold_stage_plan", "ledgr_fold_stage_apply",
    "ledgr_fold_pulse_plan_accounting_events", "ledgr_fold_pulse_plan_fill_intents", "ledgr_fill_publication_deltas", per_fill)),
  "FAIL", old, "vector(\"list\") and as.POSIXct in a fill loop",
  str2lang("function(q) { o <- numeric(length(q)); for (k in seq_along(q)) o[k] <- q[k] * 2; o }"),
  str2lang("function(q, ts) for (k in seq_along(q)) { r <- vector(\"list\", 2L); t <- as.POSIXct(ts[k]) }"))
char_index <- function(i) (is.symbol(i) && grepl("^(id|ids|inst_id|instrument_ids?|context_ids|target_names)$", as.character(i))) ||
  (is.call(i) && head_of(i) %in% c("names", "as.character"))
static("D3", "no character indexing on run/context-axis vectors",
  function(e, nm) unlist(lapply(calls(e), function(x) if (head_of(x) %in% c("[", "[[") && length(x) >= 3L && char_index(x[[3L]])) substr(txt(x), 1L, 50L))),
  pick(c(kernel, "ledgr_replay_accounting_events", "ledgr_fold_stage_decide", "ledgr_fold_stage_plan", "ledgr_fold_build_availability_pulse_plan")),
  "FAIL", old, "net_by_inst[[id]]", str2lang("function(b, pos) b$net_by_inst[[pos]]"), str2lang("function(b, id) b$net_by_inst[[id]]"))
static("D6", "JSON encode/parse in fold stages only at routed sites (meta_json, H5, intent reason, stop/exception detail)",
  function(e, nm) { t <- vapply(Filter(function(x) grepl("json|JSON", head_of(x)), calls(e)), txt, "")
    substr(t[!grepl("intent_reason|risk_step|ledgr_availability_detail_json|virtual_final_cash|exception|meta_json", t)], 1L, 50L) },
  pick(stages), "FAIL", "P5 serialises strategy state with canonical_json(state_update) each pulse (fe:1521), a site the routed list omits",
  "new canonical_json call in P3", str2lang("function(x) canonical_json(list(intent_reason = x))"), str2lang("function(x) canonical_json(list(plan = x))"))
static("D8", "no fill-intent object in the fold or sinks (static part)",
  function(e, nm) c(intersect(all.names(e), c("fill_intent", "ledgr_fold_pulse_plan_fill_intents")),
    if (grepl('"ledgr_fill_intent"', txt(e), fixed = TRUE)) "class ledgr_fill_intent"),
  pick(c(stages, "ledgr_output_handler", per_fill)), "FAIL", old, "reconstruct an intent",
  str2lang("function(f) f$qty"), str2lang("function(f) structure(list(qty = 1), class = \"ledgr_fill_intent\")"))
static("D9", "no per-fill or per-leg staging list in publication; routed memory meta allowed",
  function(e, nm) unlist(lapply(assigns(e), function(x) if (is.symbol(x[[2L]]) && grepl("fill|leg", as.character(x[[2L]])) &&
    grepl('^(c\\(.*)?vector\\("list"', txt(x[[3L]]))) as.character(x[[2L]]))),
  pick(sinks), "FAIL", old, "staged per-fill list",
  str2lang("function(n) { cols <- list(); cols$meta <- vector(\"list\", n) }"), str2lang("function(n) pulse_fill_rows <- vector(\"list\", n)"))
static("D10", "no equity accumulator in fold or service slots (slot inspection; writer count needs the typed record)",
  function(e, nm) intersect(all.names(e), c("equity_fact_accumulator", "record_equity_fact")), pick(c(stages, "ledgr_fold_envelope", sinks)),
  "FAIL", "both current accumulators exist until LDG-3168", "keep the accumulator",
  str2lang("function(r, i, x) { r$cash[i] <- x; r }"), str2lang("function(services, x) services$equity_fact_accumulator$append(x)"))
static("D11", "positions read from lot-derived net_by_inst, never positions plus a delta",
  function(e, nm) unlist(lapply(assigns(e), function(x) if ("positions" %in% all.names(x[[2L]]) && any(c("+", "-") %in% all.names(x[[3L]])) &&
    any(grepl("position|qty|delta", setdiff(all.names(x[[3L]]), c("+", "-"))))) txt(x))),
  pick(c("ledgr_fold_stage_apply", "ledgr_replay_accounting_events")), "PASS", "base P4 and replay read ledgr_position_from_lots",
  "positions + delta injected into base P4", P4, inject(P4, "positions[[inst_idx]] <- positions[[inst_idx]] + qty"))
static("D15", "no by-reference write on book columns", function(e, nm) intersect(heads(e), c("setv", "set", "setattr", ":=", "setDT")),
  pick(kernel), "PASS", "the base kernel copies on modify", "collapse::setv injected", K, inject(K, "collapse::setv(state$lot_qty, 1L, 0)"))
static("D17", "the lot kernel computes no cash", function(e, nm) grep("cash", all.names(e), value = TRUE), pick(kernel), "PASS",
  "base lot functions never touch cash", "cash injected into the kernel", K, inject(K, "cash <- cash - qty * price"))
static("D25", "independent lot operations not dispatched by an R loop per instrument (FIFO depth and the ordered aggregate scan permitted)",
  function(e, nm) unlist(lapply(loop_bodies(e), function(b) intersect(heads(b), lot_ops))), pick(c(kernel, "ledgr_fold_stage_apply")),
  "FAIL", paste(old, "(P4 and opening loops); replay is not examined: decision (6) permits singleton replay"), "per-instrument lot loop; aggregate scan kept",
  str2lang("function(b, pos, q, basis) { b <- ledgr_lot_kernel(b, pos, q); s <- 0; for (i in seq_along(basis)) s <- s + basis[[i]]; b }"),
  str2lang("function(b, pos, q) { for (k in seq_along(pos)) b <- ledgr_lot_kernel(b, pos[k], q[k]); b }"))
fifo <- c("ledgr_lot_state", "ledgr_lot_apply_fill", "ledgr_position_from_lots", "ledgr_lot_ensure_instrument", "ledgr_lot_values", "ledgr_lot_count")
record("D19", "no named-list FIFO function defined in R/", c("all R/ definitions:", fifo), intersect(names(D), fifo), "FAIL", old,
  "define ledgr_lot_apply_fill", !length(intersect("ledgr_lot_kernel", fifo)), length(intersect("ledgr_lot_apply_fill", fifo)) > 0L)
tmp_def <- function(name, e) { f <- tempfile(fileext = ".R"); writeLines(c(paste(name, "<-"), deparse(e, width.cutoff = 500L)), f); f }
phase <- function(rx, extra = character()) grep(rx, ledgr_fold_phase_source_findings(c(files, extra)), value = TRUE)
ph <- list(D21 = c("^substrate_reference:ledgr_fold_stage_(plan|apply|commit)|^service_owner:.*history_reader", "ledgr_fold_stage_plan",
  "services$history_substrate$read(1L)", "no history or substrate access in P3-P5 (phase checker)", "injected P3 history read"),
  D24 = c("^service_owner:.*(decision_view|execution_view|history_reader)", "ledgr_fold_stage_apply", "services$availability_provider$execution_view(1L)",
    "execution view and history services only from declared stages (checker; add ledgr_carrier_execution_view() at LDG-3166)", "call it from P4"))
for (k in names(ph)) record(k, ph[[k]][4], stages, phase(ph[[k]][1]), "PASS", "the base passes the existing phase checker", ph[[k]][5],
  !length(phase(ph[[k]][1])), length(phase(ph[[k]][1], tmp_def(ph[[k]][2], inject(D[[ph[[k]][2]]], ph[[k]][3])))) > 0L)
# Frozen-identity detectors: --freeze=1 on the base writes the reference values.
deps <- function(d) paste(gsub("\\s+", "", d[, intersect(c("Depends", "Imports", "LinkingTo", "Suggests"), colnames(d))]), collapse = ";")
exports <- function(lines) paste(sort(grep("^(export|S3method)\\(", lines, value = TRUE)), collapse = ";")
census <- function(fs) paste(basename(fs), vapply(fs, function(f) {
  l <- readLines(f); sum(lengths(regmatches(l, gregexpr("availability_active", l, fixed = TRUE))))
}, 0), collapse = ";")
dense <- c("ledgr_pulse_context", "ledgr_update_pulse_context_helpers", "ledgr_dense_eligibility_planes", "ledgr_fold_build_pulse_plan")
dhash <- function(fns) digest::digest(vapply(fns, txt, ""), algo = "sha256")
desc <- read.dcf(file.path(root, "DESCRIPTION")); ns_lines <- readLines(file.path(root, "NAMESPACE"))
e12 <- function(f) deparse(f[[2L]]$compiled_accounting_model) # ledgr_run's default: NULL means no compiled default
now <- c(D12b = deps(desc), D12c = exports(ns_lines), D12d = census(files), D13 = dhash(D[dense]), D12e = e12(D$ledgr_run))
if (identical(arg("freeze", "0"), "1")) utils::write.csv(data.frame(id = names(now), value = now), file.path(out, "frozen.csv"), row.names = FALSE)
frozen <- with(utils::read.csv(file.path(out, "frozen.csv"), colClasses = "character"), stats::setNames(value, id))
same <- function(id, v) if (identical(unname(frozen[[id]]), unname(v))) character() else paste(id, "differs from the frozen base")
d2 <- desc; d2[, "Imports"] <- paste0(d2[, "Imports"], ", newpkg")
bad <- list(D12b = deps(d2), D12c = exports(c(ns_lines, "export(ledgr_new)")), D12d = paste0(now[["D12d"]], ";new.R 1"),
  D13 = dhash(c(D[dense[-4L]], list(inject(D[[dense[[4L]]]], "NULL")))), D12e = "ledgr_compiled_spot_fifo()")
spec <- data.frame(id = names(now), examined = c("DESCRIPTION", "NAMESPACE", "R/*.R", paste(dense, collapse = " "), "ledgr_run"),
  predicate = c("Depends/Imports/LinkingTo/Suggests equal the frozen base", "export and S3method census equals the frozen base",
    "availability_active census per R/ file equals the frozen base (LTB-0331 stays the registered census)",
    "named dense observe/ctx builders hash equal to the frozen base (function list chosen here; the note names none)",
    "compiled_accounting_model default equals the frozen base (NULL: no compiled default)"),
  control = c("add an import", "add an export", "add a branch", "edit a dense view builder", "flip the default"))
for (i in seq_len(nrow(spec))) record(spec$id[i], spec$predicate[i], spec$examined[i], same(spec$id[i], now[[i]]), "PASS",
  "frozen from this base", spec$control[i], !length(same(spec$id[i], now[[i]])), length(same(spec$id[i], bad[[i]])) > 0L)
# Runtime detectors on the installed library (process-local namespace hooks).
suppressPackageStartupMessages(library(ledgr)); ns <- asNamespace("ledgr")
n_k <- 0; env <- new.env(parent = ns)
env$ledgr_lot_add_realized <- function(state, delta) { n_k <<- n_k + 1; ns$ledgr_lot_add_realized(state, delta) }
open_ok <- function(op) {
  environment(op) <- env; n_k <<- 0
  s0 <- ns$ledgr_lot_state("A"); s0$realized_pnl <- 5; s0$realized_comp <- 1e-13
  n_k == 0 && identical(op(s0, "A", 3, 10)$realized_comp, s0$realized_comp)
}
op <- ns$ledgr_lot_apply_opening; m6 <- op
body(m6) <- as.call(c(as.list(body(op))[1L], quote(state <- ledgr_lot_add_realized(state, 0)), as.list(body(op))[-1L]))
record("D7", "opening performs no Kahan step; nonzero compensation preserved (invocation counter)", "ledgr_lot_apply_opening",
  if (open_ok(op)) character() else "Kahan step on opening", "PASS", "base openings skip ledgr_lot_add_realized", "M6", open_ok(op), !open_ok(m6))
ev <- list(event_id = c("e1", "e2"), run_id = c("r", "r"), ts_utc = as.POSIXct(c("2020-01-02 21:00:00", "2020-01-03 21:00:00"), tz = "UTC"),
  event_type = c("FILL", "FILL"), instrument_id = c("A", "A"), side = c("BUY", "SELL"), qty = c(2, 1), price = c(10, 12),
  fee = c(1, 1), meta_json = c(NA_character_, NA_character_), event_seq = 1:2)
cash_ok <- function(replay) isTRUE(all.equal(replay(ns$ledgr_prepare_accounting_events(ev, "A"), initial_cash = 100)$cash, 100 - 21 + 11))
rp <- ns$ledgr_replay_accounting_events
twice <- eval(str2lang(sub("cash <- cash + prepared$cash_delta[[i]]", "cash <- cash + 2 * prepared$cash_delta[[i]]",
  paste(deparse(rp), collapse = "\n"), fixed = TRUE)), ns)
record("D23", "replay applies each published cash effect once (two-event witness 100 - 21 + 11)", "ledgr_replay_accounting_events",
  if (cash_ok(rp)) character() else "cash witness differs", "PASS", "base replay adds each cash_delta once", "apply a delta twice", cash_ok(rp), !cash_ok(twice))
pit <- ledgr_sim_pit_inputs(sprintf("A%d", 1:4), from = "2020-01-01", to = "2020-02-29", cases = character())
facts <- ledgr_facts(ledgr_facts_sessions(pit$sessions, "DEMO_VENUE"), ledgr_facts_lifetime(pit$lifetime))
snap <- ledgr_snapshot_from_df(pit$bars, db_path = tempfile(fileext = ".duckdb"), snapshot_id = "det", price_basis = "split_adjusted", facts = facts)
toggle <- function(ctx, params) {
  k <- if (is.null(ctx$state_prev$k)) 1L else ctx$state_prev$k + 1L
  list(targets = ctx$hold() * 0 + k %% 2L, state_update = list(k = k))
}
cnt <- new.env(); p2_names <- character()
nm_all <- function(x, d = 0L) if (is.list(x) && d < 3L) c(names(x), unlist(lapply(x, nm_all, d + 1L)))
hook <- function(name, pre = NULL) {
  orig <- get(name, ns); force(pre); cnt[[name]] <- 0
  utils::assignInNamespace(name, function(...) { cnt[[name]] <- cnt[[name]] + 1; if (!is.null(pre)) pre(...); orig(...) }, ns = "ledgr")
}
hook("ledgr_fold_stage_decide", function(fold_state, services, observation, ...) p2_names <<- unique(c(p2_names, nm_all(observation))))
for (h in c("ledgr_validate_strategy_targets", "ledgr_validate_post_risk_targets", "ledgr_fill_publication_deltas")) hook(h)
bt <- suppressWarnings(ledgr_run(ledgr_experiment(snap, toggle, opening = ledgr_opening(cash = 1e6), cost_model = ledgr_cost_zero()), run_id = "d"))
counts <- as.list(cnt); fills <- nrow(ledgr_results(bt, "fills")); close(bt)
once <- function(n, per) if (isTRUE(n == per)) character() else sprintf("%g calls for %g units", n, per)
nb <- function(x) grep("^(next|exec)", x, value = TRUE)
record("D4", "strategy return shape/name normalised once per pulse (runtime counter)", "ledgr_validate_strategy_targets ledgr_validate_post_risk_targets",
  once(counts$ledgr_validate_strategy_targets + counts$ledgr_validate_post_risk_targets, counts$ledgr_fold_stage_decide), "FAIL",
  "base validates after the strategy and again after risk", "a second call", !length(once(10, 10)), length(once(20, 10)) > 0L)
record("D5", "P2's input carries no execution-packet field (observation names, depth 3)", "ledgr_fold_stage_decide", nb(p2_names), "FAIL",
  "base observation$history_bars carries next_bar into P2", "pass next_bar",
  !length(nb(nm_all(list(decision = list(close = 1))))), length(nb(nm_all(list(history_bars = list(next_bar = 1))))) > 0L)
record("D8b", "effects computed once: ledgr_fill_publication_deltas calls per actual fill (runtime counter)", "ledgr_fill_publication_deltas",
  once(counts$ledgr_fill_publication_deltas, fills), "PASS", "one helper call per fill; P4's inline cash_delta (fe:1384-1388) is invisible to it",
  "compute twice", !length(once(10, 10)), length(once(20, 10)) > 0L)
na <- c(D2 = "typed pulse staging does not exist on the base", D12a = "needs scope (c)'s C1 config-hash witness and the existing store tests",
  D16 = "no provider adapter on the base", D18 = "the base kernel takes one fill per call; no kernel to refuse duplicates",
  D20 = "a candidate-versus-base route diff; the base side is the A0 and case records", D22 = "no integer dictionaries on the base",
  W1 = "no candidate book or block publication entry on the base")
for (k in names(na)) record(k, "design note Section 6", "", character(), "NOT_EVALUABLE", na[[k]], "", NA, NA)
res <- do.call(rbind, rows); res$base_outcome[res$expected_base_outcome == "NOT_EVALUABLE"] <- "NOT_EVALUABLE"
utils::write.csv(res, file.path(out, "baseline.csv"), row.names = FALSE)
print(res[c("id", "base_outcome", "expected_base_outcome", "n_hits", "control_compliant_passes", "control_violation_fails")], row.names = FALSE)

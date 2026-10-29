# RNG baseline successor comparator (LDG-3161; ws2_rng_design.md Sections
# 8.2 and 8.2.1).
#
# Reads the unchanged original RNG baseline records and a successor record
# table by table and checks the frozen predicates. Every field a predicate
# does not name must be identical; every changed economic row is attributed
# to its named cause (kind pinning, RNG-neutral storage or the v2 pulse rule)
# by the predicate it satisfies:
#
#   pulse_seeds        v2 rule: keys identical; pulse_seed equals the
#                      independent reference (../lib.R) on every row.
#   rule_overlap       v2 rule: add/stride/mixer rows identical; every current
#                      row equals the original mixer row of the same metric.
#   census             Section 8.2.1: typed header, copy rows, field
#                      predicates and the independent expected-call ledger.
#   worker_agreement   kind pin + v2 rule: identities kept, DONE, agreement
#                      booleans TRUE, equal trade counts >= 10 and equal final
#                      equities across paths, equal to the pulse-rule model.
#   stochastic_fills   v2 rule: equal the pulse-rule model (model.R).
#   stochastic_trades  v2 rule: run and sweep_w1 rows equal the model; kind
#                      pin: sweep_w2 rows equal sweep_w1 rows.
#   caller_rng         storage neutrality (01, 05, 09) and caller restore
#                      (13, 15): every row unchanged state; only those rows,
#                      only the three state fields change.
#   store_rng          storage neutrality: both rows identical equities with
#                      the frozen values.
#   detection_gap      identical (decision (11)).
#
# Usage: Rscript compare.R [--original=<dir>] [--successor=<dir>] [--model=<dir>]
#                          [--result=<csv>]
# Exit status 0 when every predicate holds, 1 otherwise.

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  source(file.path(here, "..", "lib.R"))
})
sr_ref_selftest()
orig_dir <- sr_arg("original", file.path(sr_root, "dev", "bench", "v0_2_3_rng_baseline", "records"))
succ_dir <- sr_arg("successor", file.path(sr_dir, "rng", "records"))
model_dir <- sr_arg("model", file.path(sr_dir, "rng", "model"))
result_file <- sr_arg("result", NULL)

rows <- list()
check <- function(table, predicate, cause, ok, detail = "") {
  rows[[length(rows) + 1L]] <<- data.frame(table = table, predicate = predicate, cause = cause,
    status = if (isTRUE(ok)) "PASS" else "FAIL", detail = detail, stringsAsFactors = FALSE)
}
rd <- function(d, t) sr_read_csv(file.path(d, paste0(t, ".csv")))
val <- function(t, col) sr_value(t$cells[, col])
num <- function(t, col) as.numeric(val(t, col))
safely <- function(table, expr) tryCatch(expr, error = function(e) check(table, "ERROR", "", FALSE, conditionMessage(e)))

# Manifests and file set.
manifest_ok <- function(d) {
  m <- utils::read.csv(file.path(d, "manifest.csv"), colClasses = "character")
  sha <- vapply(file.path(d, m$file), function(f) digest::digest(file = f, algo = "sha256"), character(1))
  list(m = m, bad = m$file[sha != m$sha256])
}
mo <- manifest_ok(orig_dir); ms <- manifest_ok(succ_dir); mm <- manifest_ok(model_dir)
check("manifest", "files on manifest, same table set", "", length(mo$bad) + length(ms$bad) + length(mm$bad) == 0L &&
  identical(sort(mo$m$file), sort(ms$m$file)),
  sprintf("off-manifest: original %d, successor %d, model %d; tables %d/%d", length(mo$bad), length(ms$bad),
    length(mm$bad), nrow(mo$m), nrow(ms$m)))

# ---------------------------------------------------------------------------
# pulse_seeds and rule_overlap (v2 rule)
# ---------------------------------------------------------------------------

safely("pulse_seeds", {
  o <- rd(orig_dir, "pulse_seeds"); s <- rd(succ_dir, "pulse_seeds")
  keys_same <- identical(o$header, s$header) && identical(o$cells[, c("execution_seed", "pulse_idx")], s$cells[, c("execution_seed", "pulse_idx")])
  ref <- sr_v2_ref(num(s, "execution_seed"), num(s, "pulse_idx"))
  bad <- sum(ref != as.integer(val(s, "pulse_seed")))
  check("pulse_seeds", "keys identical; pulse_seed = independent v2 reference", "v2 rule (LDG-3159)",
    keys_same && bad == 0L && nrow(s$cells) == 91L,
    sprintf("%d rows; keys identical %s; reference mismatches %d; rows changed from the original %d", nrow(s$cells),
      keys_same, bad, sum(o$cells[, "pulse_seed"] != s$cells[, "pulse_seed"])))
})

safely("rule_overlap", {
  o <- rd(orig_dir, "rule_overlap"); s <- rd(succ_dir, "rule_overlap")
  key <- function(t) paste(val(t, "rule"), val(t, "metric"))
  fixed <- val(o, "rule") %in% c("add", "stride", "mixer")
  same_fixed <- identical(o$header, s$header) && identical(key(o), key(s)) &&
    identical(o$cells[fixed, ], s$cells[fixed, ])
  cur <- val(s, "rule") == "current"
  mixer <- o$cells[val(o, "rule") == "mixer", , drop = FALSE]
  cur_rows <- s$cells[cur, , drop = FALSE]
  m_val <- stats::setNames(sr_value(mixer[, "value"]), sr_value(mixer[, "metric"]))
  cur_ok <- nrow(cur_rows) == nrow(mixer) && all(sr_value(cur_rows[, "value"]) == m_val[sr_value(cur_rows[, "metric"])])
  check("rule_overlap", "add/stride/mixer identical; current = original mixer", "v2 rule (LDG-3159)", same_fixed && cur_ok,
    sprintf("fixed rows identical %s; %d current rows equal the mixer rows %s", same_fixed, nrow(cur_rows), cur_ok))
})

# ---------------------------------------------------------------------------
# census (Section 8.2.1)
# ---------------------------------------------------------------------------

safely("census", {
  o <- rd(orig_dir, "census"); s <- rd(succ_dir, "census")
  new_header <- c('"entry_seed_present:logical"', '"preserve_calls:integer"', '"rngkind_query_calls:integer"',
    '"rngkind_query_callers:character"', '"rngkind_mutation_calls:integer"', '"rngkind_mutation_callers:character"',
    '"pulse_seed_vectors:integer"')
  check("census", "typed header: original 13 unchanged + the 7 frozen cells", "observer schema",
    identical(s$header, c(o$header, new_header)), paste(s$header[-seq_along(o$header)], collapse = ","))
  cases <- val(s, "case")
  check("census", "same ten cases in order", "", identical(cases, val(o, "case")) && length(cases) == 10L,
    paste(cases, collapse = ","))
  copy <- cases %in% c("03", "08"); op <- !copy
  orig13 <- colnames(o$cells)
  check("census", "copy rows 03/08: original 13 identical; new cells NA,NA,NA,\"\",NA,\"\",NA", "observer schema",
    identical(o$cells[copy, ], s$cells[copy, orig13]) &&
      all(apply(s$cells[copy, -seq_along(orig13), drop = FALSE], 1L, function(r) identical(unname(r), c("NA", "NA", "NA", '""', "NA", '""', "NA")))),
    paste(apply(s$cells[copy, -seq_along(orig13), drop = FALSE], 1L, paste, collapse = ","), collapse = " | "))
  same_cols <- c("case", "path", "seed_arg", "default_seed", "set_seed_calls", "set_seed_seeds", "pulse_seed_execution_seeds")
  check("census", "case/path/seed_arg/default_seed/set_seed_calls/set_seed_seeds/pulse_seed_execution_seeds identical", "",
    identical(o$cells[, same_cols], s$cells[, same_cols]), "")
  out_ok <- all(val(s, "outcome")[op] == "ok")
  r05 <- which(cases == "05")
  check("census", "operational outcomes ok; row 05 ERROR -> ok", "walk-forward fix (LDG-3158)",
    out_ok && grepl("^ERROR ledgr_invalid_args", val(o, "outcome")[[r05]]) &&
      identical(val(o, "outcome")[op & cases != "05"], val(s, "outcome")[op & cases != "05"]),
    sprintf("original 05: %s", val(o, "outcome")[[r05]]))
  S <- as.integer(val(s, "set_seed_calls"))
  callers_ok <- all(ifelse(S[op] > 0L, val(s, "set_seed_callers")[op] == "ledgr_rng_seed_pinned" &
    val(s, "set_seed_kind_args")[op] == "Mersenne-Twister", val(s, "set_seed_callers")[op] == "" & val(s, "set_seed_kind_args")[op] == ""))
  check("census", "set_seed_callers ledgr_rng_seed_pinned, kind arg Mersenne-Twister (seeded rows); empty otherwise",
    "kind pin (LDG-3158)", callers_ok, sprintf("original callers: %s", paste(unique(val(o, "set_seed_callers")[op]), collapse = "|")))
  check("census", "entry_seed_present FALSE in every operational row (successor precondition)", "observer",
    all(s$cells[op, "entry_seed_present"] == '"FALSE"'), paste(s$cells[op, "entry_seed_present"], collapse = ","))
  check("census", "query callers ledgr_rng_caller_state; mutation callers ledgr_rng_restore", "caller restore (LDG-3158)",
    all(val(s, "rngkind_query_callers")[op] == "ledgr_rng_caller_state") &&
      all(val(s, "rngkind_mutation_callers")[op] == "ledgr_rng_restore"),
    paste(unique(c(val(s, "rngkind_query_callers")[op], val(s, "rngkind_mutation_callers")[op])), collapse = "|"))
  q <- as.integer(val(s, "rngkind_query_calls")); m <- as.integer(val(s, "rngkind_mutation_calls"))
  check("census", "rngkind_calls = query + mutation", "", all(as.integer(val(s, "rngkind_calls"))[op] == q[op] + m[op]), "")
  # The independent expected-call ledger (Section 8.2.1 table).
  ledger <- data.frame(case = c("01", "02", "04", "05", "06", "07", "09", "10"),
    E = c(1L, 1L, 3L, 1L, 1L, 1L, 3L, 1L), S = c(0L, 0L, 0L, 0L, 1L, 2L, 1L, 6L),
    calls = c(10L, 20L, 10L, 19L, 10L, 20L, 10L, 19L), nonnull = c(0L, 0L, 0L, 0L, 10L, 20L, 10L, 19L),
    stringsAsFactors = FALSE)
  at <- match(ledger$case, cases)
  got <- data.frame(S = S[at], preserve = as.integer(val(s, "preserve_calls"))[at], query = q[at], mutation = m[at],
    rngkind = as.integer(val(s, "rngkind_calls"))[at], calls = as.integer(val(s, "pulse_seed_calls"))[at],
    nonnull = as.integer(val(s, "pulse_seed_nonnull"))[at], vectors = as.integer(val(s, "pulse_seed_vectors"))[at])
  want <- data.frame(S = ledger$S, preserve = ledger$E, query = ledger$E + ledger$S, mutation = ledger$E + ledger$S,
    rngkind = 2L * (ledger$E + ledger$S), calls = ledger$calls, nonnull = ledger$nonnull, vectors = ledger$S)
  diff_cells <- which(as.matrix(got) != as.matrix(want), arr.ind = TRUE)
  check("census", "expected-call ledger (E, S, preserve, query, mutation, rngkind, pulse reads, vectors)",
    "kind pin, walk-forward fix, caller restore, v2 rule", nrow(diff_cells) == 0L,
    if (nrow(diff_cells)) paste(sprintf("case %s %s: got %s want %s", ledger$case[diff_cells[, 1L]], names(got)[diff_cells[, 2L]],
      as.matrix(got)[diff_cells], as.matrix(want)[diff_cells]), collapse = "; ") else
      paste(sprintf("%s:E%d/S%d", ledger$case, ledger$E, ledger$S), collapse = " "))
  oc <- as.integer(val(o, "pulse_seed_calls"))
  check("census", "pulse_seed_calls equal the original except row 05 (6 -> 19 = row 10)", "walk-forward fix (LDG-3158)",
    identical(oc[op & cases != "05"], as.integer(val(s, "pulse_seed_calls"))[op & cases != "05"]) &&
      as.integer(val(s, "pulse_seed_calls"))[[r05]] == as.integer(val(s, "pulse_seed_calls"))[[which(cases == "10")]] &&
      as.integer(val(s, "pulse_seed_nonnull"))[[r05]] == 0L && S[[r05]] == 0L,
    sprintf("row 05: %s -> %s", oc[[r05]], val(s, "pulse_seed_calls")[[r05]]))
  # No other census cell may change: rebuild the expected original-13 cells.
  e <- o$cells
  e[op, "outcome"] <- s$cells[op, "outcome"]
  e[op, c("set_seed_callers", "set_seed_kind_args", "rngkind_calls")] <- s$cells[op, c("set_seed_callers", "set_seed_kind_args", "rngkind_calls")]
  e[r05, c("pulse_seed_calls", "pulse_seed_nonnull")] <- s$cells[r05, c("pulse_seed_calls", "pulse_seed_nonnull")]
  check("census", "no other original-13 cell changed", "", identical(e, s$cells[, orig13]), "")
})

# ---------------------------------------------------------------------------
# Stochastic tables (v2 rule; kind pin for workers)
# ---------------------------------------------------------------------------

safely("worker_agreement", {
  o <- rd(orig_dir, "worker_agreement"); s <- rd(succ_dir, "worker_agreement"); m <- rd(model_dir, "worker_agreement")
  idc <- c("candidate_id", "pin", "execution_seed", "daemon_rng_kind")
  check("worker_agreement", "candidate_id, pin, execution_seed, daemon_rng_kind identical", "",
    identical(o$header, s$header) && identical(o$cells[, idc], s$cells[, idc]), paste(unique(val(s, "daemon_rng_kind")), collapse = ","))
  bools <- c("trades_run_vs_w1", "trades_w1_vs_w2", "equity_run_vs_w1", "equity_w1_vs_w2")
  nt <- sapply(c("n_trades_run", "n_trades_w1", "n_trades_w2"), function(k) as.integer(val(s, k)))
  fe <- sapply(c("final_equity_run", "final_equity_w1", "final_equity_w2"), function(k) val(s, k))
  check("worker_agreement", "statuses DONE; four agreement booleans TRUE", "kind pin (LDG-3158)",
    all(val(s, "status_w1") == "DONE") && all(val(s, "status_w2") == "DONE") && all(s$cells[, bools] == '"TRUE"'),
    sprintf("original FALSE booleans: %d", sum(o$cells[, bools] == '"FALSE"')))
  check("worker_agreement", "n_trades_run == n_trades_w1 == n_trades_w2 >= 10", "kind pin; v2 rule",
    all(nt[, 1L] == nt[, 2L] & nt[, 2L] == nt[, 3L] & nt[, 1L] >= 10L),
    paste(sprintf("%s %d", val(s, "candidate_id"), nt[, 1L]), collapse = ", "))
  mm_at <- match(val(s, "candidate_id"), val(m, "candidate_id"))
  check("worker_agreement", "final equities equal across paths and equal the pulse-rule model", "v2 rule (LDG-3159); kind pin",
    all(fe[, 1L] == fe[, 2L] & fe[, 2L] == fe[, 3L]) && all(fe[, 1L] == val(m, "final_equity_run")[mm_at]) &&
      all(fe[, 2L] == val(m, "final_equity_w1")[mm_at]) && all(nt[, 1L] == as.integer(val(m, "n_trades_run"))[mm_at]),
    paste(sprintf("%s %s", val(s, "candidate_id"), fe[, 1L]), collapse = ", "))
})

safely("stochastic_fills", {
  o <- rd(orig_dir, "stochastic_fills"); s <- rd(succ_dir, "stochastic_fills"); m <- rd(model_dir, "stochastic_fills")
  inst <- tapply(val(s, "instrument_id"), val(s, "candidate_id"), function(x) length(unique(x)))
  check("stochastic_fills", "equal the pulse-rule model; each candidate trades >= 2 instruments", "v2 rule (LDG-3159)",
    identical(s$header, m$header) && identical(s$cells, m$cells) && all(inst >= 2L),
    sprintf("%d rows (original %d); instruments per candidate: %s", nrow(s$cells), nrow(o$cells),
      paste(sprintf("%s %d", names(inst), inst), collapse = ", ")))
})

safely("stochastic_trades", {
  o <- rd(orig_dir, "stochastic_trades"); s <- rd(succ_dir, "stochastic_trades"); m <- rd(model_dir, "stochastic_trades")
  seq_paths <- c("run", "sweep_w1")
  pick <- function(t, p) t$cells[val(t, "path") %in% p, , drop = FALSE]
  check("stochastic_trades", "run and sweep_w1 rows equal the pulse-rule model", "v2 rule (LDG-3159)",
    identical(s$header, m$header) && identical(pick(s, seq_paths), pick(m, seq_paths)),
    sprintf("%d sequential rows (original %d)", nrow(pick(s, seq_paths)), nrow(pick(o, seq_paths))))
  w1 <- pick(s, "sweep_w1"); w2 <- pick(s, "sweep_w2")
  w2[, "path"] <- '"sweep_w1"'
  check("stochastic_trades", "sweep_w2 rows equal sweep_w1 rows for every candidate", "kind pin (LDG-3158)",
    identical(unname(w1), unname(w2)), sprintf("%d w2 rows", nrow(w2)))
})

# ---------------------------------------------------------------------------
# caller_rng, store_rng, detection_gap
# ---------------------------------------------------------------------------

safely("caller_rng", {
  o <- rd(orig_dir, "caller_rng"); s <- rd(succ_dir, "caller_rng")
  set <- !is.na(s$cells[, "before_sha256"]) & s$cells[, "before_sha256"] != "NA"
  state_ok <- all(s$cells[, "caller_rng_unchanged"] == '"TRUE"') && identical(s$cells[, "after_kind"], s$cells[, "before_kind"]) &&
    identical(s$cells[set, "after_sha256"], s$cells[set, "before_sha256"])
  check("caller_rng", "every row unchanged; after_kind = before_kind; after_sha256 = before_sha256 where set",
    "storage neutrality (01, 05, 09); caller restore (13, 15)", state_ok, "")
  fields <- c("caller_rng_unchanged", "after_kind", "after_sha256")
  changed <- which(apply(o$cells != s$cells, 1L, any))
  others <- setdiff(colnames(o$cells), fields)
  check("caller_rng", "only rows 01, 05, 09, 13, 15 change, only in the three state fields", "",
    identical(o$header, s$header) && identical(val(s, "case")[changed], c("01", "05", "09", "13", "15")) &&
      identical(o$cells[, others], s$cells[, others]),
    sprintf("changed rows: %s", paste(val(s, "case")[changed], collapse = ",")))
})

safely("store_rng", {
  o <- rd(orig_dir, "store_rng"); s <- rd(succ_dir, "store_rng")
  want <- c(a = "99984.34987600008", b = "99967.891749199887")
  id <- val(s, "id")
  eq_ok <- all(val(s, "equity_identical") == "TRUE") && all(s$cells[, "first_differing_pulse"] == "NA") &&
    all(val(s, "final_equity_a") == want[id]) && all(val(s, "final_equity_b") == want[id])
  others <- setdiff(colnames(o$cells), c("final_equity_a", "final_equity_b", "equity_identical", "first_differing_pulse"))
  check("store_rng", "identical equities, no differing pulse, frozen values (a 99984.34987600008, b 99967.891749199887)",
    "RNG-neutral storage (LDG-3158)", eq_ok && identical(o$header, s$header) && identical(o$cells[, others], s$cells[, others]),
    paste(sprintf("%s: %s / %s", id, val(s, "final_equity_a"), val(s, "final_equity_b")), collapse = "; "))
})

safely("detection_gap", {
  check("detection_gap", "identical", "none (decision (11))",
    identical(rd(orig_dir, "detection_gap")$lines, rd(succ_dir, "detection_gap")$lines), "")
})

rep <- do.call(rbind, rows)
if (!is.null(result_file)) utils::write.csv(rep, result_file, row.names = FALSE)
cat(sprintf("rng successor comparison: original %s, successor %s, model %s\n", orig_dir, succ_dir, model_dir))
for (i in seq_len(nrow(rep))) cat(sprintf("  %-4s %-17s %s [%s] %s\n", rep$status[[i]], rep$table[[i]], rep$predicate[[i]],
  rep$cause[[i]], rep$detail[[i]]))
fails <- sum(rep$status == "FAIL")
cat(sprintf("\nrng successor comparison: %s (%d checks, %d fail)\n", if (fails) "FAIL" else "PASS", nrow(rep), fails))
quit(status = if (fails) 1L else 0L)

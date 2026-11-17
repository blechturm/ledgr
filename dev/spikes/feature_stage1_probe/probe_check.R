# Candidates 2 and 3, correctness: every case runs under the pin and each
# candidate arm in one session, and its outputs are written as digests:
#   values   the feature matrices (values, NA placement, type, dims, names)
#   planes   the retained plane records (the ledgr_feature_planes attribute)
#   proj     the projection's indexed planes and value matrices
#   reads    history-read evidence (reasons, flags, sources, ages) for every
#            feature over every instrument x session at the last cutoff
#   refusal  condition classes and identifying fields, when the case refuses
#   rng      .Random.seed unchanged by the call
# check.R diffs the candidate rows against the pin rows.
#
#   Rscript probe_check.R --lib=<pinned library> --out=<csv>

arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
.libPaths(c(arg("lib"), .libPaths()))
library(ledgr)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
source(file.path(here, "patches.R"))
source(file.path(here, "fixtures.R"))

stopifnot(sum(grepl("treat_fields", deparse(body(c2_compute)), fixed = TRUE)) == 2L,
          sum(grepl("treat_fields", deparse(body(c2_causality)), fixed = TRUE)) == 2L)

dig <- function(x) digest::digest(x, algo = "sha256")
condition_summary <- function(e) {
  list(class = class(e), feature_id = e$feature_id, instrument_id = e$instrument_id,
       ts_utc = e$ts_utc, message = conditionMessage(e))
}

run_case <- function(substrate, defs, calculation_start) {
  set.seed(1L)
  seed <- .Random.seed
  res <- tryCatch(ns$ledgr_history_compute_feature_series(substrate, defs, calculation_start = calculation_start),
                  error = function(e) structure(condition_summary(e), class = "refusal"))
  rng_ok <- identical(seed, .Random.seed)
  if (inherits(res, "refusal")) {
    return(list(values = NA, planes = NA, proj = NA, reads = NA, refusal = dig(unclass(res)), rng = rng_ok,
                refusal_class = res$class[[1L]]))
  }
  planes <- attr(res, "ledgr_feature_planes")
  proj <- ns$ledgr_projection_from_feature_matrix(res, universe = substrate$instrument_ids,
    pulses_posix = substrate$axis, feature_engine_version = "fixed", alias_index = NULL)
  bound <- ns$ledgr_history_substrate_bind_features(substrate, proj)
  n_axis <- length(substrate$axis)
  reads <- lapply(names(res), function(id) tryCatch(
    ns$ledgr_history_feature_evidence(bound, id, seq_along(substrate$instrument_ids), seq_len(n_axis), n_axis),
    error = function(e) condition_summary(e)))
  values <- res
  attr(values, "ledgr_feature_planes") <- NULL
  list(values = dig(values), planes = dig(planes), proj = dig(proj[c("feature_values", "feature_planes")]),
       reads = dig(reads), refusal = NA, rng = rng_ok, refusal_class = "")
}

# Counts of the registered raw-call seam and of segment frames, per arm.
count_calls <- function(substrate, defs) {
  n <- new.env()
  n$raw <- 0L; n$frame <- 0L
  raw <- get("ledgr_ttr_raw_call", ns); frame <- get("ledgr_history_feature_frame", ns)
  set_binding("ledgr_ttr_raw_call", function(...) { n$raw <- n$raw + 1L; raw(...) })
  set_binding("ledgr_history_feature_frame", function(...) { n$frame <- n$frame + 1L; frame(...) })
  on.exit({ set_binding("ledgr_ttr_raw_call", raw); set_binding("ledgr_history_feature_frame", frame) })
  ns$ledgr_history_compute_feature_series(substrate, defs)
  c(raw = n$raw, frame = n$frame)
}

substrates <- list(
  hostile_carry2 = fx_hostile(ledgr::ledgr_history_policy(price_carry = 2L)),
  hostile_strict = fx_hostile(ledgr::ledgr_history_policy(price_carry = NULL)),
  hostile_outcarry = fx_hostile(ledgr::ledgr_history_policy(price_carry = 2L, output_carry = 2L)),
  panel_carry5 = fx_panel(ledgr::ledgr_history_policy()),
  panel_strict_outcarry = fx_panel(ledgr::ledgr_history_policy(price_carry = NULL, output_carry = 3L)),
  short = fx_short(ledgr::ledgr_history_policy()))
sets <- fx_defs()
starts <- list(data_start = NULL, late_start = "late", past_end = "past")
# c2naive is the negative control: it must differ somewhere.
arms <- c("pin", "c2", "c3", "c23", "c2naive")

rows <- list()
for (s in names(substrates)) {
  sub <- substrates[[s]]
  for (st in names(starts)) {
    calc_start <- switch(st, data_start = NULL,
                         late_start = sub$axis[[max(1L, floor(length(sub$axis) / 3))]],
                         past_end = sub$axis[[length(sub$axis)]] + 86400)
    for (set in names(sets)) {
      for (arm in arms) {
        use_arm(arm)
        r <- run_case(sub, sets[[set]], calc_start)
        rows[[length(rows) + 1L]] <- data.frame(substrate = s, start = st, set = set, arm = arm,
          values = r$values, planes = r$planes, proj = r$proj, reads = r$reads, refusal = r$refusal,
          refusal_class = r$refusal_class, rng = r$rng, stringsAsFactors = FALSE)
      }
    }
  }
}

# Single-definition history-read entry (ledgr_history_feature_planes) for a
# few definitions; it calls the calculation without a raw cache.
for (s in c("hostile_carry2", "panel_carry5")) {
  sub <- substrates[[s]]
  for (set in c("close", "hlc", "custom_volume")) {
    for (d in sets[[set]][seq_len(min(3L, length(sets[[set]])))]) {
      for (arm in arms) {
        use_arm(arm)
        out <- lapply(sub$instrument_ids, function(id) tryCatch(
          ns$ledgr_history_feature_planes(sub, id, d), error = condition_summary))
        rows[[length(rows) + 1L]] <- data.frame(substrate = s, start = "planes_entry", set = paste0(set, ":", d$id),
          arm = arm, values = dig(out), planes = NA, proj = NA, reads = NA, refusal = NA, refusal_class = "",
          rng = TRUE, stringsAsFactors = FALSE)
      }
    }
  }
}
out <- do.call(rbind, rows)
utils::write.csv(out, arg("out"), row.names = FALSE)

# Raw-call sharing and frame counts.
counts <- list()
for (s in c("hostile_carry2", "panel_carry5")) for (set in c("close", "hlc", "all_cert", "mixed")) {
  for (arm in arms) {
    use_arm(arm)
    k <- tryCatch(count_calls(substrates[[s]], sets[[set]]), error = function(e) c(raw = NA, frame = NA))
    counts[[length(counts) + 1L]] <- data.frame(substrate = s, set = set, arm = arm,
      raw_calls = k[["raw"]], frames = k[["frame"]], stringsAsFactors = FALSE)
  }
}
use_arm("pin")
utils::write.csv(do.call(rbind, counts), sub("[.]csv$", "_counts.csv", arg("out")), row.names = FALSE)

# Field unions the c2 rule computes per set (certified canonical required fields).
unions <- vapply(sets, function(defs) paste(c2_field_union(lapply(defs, ns$ledgr_feature_certify)), collapse = ","), "")
utils::write.csv(data.frame(set = names(unions), treated_fields = unname(unions)),
                 sub("[.]csv$", "_unions.csv", arg("out")), row.names = FALSE)

# Catalogue invariant the c2 rule relies on: each registered TTR row's
# required fields equal its input mapping's fields.
cat_rows <- ns$ledgr_indicator_history_catalogue()
rules <- ns$ledgr_ind_ttr_warmup_rules()
ttr_rows <- cat_rows[cat_rows$source == "TTR", ]
mapped <- vapply(ttr_rows$family, function(f) {
  paste(ns$ledgr_ttr_required_fields(rules$input[match(f, rules$ttr_fn)]), collapse = ",")
}, "")
cat("catalogue TTR rows whose required fields differ from the input mapping:",
    sum(mapped != ttr_rows$required_fields), "of", nrow(ttr_rows), "\n")
cat("cases:", nrow(out) / length(arms)," refusing pin cases:", sum(out$arm == "pin" & nzchar(out$refusal_class)), "\n")
print(table(out$refusal_class[out$arm == "pin"]))

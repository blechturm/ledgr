# The feature-path oracle's checker (Cut 22 decision 2, LDG-3249). Diffs a
# candidate arm's observations against the pin arm's, case by case and
# component by component, and checks both against the committed corpus
# (corpus_expected.csv: the case list and each case's certification, field
# union, route, refusal class and TTR route agreement, as the pin d5b3a151
# produced them).
#
#   Rscript check.R --pin=<runner out dir> --candidate=<runner out dir> [--expected=<csv>]
#   Rscript check.R --pin=<runner out dir> --write-expected=<csv>   (records the corpus from a pin run)
#   Rscript check.R --pin=<runner out dir> --write-gate-expected=<csv>   (records the gate expectation)
#
# Stage 3 (Cut 24 LDG-3264, synthesis rule 11): the direct path removes
# treatment hand-offs and adds debug shadow work, so three mechanism
# observations are no longer compared as text with the pin. handoffs:
# reach and causality fields equal the pin's and inputs observed plus
# untreated ranges equal the pin's inputs observed. gate: the cells the
# direct path computed and the ranges it left untreated, per preparation,
# equal the committed gate_expected.csv (the harness predicate on the pin)
# for an arm with the direct path (untreated ranges only with debug off),
# and are empty otherwise; a refusing case may stop early, so its
# observations are a prefix of the expectation. shadow: none with debug
# off; with debug on, exactly one shadow cell per direct cell. Every other
# component, the production route and calculated_count included, still
# equals the pin.
#
# Exit 0 and "CHECK PASS": every case identical and matching the corpus.
# Exit 1: a difference; one "SIGNAL <component> <n cases>" line per differing
#   component, then "CHECK FAIL".
# Exit 2: a refusal; a missing arm, case or component, or an unreadable file.
local({
  argv <- commandArgs(TRUE)
  arg <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  refuse <- function(...) {
    cat("REFUSED:", ..., "\n")
    quit(save = "no", status = 2L)
  }
  read_arm <- function(dir, what) {
    if (is.null(dir)) refuse("--", what, "=<dir> is required")
    file <- file.path(dir, "observations.csv")
    if (!file.exists(file)) refuse("missing arm: no observations.csv in ", dir)
    x <- utils::read.csv(file, stringsAsFactors = FALSE, na.strings = character(), colClasses = "character")
    if (!identical(names(x), c("family", "case", "component", "value"))) refuse("unexpected columns in ", file)
    key <- paste(x$family, x$case, x$component, sep = " | ")
    if (anyDuplicated(key)) refuse("duplicated observation in ", file, ": ", key[anyDuplicated(key)])
    x$key <- key
    x$case_key <- paste(x$family, x$case, sep = " | ")
    x
  }
  always <- c("rng", "route", "callback", "causality", "treated_fields", "handoffs", "refusal", "refusal_class",
              "gate_expected", "gate", "shadow", "calculated_count")
  per_family <- list(
    compute = list(always = c("certification", "field_union"), data = c("values", "na", "planes", "proj", "reads")),
    read_entry = list(always = "certification", data = "values"),
    ttr_route = list(always = character(), data = c("values", "routes_equal")),
    axis = list(always = character(), data = c("dimnames", "pulse_index", "pulses_posix", "pulses_iso",
                                               "projection", "slice", "axis_hash", "history_axis")))
  e2e_data <- list(run = "history", sweep = c("history", "sweep_table"), precompute = "precompute",
                   precompute_reuse = c("history", "sweep_table"), inspect = "history", dated_run = "history",
                   refuse_run = character(), refuse_sweep = character(), refuse_precompute = character())
  e2e_always <- list(refuse_run = "store", refuse_sweep = "store")
  # Each case holds its family's components: the data components exactly when
  # it did not refuse.
  complete <- function(x, label) {
    for (ck in unique(x$case_key)) {
      rows <- x[x$case_key == ck, ]
      family <- rows$family[[1L]]
      if (family == "e2e") {
        kind <- sub("^[^|]*[|]", "", rows$case[[1L]])
        if (is.null(e2e_data[[kind]])) refuse(label, ": unknown e2e case ", ck)
        need <- c(always, e2e_always[[kind]])
        data <- e2e_data[[kind]]
      } else {
        if (is.null(per_family[[family]])) refuse(label, ": unknown family ", family)
        need <- c(always, per_family[[family]]$always)
        data <- per_family[[family]]$data
      }
      refused <- any(rows$component == "refusal" & rows$value != "none")
      if (!refused) need <- c(need, data)
      missing <- setdiff(need, rows$component)
      extra <- setdiff(rows$component, c(need, if (refused) character() else data))
      if (length(missing)) refuse(label, ": case ", ck, " lacks component(s) ", paste(missing, collapse = ", "))
      if (length(extra)) refuse(label, ": case ", ck, " has unexpected component(s) ", paste(extra, collapse = ", "))
    }
  }
  pin <- read_arm(arg("pin"), "pin")
  complete(pin, "pin")
  structural <- c("certification", "field_union", "route", "refusal_class", "routes_equal")

  if (!is.null(arg("write-gate-expected"))) {
    out <- pin[pin$component == "gate_expected", c("family", "case", "value")]
    out <- out[order(out$family, out$case, method = "radix"), ]
    utils::write.csv(out, arg("write-gate-expected"), row.names = FALSE)
    cat("wrote", nrow(out), "gate expectations to", arg("write-gate-expected"), "\n")
    quit(save = "no", status = 0L)
  }
  if (!is.null(arg("write-expected"))) {
    out <- pin[pin$component %in% structural, c("family", "case", "component", "value")]
    cases <- unique(pin[c("family", "case")])
    out <- rbind(out, data.frame(family = cases$family, case = cases$case, component = "case", value = "present"))
    out <- out[order(out$family, out$case, out$component, method = "radix"), ]
    utils::write.csv(out, arg("write-expected"), row.names = FALSE)
    cat("wrote", nrow(cases), "cases to", arg("write-expected"), "\n")
    quit(save = "no", status = 0L)
  }

  cand <- read_arm(arg("candidate"), "candidate")
  complete(cand, "candidate")
  expected_file <- arg("expected", file.path(here, "corpus_expected.csv"))
  if (!file.exists(expected_file)) refuse("missing corpus file ", expected_file)
  expected <- utils::read.csv(expected_file, stringsAsFactors = FALSE, na.strings = character(),
                              colClasses = "character")
  expected$key <- paste(expected$family, expected$case, expected$component, sep = " | ")
  corpus_cases <- unique(paste(expected$family, expected$case, sep = " | "))
  for (arm in list(list("pin", pin), list("candidate", cand))) {
    have <- unique(arm[[2L]]$case_key)
    missing <- setdiff(corpus_cases, have)
    extra <- setdiff(have, corpus_cases)
    if (length(missing)) refuse(arm[[1L]], " misses ", length(missing), " corpus case(s), first: ", missing[[1L]])
    if (length(extra)) refuse(arm[[1L]], " has ", length(extra), " case(s) outside the corpus, first: ", extra[[1L]])
  }

  bad <- 0L
  signal <- function(component, cases, why) {
    cat(sprintf("SIGNAL %s %d  (%s; first: %s)\n", component, length(cases), why, cases[[1L]]))
    bad <<- bad + 1L
  }
  # 1. the corpus: both arms take the recorded route, certification, field
  #    union and refusal class on every case.
  want <- expected[expected$component != "case", ]
  for (arm in list(list("pin", pin), list("candidate", cand))) {
    got <- arm[[2L]][match(want$key, arm[[2L]]$key), ]
    off <- is.na(got$value) | got$value != want$value
    for (component in unique(want$component[off])) {
      hit <- off & want$component == component
      signal(component, paste(want$family[hit], want$case[hit], sep = " | "), paste(arm[[1L]], "differs from the corpus"))
    }
  }
  # 2. candidate against pin, every component but treated_fields, which each
  #    arm's own mechanism determines (4. below). handoffs (which hand-offs a
  #    case reaches and how many were observed) is compared here, so the
  #    candidate's reach is the pin's.
  keys <- union(pin$key, cand$key)
  a <- pin$value[match(keys, pin$key)]
  b <- cand$value[match(keys, cand$key)]
  component <- c(pin$component, cand$component)[match(keys, c(pin$key, cand$key))]
  case_key <- c(pin$case_key, cand$case_key)[match(keys, c(pin$key, cand$key))]
  off <- (is.na(a) | is.na(b) | a != b) & !component %in% c("treated_fields", "handoffs", "gate", "shadow")
  for (cmp in sort(unique(component[off]), method = "radix")) {
    signal(cmp, unique(case_key[off & component == cmp]), "candidate differs from pin")
  }
  # 3. invariants inside each arm.
  for (arm in list(list("pin", pin), list("candidate", cand))) {
    x <- arm[[2L]]
    for (cmp in c("rng", "routes_equal")) {
      hit <- x$component == cmp & x$value != "TRUE"
      if (any(hit)) signal(cmp, x$case_key[hit], paste(arm[[1L]], "has FALSE"))
    }
  }
  # 4. the fields each arm actually treats (close review round 1, F3),
  #    observed at every ledgr_history_feature_inputs() call of the
  #    preparation and of the causality probe. An arm with the field selector
  #    (candidate 2) must treat exactly the certified union the corpus records
  #    for a compute case; an arm without it (the pin) treats all five; the
  #    single-definition read entry treats all five on every arm. Each phase
  #    is checked on its own and must be observed wherever the case reaches
  #    it (re-review 1, G1): handoffs records, from other seams, the hand-offs
  #    reached per phase and the number observed. A phase has field entries
  #    exactly when it was observed; every reached hand-off is observed, and
  #    a case whose preparation reached a hand-off has observed at least one,
  #    refusals included (re-review 2, H1: the counts come from one observer,
  #    so only the independent reach can demand it); a refusal during
  #    preparation may stop before the rest of its ranges, so a refusing case
  #    may observe fewer, never none. The causality phase is reached whenever the probe checked a definition,
  #    that is whenever cells were calculated, and is absent otherwise; an
  #    empty preparation trace is allowed only where no hand-off was reached
  #    (an early return).
  all5 <- "open,high,low,close,volume"
  selector <- function(dir) {
    p <- utils::read.csv(file.path(dir, "provenance.csv"), stringsAsFactors = FALSE, colClasses = "character")
    v <- p$value[p$field == "field_selector"]
    if (length(v) != 1L) refuse("no field_selector in ", file.path(dir, "provenance.csv"))
    identical(v, "TRUE")
  }
  union_of <- stats::setNames(expected$value[expected$component == "field_union"],
                              paste(expected$family, expected$case, sep = " | ")[expected$component == "field_union"])
  for (arm in list(list("pin", pin, arg("pin")), list("candidate", cand, arg("candidate")))) {
    x <- arm[[2L]]
    has_selector <- selector(arm[[3L]])
    tf <- x[x$component == "treated_fields", ]
    ho <- x$value[match(paste(tf$case_key, "handoffs", sep = " | "), x$key)]
    refused <- x$value[match(paste(tf$case_key, "refusal", sep = " | "), x$key)] != "none"
    missing <- character()
    wrong <- character()
    for (i in seq_len(nrow(tf))) {
      h <- strsplit(strsplit(ho[[i]], ";", fixed = TRUE)[[1L]], "=", fixed = TRUE)
      h <- stats::setNames(as.integer(vapply(h, `[`, "", 2L)), vapply(h, `[`, "", 1L))
      # Ranges the direct path left untreated (stage 3) are reached and
      # handed off without a treated-fields observation.
      direct <- if ("prep_direct" %in% names(h)) h[["prep_direct"]] else 0L
      entries <- if (nzchar(tf$value[[i]])) strsplit(tf$value[[i]], ";", fixed = TRUE)[[1L]] else character()
      tag <- sub(":.*$", "", entries)
      fields <- sub("^[^:]*:", "", entries)
      ok <- all(tag %in% c("prep", "causality")) &&
        (h[["prep_seen"]] > 0L) == any(tag == "prep") &&
        (h[["causality_seen"]] > 0L) == any(tag == "causality") &&
        (h[["prep_reached"]] == 0L || h[["prep_seen"]] + direct >= 1L) &&
        (if (refused[[i]]) h[["prep_seen"]] + direct <= h[["prep_reached"]] else h[["prep_seen"]] + direct == h[["prep_reached"]]) &&
        h[["causality_seen"]] == h[["causality_reached"]] &&
        (h[["causality_checks"]] > 0L) == (h[["causality_reached"]] > 0L)
      if (!ok) missing <- c(missing, tf$case_key[[i]])
      if (!tf$family[[i]] %in% c("compute", "read_entry")) next
      want <- if (tf$family[[i]] == "read_entry" || !has_selector) all5 else union_of[[tf$case_key[[i]]]]
      for (p in c("prep", "causality")) {
        if (any(fields[tag == p] != want)) wrong <- c(wrong, tf$case_key[[i]])
      }
    }
    if (length(missing)) {
      signal("treated_fields", unique(missing), paste(arm[[1L]], "lacks a treated-fields observation where its hand-offs say one was reached"))
    }
    if (length(wrong)) {
      signal("treated_fields", unique(wrong),
             paste(arm[[1L]], if (has_selector) "treats fields other than the certified union" else "does not treat all five fields"))
    }
  }
  # 5. stage-3 mechanism (LDG-3264): hand-offs, gate choices, debug shadow.
  parse_kv <- function(v) {
    kv <- strsplit(strsplit(v, ";", fixed = TRUE)[[1L]], "=", fixed = TRUE)
    stats::setNames(as.integer(vapply(kv, `[`, "", 2L)), vapply(kv, `[`, "", 1L))
  }
  ho_pin <- pin[pin$component == "handoffs", ]
  ho_cand <- cand$value[match(ho_pin$key, cand$key)]
  ho_bad <- character()
  for (i in seq_len(nrow(ho_pin))) {
    a <- parse_kv(ho_pin$value[[i]])
    b <- parse_kv(ho_cand[[i]])
    direct_a <- if ("prep_direct" %in% names(a)) a[["prep_direct"]] else 0L
    direct_b <- if ("prep_direct" %in% names(b)) b[["prep_direct"]] else 0L
    same <- c("prep_reached", "causality_checks", "causality_reached", "causality_seen")
    if (!all(same %in% names(b)) || !identical(a[same], b[same]) ||
        a[["prep_seen"]] + direct_a != b[["prep_seen"]] + direct_b) {
      ho_bad <- c(ho_bad, ho_pin$case_key[[i]])
    }
  }
  if (length(ho_bad)) signal("handoffs", ho_bad, "candidate hand-offs differ from the pin's")
  gate_file <- arg("gate-expected", file.path(here, "gate_expected.csv"))
  if (!file.exists(gate_file)) refuse("missing gate expectation file ", gate_file)
  gate_want <- utils::read.csv(gate_file, stringsAsFactors = FALSE, na.strings = character(), colClasses = "character")
  gate_want <- stats::setNames(gate_want$value, paste(gate_want$family, gate_want$case, sep = " | "))
  if (!setequal(names(gate_want), corpus_cases)) refuse("gate expectation cases differ from the corpus in ", gate_file)
  prov <- function(dir, field) {
    p <- utils::read.csv(file.path(dir, "provenance.csv"), stringsAsFactors = FALSE, colClasses = "character")
    v <- p$value[p$field == field]
    if (length(v) == 1L) v else ""
  }
  # One expectation per preparation: "#<n> cells=<a,b> untreated=<c,d>".
  expected_steps <- function(value, debug_on) {
    if (!nzchar(value)) return(character())
    steps <- character()
    for (prep in strsplit(value, ";", fixed = TRUE)[[1L]]) {
      n <- sub("^(#[0-9]+) .*$", "\\1", prep)
      cells <- sub("^.* cells=([^ ]*) untreated=.*$", "\\1", prep)
      untreated <- sub("^.* untreated=(.*)$", "\\1", prep)
      split <- function(s) if (nzchar(s)) strsplit(s, ",", fixed = TRUE)[[1L]] else character()
      cells <- split(cells)
      untreated <- if (debug_on) character() else split(untreated)
      # The direct path reads an instrument's untreated inputs before its
      # cells, in instrument order.
      inst <- sub("^.*@", "", cells)
      order_keys <- unique(c(inst, untreated))
      for (id in order_keys) {
        if (id %in% untreated) steps <- c(steps, paste0(n, " untreated=", id))
        steps <- c(steps, paste0(n, " cell=", cells[inst == id]))
      }
    }
    steps
  }
  for (arm in list(list("pin", pin, arg("pin")), list("candidate", cand, arg("candidate")))) {
    x <- arm[[2L]]
    direct_path <- identical(prov(arm[[3L]], "direct_path"), "TRUE")
    debug_on <- identical(prov(arm[[3L]], "debug"), "1")
    ge <- x[x$component == "gate_expected", ]
    off <- ge$value != unname(gate_want[ge$case_key])
    if (any(off)) signal("gate_expected", ge$case_key[off], paste(arm[[1L]], "harness predicate differs from", basename(gate_file)))
    g <- x[x$component == "gate", ]
    refused <- x$value[match(paste(g$case_key, "refusal", sep = " | "), x$key)] != "none"
    gate_bad <- character()
    shadow_bad <- character()
    for (i in seq_len(nrow(g))) {
      seen <- if (nzchar(g$value[[i]])) strsplit(g$value[[i]], ";", fixed = TRUE)[[1L]] else character()
      want <- if (direct_path) expected_steps(gate_want[[g$case_key[[i]]]], debug_on) else character()
      ok <- if (refused[[i]]) identical(seen, utils::head(want, length(seen))) else identical(seen, want)
      if (!ok) gate_bad <- c(gate_bad, g$case_key[[i]])
      sh <- parse_kv(x$value[match(paste(g$case_key[[i]], "shadow", sep = " | "), x$key)])
      cells <- sum(grepl(" cell=", seen, fixed = TRUE))
      want_shadow <- if (debug_on) cells else 0L
      quiet <- sum(sh[setdiff(names(sh), "cells")]) == 0L
      if (sh[["cells"]] != want_shadow || (!debug_on && !quiet) || (debug_on && cells == 0L && !quiet)) {
        shadow_bad <- c(shadow_bad, g$case_key[[i]])
      }
    }
    if (length(gate_bad)) signal("gate", gate_bad, paste(arm[[1L]], "gate choices differ from", basename(gate_file)))
    if (length(shadow_bad)) signal("shadow", shadow_bad, paste(arm[[1L]], "debug shadow work differs from one shadow cell per direct cell"))
  }
  n_cases <- length(corpus_cases)
  n_refusing <- sum(pin$component == "refusal_class" & pin$value != "none")
  cat(sprintf("cases %d (refusing on the pin %d), observations pin %d candidate %d\n",
              n_cases, n_refusing, nrow(pin), nrow(cand)))
  if (bad > 0L) {
    cat("CHECK FAIL:", bad, "signal(s)\n")
    quit(save = "no", status = 1L)
  }
  cat("CHECK PASS\n")
})

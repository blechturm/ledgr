# The feature-path oracle's checker (Cut 22 decision 2, LDG-3249). Diffs a
# candidate arm's observations against the pin arm's, case by case and
# component by component, and checks both against the committed corpus
# (corpus_expected.csv: the case list and each case's certification, field
# union, route, refusal class and TTR route agreement, as the pin d5b3a151
# produced them).
#
#   Rscript check.R --pin=<runner out dir> --candidate=<runner out dir> [--expected=<csv>]
#   Rscript check.R --pin=<runner out dir> --write-expected=<csv>   (records the corpus from a pin run)
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
  always <- c("rng", "route", "callback", "causality", "refusal", "refusal_class")
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
  # 2. candidate against pin, every component.
  keys <- union(pin$key, cand$key)
  a <- pin$value[match(keys, pin$key)]
  b <- cand$value[match(keys, cand$key)]
  component <- c(pin$component, cand$component)[match(keys, c(pin$key, cand$key))]
  case_key <- c(pin$case_key, cand$case_key)[match(keys, c(pin$key, cand$key))]
  off <- is.na(a) | is.na(b) | a != b
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

# Hot-path bans (macro rule 17; contract: inst/design/ledgr_v0_2_3_spec_packet
# macro_plan.md Section 1 rules 14 and 17). Code that can run per pulse may
# not gain a banned call (match, %in%, setdiff, setNames, unique, data.frame,
# as.data.frame, rbind, all.equal) or a canonical JSON encode or parse without
# a reviewed baseline row. The scanner lives in tools/codebase-structure.R and
# its committed records in dev/bench/v0_2_2_pre_cran_removal/census/hot_path_*.
# Synthetic packages below exercise each rule without product code.

ledgr_hot_path_scanner <- local({
  cached <- NULL
  function() {
    if (!is.null(cached)) return(cached)
    scanner <- new.env(parent = globalenv())
    sys.source(
      file.path(ledgr_test_source_root(), "tools", "codebase-structure.R"),
      envir = scanner
    )
    cached <<- scanner
    cached
  }
})

# A synthetic package: an envelope whose run loop calls stage_observe() each
# pulse, after a setup call that is not per pulse. `body` is placed in
# stage_observe(), `loop` inside the loop, `extra` after the envelope.
ledgr_hot_path_probe <- function(body = "invisible(NULL)", loop = "",
                                 extra = character(), exports = character(),
                                 s3 = character(), marker = TRUE, after = "") {
  root <- tempfile("ledgr-hot-path-probe-")
  dir.create(file.path(root, "R"), recursive = TRUE)
  stage <- if (marker) "      stage_observe(i)" else "      other_stage(i)"
  writeLines(c(
    "envelope <- function() {",
    "  run_loop <- function() {",
    "    setup_only()",
    "    for (i in 1:3) {",
    stage,
    paste0("      ", loop),
    "    }",
    paste0("    ", after),
    "  }",
    "  run_loop()",
    "}",
    "stage_observe <- function(i) {",
    paste0("  ", body),
    "}",
    "other_stage <- function(i) invisible(i)",
    "setup_only <- function() match(1, 1)",
    extra
  ), file.path(root, "R", "probe.R"))
  namespace <- c(
    if (length(exports)) paste0("export(", exports, ")"),
    if (length(s3)) paste0("S3method(", s3, ")")
  )
  writeLines(as.character(namespace), file.path(root, "NAMESPACE"))
  root
}

ledgr_hot_path_probe_policy <- function() {
  policy <- ledgr_hot_path_scanner()$ledgr_hot_path_default_policy()
  policy$loop_owner <- "envelope/run_loop"
  policy$loop_marker <- "stage_observe"
  policy$bundle_owner <- "probe_bundle"
  policy
}

ledgr_hot_path_probe_eval <- function(root, records = list()) {
  ledgr_hot_path_scanner()$ledgr_hot_path_evaluate(
    root, records, ledgr_hot_path_probe_policy()
  )
}

ledgr_hot_path_count <- function(evaluation, node, call) {
  bans <- evaluation$bans
  sum(bans$count[bans$node == node & bans$call == call])
}

ledgr_hot_path_table <- function(...) {
  rows <- list(...)
  as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
}

ledgr_hot_path_declarations <- function(...) {
  columns <- c("kind", "node", "site", "occurrence", "targets", "reason")
  rows <- list(...)
  if (!length(rows)) {
    return(stats::setNames(
      as.data.frame(matrix(character(), 0L, 6L), stringsAsFactors = FALSE),
      columns
    ))
  }
  out <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  stats::setNames(out, columns)
}

# A discovery result is usable only when it found functions and the loop.
ledgr_hot_path_assert_discovery <- function(evaluation) {
  if (length(evaluation$scan$nodes) == 0L || evaluation$scan$loop_count != 1L) {
    stop("hot-path discovery found nothing to check", call. = FALSE)
  }
  invisible(TRUE)
}

# ledgr-test-profile: fast
testthat::test_that("[LTB-0546] banned calls in per-pulse package code equal the committed hot-path baseline", {
  root <- ledgr_test_source_root()
  scanner <- ledgr_hot_path_scanner()
  if (ledgr_test_checkout_context(root)) {
    records <- scanner$ledgr_hot_path_read_records(scanner$ledgr_hot_path_record_dir(root))
    evaluation <- scanner$ledgr_hot_path_evaluate(root, records)
    ledgr_hot_path_assert_discovery(evaluation)
    testthat::expect_true(scanner$ledgr_hot_path_check(
      evaluation, records, scanner$ledgr_hot_path_analyzer_hash(root)
    ))
    # A checkout with a missing record fails rather than skipping.
    partial <- tempfile("ledgr-hot-path-partial-")
    dir.create(partial)
    files <- scanner$ledgr_hot_path_record_files()
    file.copy(file.path(scanner$ledgr_hot_path_record_dir(root), files[-1L]), partial)
    testthat::expect_error(
      scanner$ledgr_hot_path_read_records(partial),
      "missing hot-path records"
    )
  } else {
    testthat::expect_false(dir.exists(file.path(root, "dev")))
    evaluation <- scanner$ledgr_hot_path_evaluate(root, list())
    ledgr_hot_path_assert_discovery(evaluation)
    testthat::expect_gt(nrow(evaluation$reach), 0L)
  }
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0547] a banned call in per-pulse code is counted however it is written", {
  node <- "stage_observe"
  cases <- list(
    "call head" = list(body = "match(i, 1)", node = node),
    "formals default" = list(body = "invisible(i)", node = "helper_default",
      extra = "helper_default <- function(x = match(1, 1)) x", hook = "helper_default()"),
    "bare function argument" = list(body = "vapply(list(i), match, integer(1), table = 1)", node = node),
    "qualified function argument" = list(body = "lapply(list(i), base::match, table = 1)", node = node),
    "literal do.call" = list(body = "do.call(\"match\", list(i, 1))", node = node),
    "local alias" = list(body = "f <- match; f(i, 1)", node = node),
    "named inline FUN" = list(body = "lapply(list(i), FUN = function(z) match(z, 1))", node = node),
    "lexical local closure" = list(body = "g <- function(z) match(z, 1); g(i)", node = "stage_observe/g"),
    "list member dispatch" = list(body = "obj <- list(run = function(z) match(z, 1)); obj$run(i)",
      node = "stage_observe$run"),
    "assigned member dispatch" = list(body = "obj <- list(); obj$run <- function(z) match(z, 1); obj$run(i)",
      node = "stage_observe$run"),
    "literal [[ dispatch" = list(body = "obj <- list(run = function(z) match(z, 1)); obj[[\"run\"]](i)",
      node = "stage_observe$run"),
    "message argument" = list(body = "message(match(i, 1))", node = node),
    "returning *_abort lookalike" = list(body = "probe_check_abort(match(i, 1))", node = node,
      extra = "probe_check_abort <- function(x) x")
  )
  for (label in names(cases)) {
    case <- cases[[label]]
    body <- if (is.null(case$hook)) case$body else paste(case$body, ";", case$hook)
    root <- ledgr_hot_path_probe(body = body, extra = c(case$extra, character()))
    evaluation <- ledgr_hot_path_probe_eval(root)
    testthat::expect_identical(ledgr_hot_path_count(evaluation, case$node, "match"), 1L, info = label)
  }
  # Directly in the loop body, and in a helper only the loop reaches.
  root <- ledgr_hot_path_probe(loop = "match(i, 1); skip_helper(i)",
                               extra = "skip_helper <- function(i) i %in% 1")
  evaluation <- ledgr_hot_path_probe_eval(root)
  testthat::expect_identical(ledgr_hot_path_count(evaluation, "envelope/run_loop/<pulse-loop>", "match"), 1L)
  testthat::expect_identical(ledgr_hot_path_count(evaluation, "skip_helper", "%in%"), 1L)
  # Setup before the loop is not per pulse.
  testthat::expect_identical(ledgr_hot_path_count(evaluation, "setup_only", "match"), 0L)
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0548] a call the walker cannot resolve fails until its own site is declared", {
  scanner <- ledgr_hot_path_scanner()
  extra <- c("apply_cb <- function(f) f(1)", "map_cb <- function(xs, f) lapply(xs, FUN = f)")
  root <- ledgr_hot_path_probe(body = "apply_cb(identity); map_cb(list(i), identity)", extra = extra)
  undeclared <- ledgr_hot_path_probe_eval(root, list(declarations = ledgr_hot_path_declarations()))
  testthat::expect_match(paste(undeclared$problems, collapse = "\n"), "apply_cb [call:f #1]", fixed = TRUE)
  testthat::expect_match(paste(undeclared$problems, collapse = "\n"),
                         "map_cb [argument:lapply:FUN=f #1]", fixed = TRUE)
  declared <- ledgr_hot_path_declarations(
    c("site", "apply_cb", "call:f", "1", "terminal", "callback supplied by the caller"),
    c("site", "map_cb", "argument:lapply:FUN=f", "1", "terminal", "callback supplied by the caller")
  )
  testthat::expect_length(ledgr_hot_path_probe_eval(root, list(declarations = declared))$problems, 0L)
  # A second site of the same callee is not discharged by the first declaration.
  root_two <- ledgr_hot_path_probe(body = "apply_cb(identity); map_cb(list(i), identity)",
    extra = c("apply_cb <- function(f) { f(1); f(2) }", extra[[2L]]))
  second <- ledgr_hot_path_probe_eval(root_two, list(declarations = declared))
  testthat::expect_match(paste(second$problems, collapse = "\n"), "apply_cb [call:f #2]", fixed = TRUE)
  # A declaration naming a site that no longer exists, or a target that does
  # not exist, fails.
  stale <- ledgr_hot_path_declarations(declared[1L, ], declared[2L, ],
    c("site", "apply_cb", "call:g", "1", "terminal", "gone"))
  testthat::expect_match(paste(ledgr_hot_path_probe_eval(root, list(declarations = stale))$problems,
                               collapse = "\n"), "stale site rows", fixed = TRUE)
  bad_target <- declared
  bad_target$targets[[1L]] <- "no_such_function"
  testthat::expect_match(paste(ledgr_hot_path_probe_eval(root, list(declarations = bad_target))$problems,
                               collapse = "\n"), "targets naming nothing", fixed = TRUE)
  # A declared target is followed: its banned call is counted.
  targeted <- declared
  targeted$targets[[1L]] <- "cb_target"
  root_target <- ledgr_hot_path_probe(body = "apply_cb(identity); map_cb(list(i), identity)",
    extra = c(extra, "cb_target <- function(x) unique(x)"))
  testthat::expect_identical(ledgr_hot_path_count(
    ledgr_hot_path_probe_eval(root_target, list(declarations = targeted)), "cb_target", "unique"), 1L)
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0549] same-key definitions fail unless declared and distinct scopes never collide", {
  # root/a/f and root/b/f are distinct: calling a's f counts its match.
  scopes <- ledgr_hot_path_probe(body = "scoped_root()", extra = c(
    "scoped_root <- function() {",
    "  a <- function() { f <- function() match(1, 1); f() }",
    "  b <- function() { f <- function() 1; f() }",
    "  a()",
    "}"
  ))
  evaluation <- ledgr_hot_path_probe_eval(scopes, list(declarations = ledgr_hot_path_declarations()))
  testthat::expect_identical(ledgr_hot_path_count(evaluation, "scoped_root/a/f", "match"), 1L)
  testthat::expect_length(evaluation$problems, 0L)
  # Two definitions under one key: both are kept, and the key must be declared.
  duplicate <- ledgr_hot_path_probe(body = "dup_root()", extra = c(
    "dup_root <- function() {",
    "  h <- function() match(1, 1)",
    "  if (FALSE) h <- function() unique(1)",
    "  h()",
    "}"
  ))
  undeclared <- ledgr_hot_path_probe_eval(duplicate, list(declarations = ledgr_hot_path_declarations()))
  testthat::expect_match(paste(undeclared$problems, collapse = "\n"),
                         "same-key definitions not declared: dup_root/h", fixed = TRUE)
  declared <- ledgr_hot_path_probe_eval(duplicate, list(declarations = ledgr_hot_path_declarations(
    c("duplicate", "dup_root/h", "", "", "", "branch alternative"))))
  testthat::expect_length(declared$problems, 0L)
  testthat::expect_identical(ledgr_hot_path_count(declared, "dup_root/h", "match"), 1L)
  testthat::expect_identical(ledgr_hot_path_count(declared, "dup_root/h#2", "unique"), 1L)
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0550] exactly one pulse loop is located and an unrelated loop is never selected", {
  missing <- ledgr_hot_path_probe(marker = FALSE)
  testthat::expect_match(paste(ledgr_hot_path_probe_eval(missing)$problems, collapse = "\n"),
                         "found 0", fixed = TRUE)
  twice <- ledgr_hot_path_probe(after = "for (j in 1:2) stage_observe(j)")
  testthat::expect_match(paste(ledgr_hot_path_probe_eval(twice)$problems, collapse = "\n"),
                         "found 2", fixed = TRUE)
  unrelated <- ledgr_hot_path_probe(extra = c(
    "envelope2 <- function() for (k in 1:2) unique(k)"
  ))
  evaluation <- ledgr_hot_path_probe_eval(unrelated)
  testthat::expect_identical(evaluation$scan$loop_count, 1L)
  testthat::expect_identical(ledgr_hot_path_count(evaluation, "envelope2", "unique"), 0L)
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0551] JSON calls are counted at every site and the inventory is complete", {
  json <- ledgr_hot_path_table(
    c(identity = "yyjsonr::write_json_str", role = "backend", counted = "TRUE", reason = "backend"),
    c(identity = "probe_json", role = "wrapper", counted = "TRUE", reason = "wrapper")
  )
  root <- ledgr_hot_path_probe(body = "probe_json(i)",
    extra = "probe_json <- function(x) { unique(x); yyjsonr::write_json_str(x) }")
  evaluation <- ledgr_hot_path_probe_eval(root, list(json = json))
  testthat::expect_length(evaluation$problems, 0L)
  testthat::expect_identical(ledgr_hot_path_count(evaluation, "stage_observe", "probe_json"), 1L)
  testthat::expect_identical(ledgr_hot_path_count(evaluation, "probe_json", "yyjsonr::write_json_str"), 1L)
  testthat::expect_identical(ledgr_hot_path_count(evaluation, "probe_json", "unique"), 1L)
  # An independent expected backend: a called backend missing from the
  # inventory fails, and so does a direct backend caller not listed as wrapper.
  reader <- ledgr_hot_path_probe(body = "probe_json(i); probe_read(i)",
    extra = c("probe_json <- function(x) yyjsonr::write_json_str(x)",
              "probe_read <- function(x) yyjsonr::read_json_str(x)"))
  problems <- paste(ledgr_hot_path_probe_eval(reader, list(json = json))$problems, collapse = "\n")
  testthat::expect_match(problems, "backend calls not inventoried: yyjsonr::read_json_str", fixed = TRUE)
  json_more <- rbind(json, c("yyjsonr::read_json_str", "backend", "TRUE", "backend"))
  problems <- paste(ledgr_hot_path_probe_eval(reader, list(json = json_more))$problems, collapse = "\n")
  testthat::expect_match(problems, "not inventoried as wrappers: probe_read", fixed = TRUE)
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0552] every export and S3 method is classified exactly once", {
  surface <- ledgr_hot_path_table(
    c(name = "stage_observe", kind = "export", per_pulse = "TRUE", family = "probe", reason = "hot"),
    c(name = "print.probe", kind = "S3method", per_pulse = "FALSE", family = "", reason = "printing")
  )
  families <- ledgr_hot_path_table(c(family = "probe", roots = "stage", returned_closures = "",
    workload = "", uncovered = "static only", reason = "probe"))
  root <- ledgr_hot_path_probe(exports = c("stage_observe", "cold_export"), s3 = "print,probe",
    extra = c("print.probe <- function(x, ...) invisible(x)", "cold_export <- function() 1"))
  problems <- paste(ledgr_hot_path_probe_eval(root, list(surface = surface, families = families))$problems,
                    collapse = "\n")
  testthat::expect_match(problems, "unclassified: export:cold_export", fixed = TRUE)
  extra_row <- rbind(surface, c("cold_export", "export", "FALSE", "", "cold"),
                     c("gone_export", "export", "FALSE", "", "cold"))
  problems <- paste(ledgr_hot_path_probe_eval(root, list(surface = extra_row, families = families))$problems,
                    collapse = "\n")
  testthat::expect_match(problems, "rows naming nothing: export:gone_export", fixed = TRUE)
  complete <- extra_row[extra_row$name != "gone_export", ]
  testthat::expect_length(
    ledgr_hot_path_probe_eval(root, list(surface = complete, families = families))$problems, 0L)
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0553] regeneration writes removals freely and refuses unreasoned growth or weakening", {
  scanner <- ledgr_hot_path_scanner()
  json <- ledgr_hot_path_table(
    c(identity = "yyjsonr::write_json_str", role = "backend", counted = "TRUE", reason = "backend"),
    c(identity = "probe_json", role = "wrapper", counted = "TRUE", reason = "wrapper"),
    c(identity = "probe_outer", role = "wrapper", counted = "TRUE", reason = "second-level wrapper")
  )
  inputs <- list(
    surface = ledgr_hot_path_table(c(name = "stage_observe", kind = "export", per_pulse = "FALSE",
                                     family = "", reason = "reached from the loop")),
    families = ledgr_hot_path_table(c(family = "loop", roots = "loop", returned_closures = "",
                                      workload = "", uncovered = "static", reason = "probe")),
    declarations = ledgr_hot_path_declarations(),
    json = json
  )
  dir <- tempfile("ledgr-hot-path-records-")
  dir.create(dir)
  write_inputs <- function(x = inputs) {
    files <- scanner$ledgr_hot_path_record_files()
    for (name in names(x)) {
      utils::write.csv(x[[name]], file.path(dir, files[[name]]), row.names = FALSE,
                       fileEncoding = "UTF-8", eol = "\n")
    }
  }
  write_generated <- function(out) {
    files <- scanner$ledgr_hot_path_record_files()
    for (name in c("bans", "reach", "policy")) {
      utils::write.csv(out[[name]], file.path(dir, files[[name]]), row.names = FALSE,
                       na = "", fileEncoding = "UTF-8", eol = "\n")
    }
  }
  probe <- function(body) ledgr_hot_path_probe(body = body, exports = "stage_observe",
    extra = c("probe_json <- function(x) yyjsonr::write_json_str(x)",
              "probe_outer <- function(x) probe_json(x)"))
  evaluate <- function(root, initial = FALSE) {
    records <- scanner$ledgr_hot_path_read_records(dir, initial = initial)
    list(records = records, evaluation = ledgr_hot_path_probe_eval(root, records))
  }
  hash <- "analyzer-a"
  write_inputs()
  base <- probe("match(i, 1); unique(i); probe_outer(i)")
  first <- evaluate(base, initial = TRUE)
  testthat::expect_error(scanner$ledgr_hot_path_regenerate(first$evaluation, first$records, hash,
                                                           initial = TRUE), "needs a reason")
  write_generated(scanner$ledgr_hot_path_regenerate(first$evaluation, first$records, hash,
                                                    reason = "initial baseline, cut 8", initial = TRUE))
  current <- evaluate(base)
  testthat::expect_true(scanner$ledgr_hot_path_check(current$evaluation, current$records, hash))
  # An "error path" reason neither exempts the row nor permits a count change.
  bans_path <- file.path(dir, scanner$ledgr_hot_path_record_files()[["bans"]])
  bans <- utils::read.csv(bans_path, colClasses = "character")
  bans$reason[bans$call == "unique"] <- "error path"
  utils::write.csv(bans, bans_path, row.names = FALSE, fileEncoding = "UTF-8", eol = "\n")
  testthat::expect_true(scanner$ledgr_hot_path_check(evaluate(base)$evaluation, evaluate(base)$records, hash))
  grown_unique <- evaluate(probe("match(i, 1); unique(i); unique(i); probe_outer(i)"))
  testthat::expect_error(scanner$ledgr_hot_path_check(grown_unique$evaluation, grown_unique$records, hash),
                         "unrecorded bans")
  # Delete a call: the old record fails, regeneration is free, and the
  # reintroduced call fails again until a reason is given.
  removed <- evaluate(probe("unique(i); probe_outer(i)"))
  testthat::expect_error(scanner$ledgr_hot_path_check(removed$evaluation, removed$records, hash), "stale bans")
  write_generated(scanner$ledgr_hot_path_regenerate(removed$evaluation, removed$records, hash))
  reintroduced <- evaluate(base)
  testthat::expect_error(scanner$ledgr_hot_path_check(reintroduced$evaluation, reintroduced$records, hash),
                         "unrecorded bans")
  testthat::expect_error(scanner$ledgr_hot_path_regenerate(reintroduced$evaluation, reintroduced$records, hash),
                         "new or increased")
  regenerated <- scanner$ledgr_hot_path_regenerate(reintroduced$evaluation, reintroduced$records, hash,
                                                   reason = "accepted by review")
  testthat::expect_identical(regenerated$bans$reason[regenerated$bans$call == "match"], "accepted by review")
  write_generated(regenerated)
  # Coverage loss: the loop no longer reaches probe_outer.
  lost <- evaluate(probe("match(i, 1); unique(i)"))
  testthat::expect_error(scanner$ledgr_hot_path_regenerate(lost$evaluation, lost$records, hash), "coverage loss")
  # Weakening the JSON inventory with stable reachability, or changing the
  # analyzer, needs a reason.
  weaker <- inputs
  weaker$json <- json[json$identity != "probe_outer", ]
  write_inputs(weaker)
  weakened <- evaluate(base)
  testthat::expect_error(scanner$ledgr_hot_path_check(weakened$evaluation, weakened$records, hash),
                         "policy input_json changed")
  testthat::expect_error(scanner$ledgr_hot_path_regenerate(weakened$evaluation, weakened$records, hash),
                         "input or analyzer change")
  write_inputs()
  testthat::expect_error(scanner$ledgr_hot_path_regenerate(evaluate(base)$evaluation, evaluate(base)$records,
                                                           "analyzer-b"), "analyzer_hash")
  # Duplicate keys and blank reasons fail.
  blank <- inputs
  blank$families$reason <- " "
  write_inputs(blank)
  testthat::expect_match(paste(evaluate(base)$evaluation$problems, collapse = "\n"),
                         "families: blank reason", fixed = TRUE)
  write_inputs()
  duplicated_bans <- utils::read.csv(bans_path, colClasses = "character")
  utils::write.csv(rbind(duplicated_bans, duplicated_bans[1L, ]), bans_path, row.names = FALSE,
                   fileEncoding = "UTF-8", eol = "\n")
  testthat::expect_error(scanner$ledgr_hot_path_check(evaluate(base)$evaluation, evaluate(base)$records, hash),
                         "duplicate node/call rows")
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0554] discovery and the witnesses cannot pass vacuously", {
  scanner <- ledgr_hot_path_scanner()
  # Empty discovery is a failure, not a pass.
  empty <- tempfile("ledgr-hot-path-empty-")
  dir.create(file.path(empty, "R"), recursive = TRUE)
  testthat::expect_error(
    ledgr_hot_path_assert_discovery(ledgr_hot_path_probe_eval(empty)),
    "found nothing to check"
  )
  # A broken checker that accepts everything is caught by the witness.
  witness <- function(check) {
    root <- ledgr_hot_path_probe(body = "match(i, 1)")
    evaluation <- ledgr_hot_path_probe_eval(root)
    records <- list(
      bans = data.frame(node = character(), file = character(), call = character(),
                        count = character(), reason = character(), stringsAsFactors = FALSE),
      reach = evaluation$reach,
      policy = scanner$ledgr_hot_path_policy_rows(evaluation$scan, list(fingerprints = character()), "h", "")
    )
    refused <- tryCatch({
      check(evaluation, list(bans = records$bans, reach = records$reach, policy = records$policy,
                             fingerprints = character()), "h")
      FALSE
    }, error = function(e) TRUE)
    refused
  }
  testthat::expect_true(witness(scanner$ledgr_hot_path_check))
  testthat::expect_false(witness(function(...) invisible(TRUE)))
})

# The census command on a synthetic package, through tools/ copied from the
# source tree. Each control runs one Rscript process.
ledgr_hot_path_cli_probe <- function() {
  root <- tempfile("ledgr-hot-path-cli-")
  census <- file.path(root, "dev", "bench", "v0_2_2_pre_cran_removal", "census")
  dir.create(file.path(root, "R"), recursive = TRUE)
  dir.create(file.path(root, "tools"))
  dir.create(census, recursive = TRUE)
  source_tools <- file.path(ledgr_test_source_root(), "tools")
  file.copy(file.path(source_tools, c("codebase-structure.R", "check-codebase-contracts.R")),
            file.path(root, "tools"))
  writeLines(c(
    "ledgr_fold_envelope <- function() {",
    "  run_loop <- function() for (i in 1:3) ledgr_fold_stage_observe_settle(i)",
    "  run_loop()",
    "}",
    "ledgr_fold_stage_observe_settle <- function(i) match(i, 1)"
  ), file.path(root, "R", "probe.R"))
  writeLines("export(ledgr_fold_stage_observe_settle)", file.path(root, "NAMESPACE"))
  writeLines(c('"name","kind","per_pulse","family","reason"',
               '"ledgr_fold_stage_observe_settle","export","FALSE","","reached from the loop"'),
             file.path(census, "hot_path_surface.csv"))
  writeLines(c('"family","roots","returned_closures","workload","uncovered","reason"',
               '"loop","loop","","","static","probe"'), file.path(census, "hot_path_families.csv"))
  writeLines('"kind","node","site","occurrence","targets","reason"', file.path(census, "hot_path_declarations.csv"))
  writeLines('"identity","role","counted","reason"', file.path(census, "hot_path_json.csv"))
  list(root = root, census = census, script = file.path(root, "tools", "check-codebase-contracts.R"))
}

ledgr_hot_path_cli <- function(probe, ...) {
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), c(shQuote(probe$script), "--hot-path-only", ...),
    stdout = TRUE, stderr = TRUE
  ))
  list(status = attr(output, "status") %||% 0L, text = paste(output, collapse = "\n"))
}

ledgr_hot_path_hashes <- function(dir) {
  files <- list.files(dir, full.names = TRUE)
  stats::setNames(unname(tools::md5sum(files)), basename(files))
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0555] the census command validates hot-path records completely before writing anything", {
  scanner <- ledgr_hot_path_scanner()
  probe <- ledgr_hot_path_cli_probe()
  seeded <- ledgr_hot_path_cli(probe, "--mode=report", "--hot-path-initial",
                               shQuote("--hot-path-reason=initial baseline, cut 8"))
  testthat::expect_identical(seeded$status, 0L, info = seeded$text)
  testthat::expect_identical(ledgr_hot_path_cli(probe, "--mode=check")$status, 0L)
  # Initial seeding refuses an existing generated record.
  again <- ledgr_hot_path_cli(probe, "--mode=report", "--hot-path-initial", "--hot-path-reason=again")
  testthat::expect_match(again$text, "refuses an existing generated record", fixed = TRUE)
  before <- ledgr_hot_path_hashes(probe$census)
  # Missing or partial prior records fail, from an explicit input directory.
  partial <- tempfile("ledgr-hot-path-partial-")
  dir.create(partial)
  file.copy(list.files(probe$census, full.names = TRUE), partial)
  unlink(file.path(partial, "hot_path_bans.csv"))
  out_partial <- tempfile("ledgr-hot-path-out-")
  refused <- ledgr_hot_path_cli(probe, "--mode=report", paste0("--hot-path-input=", shQuote(partial)),
                                paste0("--output=", shQuote(out_partial)))
  testthat::expect_match(refused$text, "missing hot-path records", fixed = TRUE)
  testthat::expect_false(dir.exists(out_partial))
  # Growth into an empty output directory is refused without a reason; the
  # prior records stay byte-identical and the output stays empty.
  probe_file <- file.path(probe$root, "R", "probe.R")
  writeLines(sub("function(i) match(i, 1)", "function(i) { match(i, 1); unique(i) }",
                 readLines(probe_file), fixed = TRUE), probe_file)
  empty_out <- tempfile("ledgr-hot-path-empty-out-")
  dir.create(empty_out)
  grown <- ledgr_hot_path_cli(probe, "--mode=report", paste0("--output=", shQuote(empty_out)))
  testthat::expect_match(grown$text, "regeneration refused without --hot-path-reason", fixed = TRUE)
  testthat::expect_identical(ledgr_hot_path_hashes(probe$census), before)
  testthat::expect_length(list.files(empty_out), 0L)
  # Check mode on the same tree fails before anything is written.
  check_out <- tempfile("ledgr-hot-path-check-out-")
  failed <- ledgr_hot_path_cli(probe, "--mode=check", paste0("--output=", shQuote(check_out)))
  testthat::expect_match(failed$text, "unrecorded bans", fixed = TRUE)
  testthat::expect_false(dir.exists(check_out))
  # A late input change is refused before any write as well.
  surface_path <- file.path(probe$census, "hot_path_surface.csv")
  writeLines(sub("reached from the loop", "reached from the pulse loop", readLines(surface_path)), surface_path)
  changed <- ledgr_hot_path_hashes(probe$census)
  late <- ledgr_hot_path_cli(probe, "--mode=report", "--hot-path-reason=")
  testthat::expect_match(late$text, "input or analyzer change: input_surface", fixed = TRUE)
  testthat::expect_identical(ledgr_hot_path_hashes(probe$census), changed)
  # With a reason the command writes, and its records equal the fast scanner's.
  out <- tempfile("ledgr-hot-path-reasoned-")
  written <- ledgr_hot_path_cli(probe, "--mode=report", shQuote("--hot-path-reason=accepted by review"),
                                paste0("--output=", shQuote(out)))
  testthat::expect_identical(written$status, 0L, info = written$text)
  cli_bans <- utils::read.csv(file.path(out, "hot_path_bans.csv"), colClasses = "character")
  fast <- scanner$ledgr_hot_path_evaluate(
    probe$root, scanner$ledgr_hot_path_read_records(probe$census)
  )$bans
  testthat::expect_identical(
    paste(cli_bans$node, cli_bans$call, cli_bans$count),
    paste(fast$node, fast$call, fast$count)
  )
  testthat::expect_identical(cli_bans$reason[cli_bans$call == "unique"], "accepted by review")
})

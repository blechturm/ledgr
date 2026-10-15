# ledgr-test-file-profile: review

testthat::test_that("[LTB-0273] governance report stays deterministic, failure-sensitive, and report-only", {
  package_root <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
  tool <- file.path(package_root, "tools", "governance-report.R")
  fixture <- file.path(
    package_root,
    "dev",
    "governance_guard",
    "fixtures",
    "reviewed"
  )
  require_source_fixture <- function(tool_path, fixture_path) {
    if (!file.exists(tool_path)) {
      return(FALSE)
    }
    if (!dir.exists(fixture_path)) {
      stop("required governance fixture is missing inside the source checkout")
    }
    TRUE
  }
  source_tree <- require_source_fixture(tool, fixture)
  testthat::skip_if_not(
    source_tree,
    "governance sources are intentionally absent from an installed package"
  )
  synthetic_tool <- tempfile("governance-tool-")
  file.create(synthetic_tool)
  on.exit(unlink(synthetic_tool), add = TRUE)
  testthat::expect_error(
    require_source_fixture(synthetic_tool, tempfile("missing-fixture-")),
    "required governance fixture is missing"
  )

  guard <- new.env(parent = globalenv())
  sys.source(tool, envir = guard)
  lf_claims <- tempfile("claims-lf-", fileext = ".yml")
  crlf_claims <- tempfile("claims-crlf-", fileext = ".yml")
  on.exit(unlink(c(lf_claims, crlf_claims)), add = TRUE)
  writeBin(
    charToRaw("claims:\n  - id: portable\n    source: accepted synthesis\n"),
    lf_claims
  )
  writeBin(
    charToRaw("claims:\r\n  - id: portable\r\n    source: accepted synthesis\r\n"),
    crlf_claims
  )
  testthat::expect_identical(
    guard$governance_sha256_file(lf_claims),
    guard$governance_sha256_file(crlf_claims)
  )
  production_baseline <- yaml::read_yaml(file.path(
    package_root,
    "dev",
    "governance_guard",
    "baseline.yml"
  ))
  testthat::expect_length(production_baseline$entries, 51L)
  testthat::expect_null(production_baseline$census)
  testthat::expect_false(any(grepl(
    "governance_census",
    readLines(tool, warn = FALSE),
    fixed = TRUE
  )))
  copy_fixture <- function() {
    parent <- tempfile("ledgr-governance-fixture-")
    dir.create(parent)
    destination <- file.path(parent, "reviewed")
    dir.create(destination)
    copied <- file.copy(
      list.files(fixture, full.names = TRUE, all.files = TRUE, no.. = TRUE),
      destination,
      recursive = TRUE
    )
    testthat::expect_true(all(copied))
    destination
  }
  run_fixture <- function(root) {
    guard$governance_report(
      root = root,
      baseline_path = file.path(root, "baseline.yml"),
      claims_path = file.path(root, "claims.yml"),
      tracked_path = file.path(root, "tracked.yml"),
      current_packet = "inst/design/current_packet"
    )
  }
  replace_once <- function(root, path, before, after) {
    target <- file.path(root, path)
    lines <- readLines(target, warn = FALSE, encoding = "UTF-8")
    hit <- which(grepl(before, lines, fixed = TRUE))
    testthat::expect_length(hit, 1L)
    lines[[hit]] <- sub(before, after, lines[[hit]], fixed = TRUE)
    writeLines(lines, target, useBytes = TRUE)
  }
  finding_line <- function(report, kind, occurrence = NULL) {
    out <- report[
      startsWith(report, "FINDING\t") &
        grepl(paste0("kind=", kind, "\t"), report, fixed = TRUE)
    ]
    if (!is.null(occurrence)) {
      out <- out[grepl(
        paste0("occurrence=", occurrence, "\t"),
        out,
        fixed = TRUE
      )]
    }
    out
  }

  pristine <- copy_fixture()
  on.exit(unlink(dirname(pristine), recursive = TRUE), add = TRUE)
  first <- run_fixture(pristine)
  second <- run_fixture(pristine)
  testthat::expect_identical(first, second)
  testthat::expect_true("MODE\treport-only" %in% first)
  testthat::expect_true("BASELINE_SOURCE_COUNT\t11" %in% first)
  testthat::expect_true(any(startsWith(first, "BASELINE_SOURCE_SHA256\t")))
  testthat::expect_true("BASELINE_POPULATION_MATCH\ttrue" %in% first)
  testthat::expect_true("SCAN_SOURCE_COUNT\t11" %in% first)
  testthat::expect_true("CLAIMS_INPUT\tclaims.yml" %in% first)
  testthat::expect_true(paste0(
    "CLAIMS_SHA256\t",
    guard$governance_sha256_file(file.path(pristine, "claims.yml"))
  ) %in% first)
  testthat::expect_true("CLAIMS_COUNT\t1" %in% first)
  testthat::expect_true("NEW_STRUCTURAL_COUNT\t0" %in% first)
  testthat::expect_length(finding_line(first, "broken_local_target", 1L), 1L)
  testthat::expect_match(
    finding_line(first, "broken_local_target", 1L),
    "state=baseline",
    fixed = TRUE
  )
  testthat::expect_length(finding_line(first, "untracked_local_target"), 1L)

  portable <- copy_fixture()
  on.exit(unlink(dirname(portable), recursive = TRUE), add = TRUE)
  testthat::expect_identical(first, run_fixture(portable))

  kind_key <- copy_fixture()
  on.exit(unlink(dirname(kind_key), recursive = TRUE), add = TRUE)
  replace_once(
    kind_key,
    "baseline.yml",
    "kind: broken_local_target",
    "kind: broken_local_anchor"
  )
  kind_report <- run_fixture(kind_key)
  kind_finding <- finding_line(kind_report, "broken_local_target", 1L)
  testthat::expect_length(kind_finding, 1L)
  testthat::expect_match(kind_finding, "state=new", fixed = TRUE)
  testthat::expect_true(any(grepl(
    paste0(
      "RESOLVED_BASELINE_ENTRY\tkind=broken_local_anchor",
      "\tsource=inst/design/README.md\ttarget=missing.md\toccurrence=1"
    ),
    kind_report,
    fixed = TRUE
  )))

  new_debt <- copy_fixture()
  on.exit(unlink(dirname(new_debt), recursive = TRUE), add = TRUE)
  cat(
    "\n[Second inherited target use](missing.md).\n",
    file = file.path(new_debt, "inst", "design", "README.md"),
    append = TRUE
  )
  new_debt_report <- run_fixture(new_debt)
  second_debt <- finding_line(new_debt_report, "broken_local_target", 2L)
  testthat::expect_length(second_debt, 1L)
  testthat::expect_match(second_debt, "state=new", fixed = TRUE)

  links <- copy_fixture()
  on.exit(unlink(dirname(links), recursive = TRUE), add = TRUE)
  replace_once(
    links,
    "inst/design/README.md",
    "rfc/change.md#new-rule",
    "rfc/change.md#missing-anchor"
  )
  testthat::expect_length(
    finding_line(run_fixture(links), "broken_local_anchor"),
    1L
  )

  root_link <- copy_fixture()
  on.exit(unlink(dirname(root_link), recursive = TRUE), add = TRUE)
  replace_once(
    root_link,
    "inst/design/README.md",
    "../../outside.md#current-rule",
    "/outside.md#current-rule"
  )
  root_link_report <- run_fixture(root_link)
  testthat::expect_false(any(grepl(
    "target=/outside.md#current-rule",
    root_link_report,
    fixed = TRUE
  )))

  broken_root_link <- copy_fixture()
  on.exit(unlink(dirname(broken_root_link), recursive = TRUE), add = TRUE)
  replace_once(
    broken_root_link,
    "inst/design/README.md",
    "../../outside.md#current-rule",
    "/missing-root.md"
  )
  broken_root_finding <- finding_line(
    run_fixture(broken_root_link),
    "broken_local_target"
  )
  testthat::expect_true(any(grepl(
    "target=/missing-root.md",
    broken_root_finding,
    fixed = TRUE
  )))

  escaping <- copy_fixture()
  on.exit(unlink(dirname(escaping), recursive = TRUE), add = TRUE)
  replace_once(
    escaping,
    "inst/design/README.md",
    "../../outside.md#current-rule",
    "../../../outside.md#current-rule"
  )
  escaping_finding <- finding_line(run_fixture(escaping), "broken_local_target")
  testthat::expect_true(any(grepl(
    "local target escapes the repository root",
    escaping_finding,
    fixed = TRUE
  )))

  ids <- copy_fixture()
  on.exit(unlink(dirname(ids), recursive = TRUE), add = TRUE)
  cat(
    "\n<a id=\"pending-choice\"></a>\n",
    file = file.path(ids, "inst", "design", "decisions.md"),
    append = TRUE
  )
  outside <- file.path(ids, "outside.md")
  cat("\n## Duplicate\n\n## Duplicate\n", file = outside, append = TRUE)
  cat(
    "\n[Ambiguous heading](../../outside.md#duplicate).\n",
    file = file.path(ids, "inst", "design", "README.md"),
    append = TRUE
  )
  id_report <- run_fixture(ids)
  testthat::expect_length(finding_line(id_report, "duplicate_explicit_id"), 1L)
  testthat::expect_length(finding_line(id_report, "ambiguous_heading_slug"), 1L)

  metadata <- copy_fixture()
  on.exit(unlink(dirname(metadata), recursive = TRUE), add = TRUE)
  replace_once(metadata, "inst/design/README.md", "Role: living", "Role: archive")
  replace_once(metadata, "inst/design/rfc/pipeline.md", "active", "started")
  replace_once(metadata, "inst/design/rfc/review.md", "PASS", "MAYBE")
  replacement_path <- file.path(metadata, "inst", "design", "manual", "guide.qmd")
  replacement_lines <- readLines(replacement_path, warn = FALSE)
  replacement_lines <- replacement_lines[!startsWith(replacement_lines, "Replacement:")]
  writeLines(replacement_lines, replacement_path, useBytes = TRUE)
  status_path <- file.path(metadata, "inst", "design", "current_packet", "README.md")
  status_lines <- readLines(status_path, warn = FALSE)
  status_lines <- status_lines[!startsWith(status_lines, "Status:")]
  writeLines(status_lines, status_path, useBytes = TRUE)
  metadata_report <- run_fixture(metadata)
  for (kind in c(
    "invalid_role", "missing_status", "invalid_row_state", "invalid_verdict",
    "missing_replacement_provenance"
  )) {
    testthat::expect_gt(length(finding_line(metadata_report, kind)), 0L)
  }

  invalid_status <- copy_fixture()
  on.exit(unlink(dirname(invalid_status), recursive = TRUE), add = TRUE)
  replace_once(
    invalid_status,
    "inst/design/README.md",
    "Status: working",
    "Status: started"
  )
  testthat::expect_length(
    finding_line(run_fixture(invalid_status), "invalid_status"),
    1L
  )

  missing_headers <- copy_fixture()
  on.exit(unlink(dirname(missing_headers), recursive = TRUE), add = TRUE)
  header_path <- file.path(missing_headers, "inst", "design", "README.md")
  header_lines <- readLines(header_path, warn = FALSE)
  header_lines <- header_lines[
    !startsWith(header_lines, "Role:") &
      !startsWith(header_lines, "Authority:")
  ]
  writeLines(header_lines, header_path, useBytes = TRUE)
  missing_header_report <- run_fixture(missing_headers)
  testthat::expect_length(finding_line(missing_header_report, "missing_role"), 1L)
  testthat::expect_length(
    finding_line(missing_header_report, "missing_authority"),
    1L
  )

  embedded_authority <- copy_fixture()
  on.exit(unlink(dirname(embedded_authority), recursive = TRUE), add = TRUE)
  embedded_path <- file.path(embedded_authority, "inst", "design", "README.md")
  embedded_lines <- readLines(embedded_path, warn = FALSE)
  embedded_lines <- sub(
    "Role: living; fixture navigation front door.",
    "Role: record; accepted governance decisions, binding in their stated scope.",
    embedded_lines,
    fixed = TRUE
  )
  embedded_lines <- embedded_lines[!startsWith(embedded_lines, "Authority:")]
  writeLines(embedded_lines, embedded_path, useBytes = TRUE)
  testthat::expect_length(
    finding_line(run_fixture(embedded_authority), "missing_authority"),
    0L
  )

  amendment <- copy_fixture()
  on.exit(unlink(dirname(amendment), recursive = TRUE), add = TRUE)
  replace_once(
    amendment,
    "inst/design/current_packet/README.md",
    "Status: accepted",
    "Status: amended 2026-10-14"
  )
  testthat::expect_length(
    finding_line(run_fixture(amendment), "missing_amendment_provenance"),
    1L
  )

  receiver <- copy_fixture()
  on.exit(unlink(dirname(receiver), recursive = TRUE), add = TRUE)
  replace_once(
    receiver,
    "inst/design/current_packet/README.md",
    "Status: accepted",
    "Status: consolidated"
  )
  testthat::expect_length(
    finding_line(run_fixture(receiver), "missing_receiver_provenance"),
    1L
  )

  remainder <- copy_fixture()
  on.exit(unlink(dirname(remainder), recursive = TRUE), add = TRUE)
  replace_once(
    remainder,
    "inst/design/manual/guide.qmd",
    "Status: superseded",
    "Status: superseded in part"
  )
  testthat::expect_length(
    finding_line(run_fixture(remainder), "missing_remainder_provenance"),
    1L
  )

  rejected <- copy_fixture()
  on.exit(unlink(dirname(rejected), recursive = TRUE), add = TRUE)
  replace_once(
    rejected,
    "inst/design/current_packet/README.md",
    "Status: accepted",
    "Status: rejected"
  )
  testthat::expect_length(
    finding_line(run_fixture(rejected), "missing_rejection_reason"),
    1L
  )

  type_2 <- copy_fixture()
  on.exit(unlink(dirname(type_2), recursive = TRUE), add = TRUE)
  replace_once(type_2, "inst/design/rfc/review.md", "Mode: Type 1", "Mode: Type 2")
  replace_once(
    type_2,
    "inst/design/rfc/review.md",
    "Verdict: PASS",
    "Verdict: **`REVISE_SEED`**"
  )
  cat(
    "\n## Historical quotation\n\nVerdict: MAYBE\n",
    file = file.path(type_2, "inst", "design", "rfc", "review.md"),
    append = TRUE
  )
  testthat::expect_length(
    finding_line(run_fixture(type_2), "invalid_verdict"),
    0L
  )

  type_1_changes <- copy_fixture()
  on.exit(unlink(dirname(type_1_changes), recursive = TRUE), add = TRUE)
  replace_once(
    type_1_changes,
    "inst/design/rfc/review.md",
    "Verdict: PASS",
    "Verdict: **`CHANGES_REQUIRED`**"
  )
  testthat::expect_length(
    finding_line(run_fixture(type_1_changes), "invalid_verdict"),
    0L
  )

  accepted_verdicts <- list(
    `Type 1` = c("PASS", "PASS_AFTER_PATCHES", "CHANGES_REQUIRED", "NEEDS_TYPE_2"),
    `Type 2` = c("PROCEED", "REVISE_SEED", "REJECT")
  )
  verdict_root <- tempfile("governance-verdicts-")
  dir.create(verdict_root)
  on.exit(unlink(verdict_root, recursive = TRUE), add = TRUE)
  verdict_sources <- character()
  for (mode in names(accepted_verdicts)) {
    for (token in accepted_verdicts[[mode]]) {
      source <- paste0(
        tolower(gsub("[^A-Z0-9]+", "-", paste(mode, token))),
        ".md"
      )
      decorated <- if (token %in% c("CHANGES_REQUIRED", "REVISE_SEED")) {
        paste0("**`", token, "`**")
      } else {
        token
      }
      writeLines(
        c(paste0("Mode: ", mode), paste0("Verdict: ", decorated)),
        file.path(verdict_root, source),
        useBytes = TRUE
      )
      verdict_sources <- c(verdict_sources, source)
    }
  }
  testthat::expect_equal(
    nrow(guard$governance_scan_states_and_verdicts(verdict_root, verdict_sources)),
    0L
  )

  invalid_type_2 <- copy_fixture()
  on.exit(unlink(dirname(invalid_type_2), recursive = TRUE), add = TRUE)
  replace_once(
    invalid_type_2,
    "inst/design/rfc/review.md",
    "Mode: Type 1",
    "Mode: Type 2"
  )
  testthat::expect_length(
    finding_line(run_fixture(invalid_type_2), "invalid_verdict"),
    1L
  )

  notices <- copy_fixture()
  on.exit(unlink(dirname(notices), recursive = TRUE), add = TRUE)
  notice_path <- file.path(notices, "inst", "design", "contracts.md")
  notice_lines <- readLines(notice_path, warn = FALSE)
  notice_lines <- notice_lines[!startsWith(notice_lines, "Amendments:")]
  notice_lines <- sub(
    "Superseded in part by the [new partial rule](rfc/change.md#new-partial).",
    "The old partial statement remains here without its marker.",
    notice_lines,
    fixed = TRUE
  )
  writeLines(notice_lines, notice_path, useBytes = TRUE)
  notice_report <- run_fixture(notices)
  testthat::expect_gt(length(finding_line(notice_report, "missing_target_notice")), 0L)
  testthat::expect_length(finding_line(notice_report, "missing_target_marker"), 1L)

  invalid_disposition <- copy_fixture()
  on.exit(unlink(dirname(invalid_disposition), recursive = TRUE), add = TRUE)
  replace_once(
    invalid_disposition,
    "inst/design/rfc/change.md",
    "| superseded |",
    "| retired |"
  )
  testthat::expect_length(
    finding_line(run_fixture(invalid_disposition), "invalid_disposition"),
    1L
  )

  malformed_row <- copy_fixture()
  on.exit(unlink(dirname(malformed_row), recursive = TRUE), add = TRUE)
  replace_once(
    malformed_row,
    "inst/design/rfc/change.md",
    "[New rule](#new-rule)",
    "New rule"
  )
  testthat::expect_length(
    finding_line(run_fixture(malformed_row), "malformed_change_row"),
    1L
  )

  declared_remainder <- copy_fixture()
  on.exit(unlink(dirname(declared_remainder), recursive = TRUE), add = TRUE)
  replace_once(
    declared_remainder,
    "inst/design/rfc/change.md",
    "[Partial remainder](../contracts.md#partial-remainder)",
    "Partial remainder"
  )
  testthat::expect_length(
    finding_line(run_fixture(declared_remainder), "missing_declared_remainder"),
    1L
  )

  invalid_bridge <- copy_fixture()
  on.exit(unlink(dirname(invalid_bridge), recursive = TRUE), add = TRUE)
  replace_once(
    invalid_bridge,
    "inst/design/decisions.md",
    "| pending |",
    "| started |"
  )
  testthat::expect_length(
    finding_line(run_fixture(invalid_bridge), "invalid_row_state"),
    1L
  )

  stages <- copy_fixture()
  on.exit(unlink(dirname(stages), recursive = TRUE), add = TRUE)
  replace_once(
    stages,
    "inst/design/decisions.md",
    "rfc/change.md#new-rule",
    "rfc/change.md#change-map"
  )
  replace_once(
    stages,
    "inst/design/contracts.md",
    "Accepted change pending: [pending choice](decisions.md#pending-choice).",
    "The pending receiver lost its backlink."
  )
  testthat::expect_gte(
    length(finding_line(run_fixture(stages), "stage_inconsistent_mapping")),
    2L
  )

  stale_backlink <- copy_fixture()
  on.exit(unlink(dirname(stale_backlink), recursive = TRUE), add = TRUE)
  replace_once(
    stale_backlink,
    "inst/design/contracts.md",
    "The accepted rule is consolidated. There is no pending backlink.",
    paste0(
      "Accepted change pending: [consolidated choice]",
      "(decisions.md#consolidated-choice)."
    )
  )
  stale_report <- finding_line(
    run_fixture(stale_backlink),
    "stage_inconsistent_mapping"
  )
  testthat::expect_true(any(grepl(
    "consolidated bridge row retains a stale pending backlink",
    stale_report,
    fixed = TRUE
  )))

  orphan_notice <- copy_fixture()
  on.exit(unlink(dirname(orphan_notice), recursive = TRUE), add = TRUE)
  replace_once(
    orphan_notice,
    "inst/design/current_packet/README.md",
    "Authority: fixture ticket cut.",
    paste0(
      "Authority: fixture ticket cut.\n",
      "Amendments: 2026-10-14 [accepted change map]",
      "(../rfc/change.md#change-map)."
    )
  )
  testthat::expect_length(
    finding_line(run_fixture(orphan_notice), "missing_change_row"),
    1L
  )

  orphan_marker <- copy_fixture()
  on.exit(unlink(dirname(orphan_marker), recursive = TRUE), add = TRUE)
  cat(
    paste0(
      "\n## Orphan marker\n\nSuperseded by the ",
      "[new rule](rfc/change.md#new-rule).\n"
    ),
    file = file.path(orphan_marker, "inst", "design", "contracts.md"),
    append = TRUE
  )
  testthat::expect_length(
    finding_line(run_fixture(orphan_marker), "missing_change_row"),
    1L
  )

  untracked <- copy_fixture()
  on.exit(unlink(dirname(untracked), recursive = TRUE), add = TRUE)
  unlink(file.path(untracked, "untracked.md"))
  deleted_report <- run_fixture(untracked)
  deleted <- finding_line(deleted_report, "broken_local_target")
  testthat::expect_true(any(grepl("untracked.md#draft-rule", deleted, fixed = TRUE)))
  testthat::expect_false(any(grepl("kind=untracked_local_target", deleted_report, fixed = TRUE)))

  malformed <- copy_fixture()
  on.exit(unlink(dirname(malformed), recursive = TRUE), add = TRUE)
  writeLines("version: [", file.path(malformed, "baseline.yml"))
  testthat::expect_error(
    run_fixture(malformed),
    class = "ledgr_governance_report_input"
  )
  invalid_baseline <- copy_fixture()
  on.exit(unlink(dirname(invalid_baseline), recursive = TRUE), add = TRUE)
  invalid_baseline_value <- yaml::read_yaml(file.path(invalid_baseline, "baseline.yml"))
  invalid_baseline_value$entries[[1L]]$kind <- NULL
  yaml::write_yaml(invalid_baseline_value, file.path(invalid_baseline, "baseline.yml"))
  testthat::expect_error(
    run_fixture(invalid_baseline),
    "baseline entry 1 is malformed",
    class = "ledgr_governance_report_input"
  )
  malformed_claims <- copy_fixture()
  on.exit(unlink(dirname(malformed_claims), recursive = TRUE), add = TRUE)
  writeLines("claims: [", file.path(malformed_claims, "claims.yml"))
  testthat::expect_error(
    run_fixture(malformed_claims),
    class = "ledgr_governance_report_input"
  )
  invalid_claims <- copy_fixture()
  on.exit(unlink(dirname(invalid_claims), recursive = TRUE), add = TRUE)
  invalid_claims_value <- yaml::read_yaml(file.path(invalid_claims, "claims.yml"))
  invalid_claims_value$claims[[1L]]$source <- NULL
  yaml::write_yaml(invalid_claims_value, file.path(invalid_claims, "claims.yml"))
  testthat::expect_error(
    run_fixture(invalid_claims),
    "claims entry 1 lacks id or source",
    class = "ledgr_governance_report_input"
  )
  malformed_tracked <- copy_fixture()
  on.exit(unlink(dirname(malformed_tracked), recursive = TRUE), add = TRUE)
  writeLines("tracked: 12", file.path(malformed_tracked, "tracked.yml"))
  testthat::expect_error(
    run_fixture(malformed_tracked),
    "tracked manifest must contain a non-empty tracked list",
    class = "ledgr_governance_report_input"
  )
  unreadable <- copy_fixture()
  on.exit(unlink(dirname(unreadable), recursive = TRUE), add = TRUE)
  unlink(file.path(unreadable, "inst", "design", "current_packet", "README.md"))
  testthat::expect_error(
    run_fixture(unreadable),
    class = "ledgr_governance_report_input"
  )

  claims_warning <- copy_fixture()
  on.exit(unlink(dirname(claims_warning), recursive = TRUE), add = TRUE)
  replace_once(
    claims_warning,
    "claims.yml",
    "accepted synthesis Section 6",
    "LDG-3042"
  )
  warning_line <- finding_line(
    run_fixture(claims_warning),
    "claim_source_ticket_only"
  )
  testthat::expect_length(warning_line, 1L)
  testthat::expect_match(warning_line, "source=claims.yml", fixed = TRUE)
  testthat::expect_error(
    guard$governance_parse_args("--check"),
    class = "ledgr_governance_report_input"
  )

  rscript <- file.path(R.home("bin"), "Rscript")
  cli <- suppressWarnings(system2(
    rscript,
    c(
      "--vanilla",
      shQuote(tool),
      shQuote(paste0("--root=", links)),
      "--baseline=baseline.yml",
      "--claims=claims.yml",
      "--tracked=tracked.yml",
      "--current-packet=inst/design/current_packet"
    ),
    stdout = TRUE,
    stderr = TRUE
  ))
  testthat::expect_null(attr(cli, "status"))
  testthat::expect_true(any(grepl("NEW_STRUCTURAL_COUNT", cli, fixed = TRUE)))
})


testthat::test_that("[LTB-0275] horizon classification drift stays report-only and mutation-sensitive", {
  package_root <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
  tool <- file.path(package_root, "tools", "governance-report.R")
  fixture <- file.path(package_root, "dev", "governance_guard", "fixtures", "reviewed")
  testthat::skip_if_not(
    file.exists(tool) && dir.exists(fixture),
    "governance sources are intentionally absent from an installed package"
  )

  guard <- new.env(parent = globalenv())
  sys.source(tool, envir = guard)
  copy_fixture <- function() {
    parent <- tempfile("ledgr-horizon-fixture-")
    dir.create(parent)
    destination <- file.path(parent, "reviewed")
    dir.create(destination)
    copied <- file.copy(
      list.files(fixture, full.names = TRUE, all.files = TRUE, no.. = TRUE),
      destination,
      recursive = TRUE
    )
    testthat::expect_true(all(copied))
    destination
  }
  run_fixture <- function(root) {
    guard$governance_report(
      root = root,
      baseline_path = file.path(root, "baseline.yml"),
      claims_path = file.path(root, "claims.yml"),
      tracked_path = file.path(root, "tracked.yml"),
      current_packet = "inst/design/current_packet"
    )
  }
  replace_once <- function(root, path, before, after) {
    target <- file.path(root, path)
    lines <- readLines(target, warn = FALSE, encoding = "UTF-8")
    hit <- which(grepl(before, lines, fixed = TRUE))
    testthat::expect_length(hit, 1L)
    lines[[hit]] <- sub(before, after, lines[[hit]], fixed = TRUE)
    writeLines(lines, target, useBytes = TRUE)
  }
  finding_kind <- function(report, kind) {
    report[
      startsWith(report, "FINDING\t") &
        grepl(paste0("kind=", kind, "\t"), report, fixed = TRUE)
    ]
  }
  insert_before_redirects <- function(root, addition) {
    path <- file.path(root, "inst", "design", "horizon.md")
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    before <- match("## Historical redirects", lines)
    testthat::expect_false(is.na(before))
    lines <- append(lines, addition, after = before - 1L)
    writeLines(lines, path, useBytes = TRUE)
  }

  pristine <- copy_fixture()
  on.exit(unlink(dirname(pristine), recursive = TRUE), add = TRUE)
  pristine_report <- run_fixture(pristine)
  for (kind in c(
    "missing_horizon_open_section",
    "missing_horizon_classification_table",
    "duplicate_horizon_classification",
    "unclassified_horizon_open",
    "missing_horizon_redirect",
    "missing_horizon_archive_body",
    "archived_horizon_body_current"
  )) {
    testthat::expect_length(finding_kind(pristine_report, kind), 0L)
  }

  missing_open <- copy_fixture()
  on.exit(unlink(dirname(missing_open), recursive = TRUE), add = TRUE)
  replace_once(
    missing_open,
    "inst/design/horizon.md",
    "## Open",
    "## Parking"
  )
  testthat::expect_length(
    finding_kind(run_fixture(missing_open), "missing_horizon_open_section"),
    1L
  )

  missing_table <- copy_fixture()
  on.exit(unlink(dirname(missing_table), recursive = TRUE), add = TRUE)
  replace_once(
    missing_table,
    "inst/design/current_packet/horizon_open_classification.md",
    "| ID | Original heading | Class | Evidence | Destination |",
    "Classification rows follow:"
  )
  testthat::expect_length(
    finding_kind(
      run_fixture(missing_table),
      "missing_horizon_classification_table"
    ),
    1L
  )

  unclassified <- copy_fixture()
  on.exit(unlink(dirname(unclassified), recursive = TRUE), add = TRUE)
  insert_before_redirects(
    unclassified,
    c("", "### 2026-10-16 [data] Unclassified fixture question", "", "Unowned.")
  )
  testthat::expect_length(
    finding_kind(run_fixture(unclassified), "unclassified_horizon_open"),
    1L
  )

  missing_redirect <- copy_fixture()
  on.exit(unlink(dirname(missing_redirect), recursive = TRUE), add = TRUE)
  redirect_path <- file.path(missing_redirect, "inst", "design", "horizon.md")
  redirect_lines <- readLines(redirect_path, warn = FALSE, encoding = "UTF-8")
  redirect_lines <- redirect_lines[
    redirect_lines != "### 2026-10-14 [ux] Shipped fixture question"
  ]
  writeLines(redirect_lines, redirect_path, useBytes = TRUE)
  testthat::expect_length(
    finding_kind(run_fixture(missing_redirect), "missing_horizon_redirect"),
    1L
  )

  missing_archive_body <- copy_fixture()
  on.exit(unlink(dirname(missing_archive_body), recursive = TRUE), add = TRUE)
  archive_path <- file.path(
    missing_archive_body,
    "inst", "design", "horizon_archive.md"
  )
  archive_lines <- readLines(archive_path, warn = FALSE, encoding = "UTF-8")
  archive_lines <- archive_lines[
    archive_lines != "The preserved body is historical and has one redirect."
  ]
  writeLines(archive_lines, archive_path, useBytes = TRUE)
  testthat::expect_length(
    finding_kind(
      run_fixture(missing_archive_body),
      "missing_horizon_archive_body"
    ),
    1L
  )

  duplicate_classification <- copy_fixture()
  on.exit(unlink(dirname(duplicate_classification), recursive = TRUE), add = TRUE)
  classification_path <- file.path(
    duplicate_classification,
    "inst", "design", "current_packet", "horizon_open_classification.md"
  )
  classification_lines <- readLines(
    classification_path,
    warn = FALSE,
    encoding = "UTF-8"
  )
  duplicate_row <- classification_lines[
    startsWith(
      classification_lines,
      "| H001 | 2026-10-15 [research] Genuine fixture question |"
    )
  ]
  testthat::expect_length(duplicate_row, 1L)
  writeLines(
    c(classification_lines, duplicate_row),
    classification_path,
    useBytes = TRUE
  )
  testthat::expect_length(
    finding_kind(
      run_fixture(duplicate_classification),
      "duplicate_horizon_classification"
    ),
    2L
  )

  archived_current <- copy_fixture()
  on.exit(unlink(dirname(archived_current), recursive = TRUE), add = TRUE)
  insert_before_redirects(
    archived_current,
    c("", "### 2026-10-14 [ux] Shipped fixture question", "", "Historical body.")
  )
  testthat::expect_length(
    finding_kind(run_fixture(archived_current), "archived_horizon_body_current"),
    1L
  )
})

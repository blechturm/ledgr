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
  source_tree <- file.exists(tool) && dir.exists(fixture)
  testthat::skip_if_not(
    source_tree,
    "governance sources are intentionally absent from an installed package"
  )

  guard <- new.env(parent = globalenv())
  sys.source(tool, envir = guard)
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
  testthat::expect_true("BASELINE_POPULATION_MATCH\ttrue" %in% first)
  testthat::expect_true("SCAN_SOURCE_COUNT\t8" %in% first)
  testthat::expect_true("CLAIMS_COUNT\t1" %in% first)
  testthat::expect_true("NEW_STRUCTURAL_COUNT\t0" %in% first)
  testthat::expect_length(finding_line(first, "broken_local_target", 1L), 1L)
  testthat::expect_match(
    finding_line(first, "broken_local_target", 1L),
    "state=baseline",
    fixed = TRUE
  )
  testthat::expect_length(finding_line(first, "untracked_local_target"), 1L)

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
  unreadable <- copy_fixture()
  on.exit(unlink(dirname(unreadable), recursive = TRUE), add = TRUE)
  unlink(file.path(unreadable, "inst", "design", "current_packet", "README.md"))
  testthat::expect_error(
    run_fixture(unreadable),
    class = "ledgr_governance_report_input"
  )
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

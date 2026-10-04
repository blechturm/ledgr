testthat::test_that("[LTB-0149] exact fact bytes and identities are frozen before optimization", {
  manifest <- ws10_read_oracle_manifest()
  shapes <- ws10_fact_shapes()
  bundle <- ws10_fact_bundle()

  testthat::expect_identical(nrow(manifest), 20L)
  testthat::expect_setequal(
    unique(manifest$shape[manifest$record_type == "family"]),
    names(shapes)
  )
  for (shape in names(shapes)) {
    family <- shapes[[shape]]
    actual <- list(
      rows = ledgr:::ledgr_fact_frame_payload_json(family$rows),
      headers = ledgr:::ledgr_fact_frame_payload_json(family$headers),
      family = ledgr:::ledgr_fact_family_payload_json(
        family$family,
        family$scope_id,
        family$rows,
        family$headers,
        family$metadata
      )
    )
    for (kind in names(actual)) {
      record <- manifest[
        manifest$artifact_id == paste(shape, kind, sep = ":"),
        ,
        drop = FALSE
      ]
      expected <- ws10_read_oracle_bytes(record$file[[1L]])
      testthat::expect_identical(actual[[kind]], expected, info = record$artifact_id)
      testthat::expect_identical(
        length(charToRaw(enc2utf8(actual[[kind]]))),
        record$byte_length[[1L]],
        info = record$artifact_id
      )
      testthat::expect_identical(
        digest::digest(
          charToRaw(enc2utf8(actual[[kind]])),
          algo = "sha256",
          serialize = FALSE
        ),
        record$sha256[[1L]],
        info = record$artifact_id
      )
      if (identical(kind, "family")) {
        testthat::expect_identical(
          family$fact_hash,
          record$identity_hash[[1L]],
          info = record$artifact_id
        )
      }
    }
  }

  bundle_record <- manifest[manifest$record_type == "bundle", , drop = FALSE]
  bundle_payload <- as.character(ledgr:::canonical_json(list(
    schema = "ledgr_facts_v1",
    family_hashes = vapply(
      bundle$families,
      `[[`,
      character(1),
      "fact_hash"
    )
  )))
  testthat::expect_identical(
    bundle_payload,
    ws10_read_oracle_bytes(bundle_record$file[[1L]])
  )
  testthat::expect_identical(
    bundle$bundle_hash,
    bundle_record$identity_hash[[1L]]
  )
  testthat::expect_true(all(nzchar(manifest$public_boundary)))
  testthat::expect_true(all(nzchar(manifest$oracle_independence)))

  interval_family <- shapes$membership_intervals
  testthat::expect_identical(nrow(interval_family$headers), 0L)
  testthat::expect_true(anyNA(interval_family$rows$effective_to))
  testthat::expect_identical(
    length(unique(interval_family$rows$effective_from)),
    1L
  )
  testthat::expect_true(anyNA(shapes$lifetime$rows$effective_to))
  testthat::expect_true(anyNA(
    shapes$equity_corporate_actions$rows$payment_time
  ))
})

testthat::test_that("[LTB-0150] constructed fact corruption fails at the exact boundary", {
  base <- ws10_fact_bundle()
  family_index <- function(family_name, scope_id = NULL) {
    matches <- vapply(base$families, function(family) {
      identical(family$family, family_name) &&
        (is.null(scope_id) || identical(family$scope_id, scope_id))
    }, logical(1))
    which(matches)[[1L]]
  }
  expect_corruption <- function(family_name, field, value, scope_id = NULL) {
    mutated <- base
    index <- family_index(family_name, scope_id)
    mutated$families[[index]]$rows[[field]][[1L]] <- value
    condition <- tryCatch(ledgr:::ledgr_facts_assert(mutated), error = identity)
    testthat::expect_s3_class(condition, "ledgr_invalid_facts")
    testthat::expect_identical(
      condition$message,
      "`facts` must be an untampered ledgr_facts object."
    )
  }

  membership <- base$families[[family_index("membership", "matrix")]]
  status <- base$families[[family_index("trading_status")]]
  lifetime <- base$families[[family_index("lifetime")]]
  actions <- base$families[[family_index("equity_corporate_actions")]]
  sessions <- base$families[[family_index("sessions")]]
  expect_corruption(
    "membership",
    "effective_from",
    membership$rows$effective_from[[1L]] + 1,
    "matrix"
  )
  expect_corruption("membership", "member", FALSE, "matrix")
  expect_corruption(
    "trading_status",
    "effective_from",
    status$rows$effective_from[[1L]] + 1
  )
  expect_corruption(
    "lifetime",
    "knowledge_time",
    lifetime$rows$knowledge_time[[1L]] + 1
  )
  expect_corruption(
    "equity_corporate_actions",
    "entitlement_time",
    actions$rows$entitlement_time[[1L]] + 1
  )
  expect_corruption(
    "sessions",
    "knowledge_time",
    sessions$rows$knowledge_time[[1L]] + 1
  )

  fractional <- ws14_utc("2020-01-01 16:00:00") + 0.5
  condition <- tryCatch(
    ledgr_facts_membership_intervals(
      data.frame(
        instrument_id = "AAA",
        effective_from = fractional,
        member = TRUE,
        stringsAsFactors = FALSE
      ),
      universe_id = "fractional",
      knowledge = "assume_effective"
    ),
    error = identity
  )
  testthat::expect_s3_class(condition, "LEDGR_SUBSECOND_TIMESTAMP")
  testthat::expect_s3_class(condition, "ledgr_fact_invalid_time")
  testthat::expect_match(
    condition$message,
    "whole-second UTC timestamps",
    fixed = TRUE
  )
})

testthat::test_that("[LTB-0152] canonical fact clocks format each distinct instant once", {
  original <- ledgr:::ledgr_fact_time_token
  values <- as.POSIXct(
    c(1, 1, NA, 2, 2, 2, 3, NA),
    origin = "2020-01-01",
    tz = "UTC"
  )
  formatted_elements <- 0L
  testthat::local_mocked_bindings(
    ledgr_fact_time_token = function(x) {
      formatted_elements <<- formatted_elements + length(x)
      original(x)
    },
    .package = "ledgr"
  )
  actual <- ledgr:::ledgr_fact_canonical_frame(data.frame(clock = values))
  testthat::expect_identical(actual$clock, original(values))
  testthat::expect_identical(
    formatted_elements,
    length(unique(values[!is.na(values)]))
  )
  testthat::expect_identical(
    ledgr:::ledgr_fact_time_tokens_distinct(values),
    original(values)
  )
})

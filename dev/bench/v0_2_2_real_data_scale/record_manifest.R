ledgr_scale_record_manifest_read <- function(path) {
  manifest <- utils::read.csv(
    path,
    colClasses = "character",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  required <- c("lane", "selection", "record_phase", "family")
  if (!identical(names(manifest), required) ||
      anyNA(manifest) || any(!nzchar(as.matrix(manifest)))) {
    stop(
      "The scale-record family manifest must contain complete lane, selection, record_phase and family columns.",
      call. = FALSE
    )
  }
  if (anyDuplicated(manifest[c("lane", "family")])) {
    stop("The scale-record family manifest contains a duplicate lane/family row.", call. = FALSE)
  }
  manifest
}

ledgr_scale_record_selection_enabled <- function(selection, phases) {
  if (identical(selection, "always")) return(TRUE)
  alternatives <- strsplit(selection, "|", fixed = TRUE)[[1L]]
  any(vapply(alternatives, function(alternative) {
    required <- strsplit(alternative, "+", fixed = TRUE)[[1L]]
    all(required %in% phases)
  }, logical(1L)))
}

ledgr_scale_record_expected_families <- function(manifest, lane, phases) {
  applies <- manifest$lane %in% c("both", lane)
  selected <- vapply(
    manifest$selection,
    ledgr_scale_record_selection_enabled,
    logical(1L),
    phases = phases
  )
  sort(manifest$family[applies & selected])
}

ledgr_scale_record_validate_manifest <- function(record_dir, manifest, lane, phases) {
  expected <- ledgr_scale_record_expected_families(manifest, lane, phases)
  actual <- sort(sub(
    "\\.csv$", "",
    list.files(file.path(record_dir, "families"), pattern = "\\.csv$")
  ))
  missing <- setdiff(expected, actual)
  extra <- setdiff(actual, expected)
  if (length(missing) || length(extra)) {
    detail <- c(
      if (length(missing)) paste0("missing: ", paste(missing, collapse = ", ")),
      if (length(extra)) paste0("extra: ", paste(extra, collapse = ", "))
    )
    stop(
      paste0("Scale-record family manifest mismatch (", paste(detail, collapse = "; "), ")."),
      call. = FALSE
    )
  }
  invisible(actual)
}

ledgr_scale_record_validate_transition <- function(manifest, transition_path) {
  transition <- utils::read.csv(
    transition_path,
    colClasses = "character",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (!identical(names(transition), c("change", "family")) ||
      anyNA(transition) || any(!nzchar(as.matrix(transition))) ||
      !setequal(transition$change, c("added", "removed"))) {
    stop("The scale-record family transition is malformed.", call. = FALSE)
  }
  current <- unique(manifest$family)
  added <- transition$family[transition$change == "added"]
  removed <- transition$family[transition$change == "removed"]
  if (!identical(sort(added), "momentum_feature_plane") ||
      !identical(sort(removed), sort(c("equal_weight_features", "momentum_features"))) ||
      !all(added %in% current) || any(removed %in% current)) {
    stop("The scale-record family transition no longer matches the schema-120 repair.", call. = FALSE)
  }
  invisible(transition)
}

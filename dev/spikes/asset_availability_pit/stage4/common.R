`%||%` <- function(x, y) if (is.null(x)) y else x

stage4_root <- function() {
  normalizePath(
    file.path("dev", "spikes", "asset_availability_pit"),
    winslash = "/", mustWork = TRUE
  )
}

stage4_assert <- function(ok, message) {
  if (!isTRUE(ok)) stop(message, call. = FALSE)
  invisible(TRUE)
}

stage4_ts <- function(x) {
  as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

stage4_value_type <- function(value) {
  if (is.null(value) || (length(value) == 1L && is.na(value))) return("absent")
  if (inherits(value, "POSIXct")) return("timestamp")
  if (is.logical(value)) return("logical")
  if (is.integer(value)) return("integer")
  if (is.numeric(value)) return("double")
  "character"
}

stage4_value_string <- function(value, value_type = stage4_value_type(value)) {
  if (identical(value_type, "absent")) return("")
  if (identical(value_type, "timestamp")) return(stage3_iso(value))
  stage3_value_string(value, value_type)
}

stage4_rows <- function(case_id,
                        field,
                        value,
                        event_time = "",
                        asset_id = "",
                        effective_time = NULL,
                        knowledge_time = NULL,
                        revision_time = NULL) {
  if (is.null(effective_time)) effective_time <- event_time
  if (is.null(knowledge_time)) knowledge_time <- event_time
  if (is.null(revision_time)) revision_time <- knowledge_time
  n <- max(
    length(case_id), length(field), length(value), length(event_time),
    length(asset_id), length(effective_time), length(knowledge_time),
    length(revision_time)
  )
  recycle <- function(x) rep(x, length.out = n)
  values <- recycle(value)
  data.frame(
    case_id = as.character(recycle(case_id)),
    event_time = as.character(recycle(event_time)),
    effective_time = as.character(recycle(effective_time)),
    knowledge_time = as.character(recycle(knowledge_time)),
    revision_time = as.character(recycle(revision_time)),
    asset_id = as.character(recycle(asset_id)),
    field = as.character(recycle(field)),
    value_type = vapply(values, stage4_value_type, character(1L)),
    value = I(unname(as.list(values))),
    stringsAsFactors = FALSE
  )
}

stage4_bind_rows <- function(...) {
  rows <- list(...)
  rows <- rows[vapply(rows, nrow, integer(1L)) > 0L]
  if (length(rows) == 0L) {
    return(stage4_rows(character(), character(), list()))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

stage4_fact_key <- function(case_id, field, event_time = "", asset_id = "") {
  paste(case_id, field, event_time, asset_id, sep = "\035")
}

stage4_fixture <- function(witness_id, rows, metadata = list()) {
  required <- c(
    "case_id", "event_time", "effective_time", "knowledge_time",
    "revision_time", "asset_id", "field", "value_type", "value"
  )
  stage4_assert(nzchar(witness_id), "A Stage 4 fixture requires a witness ID.")
  stage4_assert(identical(names(rows), required), "Invalid Stage 4 fixture schema.")
  keys <- stage4_fact_key(rows$case_id, rows$field, rows$event_time, rows$asset_id)
  stage4_assert(!anyDuplicated(keys), "Stage 4 fixture facts must have unique keys.")
  structure(
    list(witness_id = witness_id, rows = rows, metadata = metadata),
    class = "stage4_fixture"
  )
}

stage4_fact <- function(provider,
                        case_id,
                        field,
                        event_time = "",
                        asset_id = "") {
  UseMethod("stage4_fact")
}

stage4_decision_view <- function(provider,
                                 case_id,
                                 event_time,
                                 held_ids = character(),
                                 knowledge_cutoff = event_time) {
  UseMethod("stage4_decision_view")
}

stage4_execution_view <- function(provider,
                                  case_id,
                                  event_time,
                                  asset_ids,
                                  knowledge_cutoff = event_time) {
  UseMethod("stage4_execution_view")
}

stage4_history <- function(provider,
                           case_id,
                           field,
                           asset_id,
                           through = NULL,
                           knowledge_cutoff = through) {
  UseMethod("stage4_history")
}

stage4_inventory <- function(provider) UseMethod("stage4_inventory")

stage4_provider_kinds <- function() {
  c("dense_state_planes", "dynamic_active_matrices", "sparse_fact_materializer")
}

stage4_normalize_rows <- function(rows) {
  if (nrow(rows) == 0L) return(rows)
  key <- do.call(paste, c(
    rows[c(
      "case_id", "field", "event_time", "effective_time",
      "knowledge_time", "revision_time", "asset_id", "value_type"
    )], sep = "\035"
  ))
  rows[order(key, method = "radix"), , drop = FALSE]
}

stage4_rows_hash_payload <- function(witness_id, rows) {
  rows <- stage4_normalize_rows(rows)
  list(
    witness_id = witness_id,
    rows = lapply(seq_len(nrow(rows)), function(i) {
      list(
        case_id = rows$case_id[[i]],
        event_time = rows$event_time[[i]],
        effective_time = rows$effective_time[[i]],
        knowledge_time = rows$knowledge_time[[i]],
        revision_time = rows$revision_time[[i]],
        asset_id = rows$asset_id[[i]],
        field = rows$field[[i]],
        value_type = rows$value_type[[i]],
        value = stage4_value_string(rows$value[[i]], rows$value_type[[i]])
      )
    })
  )
}

stage4_recovered_fact_identity <- function(provider) {
  stage3_hash(stage4_rows_hash_payload(
    provider$witness_id, stage4_provider_rows(provider)
  ))
}

stage4_provider_identity <- function(provider) {
  stage3_hash(list(
    kind = "asset_availability_recovered_rows_v1",
    recovered_fact_identity = stage4_recovered_fact_identity(provider)
  ))
}

stage4_prototype_identity <- function(provider) {
  stage3_hash(list(
    kind = "asset_availability_stage4_fork_v1",
    provider_kind = provider$provider_kind,
    provider_identity = stage4_provider_identity(provider)
  ))
}

stage4_serialize <- function(provider) serialize(provider, NULL, version = 3L)

stage4_restore <- function(bytes) {
  provider <- unserialize(bytes)
  stage4_assert(inherits(provider, "stage4_provider"), "Not a Stage 4 provider.")
  provider
}

stage4_provider_base <- function(kind, fixture) {
  telemetry <- new.env(parent = emptyenv())
  telemetry$temporary_rows <- 0L
  telemetry$temporary_bytes <- 0
  list(
    provider_kind = kind,
    witness_id = fixture$witness_id,
    metadata = fixture$metadata,
    telemetry = telemetry
  )
}

stage4_record_temporary <- function(provider, value) {
  provider$telemetry$temporary_rows <- provider$telemetry$temporary_rows +
    if (is.data.frame(value)) nrow(value) else length(value)
  provider$telemetry$temporary_bytes <- provider$telemetry$temporary_bytes +
    as.double(object.size(value))
  value
}

stage4_memory_row <- function(provider, path) {
  inventory <- stage4_inventory(provider)
  data.frame(
    provider = provider$provider_kind,
    path = path,
    retained_object_count = nrow(inventory),
    retained_bytes = sum(inventory$bytes),
    serialized_bytes = length(stage4_serialize(provider)),
    temporary_rows = provider$telemetry$temporary_rows,
    temporary_bytes = provider$telemetry$temporary_bytes,
    evidence_role = "fork_derived",
    stringsAsFactors = FALSE
  )
}

stage4_evidence_builder <- function(provider, witness_id) {
  values <- list()
  emit <- function(case_id,
                   field,
                   value,
                   event_time = "",
                   asset_id = "",
                   reason_code = "",
                   evidence_role = "fork_derived",
                   identity_name = "") {
    values[[length(values) + 1L]] <<- data.frame(
      provider = provider$provider_kind,
      witness_id = witness_id,
      case_id = as.character(case_id),
      event_time = as.character(event_time),
      asset_id = as.character(asset_id),
      field = as.character(field),
      observed_type = if (nzchar(identity_name)) "identity" else
        stage4_value_type(value),
      observed_value = if (nzchar(identity_name)) as.character(value) else
        stage4_value_string(value),
      reason_code = as.character(reason_code),
      identity_name = as.character(identity_name),
      evidence_role = evidence_role,
      stringsAsFactors = FALSE
    )
    invisible(NULL)
  }
  finish <- function() {
    if (length(values) == 0L) stop("Stage 4 case emitted no evidence.", call. = FALSE)
    out <- do.call(rbind, values)
    key <- paste(out$case_id, out$event_time, out$asset_id, out$field, sep = "\034")
    stage4_assert(!anyDuplicated(key), "Stage 4 emitted duplicate evidence keys.")
    rownames(out) <- NULL
    out
  }
  list(emit = emit, finish = finish)
}

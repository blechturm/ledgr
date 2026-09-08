stage4_build_provider <- function(kind, fixture) {
  builder <- get(paste0("stage4_build_", kind), mode = "function")
  builder(fixture)
}

stage4_dense_planes_from_rows <- function(rows) {
  timed <- nzchar(rows$event_time) & nzchar(rows$asset_id)
  ids <- unique(rows$asset_id[nzchar(rows$asset_id)])
  times <- sort(unique(rows$event_time[nzchar(rows$event_time)]), method = "radix")
  if (length(ids) == 0L || length(times) == 0L) return(list())
  keys <- unique(paste(rows$case_id[timed], rows$field[timed], sep = "\035"))
  planes <- lapply(keys, function(key) {
    parts <- strsplit(key, "\035", fixed = TRUE)[[1L]]
    selected <- rows[
      timed & rows$case_id == parts[[1L]] & rows$field == parts[[2L]],
      , drop = FALSE
    ]
    plane <- matrix(
      vector("list", length(ids) * length(times)),
      nrow = length(ids), ncol = length(times), dimnames = list(ids, times)
    )
    for (i in seq_len(nrow(selected))) {
      plane[[selected$asset_id[[i]], selected$event_time[[i]]]] <-
        selected[i, , drop = FALSE]
    }
    plane
  })
  names(planes) <- keys
  planes
}

stage4_build_dense_state_planes <- function(fixture) {
  rows <- fixture$rows
  timed <- nzchar(rows$event_time) & nzchar(rows$asset_id)
  structure(
    c(stage4_provider_base("dense_state_planes", fixture), list(
      planes = stage4_dense_planes_from_rows(rows),
      records = rows[!timed, , drop = FALSE],
      source_keys = stage4_fact_key(
        rows$case_id, rows$field, rows$event_time, rows$asset_id
      )
    )),
    class = c("stage4_dense_state_planes", "stage4_provider")
  )
}

stage4_build_dynamic_active_matrices <- function(fixture) {
  structure(
    c(stage4_provider_base("dynamic_active_matrices", fixture), list(
      effective_facts = fixture$rows
    )),
    class = c("stage4_dynamic_active_matrices", "stage4_provider")
  )
}

stage4_build_sparse_fact_materializer <- function(fixture) {
  facts <- fixture$rows
  facts$key <- stage4_fact_key(
    facts$case_id, facts$field, facts$event_time, facts$asset_id
  )
  structure(
    c(stage4_provider_base("sparse_fact_materializer", fixture), list(
      facts = facts,
      index = split(seq_len(nrow(facts)), facts$key)
    )),
    class = c("stage4_sparse_fact_materializer", "stage4_provider")
  )
}

stage4_provider_rows <- function(provider) {
  if (inherits(provider, "stage4_dynamic_active_matrices")) {
    return(provider$effective_facts)
  }
  if (inherits(provider, "stage4_sparse_fact_materializer")) {
    out <- provider$facts
    out$key <- NULL
    return(stage4_record_temporary(provider, out))
  }
  parts <- list(provider$records)
  for (plane in provider$planes) {
    for (i in seq_len(length(plane))) {
      if (!is.null(plane[[i]])) parts[[length(parts) + 1L]] <- plane[[i]]
    }
  }
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  keys <- stage4_fact_key(out$case_id, out$field, out$event_time, out$asset_id)
  out <- out[match(provider$source_keys, keys), , drop = FALSE]
  stage4_record_temporary(provider, out)
}

stage4_exact_row <- function(rows,
                             case_id,
                             field,
                             event_time = "",
                             asset_id = "") {
  keep <- rows$case_id == case_id & rows$field == field &
    rows$event_time == event_time & rows$asset_id == asset_id
  stage4_assert(sum(keep) == 1L, paste(
    "Provider fact is absent or ambiguous:",
    paste(case_id, field, event_time, asset_id, sep = "/")
  ))
  rows[which(keep), , drop = FALSE]
}

stage4_fact.stage4_dense_state_planes <- function(provider,
                                                   case_id,
                                                   field,
                                                   event_time = "",
                                                   asset_id = "") {
  if (nzchar(event_time) && nzchar(asset_id)) {
    plane <- provider$planes[[paste(case_id, field, sep = "\035")]]
    stage4_assert(!is.null(plane), "Dense provider field is absent.")
    stage4_assert(
      asset_id %in% rownames(plane) && event_time %in% colnames(plane),
      "Dense provider fact is outside its fixed plane."
    )
    row <- plane[[asset_id, event_time]]
    stage4_assert(!is.null(row), "Dense provider fact is absent.")
    return(row$value[[1L]])
  }
  stage4_exact_row(provider$records, case_id, field, event_time, asset_id)$value[[1L]]
}

stage4_fact.stage4_dynamic_active_matrices <- function(provider,
                                                       case_id,
                                                       field,
                                                       event_time = "",
                                                       asset_id = "") {
  rows <- provider$effective_facts
  if (nzchar(event_time)) {
    rows <- stage4_record_temporary(
      provider, rows[rows$case_id == case_id & rows$event_time == event_time, , drop = FALSE]
    )
  } else {
    rows <- rows[!nzchar(rows$event_time), , drop = FALSE]
  }
  stage4_exact_row(rows, case_id, field, event_time, asset_id)$value[[1L]]
}

stage4_sparse_hydrate <- function(provider, case_id, fields, from, through) {
  facts <- provider$facts
  keep <- facts$case_id == case_id & facts$field %in% fields &
    facts$event_time >= from & facts$event_time <= through
  out <- facts[keep, setdiff(names(facts), "key"), drop = FALSE]
  out <- out[order(out$event_time, out$asset_id, out$field, method = "radix"), , drop = FALSE]
  stage4_record_temporary(provider, out)
}

stage4_fact.stage4_sparse_fact_materializer <- function(provider,
                                                        case_id,
                                                        field,
                                                        event_time = "",
                                                        asset_id = "") {
  if (nzchar(event_time)) {
    rows <- stage4_sparse_hydrate(provider, case_id, field, event_time, event_time)
    return(stage4_exact_row(rows, case_id, field, event_time, asset_id)$value[[1L]])
  }
  key <- stage4_fact_key(case_id, field, event_time, asset_id)
  at <- provider$index[[key]]
  stage4_assert(length(at) == 1L, "Sparse provider fact is absent or ambiguous.")
  provider$facts$value[[at]]
}

stage4_known_rows <- function(rows, event_time, knowledge_cutoff) {
  effective <- !nzchar(rows$effective_time) | rows$effective_time <= event_time
  known <- !nzchar(rows$knowledge_time) | rows$knowledge_time <= knowledge_cutoff
  rows[effective & known, , drop = FALSE]
}

stage4_latest_by_asset <- function(rows) {
  if (nrow(rows) == 0L) return(rows)
  out <- lapply(unique(rows$asset_id), function(id) {
    x <- rows[rows$asset_id == id, , drop = FALSE]
    x <- x[order(
      x$effective_time, x$knowledge_time, x$revision_time, method = "radix"
    ), , drop = FALSE]
    x[nrow(x), , drop = FALSE]
  })
  do.call(rbind, out)
}

stage4_decision_view_from_rows <- function(provider,
                                           rows,
                                           case_id,
                                           event_time,
                                           held_ids,
                                           knowledge_cutoff) {
  member_rows <- rows[
    rows$case_id == case_id & rows$field == "member" & nzchar(rows$asset_id),
    , drop = FALSE
  ]
  members <- character()
  if (nrow(member_rows) > 0L) {
    current <- stage4_latest_by_asset(
      stage4_known_rows(member_rows, event_time, knowledge_cutoff)
    )
    members <- current$asset_id[vapply(current$value, isTRUE, logical(1L))]
  }
  ids <- unique(c(members, held_ids))
  stage4_record_temporary(provider, data.frame(
    asset_id = ids,
    member = ids %in% members,
    held = ids %in% held_ids,
    target_restricted = ids %in% held_ids & !ids %in% members,
    stringsAsFactors = FALSE
  ))
}

stage4_decision_view.stage4_dense_state_planes <- function(
    provider, case_id, event_time, held_ids = character(),
    knowledge_cutoff = event_time) {
  stage4_decision_view_from_rows(
    provider, stage4_provider_rows(provider), case_id, event_time,
    held_ids, knowledge_cutoff
  )
}

stage4_decision_view.stage4_dynamic_active_matrices <- function(
    provider, case_id, event_time, held_ids = character(),
    knowledge_cutoff = event_time) {
  stage4_decision_view_from_rows(
    provider, provider$effective_facts, case_id, event_time,
    held_ids, knowledge_cutoff
  )
}

stage4_decision_view.stage4_sparse_fact_materializer <- function(
    provider, case_id, event_time, held_ids = character(),
    knowledge_cutoff = event_time) {
  stage4_decision_view_from_rows(
    provider, stage4_provider_rows(provider), case_id, event_time,
    held_ids, knowledge_cutoff
  )
}

stage4_latest_fact <- function(rows,
                               case_id,
                               fields,
                               asset_id,
                               event_time,
                               knowledge_cutoff) {
  selected <- rows[
    rows$case_id == case_id & rows$field %in% fields &
      rows$asset_id == asset_id,
    , drop = FALSE
  ]
  selected <- stage4_known_rows(selected, event_time, knowledge_cutoff)
  if (nrow(selected) == 0L) return(NULL)
  selected <- selected[order(
    selected$effective_time, selected$knowledge_time,
    selected$revision_time, match(selected$field, fields), method = "radix"
  ), , drop = FALSE]
  selected[nrow(selected), , drop = FALSE]
}

stage4_execution_view_from_rows <- function(provider,
                                            rows,
                                            case_id,
                                            event_time,
                                            asset_ids,
                                            knowledge_cutoff) {
  out <- lapply(asset_ids, function(id) {
    price <- stage4_latest_fact(
      rows, case_id, c("execution_price", "next_open", "open"),
      id, event_time, knowledge_cutoff
    )
    status <- stage4_latest_fact(
      rows, case_id, c("trading_status", "resolved_status"),
      id, event_time, knowledge_cutoff
    )
    data.frame(
      asset_id = id,
      execution_price = if (is.null(price)) NA_real_ else
        as.numeric(price$value[[1L]]),
      trading_status = if (is.null(status)) "status_unknown" else
        as.character(status$value[[1L]]),
      stringsAsFactors = FALSE
    )
  })
  stage4_record_temporary(provider, do.call(rbind, out))
}

stage4_execution_view.stage4_dense_state_planes <- function(
    provider, case_id, event_time, asset_ids, knowledge_cutoff = event_time) {
  stage4_execution_view_from_rows(
    provider, stage4_provider_rows(provider), case_id, event_time,
    asset_ids, knowledge_cutoff
  )
}

stage4_execution_view.stage4_dynamic_active_matrices <- function(
    provider, case_id, event_time, asset_ids, knowledge_cutoff = event_time) {
  stage4_execution_view_from_rows(
    provider, provider$effective_facts, case_id, event_time,
    asset_ids, knowledge_cutoff
  )
}

stage4_execution_view.stage4_sparse_fact_materializer <- function(
    provider, case_id, event_time, asset_ids, knowledge_cutoff = event_time) {
  rows <- stage4_sparse_hydrate(
    provider, case_id, c("execution_price", "next_open", "open",
      "trading_status", "resolved_status"), event_time, event_time
  )
  stage4_execution_view_from_rows(
    provider, rows, case_id, event_time, asset_ids, knowledge_cutoff
  )
}

stage4_history_from_rows <- function(provider,
                                     rows,
                                     case_id,
                                     field,
                                     asset_id,
                                     through,
                                     knowledge_cutoff) {
  keep <- rows$case_id == case_id & rows$field == field &
    rows$asset_id == asset_id & nzchar(rows$event_time)
  out <- rows[keep, , drop = FALSE]
  if (!is.null(through)) out <- out[out$event_time <= through, , drop = FALSE]
  if (!is.null(knowledge_cutoff)) {
    out <- out[!nzchar(out$knowledge_time) |
      out$knowledge_time <= knowledge_cutoff, , drop = FALSE]
  }
  out <- out[order(out$event_time, out$revision_time, method = "radix"), , drop = FALSE]
  stage4_record_temporary(
    provider, unname(unlist(out$value, recursive = FALSE, use.names = FALSE))
  )
}

stage4_history.stage4_dense_state_planes <- function(
    provider, case_id, field, asset_id, through = NULL,
    knowledge_cutoff = through) {
  stage4_history_from_rows(
    provider, stage4_provider_rows(provider), case_id, field, asset_id,
    through, knowledge_cutoff
  )
}

stage4_history.stage4_dynamic_active_matrices <- function(
    provider, case_id, field, asset_id, through = NULL,
    knowledge_cutoff = through) {
  stage4_history_from_rows(
    provider, provider$effective_facts, case_id, field, asset_id,
    through, knowledge_cutoff
  )
}

stage4_history.stage4_sparse_fact_materializer <- function(
    provider, case_id, field, asset_id, through = NULL,
    knowledge_cutoff = through) {
  rows <- provider$facts
  rows$key <- NULL
  stage4_history_from_rows(
    provider, rows, case_id, field, asset_id, through, knowledge_cutoff
  )
}

stage4_inventory.stage4_dense_state_planes <- function(provider) {
  objects <- c(provider$planes, list(records = provider$records))
  data.frame(
    object = names(objects),
    role = c(rep("fixed_superset_plane", length(provider$planes)), "scalar_records"),
    bytes = vapply(objects, function(x) as.double(object.size(x)), numeric(1L)),
    stringsAsFactors = FALSE
  )
}

stage4_inventory.stage4_dynamic_active_matrices <- function(provider) {
  data.frame(
    object = "effective_facts", role = "effective_dated_rows",
    bytes = as.double(object.size(provider$effective_facts)),
    stringsAsFactors = FALSE
  )
}

stage4_inventory.stage4_sparse_fact_materializer <- function(provider) {
  data.frame(
    object = c("facts", "index"),
    role = c("sparse_facts", "fact_index"),
    bytes = c(as.double(object.size(provider$facts)),
      as.double(object.size(provider$index))),
    stringsAsFactors = FALSE
  )
}

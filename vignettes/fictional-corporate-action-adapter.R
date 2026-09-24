fictional_corporate_action_adapter <- function(records) {
  required <- c(
    "record_key", "effect_code", "subject_key", "rights_at",
    "changes_at", "seen_at", "settles_at", "terms_ready",
    "why_refused", "lineage_level", "source_build", "price_release",
    "cash_units", "cash_checked", "destination_key",
    "destination_checked", "share_units", "share_units_checked"
  )
  if (!is.data.frame(records) || !all(required %in% names(records))) {
    stop("Fictional records do not match the adapter contract.", call. = FALSE)
  }
  subtype_map <- c(
    PAYMENT = "ordinary_cash_dividend",
    CHILD_GRANT = "spin_off"
  )
  subtype <- unname(subtype_map[as.character(records$effect_code)])
  if (anyNA(subtype)) {
    stop("Fictional records contain an unknown effect code.", call. = FALSE)
  }

  canonical <- data.frame(
    fact_id = as.character(records$record_key),
    subtype = subtype,
    parent_instrument_id = as.character(records$subject_key),
    entitlement_time = records$rights_at,
    effective_time = records$changes_at,
    knowledge_time = records$seen_at,
    payment_time = records$settles_at,
    complete = as.logical(records$terms_ready),
    refusal_reason = as.character(records$why_refused),
    provenance_tier = as.character(records$lineage_level),
    upstream_build_id = as.character(records$source_build),
    bar_vintage_id = as.character(records$price_release),
    gross_cash_per_parent_unit = as.numeric(records$cash_units),
    gross_cash_validated = as.logical(records$cash_checked),
    recipient_instrument_id = as.character(records$destination_key),
    recipient_identity_validated = as.logical(records$destination_checked),
    recipient_quantity_per_parent_unit = as.numeric(records$share_units),
    recipient_quantity_validated = as.logical(records$share_units_checked),
    source = "fictional_adapter",
    stringsAsFactors = FALSE
  )
  ledgr_facts_equity_corporate_actions(canonical)
}

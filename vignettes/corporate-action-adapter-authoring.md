# Authoring A Corporate-Action Adapter


You have corporate-action records from a data vendor and want ledgr to
use them. This article shows how to write the adapter that translates
those records into ledgr’s canonical facts, and how to seal the result.
It is for adapter authors; if your facts already use ledgr’s canonical
form, `vignette("corporate-action-cash", package = "ledgr")` is enough.

An adapter has one job: translate a source’s vocabulary and units into
ledgr’s canonical, vendor-neutral corporate-action facts. It must not
make portfolio policy decisions. Sealing then validates and binds those
facts to the snapshot; execution policy is selected later by the
experiment.

The boundary is:

    private source rows -> adapter -> canonical facts -> sealed snapshot
                                                  |
                                                  +-> experiment policy -> run

## The Canonical Header

Every row needs a stable `fact_id`, a closed `subtype`, and a
`parent_instrument_id`. Four clocks have distinct meanings:

- `entitlement_time` determines which holding is entitled;
- `effective_time` records when the source says the event takes effect;
- `knowledge_time` is the first instant the terms may be used without
  look-ahead; and
- `payment_time` is optional evidence, not the research preset’s posting
  clock.

`complete` says whether the required terms are present. An incomplete
row must carry a declared `refusal_reason`; it is evidence of an
unsupported event, not an absent event.

## Terms, Units, And Validation Flags

Cash is expressed as `gross_cash_per_parent_unit`. A security leg uses
`recipient_instrument_id` and `recipient_quantity_per_parent_unit`. Each
leg has its own validation flag. An adapter sets a flag only after it
has checked the source meaning and converted the term to the unit basis
of the sealed bars.

ledgr does not redo a vendor adjustment. The snapshot therefore declares
a `price_basis`. Corporate-action settlement requires `split_adjusted`;
bars that already include distributions are refused because posting cash
again would double count it.

The fictional source below reports its dividend as 2.5 old parent units
and declares a 0.5 parent-unit multiplier for a later split. The
canonical term is therefore 1.25 in the same unit basis as the sealed
bars. The source adapter, not ledgr execution, owns that conversion.

## Provenance

`provenance_tier = "snapshot_bound"` is the portable tier. It binds the
canonical facts to the sealed snapshot without requiring a provider
build. `build_and_vintage_bound` is stronger: it additionally requires
`upstream_build_id` and `bar_vintage_id`. The tier records evidence
strength; it does not select a settlement capability.

Keep the original source locator or record key in `fact_id` or
source-owned lineage before translation. Never place licensed
identifiers or raw payloads in public examples or error messages.

## The Adapter

The setup chunk sources the same companion file shown below, so the
displayed function is the function the example executes. It validates
the source shape, maps the source vocabulary, normalizes cash units, and
then hands the canonical rows to ledgr’s public fact constructor.

``` r
fictional_corporate_action_adapter <- function(records) {
  required <- c(
    "record_key", "effect_code", "subject_key", "rights_at",
    "changes_at", "seen_at", "settles_at", "terms_ready",
    "why_refused", "lineage_level", "source_build", "price_release",
    "cash_units", "parent_unit_multiplier", "cash_checked", "destination_key",
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
    gross_cash_per_parent_unit = as.numeric(
      records$cash_units * records$parent_unit_multiplier
    ),
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
```

## A Fictional Source

This example intentionally uses source names that do not resemble the
canonical names. That makes the adapter boundary visible instead of
merely copying a data frame.

``` r
times <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC") + 86400 * 0:2
records <- data.frame(
  record_key = c("notice-1", "notice-2"),
  effect_code = c("PAYMENT", "CHILD_GRANT"),
  subject_key = c("AAA", "AAA"),
  rights_at = c(times[[2]], times[[3]]),
  changes_at = c(times[[2]], times[[3]]),
  seen_at = c(times[[1]], times[[1]]),
  settles_at = as.POSIXct(c(NA, NA), origin = "1970-01-01", tz = "UTC"),
  terms_ready = c(TRUE, TRUE),
  why_refused = c(NA_character_, NA_character_),
  lineage_level = c("snapshot_bound", "snapshot_bound"),
  source_build = c(NA_character_, NA_character_),
  price_release = c(NA_character_, NA_character_),
  cash_units = c(2.5, NA_real_),
  parent_unit_multiplier = c(0.5, 1),
  cash_checked = c(TRUE, FALSE),
  destination_key = c(NA_character_, "BBB"),
  destination_checked = c(FALSE, TRUE),
  share_units = c(NA_real_, 0.5),
  share_units_checked = c(FALSE, TRUE),
  stringsAsFactors = FALSE
)

facts <- fictional_corporate_action_adapter(records)
facts
#> ledgr fact family
#> Family: equity_corporate_actions
#> Scope:  equity
#> Rows:   2
```

The adapter owns the mapping from `PAYMENT` and `CHILD_GRANT`, the clock
interpretation, unit normalization, and the validation flags. ledgr owns
the canonical validator. Unknown source codes fail in the adapter;
invalid canonical combinations fail in
`ledgr_facts_equity_corporate_actions()`.

## Seal The Result

The physical axis must contain any recipient whose value may be needed
later, even when that recipient is not a member of the strategy
universe. Physical axis closure does not grant membership and does not
make the recipient visible to features before the event.

``` r
bars <- do.call(rbind, lapply(c("AAA", "BBB"), function(id) {
  data.frame(
    instrument_id = id,
    ts_utc = times,
    open = if (id == "AAA") 10:12 else 20:22,
    high = if (id == "AAA") 10:12 else 20:22,
    low = if (id == "AAA") 10:12 else 20:22,
    close = if (id == "AAA") 10:12 else 20:22,
    volume = 1000
  )
}))
store <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(
  bars,
  instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
  facts = ledgr_facts(facts),
  price_basis = "split_adjusted",
  db_path = store,
  snapshot_id = "adapter_demo"
)
info <- ledgr_snapshot_info(snapshot)
c(
  status = info$status[[1]],
  bar_count = info$bar_count[[1]],
  instrument_count = info$instrument_count[[1]]
)
#>           status        bar_count instrument_count
#>         "SEALED"              "6"              "2"
```

The snapshot hash covers the canonical facts and their declared
provenance. Reopening verifies that identity; a consumer does not need
the private source or adapter to reproduce the sealed input.

## Refusal Is A Result

An adapter should preserve a known event whose terms cannot be
validated. Set `complete = FALSE`, provide the applicable refusal
reason, and leave unvalidated terms unavailable. Do not infer a ratio,
fabricate a mark, or turn an unsupported event into absence.

At execution time, strict policy stops on a relevant unsupported effect.
Research policy may report a quantity effect without changing account
state. Neither path claims exact recipient exposure, broker settlement,
withholding, tax treatment, or completeness of the upstream source.

This release does not claim corporate-action completeness, broker-exact
settlement, net cash, tax correctness, or exact recipient exposure.

## Where Next

- Read `vignette("metric-contexts-and-conventions", package = "ledgr")`
  for the annualization and risk-free assumptions behind the metrics.
- Read `vignette("corporate-action-cash", package = "ledgr")` to see a
  sealed cash fact affect an ordinary research run.
- Read `vignette("point-in-time-inputs", package = "ledgr")` for the
  complete fact bundle and its four clocks.
- Use `?ledgr_facts_equity_corporate_actions` as the field-level
  reference when mapping a real vendor source.

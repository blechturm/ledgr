stage3_reference_provider <- function() {
  structure(
    list(
      provider_name = "dense_state_planes_reference",
      provider_version = "1",
      policy_id = "asset_availability_initial_policy_v4",
      witness_spec = "asset_availability_witness_v3",
      calendar_id = "XSYN_synthetic_v1",
      axis_ordering = "members_in_declared_order_then_held_nonmembers"
    ),
    class = "ledgr_asset_availability_reference_provider"
  )
}

stage3_provider_assert <- function(provider) {
  stage3_assert(
    inherits(provider, "ledgr_asset_availability_reference_provider"),
    "Stage 3 requires the dense-state reference provider."
  )
  invisible(provider)
}

stage3_provider_id <- function(provider, snapshot_hash) {
  stage3_hash(list(
    kind = "asset_availability_provider_v1",
    provider_name = provider$provider_name,
    provider_version = provider$provider_version,
    snapshot_hash = snapshot_hash,
    policy_id = provider$policy_id,
    witness_spec = provider$witness_spec,
    calendar_id = provider$calendar_id,
    axis_ordering = provider$axis_ordering
  ))
}

stage3_provider_w21 <- function(provider) {
  stage3_provider_assert(provider)
  close_time <- as.POSIXct(
    c(
      "2024-01-02 21:00:00",
      "2024-01-03 21:00:00",
      "2024-01-04 21:00:00",
      "2024-01-05 21:00:00"
    ),
    tz = "UTC"
  )
  open_time <- as.POSIXct(
    c(
      "2024-01-02 14:30:00",
      "2024-01-03 14:30:00",
      "2024-01-04 14:30:00",
      "2024-01-05 14:30:00"
    ),
    tz = "UTC"
  )
  ids <- c("A02", "A01")
  values <- list(
    A01 = list(open = c(100, 100, 102, 104), close = c(100, 102, 104, 106)),
    A02 = list(open = c(50, 50, 49, 48), close = c(50, 49, 48, 52))
  )
  bars <- do.call(rbind, lapply(ids, function(id) {
    data.frame(
      instrument_id = id,
      ts_utc = close_time,
      open = values[[id]]$open,
      high = pmax(values[[id]]$open, values[[id]]$close),
      low = pmin(values[[id]]$open, values[[id]]$close),
      close = values[[id]]$close,
      volume = rep(1000, length(close_time)),
      stringsAsFactors = FALSE
    )
  }))
  rownames(bars) <- NULL
  list(
    provider = provider,
    witness_id = "W21",
    case_id = "c1",
    instrument_ids = ids,
    pulses = close_time,
    execution_times = open_time,
    bars = bars,
    opening = list(
      cash = 50000,
      positions = c(A02 = 0, A01 = 100),
      lot_basis = c(A01 = 100)
    ),
    targets = rbind(
      c(A02 = 800, A01 = 50),
      c(A02 = 660, A01 = 0),
      c(A02 = 660, A01 = 0),
      c(A02 = 0, A01 = 0)
    ),
    fixed_fee = 1,
    max_weight = 0.55
  )
}

stage3_provider_w02 <- function(provider) {
  stage3_provider_assert(provider)
  pulses <- as.POSIXct(
    c("2024-01-02 21:00:00", "2024-01-03 21:00:00"),
    tz = "UTC"
  )
  execution_times <- as.POSIXct(
    c("2024-01-02 14:30:00", "2024-01-03 14:30:00"),
    tz = "UTC"
  )
  ids <- c("A01", "A02")
  bars <- expand.grid(
    instrument_id = ids,
    ts_utc = pulses,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  price <- ifelse(bars$instrument_id == "A01", 100, 50)
  bars$open <- price
  bars$high <- price
  bars$low <- price
  bars$close <- price
  bars$volume <- 1000
  list(
    instrument_ids = ids,
    pulses = pulses,
    execution_times = execution_times,
    bars = bars,
    opening_cash = c(c0a = 10000, c0b = 10000, c1 = 10000, c2 = 0),
    opening_a01 = 300,
    prices = c(A01 = 100, A02 = 50),
    targets_a02 = c(c0a = 500, c0b = 500, c1 = 500, c2 = 600),
    target_order_dense = c("A01", "A02"),
    target_order_ragged = c("A02", "A01"),
    feasibility_order = c("A01", "A02"),
    cash_tolerance = 1e-8
  )
}

stage3_provider_status_facts <- function(provider) {
  stage3_provider_assert(provider)
  data.frame(
    asset_id = c("A01", "A01", "A01", "A01", "A01"),
    source = c("primary", "primary", "primary", "primary", "secondary"),
    precedence = rep(1L, 5L),
    status = c("active", "halted", "quotation_only", "active", "halted"),
    effective_from = as.POSIXct(
      c(
        "2023-01-02 14:30:00",
        "2024-01-04 14:00:00",
        "2024-01-05 14:00:00",
        "2024-01-08 14:00:00",
        "2024-01-09 14:00:00"
      ),
      tz = "UTC"
    ),
    effective_to = as.POSIXct(
      c(
        "2024-01-04 14:00:00",
        "2024-01-05 14:00:00",
        "2024-01-08 14:00:00",
        NA,
        NA
      ),
      tz = "UTC"
    ),
    knowledge_time = as.POSIXct(
      c(
        "2023-01-02 14:30:00",
        "2024-01-02 20:00:00",
        "2024-01-04 22:00:00",
        "2024-01-05 22:00:00",
        "2024-01-08 22:00:00"
      ),
      tz = "UTC"
    ),
    stringsAsFactors = FALSE
  )
}

stage3_provider_w22 <- function(provider) {
  stage3_provider_assert(provider)
  list(
    opening_cash = 90000,
    held_qty = 200,
    mark = 50,
    execution_price = 52,
    mark_age_fresh = 0L,
    mark_age_stale = 1L,
    max_weight = c(c0 = 0.05, c1 = 0.05, c2 = 0.5, c3 = 0.5),
    new_target = c(asset_id = "A03", value = "100")
  )
}

stage3_provider_w24 <- function(provider) {
  stage3_provider_assert(provider)
  list(
    opening_cash = 100000,
    buy_qty = 100,
    buy_price = 100,
    fold2_members = c("A02", "A03"),
    carried_id = "A01",
    carried_basis = 100
  )
}

stage3_provider_w25 <- function(provider) {
  stage3_provider_assert(provider)
  list(
    times = c(
      "2024-01-02T21:00:00Z", "2024-01-03T21:00:00Z",
      "2024-01-04T21:00:00Z", "2024-01-05T21:00:00Z"
    ),
    raw = c(1, 3, NA_real_, 9),
    calendar = "XSYN_v1",
    classifier = "observed_v1",
    population = "A01",
    cutoff = "2024-01-05T21:00:00Z",
    rng = "fixed:20240105"
  )
}

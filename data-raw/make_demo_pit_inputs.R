# Source of truth for the committed ledgr_demo_pit_inputs dataset.
# Run manually from the repository root after changing ledgr_sim_pit_inputs().

make_ledgr_demo_pit_inputs <- function(
    output_path = file.path("data", "ledgr_demo_pit_inputs.rda"),
    package_root = ".") {
  pkgload::load_all(package_root, quiet = TRUE)
  ledgr_demo_pit_inputs <- ledgr_sim_pit_inputs(
    instrument_ids = sprintf("DEMO_%02d", 1:5),
    from = "2020-01-01",
    to = "2020-01-31",
    seed = 1702L,
    venue_id = "DEMO_VENUE",
    universe_id = "demo_members",
    timezone = "America/New_York",
    session_open = "09:30:00",
    session_close = "16:00:00",
    cases = c(
      "venue_closure", "missing_observation", "delisting", "halt",
      "cash_dividend"
    )
  )

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  save(
    ledgr_demo_pit_inputs,
    file = output_path,
    compress = "xz",
    version = 2
  )
  invisible(ledgr_demo_pit_inputs)
}

if (sys.nframe() == 0L) {
  make_ledgr_demo_pit_inputs()
}

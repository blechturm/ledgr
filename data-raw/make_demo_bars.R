# Source of truth for the committed ledgr_demo_bars dataset.
# Run manually from the repository root after changing ledgr_sim_bars().

source("R/sim-bars.R")

ledgr_demo_bars <- ledgr_sim_bars(
  n_instruments = 10L,
  n_days = 252L * 5L,
  seed = 1701L,
  start = "2018-01-01"
)

dir.create("data", showWarnings = FALSE)
save(ledgr_demo_bars, file = "data/ledgr_demo_bars.rda", compress = "xz", version = 2)

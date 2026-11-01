# WS4b changes the path, not the economic workloads. Reuse the frozen WS4a
# definitions by reference so the two records cannot drift independently.
source(file.path(
  "dev", "bench", "timing", "protocols", "ws4a-timing-1", "workloads.R"
), local = TRUE)

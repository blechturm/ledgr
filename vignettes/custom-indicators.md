# Developing Custom Indicators

Full content in v0.1.3.

This vignette outline covers deterministic indicator construction, registry
usage, built-in indicators, R-function adapters, CSV adapters, and replay-safe
fingerprints.

## Outline

- Build indicators with `ledgr_indicator()`
- Use `ledgr_ind_sma()`, `ledgr_ind_ema()`, `ledgr_ind_rsi()`, and `ledgr_ind_returns()`
- Register and retrieve indicators
- Wrap package functions with `ledgr_adapter_r()`
- Use precomputed values with `ledgr_adapter_csv()`
- Understand purity and fingerprint requirements

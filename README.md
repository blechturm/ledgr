
# ledgr

<!-- badges: start -->
<!-- badges: end -->

ledgr is a correctness-first, event-sourced trading framework (R package) designed
for deterministic replay, restart safety, and strict no-lookahead guarantees.

ledgr is not a high-frequency trading engine and not a turnkey trading bot.

The binding system specification lives at `inst/design/ledgr_design_document.md`.

High-level lifecycle (v0.x):

`data -> strategy -> targets -> ledger -> execution`

## Installation

ledgr is not published yet. For local development, clone this repository and run
`devtools::install()`.

# Hot-path scan, 2026-11-02

A one-off list of banned calls in package code that can run per pulse, kept
as input for the WS14a holistic review (macro plan rule 17). It is not a
test and nothing runs it automatically.

`scan.R` parses `R/` and walks from the fold stages, the helpers the pulse
loop calls between them and what a strategy can call while deciding. It
follows direct calls, function names passed as arguments, literal
`do.call`, local and member closures and four listed indirections. It
counts `match`, `%in%`, `setdiff`, `setNames`, `unique`, `data.frame`,
`as.data.frame`, `rbind`, `all.equal` and canonical JSON encode or parse
calls in each function it reaches. Calls through variables, arguments or
computed `[[` are not followed, so the list is a floor, not a complete
inventory.

`scan.csv` holds the result on `release/v0.2.3` after Cut 9 Workstream 20:
173 function/call rows and 251 calls. Context-frame retirement removes the
bar-frame, feature-table and wide-frame construction rows from P2. The few
newly visible rows versus the old Cut 7 record belong to the accepted flat
lookup preparation already present at the Workstream 20 base; Workstream 21
changes no product hot path and adds no scan row. The record still includes
the per-fill JSON in
`ledgr_fill_event_payload`, the strategy-state encode and the
scheduled-skip helper's `%in%`. Re-run it with
`Rscript dev/bench/v0_2_3_hot_path_scan/scan.R --write` and compare the
diff.

The scan counts calls, not cost. The largest per-pulse costs in
`dev/bench/v0_2_3_fill_heavy_profile/` (DuckDB writes, carrier validation
in every stage, per-pulse frame building) are mostly not on this list.

History: cut 8 on branch `claude/rule17-banlist` first built this as an
enforced test. The maintainer withdrew the test on 2026-11-02 as tooling
the WS14a test cleanup would remove again, and kept the scan as WS14a
input.

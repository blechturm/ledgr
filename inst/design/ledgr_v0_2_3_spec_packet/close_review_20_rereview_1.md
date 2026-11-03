# Workstream 20 Focused Re-review 1

**Mode:** Type 1 focused re-review  
**Verdict:** PASS_AFTER_PATCHES  
**Correction range:** `fc9cf955..8690e349`

The F1-F6 product corrections in `376ae796` are correct. No new product
defect or design question was found. Five bounded test and record patches
remain.

## Findings

1. **N1, medium:** the preparation-count tests observed a fixed marker rather
   than calls to `ledgr_projection_feature_name_state()`. Count the real
   builder so a per-pulse rebuild fails.
2. **N2, medium:** the retained context used for the close oracle had already
   cached `close`. Retain another pulse context whose close is first read after
   the run so a shared live buffer behind the cache fails.
3. **N3, low:** the readable-name rebuild scan covered only two lookup helpers.
   Include `$`, `names()`, the available-field helper and lazy reads while
   allowing the ordinary stored-field `unique()`/`setdiff()` work.
4. **N4, low:** the evidence claimed hash-work detection more broadly than the
   test. Scan print, pulse-snapshot and strategy-error entrances for
   `canonical_json` and `sha256`.
5. **N5, low:** the evidence README still called the pre-correction profile
   directories final. Point it at the `376ae796` successor records.

After this re-review, profiling found one correction-side hot-path regression:
`cutoff_num` reparsed the already-formatted context timestamp on every pulse.
The accepted private lookup keeps the field, but the fold now supplies its
already-prepared numeric pulse time. A registered structural witness refuses
timestamp parsing in P2 and pins the numeric cutoff.

## Verified

Readable names and hashed membership are prepared once and reused;
`projection_idx`, `cutoff_num` and `readable_feature_names` are bound; fixture
feature timestamps and identifiers are validated vectorially; the unreachable
alias branch and filtered-feature frame capture are gone; mapped/unmapped
ordering, explicit-map memo refusal, missing-bar disclosure, exact error IDs,
printed Daxis, frame-free print/error handling and vector timestamp
normalization are pinned. The correction profiles contain 635/635 fast blocks
and 524/524 review blocks, with one registered optional-package skip and no
failures. The fast timing hint is recorded as an advisory miss.

## Record-only observation

A retained context's `.schedule_query` closure can reach the decide-stage
frame. That is outside the lookup-scoped WS20 claim and is already within the
future context-internals boundary recorded in `horizon.md` under
"Cutoff-bound context internals or a strategy sandbox"; this review opens no
new ticket.

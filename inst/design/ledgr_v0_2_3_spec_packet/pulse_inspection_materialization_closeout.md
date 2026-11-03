# Cut 10 pulse inspection materialization closeout

**Candidate:** `9a3b3f2a` for product code; `d40f0d61` includes exact-candidate
evidence. **Base:** `04fac1bf`. **Status:** awaiting independent Type 1 code
review.

## Product result

`ledgr_pulse_features()` now resolves the map once, reads each requested
feature vector once, reuses the prepared numeric cutoff and constructs its
five final columns with `tibble::new_tibble()`. It no longer parses the pulse's
ISO timestamp or sends the result through general tibble construction.

`ledgr_pulse_wide()` resolves the same prepared map itself and constructs one
row directly from aligned bar and feature vectors. It never calls
`ledgr_pulse_features()`, creates long rows or invokes a pivot. No signature,
class, value, alias, ordering, empty-axis or refusal behavior changes.

Private fixture contexts that do not supply `cutoff_num` prepare it once from
their scalar timestamp. Production P2 continues to pass the numeric packet
timestamp and performs no parse. The focused suite found and now pins a
private projection fixture that advances its timestamp between pulses.

## Evidence

The shared paired protocol is
`dev/bench/timing/protocols/cut10-pulse-inspection-1`. Its final record uses
eight alternating pairs and the exact product candidate:

| helper | base median | candidate median | ratio | bound |
| --- | ---: | ---: | ---: | ---: |
| long, 1,000 calls | 0.9436 s | 0.0762 s | 0.0808 | 0.40 |
| wide, 200 calls | 2.3469 s | 0.1476 s | 0.0629 | 0.25 |

Every slot reports the same output work string. The separate public-API
Rprofmem probe records 168,482 to 167,618 bytes per long call and 1,341,018
to 726,690 bytes per wide call. Its checker and gutted allocation record pass.

Registered LTB-0549 uses a real mapped pulse, literal long interleave and wide
radix names, counted vector reads, a hard-failing mocked long helper during
wide inspection and source-shape refusals. The eight focused feature-map,
feature-inspection, pulse-context and strategy-context files pass.

## Optimization-shape walk

The changed boundary has no row-wise or collection-growing append, `rbind`,
database call, hash, seal or provenance work. Each feature vector is retrieved
once. Final numeric payloads and names are allocated in bounded vectorized
operations. The only loops are `lapply()` over the requested feature set and
the fixed five OHLCV fields; neither grows an object or scans pulses, bars,
events or candidates. Generic pivoting was measured and rejected because the
source is already aligned to the final vectors.

## Identity and scope

Snapshot, store, run, strategy, configuration and result identity are
unchanged. There is no schema, dependency, compatibility or documentation
surface change. The accepted no-callback-cost-promise remains unchanged; the
clock is an implementation gate only.

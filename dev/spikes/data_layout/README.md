# Data Layout Probe: Dense, Ragged And Compact Tiles

Probe for the lean core skeleton brief
(`inst/design/ledgr_v0_2_3_spec_packet/lean_core_skeleton_brief.md`).
Question: how should prepared instrument x session data be stored so that
pulse reads and history windows are fast and memory stays bounded?

Three layouts hold the same values:

- **dense**: one instrument x session matrix per field.
- **ragged**: one long vector per field; each instrument stores only its
  live range, found by an offset.
- **tiles**: per block of sessions, one matrix over the instruments alive
  in that block, plus a global-row -> tile-row map.

## Reproduce

```powershell
Rscript dev/spikes/data_layout/probe.R
Rscript dev/spikes/data_layout/sharadar_lifetimes.R   # needs the private catalog
```

`probe.R` uses synthetic data and stops unless all three layouts return
identical pulse reads and history windows. `sharadar_lifetimes.R` prints
aggregates only (counts, averages, megabytes); no tickers, dates or rows.

## Results (2026-11-03, Windows, R 4.6.1, unpinned host; median us per read)

| Shape | Read | rows | dense | ragged | tiles |
| --- | --- | ---: | ---: | ---: | ---: |
| fixed basket 500 x 1260 | pulse | 500 | 1.5 | 4.1 | 2.3 |
| | history 20 | 500 | 46 | 104 | 20 |
| | history 252 | 500 | 399 | 1,343 | 395 |
| survivorship-free 10,000 x 5,000 | pulse | 3,427 | 11 | 32 | 9 |
| | history 20 | 3,399 | 258 | 855 | 212 |
| | history 252 | 3,009 | 5,008 | 8,840 | 3,985 |
| intraday 20 x 23,400 | pulse | 20 | 0.7 | 1.0 | 1.1 |
| | history 390 | 20 | 43 | 115 | 69 |

Tiles are 252 sessions long. The intraday history-390 window crosses a tile
edge, which is why tiles lose there; tile length must be chosen per run.
Synthetic memory per plane at 10,000 x 5,000: dense 382 MB, ragged 105 MB,
tiles 125 MB.

Real lifetimes, private Sharadar catalog, all 8,071 stock sessions, per plane
(one field or one feature):

| Universe | Instruments | Mean life | Alive on avg | Dense | Tiles | Ragged |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| all US stocks | 20,961 | 2,164 | 5,619 | 1,291 MB | 391 MB | 346 MB |
| ever S&P 500 members | 1,179 | 4,679 | 684 | 73 MB | 45 MB | 42 MB |

## Reading

Ragged is 2 to 4 times slower on every read because each read builds its
index vector. Tiles read as fast as dense (sometimes faster: smaller
matrices) and stay within 13% of ragged memory on the whole market. Dense is
ruled out for whole-market runs: 15 planes would need about 19 GB.

## Q2: tile orientation (`q2_orientation.R`)

Instrument-major (today) needs a transpose to return the public time x
instrument history; time-major does not. Median us, synthetic, one tile.

| Shape | Read | instrument-major + t() | time-major | instrument-major, no t() |
| --- | --- | ---: | ---: | ---: |
| fixed basket 500 | pulse | 1.2 | 1.4 | |
| | history 20 | 47 | 11 | 8 |
| | history 252 | 405 | 191 | 180 |
| whole market 3,400 alive | pulse | 10 | 14 | |
| | history 20 | 208 | 153 | 105 |
| | history 252 | 3,068 | 1,320 | 1,147 |
| intraday 20 | pulse | 0.4 | 0.4 | |
| | history 390 | 36 | 7 | 7 |

The transpose is half to four-fifths of a history read. Decided: time-major.

## Q7: current-product history reads (`q7_history_read.R`)

Real context from `ledgr_pulse_snapshot()` with an experiment, 400 sessions,
one SMA feature; `pkgload::load_all()`; median us.

| Read | 10 instruments | 500 instruments |
| --- | ---: | ---: |
| `ctx$fast` (feature vector, current pulse) | 11 | 11 |
| bar history, 5 sessions | 239 | 379 |
| bar history, 20 sessions | 252 | 368 |
| bar history, 252 sessions | 288 | 750 |
| feature history, 5 sessions | 451 | 708 |
| feature history, 20 sessions | 473 | 1,458 |
| feature history, 252 sessions | 816 | 12,580 |

Reproduce from the repository root: `Rscript dev/spikes/data_layout/q7_history_read.R`.

Not measured: tile preparation cost and peak, spilling tiles to disk, and
sweep workers sharing tiles.

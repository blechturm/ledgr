# v0.2.0.1 Batch 9 Prepared-Valuation Evidence

Status: implementation evidence in progress; paired prefix frozen before
reference retirement.

## Paired 757-pulse record

The same-source paired record was captured from package commit
`92ca84ad12f8b12b994a5654557c1e79705719c2`. That commit contains the prepared
valuation state and the temporary prior prefix-scanning reference. The
reference and prepared arms differ only at that temporary internal selector.
The provider and typed diagnostic paths are identical.

The binding raw prefix is
`dev/bench/results/v0_2_0_1_batch9_20260917T201320/`. Raw benchmark directories
remain ignored; the checksums below bind the local record used by this tracked
summary.

| File | SHA-256 |
| --- | --- |
| `environment.csv` | `797ebf870b7d9b28cda1ae69c9237442c39e718f63cbe5f8acd65ddbde8f6340` |
| `fixture.csv` | `1c30375ecee2ca9c33ceb824dc1c79f43c3644135f69f6f4f05552567eb766b9` |
| `paired_runs.csv` | `30d17bccb74927e5d686946ca40b42db9903e3626f1c581747e001400ba93590` |
| `surface_fingerprints.csv` | `d12673d61c581ad0306c472e8f80f36c967ffe75036f894e5e4b3434d1978adf` |
| `gate_summary.csv` | `747219327caaefd478989439edb533151320b4bd618a48b236b214ce63ea5c86` |
| `combined_case.csv` | `c026cd28f5debf90cc7715910bd4f9d06995050fa65e002ae0ccc12b4f292750` |

The registered shape was 563 source instruments, a 505-member axis, 757
pulses, 426,191 bars, and 30,300 membership rows. One shared sealed snapshot
fed copied stores for every arm. The clock surrounded `ledgr_run()`; fixture
construction and sealing were outside it. One warm-up preceded three measured
runs per arm. Runs were interleaved, and exactly one child ran at a time.

| Arm | Warm-up | Measured walls, seconds | Median | Spread | Maximum peak MiB |
| --- | ---: | --- | ---: | ---: | ---: |
| prior prefix scanner | 25.17 | 25.41 / 25.36 / 25.50 | 25.41 | 0.14 | 909.6 |
| prepared monotone state | 14.31 | 14.41 / 14.34 / 14.29 | 14.34 | 0.12 | 903.3 |

The prepared/current median ratio is 0.5643. The 11.07-second median
improvement is greater than the reference arm's full 0.14-second spread. Every
prepared peak is below 1,024 MiB, and the prepared maximum is below the
reference maximum rather than 15 percent above it. The measured gate passes.

Every arm completed `DONE`. For each paired repetition, the config hash and
the row counts and SHA-256 fingerprints of diagnostics, events, equity,
strategy state, and completion were identical. Each run contained 383,042
diagnostic rows, zero events, 757 equity rows, 757 strategy-state rows, and one
completion row.

The runtime was R 4.6.1 on Windows with DuckDB 1.5.2, testthat 3.3.2, and
collapse 2.1.8 resolved from the isolated collapse library. A prior
corroborating run under DuckDB 1.5.5 also passed, but it is not the binding
record because it did not use the registered release-library resolution.

## Structural proof

The focused test constructs the transient row index once and advances one
close-matrix column at a time. It checks exact work counters at three shapes,
including 563 source instruments, 505 emitted axis members, and 757 pulses:

- `row_index_builds == 1`;
- `pulse_cells_advanced == source_instruments * pulses`; and
- `axis_cells_emitted == axis_members * pulses`.

The same test covers leading, interior, and trailing gaps; never-observed and
current instruments; exact fresh, stale, and expired states; reordered axes;
repeated cutoffs; and fail-closed backward, duplicate, and unknown axes.
Focused availability-economics and availability-state suites passed under
both the reference and prepared arms before this prefix was frozen.

## Combined correction case

The bounded eventful case was run at the frozen evidence commit `5e88065`,
before reference retirement. Both arms used the same two-instrument,
four-pulse availability fold and a private event-buffer initial capacity of
two. They matched exactly on config hash, diagnostics, ledger events, equity,
strategy state, and completion.

Both arms crossed two geometric event-buffer boundaries and produced five
fills with a non-zero fixed fee. The case also exercised a complete-list
membership change, a held former member, an interior price gap at the exact
stale boundary, and a terminal-event stop. Every registered predicate is true
in `combined_case.csv`. The final durable test retains this shape against the
prepared production path, including reopen parity.

## Retirement rule

This tracked evidence prefix must be committed before the temporary reference
function and selector are removed. The later retirement commit must cite that
commit, remove the scanner and selector from installed source, and extend the
source guard. Combined eventful evidence, full verification, governance
reconciliation, and independent review remain outstanding at this point.

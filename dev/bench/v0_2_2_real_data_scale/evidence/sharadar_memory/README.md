# Sharadar memory per workload (sharadar_memory.R)

R heap at peak (gc max used since a reset) and process peak working set, one
fresh process per row, Sharadar S&P lake, aggregates only.

- `*-pre_cut*.csv`: tree a87bb7e (product equal to 1370ee0).
- `*-final*.csv` without a suffix name: tree 1df4d3f (500,000-row feature
  blocks, 65,536-row diagnostic chunks). `momentum-final-3.csv` is a clean
  rerun; the original third run was corrupted by an edit to the script while
  it ran and was discarded, as was a run under a namespace override that
  inflated the heap by itself.
- `momentum-final-chunk4096-*.csv`: 1df4d3f with the diagnostic chunk at 4,096
  (measuring commit 00b7ccf5, never on a branch).
- `momentum-final-block50k-*.csv`: 1df4d3f with the feature block at 50,000
  rows (measuring commit 62f93e2d, never on a branch).

Result: the R heap is unchanged in every variant (about 2,474 MB). The final
tree's process peak (3,412-3,486 MiB against 3,123-3,127 pre-cut) comes from
the 500,000-row feature blocks: at 50,000 rows it is 3,239-3,240 MiB at
unchanged run time, while the diagnostic chunk size does not lower it.
Explain: heap 3,935 to 2,630 MB, process peak 4,251 to 3,777 MiB.

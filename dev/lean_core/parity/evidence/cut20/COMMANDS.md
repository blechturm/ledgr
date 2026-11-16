# Cut 20 evidence: commands

From the package root, pin library `<pin>` (d5b3a151). `<dump>` is a local
directory of the pin's tables, written by the debug-off gate and read by the
reach cross-checks; it is not committed.

## LDG-3241 (ldg3241/)

| file | command |
| --- | --- |
| ldg3241/loop_gate_debug0.csv | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=0 --freeze=dev/lean_core/parity/loop_freeze.csv --out=<file>` |
| ldg3241/witness/, witness.log | `Rscript dev/lean_core/parity/hashed_frame_witness.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut20/ldg3241/witness` |
| ldg3241/reanchor/ | `Rscript dev/lean_core/parity/cut20_reanchor.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut20/ldg3241/reanchor` |
| shape7.txt | `Rscript dev/lean_core/parity/cut20_shape7.R dev/lean_core/parity/evidence/cut20/shape7.txt` |
| frame census | `Rscript dev/lean_core/parity/evidence/cut19/s3env/ebind.R 6e90a881 dev/lean_core/loop.R` (140 -> 140) |

The witness writes frame_checks.csv (part A: four fault settings by two
debug settings), adapter.csv with one log and CSV per adapter run (part B),
and semantics.csv (part C).

# LDG-3036 Ordinary Fast Record

This is the first valid ordinary fast-profile record at `c566e433` after the
locale witness was placed in its declared review profile. It ran 562 of 562
fast blocks with zero failures or skips in 108.72 seconds, below the unchanged
112-second bound. `tools/check-test-gate.R` wrote `gate-record.csv` and returned
`LEDGR_TEST_GATE_OK`.

An earlier invocation stopped before measurement because the locale block had
both a file-level fast declaration and a block-level review declaration. It
wrote no record and is not counted as a timing retry or gate result.

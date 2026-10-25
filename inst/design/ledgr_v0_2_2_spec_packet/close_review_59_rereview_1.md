# Workstream 59 focused re-review 1

Mode: focused Type 1 correction review.

Verdict: CHANGES_REQUIRED.

The six findings from the first close review were closed. The corrected R
accounting transition, documentation, detectors and records were otherwise
sound, but the independent reviewer found one remaining native-boundary defect.

The canonical R path carried each instrument's transition net. The compiled
path instead reconstructed its starting net by summing the live lots, and the
R unpacker repeated that sum between native batches. Those different
floating-point sequences produced bitwise position differences for fractional
partial closes and could change public sweep trade counts and warnings.

The correction must carry `net_by_inst` into, through and out of the compiled
batch, without resumming lots during unpack. Its detector must cover the exact
five-fill sequence BUY 0.1, BUY 0.2, SELL 0.05, SELL 0.1, SELL 0.07 in one
native batch and in successive batches, plus a public partially-closing sweep.

Record-only corrections also restore a canonical replay comparison to
LTB-0217, disclose the LTB-0019 absolute-zero oracle migration, and narrow the
LCL-0490 and LCL-0491 descriptions to the surfaces their tests exercise.

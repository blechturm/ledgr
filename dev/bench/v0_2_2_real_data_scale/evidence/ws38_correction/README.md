# Workstream 38 correction evidence

This directory records the scaled all-fill clock required by the first
Workstream 38 close review. The workload has 5,000 instruments and eight
pulses. Every instrument changes position on every pulse, so it exercises the
P4 position and cash mutation boundary at a size where an environment-held
vector would expose its copy-on-write growth.

Three alternating fresh-process pairs compare the accepted pre-extraction
tree `0d86608a` with correction `cfba0f8a`. The base
`R/fold-engine.R` blob was verified as
`45f7566a4817f2af06e80cc7c468b5b2434c4974`. Candidate/base ratios are
0.8395, 0.8390 and 0.8350; their median is 0.8390, below the 1.05 ceiling.

The committed reproducer is
`dev/bench/v0_2_2_real_data_scale/fold_phase_all_fill.R`. The paired record
used the same source-equivalent harness before the reproducer was committed;
the committed runner subsequently completed the candidate arm in 11.63
seconds.

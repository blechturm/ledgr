# WS41 correction fast-profile retry

Tree: `9c1e352e7c9dd5c9fea21b3f1cbaab18d60ee7e9`

This is the single complete retry set after the first correction record missed
the 112-second timing bound by 0.82 seconds. All 565 registered blocks execute
without failures or skips in every run. Elapsed times are 122.44, 127.21 and
142.59 seconds, for a 127.21-second median and a timing miss.

The increasing times on an unchanged tree are consistent with changing host
load; they are not used to claim a product regression or a pass. The retry is
retained beside the first record so the timing disposition is auditable.

Commands are the same as `../ws41_correction_fast/README.md`, with the records
directory changed to `ws41_correction_fast_retry`.

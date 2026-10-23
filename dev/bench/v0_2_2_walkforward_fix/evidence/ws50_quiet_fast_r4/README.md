# WS50 quiet-host fast-profile record

This is the candidate arm for the Workstream 50 timing gate. It was recorded
at commit `456f30ca` on Windows with R 4.6.1, the High Performance power plan
and process affinity `0xFFFF`. Each run executed 573 of 573 fast-profile
blocks with no failure or skip.

The three elapsed times are 113.65, 113.00 and 114.50 seconds (median 113.65
seconds). The paired pre-WS50 arm is in the sibling
`ws50_quiet_fast_r4_base` directory and measured 113.78, 114.15 and 114.36
seconds (median 114.15 seconds). The ratio of medians is 0.996.

Both arms exceed the unchanged 112-second absolute bound. This record is a
gate MISS, not a pass: it shows no WS50 regression, while demonstrating that
the fast lane itself has exhausted its headroom. LTB-0471 through LTB-0473
are assigned to the review profile because each is a multi-run integration
detector; their cheaper unit witnesses remain in the ordinary lanes. The
remaining lane-capacity problem is routed to macro-plan WS8.

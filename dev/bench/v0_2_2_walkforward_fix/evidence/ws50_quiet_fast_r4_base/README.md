# WS50 quiet-host fast-profile baseline

This is the pre-fix arm paired with `ws50_quiet_fast_r4`. It was recorded at
Cut 17 integration commit `2378606f`, before the LDG-3091 implementation
commits, using Windows, R 4.6.1, the High Performance power plan and process
affinity `0xFFFF`. Each run executed 573 of 573 fast-profile blocks with no
failure or skip.

The elapsed times are 113.78, 114.15 and 114.36 seconds (median 114.15
seconds). This arm also exceeds the unchanged 112-second bound. It is retained
to distinguish exhausted lane headroom from a candidate regression.

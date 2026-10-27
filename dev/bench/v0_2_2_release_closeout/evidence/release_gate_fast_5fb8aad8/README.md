# v0.2.2 final fast-profile record

Candidate: `5fb8aad8dc8d0fcc1bb3f6c3a86266c334dbc585`.

The three sequential Windows 11 / R 4.6.1 runs used the High performance
power plan and inherited the registered P-core affinity mask `0xFFFF`.
Every run executed 577 of 577 blocks without a failure or skip. Times were
114.68, 116.00 and 115.11 seconds; the median 115.11 seconds exceeds the
unchanged 112-second gate. This is a timing miss, not a pass.


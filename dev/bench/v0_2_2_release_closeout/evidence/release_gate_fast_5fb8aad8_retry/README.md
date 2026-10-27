# v0.2.2 quiet-host fast-profile retry

Candidate: `5fb8aad8dc8d0fcc1bb3f6c3a86266c334dbc585`.

The three sequential Windows 11 / R 4.6.1 runs used the High performance
power plan and inherited the registered P-core affinity mask `0xFFFF`.
Sampled background CPU was 3 to 10 percent. Every run executed 577 of 577
blocks without a failure or skip. Times were 114.98, 113.35 and 113.17
seconds; the median 113.35 seconds exceeds the unchanged 112-second gate by
1.35 seconds. This is the final local timing record. The maintainer accepted
the miss as a release-specific host-timing exception on 2026-10-27; it remains
a miss rather than a pass, and neither the threshold nor profile changed.

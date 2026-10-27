# v0.2.2 release-scale long-window record

Accepted arm: `0ffaaa0f5c9b913a45b09c935f7110f3c6d11396`.
Candidate arm: `5fb8aad8dc8d0fcc1bb3f6c3a86266c334dbc585`.

The suite ran one alternating pair for the EXP-0003-scale and walk-forward
release shapes under the registered High performance / P-core host boundary.
`check_record.R` and its corruption self-test passed. The candidate-to-
accepted ratios are 0.9944 cold and 1.0170 warm for EXP-0003, and 1.0138 cold
and 0.9580 warm for walk-forward. Peak RSS was 5,144,211,456 and 858,382,336
bytes respectively. Native identities and economic values are exact under
the cross-version comparison rules recorded by LDG-3121. Clocks and peak RSS
are workload-specific characterization.


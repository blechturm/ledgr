# v0.2.2 ordinary long-window release record

Accepted arm: `0ffaaa0f5c9b913a45b09c935f7110f3c6d11396`.
Candidate arm: `5fb8aad8dc8d0fcc1bb3f6c3a86266c334dbc585`.

The suite ran five alternating pairs for availability sweep, feature gaps
and terminal fact churn under the registered High performance / P-core host
boundary. `check_record.R` and its corruption self-test passed. All six
candidate-to-accepted cold and warm median ratios are at most 1.0602, below
the 1.10 gate. Native identities and economic values are exact under the
cross-version comparison rules recorded by LDG-3121. Clocks are
characterization only.

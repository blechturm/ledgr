# W18 Fixture: Cached Positional State Across Membership Change

- Witness: `W18`; class: `representation_discriminating`; policy v4.
- Purpose: a membership change reorders the pulse-local public axis.
  Strategy state keyed by stable asset ID stays correct; a checked accessor
  or axis-bound token rejects a stale positional reference; a raw integer
  retained by user code is documented as unsafe and not certified.
- Cases: `c1` stable-ID state; `c2` stale axis token; `c3` raw integer.

## Assets And Aliases

| stable_id | alias |
| --- | --- |
| A01 | AAA |
| A02 | BBB |
| A03 | CCC |

## Calendar (venue XSYN closes at 21:00:00Z)

S1 2024-01-02, S2 2024-01-03.

## Membership Facts (universe `inv`, declared order A01, A02, A03)

| asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- |
| A01 | 2023-12-01T00:00:00Z | 2024-01-03T00:00:00Z | 2024-01-02T22:00:00Z |
| A02 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| A03 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |

All three listed and active; flat bars (A01 100, A02 50, A03 20) at S1 and
S2. No positions; cash 100000.00; no intents.

## Axis Per Pulse

| pulse | public axis (target-vector order) | idx(A02) | idx(A03) | axis token |
| --- | --- | --- | --- | --- |
| S1 | A01, A02, A03 | 2 | 3 | axis_S1 |
| S2 | A02, A03 | 1 | 2 | axis_S2 |

## Strategy State

At the S1 decision the strategy writes `asset_state["A02"] = 42` (keyed by
stable ID) and, in `c3`, also retains the raw integer 2 outside the declared
`asset_state` map.

## Derivations

- `c1`: at S2 `asset_state["A02"]` reads 42; `idx("A02")` is 1; the entry
  survives because A02 is still a member.
- `c2`: at S2 the strategy presents token `axis_S1` with position 2; the
  checked accessor rejects it with `stale_axis_token` because the token is
  bound to the S1 axis.
- `c3`: the raw integer 2 indexes the S2 axis and refers to A03; nothing in
  the certified contract can detect this; the report documents the unsafe
  pattern.

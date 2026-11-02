# Response Review: Context Frame Retirement

- Status: Response accepted after corrections; maintainer decisions and seed v2 are next
- Reviewer: Codex (original seed author)
- Date: 2026-11-03
- Mode: RFC stage 4 response review
- Response reviewed: `rfc_context_frame_retirement_v0_2_3_response.md`
- Baseline checked: `e3bb4cec` (`release/v0.2.3`)

## Verdict

**ACCEPT_AFTER_CORRECTIONS.** The response improves the seed. It preserves the
actual architecture--retire the four frame/bar surfaces, keep the flat context
as the strategy surface, manifest inspection frames only on demand, and perform
no hashing or sealing downstream of the trusted context boundary--while
removing an unnecessary export.

The response's current-tree findings are materially correct. Its two
maintainer recommendations are also the smallest coherent choices:

1. add no `ledgr_pulse_bars()` helper; and
2. keep `ledgr_pulse_features()` and `ledgr_pulse_wide()` as inspection
   boundaries without a decision-time performance promise.

The corrections below constrain seed v2. They do not reopen the architecture.

## Independent checks

I read the response against the current implementations of P2, the strict
context, pulse snapshot construction, feature inspection and the prepared
resolver. I also reran the response probe in a disposable worktree at
`e3bb4cec`, compiled independently of the response author's checkout.

The behavioral observations reproduced:

- runtime and experiment-form contexts expose engine IDs through the
  inspection helpers even when the prepared resolver has active aliases;
- snapshot-and-universe inspection alone adds the alias-map metadata and uses
  aliases;
- unmapped and mapped long output use different row-order rules;
- a real empty decision axis returns typed empty output without a map and
  refuses the same registered feature when a map is supplied;
- a retained in-process context remains pulse-frozen after the run; and
- `gap_type == "MISSING_EXPECTED_SESSION"` is exactly the current
  `is.na(ctx$close)` mask in the exercised context, while `is_synthetic` is
  uniformly false.

The timing order also reproduced. On the response's 600-instrument,
three-feature fixture, medians were 409.85 microseconds for the isolated
current frame block and 1.70 microseconds for constructing the primitive
binding list. The flat three-feature matrix took 163.75 microseconds.
Inspection calls took about 0.21 seconds for the long active-map view and 0.85
seconds for the wide view. These are descriptive one-host measurements, not a
gate or a whole-P2 speedup claim.

## Corrections for seed v2

### R1. Seed v2 is required

Response line 28 calls seed v2 optional. It is not optional here. The response
removes the seed's only proposed export, changes the contract status of two
existing helpers, names three visible behavior corrections and changes the
migration plan. Absorbing that directly into synthesis would leave the seed's
architectural statement knowingly stale. Write seed v2 before synthesis.

### R2. Qualify the retained-context guarantee

The response says the inspection helpers work on a "saved" context. The probe
retained an in-process R object; it did not serialize, persist or reopen one.
Seed v2 must say **retained in-process pulse-frozen context** and must not imply
a durable or serialization contract. This preserves the accepted frozen-view
rule without inventing persistence.

### R3. Name the metadata deletion exactly

F3 correctly rejects the snapshot-and-universe-only alias route. Seed v2 must
state explicitly that `feature_params`, `active_alias_map`, `alias_map_json`,
`alias_map_hash` and `alias_map_version` cease to be fields on the returned
pulse context. `feature_params` remains an input to validation and resolution;
the prepared resolver remains the single alias source. No contract currently
makes those five context fields public, and no production reader consumes
them. This is what makes `names()` parity across the three context entrances a
detectable claim.

### R4. Keep the private constructor seam honest

F9 may be accepted only as a named test-fixture adapter, not as compatibility
for the retired runtime representation. The private constructor may accept
bar and feature frames as fixture input, validate and normalize them once into
the same aligned primitive lookup used by real contexts, and then discard the
frames. P2 must not call this adapter, and the resulting context must not store
or lazily rebuild the retired fields. Tests whose subject is the inspection
helpers must use a real run or pulse-inspection context.

### R5. Own the feature-name frequency defect in WS6

F10 identifies run-constant feature names being recomputed on every `$` read.
The flat benchmark migration would exercise that cost once per feature and per
pulse. The WS6 cut must prepare the readable feature-name set once with the
resolver and reuse it; this is part of completing the flat migration, not a
separate architecture question. The cut must detect restoration of the
per-read recomputation structurally. Descriptive clocks may accompany it, but
macro-plan rule 16 still forbids a broad timing gate.

### R6. Preserve the response probe before relying on its numbers

The old October probe no longer runs on the current tree. The response's
replacement probe currently lives in an ephemeral session directory. Before
seed v2 cites E1-E7 as reproducible evidence, preserve the runnable script
under `dev/spikes/ctx_frame_views/`, with its baseline, command and environment
at the top. Its timings remain descriptive. The seed and later ticket evidence
must distinguish the isolated 409.85-to-1.70-microsecond comparison from a
whole-P2 or whole-run speedup.

## Adjudication of the response

| Response item | Review disposition |
| --- | --- |
| F1, no demonstrated need for `ledgr_pulse_bars()` | Accept. Flat columns already supply the information strategies receive. |
| F2, inspection rather than callback-performance contract | Accept. Rebuild mechanically without the seven forbidden shapes, but add no hot-path promise. |
| F3, prepared resolver is the sole alias source | Accept with R3's exact metadata boundary. |
| F4, Daxis order for mapped and unmapped long output | Accept as the coherent inspection order. |
| F5, validate maps against registered features before manifesting an empty axis | Accept. Unknown IDs still refuse; known IDs yield typed empty output. |
| F6-F7, primitive P2 binding and frozen cutoff/axis | Accept with R2 and the numeric cutoff retained privately. |
| F8, October probe is historical | Accept; R6 supplies current runnable evidence. |
| F9, preserve frame-shaped fixture input | Accept only under R4's test-fixture contract. |
| F10, migrate the benchmark without re-recording the frozen oracle | Accept; source identity is the named exclusion, and R5 owns the exposed read-frequency defect. |
| F11, no `features_wide` successor | Accept. Teach ordinary named-column assembly as an idiom, not another API. |
| F12, trust boundary and mechanical deletion list | Accept. |

## Decisions and next stage

The review recommends M1(a) and M2(a), but the maintainer remains the decision
owner. Once those two choices are recorded, Codex writes seed v2 incorporating
R1-R6 and the accepted response findings. Synthesis follows under the normal
role rotation; no ticket cut or implementation begins from this review.

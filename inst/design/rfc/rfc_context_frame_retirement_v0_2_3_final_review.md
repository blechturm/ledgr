# Type 1 Final Review: Context Frame Retirement

- Status: PASS_AFTER_PATCHES
- Reviewer: Codex, author of seed v2 but not the synthesis
- Date: 2026-11-03
- Mode: Type 1 final review; verification, not design
- Synthesis: `rfc_context_frame_retirement_v0_2_3_synthesis.md`
- Baseline checked: `e3bb4cec` on `release/v0.2.3`

## 1. Verdict

**PASS_AFTER_PATCHES.** The synthesis faithfully adopts seed v2 D1 to D10,
the Type 2 response, the response review and the maintainer's decisions M1(a)
and M2(a). Its central architecture matches the current code:

- ordinary strategies already have flat pulse-frozen columns;
- P2 still constructs the four redundant frame/bar surfaces;
- the two inspection helpers are the remaining explicit frame boundaries;
- only snapshot-and-universe inspection injects the five alias metadata fields;
- the old frame-view helpers are gone; and
- the internal fixture constructor is used by tests, not by production P2.

One wording patch is required. It narrows a contract deletion to the obsolete
sentences the synthesis intends to retire. It does not reopen design or require
a maintainer decision.

**The inputs are right.** I checked the current code and contracts rather than
relying on the response's conclusions, and ran the durable probe against a
disposable worktree at the stated baseline. The probe now executes E0 itself.
The helper timings remain descriptive, as the synthesis requires. No issue
returns `NEEDS_TYPE_2`.

## 2. Required Patch

### P1. Preserve the valid half of the feature-resolution contract bullet

Correction C1 and the Section 6 table say to delete "the bundled-accessor memo
bullet" from Feature Resolution. There is no standalone memo bullet.
`contracts.md:2415-2426` is one bullet containing two different rules:

1. lines 2415-2422 bind valid run-local prepared-state ownership, pulse/axis
   enforcement, prepared indexes and candidate isolation; and
2. lines 2422-2426 describe the obsolete last-explicit-map memo.

Deleting the bullet literally would also delete the prepared-state guarantees
that the synthesis retains and extends in B4, B6 and B9.

**Patch:** in C1 and the Section 6 Feature Resolution row, replace "delete the
bundled-accessor memo bullet" with "delete only the final memo sentences from
the existing prepared-state bullet (`contracts.md:2422-2426`); retain its
decision-time, pulse/axis, run-local preparation and candidate-isolation
guarantees (`contracts.md:2415-2422`)." Add the same clarification to the
revision history.

## 3. Evidence Checked

The durable probe completed successfully at `e3bb4cec` and reported:

| Check | Result |
| --- | --- |
| E0 old frame-view helpers | both absent; the two current helpers present |
| P2 frame construction | about 423 microseconds per pulse at the probe shape |
| primitive binding | about 1.8 microseconds per pulse |
| on-demand bars frame | about 487 microseconds |
| flat feature matrix | about 171 microseconds |
| `ledgr_pulse_features()` | about 60-223 milliseconds, depending on map form |
| `ledgr_pulse_wide()` | about 850 milliseconds |

The exact clocks are host observations, not gates. They support the synthesis's
scope: frame retirement is primarily a surface and ownership cleanup; the
inspection helpers make no callback-grade performance promise.

I also verified:

- `ledgr_pulse_context_available_fields()` currently rebuilds readable feature
  names on reads, so B9 has a real implementation seam;
- `ledgr_pulse_snapshot()` adds exactly the five D5 metadata fields after
  constructing the ordinary context;
- only `active_alias_map` is consumed by current inspection code, and B4 moves
  that responsibility to the prepared resolver;
- the current bundle accessor has no production caller and no surviving memo;
- the direct stale-name census must use exact field patterns because a plain
  `ctx$bars` search also matches `ctx$bars_since_entry` and
  `ctx$bars_since_exit`; and
- the contracts and internal manuals named by C2 and C4 contain the stale
  surfaces the cut must update.

## 4. Clean Findings

- The synthesis does not add a bars helper, frame DSL, compatibility alias,
  durable context, hash or seal.
- It distinguishes changed inspection semantics from unchanged execution and
  accounting semantics.
- Empty-axis, alias-source and row-order changes are explicitly gated.
- The fixture adapter is narrowly retained for the existing test setup and is
  forbidden from production P2.
- The peer oracle remains frozen; only strategy/config source identity is
  excluded from byte parity.
- The response probe is descriptive, while ticket tests own the
  failure-sensitive absence assertions.
- No future obligation is silently closed: external-helper preflight and
  historical multi-feature panels remain with their existing owners.

## 5. Acceptance

After P1 is applied in place with a revision note, the synthesis is ready for
maintainer acceptance. Acceptance should move the RFC index row to
`Obligations open`, add the decisions bridge, and route one WS6 implementation
cut with the Section 7 detecting evidence. No implementation or ticket cut
should begin before that acceptance.

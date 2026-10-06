# Synthesis: Terminal Outcomes and Frozen Holdings for v0.2.2

**Status:** Accepted by the maintainer on 2026-10-05 after Type 1 final review
returned `PASS_AFTER_PATCHES` and both patches were applied. Binding for the
v0.2.2 terminal-outcomes ticket cut.
**Consolidated:** 2026-10-05 by LDG-2961 into the standing sections of
`contracts.md`; `ledgr_v0_2_2_spec_packet/terminal_outcomes_reconciliation.md`
maps each rule to its section, ticket and block. This file keeps the reasons.
**Author/date:** Codex, 2026-10-04. Codex wrote the Type 2 response, not either
seed. Claude wrote seed v1 and seed v2.
**Inputs:** seed v1, the Type 2 response, seed v2, the executed probes and
census, the terminal-outcome prior-art review, `contracts.md`, and the current
package implementation.
## 1. Verdict

Accept seed v2's separation of terminal disposition from valuation-horizon
exhaustion, with the corrections and decisions below. Do not write seed v3.

The resulting product has two explicit models:

1. a sealed terminal fact may cause a declared, assumption-backed
   `DISPOSITION`; and
2. an unresolved valuation gap may carry the position and its last observed
   mark without creating cash or changing quantity.

That is the smallest design that keeps broad-universe runs usable without
turning missing data, a halt, or illiquidity into a fictional sale. Evidence
always outranks either model. Strict refusal remains available.

## 2. What the evidence establishes, and what it does not

The public-API freeze probe establishes that ledgr already carries a held
position at `stale_close` inside the declared horizon, refuses fills while the
bar is absent, and realizes the actual move when a persistent target meets a
resumption bar. It does not establish that carrying the same mark indefinitely
is economically correct. Beyond the horizon, carrying is an explicit valuation
assumption and must be named as such.

The gap census establishes that the reference Sharadar data encodes many
untraded sessions as zero-volume carried bars rather than missing bars. Current
ledgr therefore neither ages the mark nor prevents fills on those rows. The
freeze design does not repair that input by itself.

The census's 118 delisted instruments with long terminal carried-price runs do
not establish that every such instrument was worthless. The vendor reasons
include acquisitions, voluntary delistings, regulatory delistings and
bankruptcy. A zero outcome can still be the conservative research default,
but it is a declared model, not a fact inferred from the count.

Seed v2 also overstates metric correctness. Cash, quantity and ledger
accounting remain exact under the declared model. Equity during a freeze is an
estimate. Endpoint total return converges once every freeze resolves; Sharpe,
volatility, drawdown and every other path-dependent statistic may remain
distorted because the price move was booked on the resumption date.

## 3. Bound design

### 3.1 Distinct triggers

A terminal disposition is eligible only when all of the following hold:

- a held instrument has a sealed `known_inactive` lifetime row;
- `terminal_event` is nonempty;
- no supported settlement fact already resolves the event; and
- the declared terminal policy does not refuse it.

An empty terminal label is not silently normalized to a reason. It remains an
unsupported terminal and produces a typed `INCOMPLETE` stop.

Valuation-horizon exhaustion is different. It means the last observed mark is
older than `max_sessions`; it proves no economic event. It never creates a
fill, a disposition, cash or a quantity change.

### 3.2 Terminal policy

Extend `ledgr_corporate_actions()`; do not add a parallel untradable policy.
`held_terminal_position` accepts one fallback choice or an exact-label map with
a required `default` entry:

- `last_permissible` (research default): dispose at the mark permissible at
  the terminal pulse;
- `last_mark`: explicit unbounded last-observation assumption;
- `haircut`: dispose at `(1 - fraction) * permissible_mark`, with one declared
  finite fraction in `[0, 1]`;
- `write_off`: dispose for zero proceeds; or
- `refuse`: stop `INCOMPLETE` with the accepted prefix.

Keys other than `default` match exact sealed `terminal_event` values. ledgr
does not interpret vendor synonyms. Mapping order, labels, choice, haircut and
defaults enter identity. Existing choices receive `v002` identities because
their trigger widens from corporate-action rows to lifetime terminal facts;
`v001` retains its existing meaning. The policy object and stored identity
advance from `policy_schema_version = 1` to version 2; schema-1 artifacts are
not silently reinterpreted.

Evidence-backed settlement runs first. A modeled outcome posts one
`DISPOSITION` at the effective pulse before the strategy decision. It is not a
fill. If the chosen rule requires a qualifying mark and none exists, the run
stops `INCOMPLETE` under a new typed no-mark reason; it must not abort.

**[Amended by the maintainer 2026-10-05 after the Workstream 14 close review
returned `NEEDS_TYPE_2`.]** A scheduled corporate-action disposition is
evidence, not a modeled loss. It disposes at the evidenced mark: the
permissible mark, or the frozen last close when the holding is frozen. Only an
explicit `last_mark` default, which uses the last observed close of any age,
and `refuse` change that. `haircut`, `write_off` and
`frozen_terminal_position` apply only to terminals without settlement
evidence. A scheduled row is a precedence barrier: if its settlement is
refused or has no usable mark, the run stops with a typed reason and the
lifetime path does not dispose that holding on that pulse. Reason: the
reference Sharadar adapter emits no scheduled rows today, but about 6,000 of
its delistings are cash or stock acquisitions, and applying a declared loss
default to them would book zero or discounted proceeds for deals that paid
shareholders. This keeps seed v2's evidence boundary and the
equity-settlement rule that a cash acquisition is a disposition at mark.

### 3.3 Horizon policy and the meaning of `max_sessions`

`ledgr_valuation_stale()` gains
`exhausted = c("freeze", "refuse")`, defaulting to `"freeze"`. No default
`max_sessions` is introduced. The valuation-policy object and stored identity
advance from `schema_version = 1` to version 2; the new field is invalid under
the old schema.

`max_sessions` remains the last age at which ledgr calls a carried mark
permissible. Under `exhausted = "freeze"`, crossing it changes the holding from
ordinary stale valuation to an explicitly assumption-backed frozen valuation:

- quantity and cash are unchanged;
- `reference` remains the risk mark;
- `mark_source` becomes `frozen_close`, and age continues increasing;
- the holding is target-restricted and is not returned by `ctx$tradable()`;
- explicit zero targets may continue to attempt an exit, but no order is
  queued and no fill occurs without an execution bar; and
- the next traded bar restores `current_close`; a persistent target may then
  fill at that bar's execution price.

Freezing applies only when no effective `known_inactive` lifetime fact covers
the holding. Labeled inactive holdings follow Sections 3.2 and 3.4; unlabeled
ones take the Section 3.1 stop. ledgr never carries a security it knows has
ended merely because its last mark also crossed the valuation horizon.

Under `exhausted = "refuse"`, the existing typed horizon stop remains. No
frozen state occurred, so frozen-exposure fields remain zero; the completion
record shows the affected IDs, age and last reference instead.

Freeze entry and exit are persisted diagnostics, not accounting events. Resume
and replay derive the same state from sealed bars, facts and policy identity.

### 3.4 Terminal while frozen

**[Accepted by the maintainer 2026-10-05; see the final review.]** Add
`frozen_terminal_position = c("write_off", "last_mark", "refuse")` to the
same corporate-action policy, defaulting to `"write_off"` in the research
preset and `"refuse"` in the strict preset.

This field is consulted only when the exact-label terminal choice requires a
currently permissible mark and the holding is already frozen. An explicit
label choice of `write_off`, `last_mark` or `refuse` still wins directly.
`write_off` is selected as a conservative, usable default, not as an assertion
that every delisted security is worthless. It is shown as **default: assumed
worthless** in results and enters identity. A supported settlement fact still
pre-empts it, and a frozen holding settled by a scheduled row disposes at its
frozen last close rather than through this fallback (section 3.2 amendment).

`haircut` is not offered as the frozen fallback in this release: without a
permissible mark its basis would silently change from the policy defined in
Section 3.2. A user may choose the explicit `last_mark` model instead.

### 3.5 Strategy and sizing behavior

Frozen holdings remain on the decision axis and remain visible through the
position and valuation planes. They are not eligible for new allocation.

The existing helper contract supplies the right behavior when frozen is
represented as target-restricted: `ledgr_target_rebalance()` preserves held
ineligible quantities and reserves their absolute marked exposure before
applying weights (`R/strategy-helpers.R:341-404`). Bind that behavior. Reported
equity includes the frozen value, but helper allocation cannot spend it a
second time. No second equity basis or excluding-size option is added now.

Hand-written targets may hold the quantity or request zero, matching the
existing restricted-target rule (`R/availability-economics.R:153-177`). A zero
target is an attempted exit, not proof of execution.

## 4. Results, warnings and metrics

Terminal outcomes extend the existing corporate-action summary and
`corporate_action_fidelity`. They report choice, exact matched label, modeled
proceeds, and whether the choice was default or explicitly declared. Do not
create a competing terminal-provenance headline.

Every ordinary result surface gains one valuation headline: current, stale, or
frozen, including affected count, longest age, maximum frozen exposure and
frozen-at-end count and value. `print()` and `summary()` put an unavoidable
warning before metrics whenever a run used an assumed terminal outcome or
entered frozen valuation.

Reject seed v2's unevidenced 5% escalation threshold. There is one warning
rule, not a severity boundary that suggests validation. A frozen-at-end value
is always named explicitly. Structured fields, rather than display severity,
let downstream users choose their own materiality rule.

Required structured fields are stale and frozen instrument-sessions, maximum
frozen gross value and equity weight, longest freeze, frozen-at-end count,
value and weight, and `total_return_if_frozen_worthless`. For the long-only
scope of this release, the last field subtracts frozen-at-end marked value from
final equity before computing endpoint return. It is a bound, not a corrected
Sharpe, drawdown or return path.

Run lists, comparison tables, sweeps, sweep review, walk-forward results and
experiment plans expose the same compact flags. They need not repeat the full
summary.

## 5. Selection and incomplete runs

Every selection surface reports attempted, done, incomplete and failed counts.
Incomplete IDs and typed completion reasons stay inspectable. A named
incomplete run remains non-comparable rather than exposing prefix metrics as a
full result.

Frozen `DONE` runs remain eligible under their declared valuation model. Their
freeze fields travel with ranking output so the assumption cannot disappear.
Effective-trial and DSR mathematics remain unchanged on completed comparable
panels. Attempted and excluded counts are disclosure only; incomplete prefixes
never become trials or return columns.

## 6. Release sequence and boundary

Implementation has two independently owned parts:

1. ledgr implements terminal policy, freeze state, accounting, persistence,
   results and selection visibility; and
2. the reference Sharadar preparation path resolves LFB-027 so untraded
   carried rows cannot be filled and contribute honest valuation age.

The package work may be implemented first against vendor-neutral missing-bar
fixtures. v0.2.2 may not claim that the reference Sharadar workflow handles
halts or untraded carried prices until the upstream decision and an end-to-end
record have landed. The release gate owns that cross-repository prerequisite;
this RFC does not dictate whether the adapter emits missing rows or a canonical
untraded flag.

## 7. Failure-sensitive evidence

One gate should cover these cases without a second registry:

1. supported settlement evidence pre-empts every modeled terminal choice;
2. default, exact-label override, haircut arithmetic, write-off and strict
   refusal each change the terminal outcome and identity as declared;
3. no qualifying mark produces a typed `INCOMPLETE` prefix, never an abort;
   an unlabeled `known_inactive` holding also stops and never freezes;
4. freeze entry, continuation, persistent resumption and one-shot non-queueing
   reproduce the public probe with exact cash, quantity and mark sources;
5. a frozen holding is visible, target-restricted, preserved and reserved by
   the ordinary rebalance helper;
6. a terminal while frozen exercises the declared frozen fallback, with
   evidence still taking precedence;
7. memory, durable reopen and resume agree on events, equity, diagnostics and
   summary fields; and
8. result and selection surfaces retain attempted/excluded counts while DSR's
   numerical inputs remain completed panels only.

Each case needs a mutation that breaks its economic rule, not only a source
pin or a timing threshold. The separate Sharadar integration record must show
that a carried zero-volume row cannot fill and ages valuation under the chosen
adapter contract.

## 8. Rejected alternatives

- **One disposition policy for terminals and gaps:** rejected because a gap is
  not evidence of a sale.
- **Fail closed by default after the horizon:** rejected because broad-market
  runs become unusable and the package already has a non-transactional carry
  model.
- **Silent indefinite carry:** rejected because it disguises model risk and
  flatters path metrics.
- **A second public untradable policy or provenance headline:** rejected as
  duplicate authority.
- **A universal 5% warning boundary:** rejected as false precision.
- **Treat incomplete attempts as effective trials:** rejected because no full
  comparable return panel exists.
- **Interpret terminal reason synonyms in ledgr:** rejected; normalization is
  adapter and preparation work.
- **Queue one-shot exits:** outside this RFC; execution-intent D9 retains it.

## 9. Deferred work

OTC continuation, shorts and leverage, exact-quantity settlement,
stale-robust statistics, assumption sweeps, fair-value models and a default
stale horizon remain outside this release. Existing pipeline owners remain
authoritative; this synthesis creates no replacement obligation for them.

The adapter's exact reason pass-through is useful follow-up work but is not a
precondition for the generic `"delisting"` fallback. It belongs to the
research-side feedback route.

## 10. Response adjudication

F1's diagnosis stands. Seed v2 supplies the missing continuation model, so the
response's fail-closed remedy is superseded. F2 through F5 and D1 through D6
are accepted with the distinctions above. The synthesis adds no second policy,
reason taxonomy, DSR input or terminal headline.

Seed v2's D-T1 recommendation was accepted by the maintainer as recorded in
Section 3.4. Its 5% banner threshold is rejected. Its rebalancing and sizing
questions are resolved by the existing reserved-exposure contract. Its
release-order question becomes the claim gate in Section 6.

## 11. Final review

Claude's Type 1 final review returned `PASS_AFTER_PATCHES`. It independently
verified the evidence boundary, policy home and ordering, existing helper
behavior, DSR boundary and failure sensitivity. P1 now excludes effective
`known_inactive` holdings from freezing; P2 binds both policy schemas to
version 2. Section 3.4 was accepted by the maintainer on 2026-10-05. No further
design or review round is required before acceptance and ticket cut.

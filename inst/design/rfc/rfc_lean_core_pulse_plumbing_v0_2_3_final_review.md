# Lean Core Pulse Plumbing: Type 1 Final Review

**Verdict: PASS_AFTER_PATCHES**

- Mode: Type 1 final review, RFC cycle stage 8. Verification, not design.
  Independent Claude session, 2026-11-06. Brief drafted by Claude (a seed v2
  co-author) and approved by the maintainer. This session wrote none of the
  seed, response, response review or synthesis.
- Reviewed head: `33fc56eb` on `release/v0.2.3`. The synthesis cites
  `ef8be540`; between the two only `inst/design/rfc/README.md:113` and the
  synthesis changed, and `git diff d5b3a151 ef8be540 -- R src tests` is
  empty, so every code citation holds at the pin and at this head.
- Evidence used: the enclosing R code at each cited line; the spike READMEs,
  runners and evidence CSVs; a read-only probe and a median recomputation
  (scratchpad `final_review/probe.R`, `medians.R` and their `.out` files);
  the uncommitted `lean_core_interface.md`, read only.
- Aliases follow the synthesis: **S** = the synthesis; **V2** = seed v2;
  **RR** = response review; **C**, **K**, **L**, **T**, **A**, **X**, **M**,
  **FP** as in S:7-8; **OH** = `R/output-handler.R`; **FE** =
  `R/fold-engine.R`. S quotes some phrases with typographic quotes; patches
  below name those phrases in plain quotes.

The synthesis implements D1-D8 faithfully. Its three corrections of V2 hold:
compact fills must carry P3's effects (C:198-200, C:531-536); the P5 finite
check is a contracted refusal (C:749-755) and the P5 equality abort raises a
documented public class; `execution_mode` is in the config hash
(`R/backtest-config.R:155,188`; `R/config-hash.R:28-61`; reproduced by
probe). The Section 2 audit is accurate, including "1,196 is unsupported",
22 diagnostic columns and 4-6 us stage calls. Nothing opens design beyond
D1-D8, so this is not NEEDS_TYPE_2. S is 450 lines, within its cap; it keeps
open questions and future obligations apart and records rejections one line
each.

The findings concern the retained-refusal list, two write-path facts that
touch refusal and identity behavior, the governance triangle, and the reach
of some installation texts.

## Findings

### 1. R3 and LR-14 omit the contracted P3 reconciliation stop

**Claim.** S:28-35 grounds the P5 equality refusal in C:1428, and R3 (S:116)
lists "P5 cash reconciliation". The contracted
`affordability_reconciliation_failed` behavior is a stop that finalizes
INCOMPLETE (C:1459; C:1534-1537), and the code implements it at P3.

**Evidence.** FE:1178-1203 (P3 compares `cash + sum(cash_delta)` with the
virtual ledger and returns an INCOMPLETE stop result). FE:1555-1566 (P5
compares the scanned cash and aborts with
`ledgr_affordability_reconciliation_failed`, a FAILED path; the class is
documented at `R/condition-reference.R:186-188`). FE:1584 with FE:110-129 is
the `ledgr_config_non_finite` check that C:749-755 names.

**Consequence.** Keeping the P5 abort is defensible under D3, but the cited
authority is the wrong one, and the P3 stop, which compares two ledgr
computations and so reads like an internal re-check under R1, is on neither
R3's list nor the ledger. A family implementer could drop a contracted stop.

**Patch (S:30-33).** Replace "The latter is `ledgr_config_non_finite`,
expressly retained by **Fill And Lot Validity** (C:749), not
`ledgr_affordability_reconciliation_failed`. **Affordability And Reason
Codes** (C:1428) also binds reconciliation." with "The latter is
`ledgr_config_non_finite`, expressly retained by **Fill And Lot Validity**
(C:749). The contracted `affordability_reconciliation_failed` stop
(**Affordability And Reason Codes**, C:1428, C:1459) is P3's INCOMPLETE stop
(`R/fold-engine.R:1178-1203`); the P5 equality abort raises the documented
class (`R/condition-reference.R:186`). D3 retains all three."

**Patch (S:116).** Replace "terminal/settlement refusals, P5 cash
reconciliation" with "terminal/settlement refusals, the P3 affordability
reconciliation stop, P5 cash reconciliation".

**Patch (S:244, LR-14).** Replace "P5 cash equality and finite
reconciliation values retain their production refusals" with "The P3
affordability reconciliation stop, P5 cash equality and finite
reconciliation values retain their production stop and refusals"; replace
"R/fold-engine.R:110,1555,1584" with "R/fold-engine.R:110,1178,1555,1584".

### 2. The capacity rule does not describe today's per-sink counting

**Claim.** S:268 says "Chunk recycling must not reset the logical count used
by the limit"; R3 (S:118) places event capacity "at P5". Section 5 claims
consistency with today's paths.

**Evidence.** The limit is pulses x instruments (FE:1750-1751; OH:480-497).
The durable buffer holds only fills, resets its count at each checkpoint
flush (OH:673-686, called at FE:1651-1656), and P1 non-fill rows bypass it
(OH:666-671). The memory buffer counts every row, so its P1 appends and
compiled batches can refuse before P5 (OH:699-705, OH:734-737). The refusal
is `R/fold-event-buffer.R:15-19`.

**Consequence.** One write path must pick one counted population; counting
P1 rows durably, or cumulatively, could add refusals that durable runs do
not raise today. The text makes that behavior choice implicitly.

**Patch (S:268).** Replace "Chunk recycling must not reset the logical count
used by the limit." with "Chunk recycling must not change which rows count
toward the limit. Today durable counts buffered fills since its last flush
(`R/output-handler.R:673-686`) and memory counts every row, refusing P1 and
compiled appends before P5 (`:699-705`, `:734-737`); the one-path counted
population is a spec-cut choice, and any refusal difference is a ledger row."

**Patch (S:118).** Replace "event-buffer logical capacity at P5" with
"event-buffer capacity at its existing refusal points (fills at P5)".

**Patch (S:433).** After "maximum pulse reservation" insert ", the
event-capacity counted population (Section 5)".

### 3. `checkpoint_every` is an existing flush control in the config hash

**Claim.** R7 drains "by a fixed row bound" (S:154); Q4 (S:307-308) lists
the identities that stay unchanged. Neither mentions today's flush control.

**Evidence.** `engine.checkpoint_every` (default 10,000 pulses) is a
`ledgr_config()` argument and `control` key stored in `engine`
(`R/backtest-config.R:93,164-169,192`; `R/run-prepare.R:43-49`) and drives
the durable flush (FE:1651-1656). The probe shows that changing it changes
`config_hash`. R8 authorizes only the mode removal (S:162-167).

**Consequence.** If the spec cut replaces or redefines it with a row bound,
it makes an API and identity change no rule authorizes; if it keeps it, its
relation to the row bound is undefined.

**Patch (S:432).** Replace "choose the concrete chunk row bound," with
"choose the concrete chunk row bound and its relation to
`engine.checkpoint_every` (a hashed pulse-count flush control,
`R/backtest-config.R:93,192`): keep its meaning, or record its change as an
explicit identity change with its own ledger row;".

**Patch (S:308).** After "unchanged by this amendment." add "R8 does not
authorize any change to `checkpoint_every`."

### 4. The governance triangle lacks receiver back-links and anchors

**Claim.** S:317 changes no contract at acceptance and installs bridge rows
(S:351-353), but adds no `Accepted change pending` link at the contract
groups the switch rewrites (S Section 7); the Section 6 table has no
disposition column.

**Evidence.** `contracts.md:9-13`; governance-lifecycle synthesis Section 4
(`rfc_governance_lifecycle_v0_2_2_synthesis.md:120-141`: a disposition per
target and a back-link at each affected contract group). Every
`decisions.md` row starts with an `<a id>` anchor (:26-36); S:351-353 have
none. Unlike the skeleton and observable-data amendments, this one changes
shipped rules at the switch (LR-12 to LR-18), so their precedent does not
carry over.

**Consequence.** Affected contract groups carry no pointer to the pending
change, and links to the new rows cannot resolve.

**Patch (S:317).** Replace "change no shipped contract or product code then."
with "change no shipped contract rule or product code then; the only
`contracts.md` edits are the pending back-links below."

**Patch (Section 6 table, new row after the rules-ledger row).** "|
`inst/design/contracts.md`: Fold Core And Output Handlers, Typed Fold
Carrier, Event Staging And Parallel Sweeps, Cost Resolution And Accounting
Events, Execution And Feature Identity, Current Store Format, Telemetry And
Recovery | Under each heading add `Accepted change pending: [lean core pulse
plumbing](decisions.md#lean-core-pulse-plumbing-checks).` No rule text
changes (`contracts.md:9-13`). |"

**Patch (S:351-353).** Prefix the Topic cells with
`<a id="lean-core-pulse-plumbing-checks"></a>`,
`<a id="lean-core-trusted-append"></a>` and
`<a id="lean-core-one-write-path"></a>`.

**Patch (before the table at S:326).** Add: "Disposition of every row:
**amended** (the addressed clauses are superseded for the pending lean core);
every section not named is **unchanged**."

### 5. K:55-56 still forbids what the amendment authorizes

The K row (S:328) re-scopes only the "public API ... identity unchanged"
sentence (K:53-55). K:55-56 goes on: "This RFC does not authorize a
production integration, new execution mode, format change or
correctness-rule change." R8 authorizes a format and identity change and
LR-13 to LR-18 change correctness rules; appended to K, the amendment is
part of "this RFC", so the unaddressed clause contradicts R1-R4 and R8.
**Patch (S:328).** After the quoted phrase "public API ... identity
unchanged" insert "and of 'does not authorize ... format change or
correctness-rule change' (K:53-56)".

### 6. The S replacements delete rules that still govern shipped code

**Claim.** S:337-339 replace manual text (validation paragraph :184-192,
Clarity item 3 at :273-274, :445-448, checklist :688 and diagram node D at
:421) with lean-core wording, while the notice (S:319-321) says the
amendment supersedes them "for the pending WS16 lean core only".

**Evidence.** AGENTS.md:53-61 binds ingest, seal, hydration and fold code
to the manual. The replaced passages carry rules for that code: "name that
edge and check the changed property there" (:190-192); "An internal helper
that remains callable with arbitrary, unguarded objects must still fail
closed" (:445-446); "is this code proving a new property or paying again"
(:688-689). M:818-820 rewrites the manual against the new core after the
switch, not before.

**Consequence.** Shipped-path rules vanish at acceptance, contradicting the
notice and S:44 ("Until the switch, shipped contracts and code continue to
apply").

**Patch (S:337).** Replace "Replace validation paragraph with:" with "Keep
the validation paragraph and append:", and begin that text with "In the lean
core, "; replace "Replace item 3 with:" with "Append to item 3:", and begin
that text with "In the lean core, ".

**Patch (S:338).** Replace "Replace the :688 checklist item with" with "Add
after the :688 checklist item".

**Patch (S:339).** Replace "replace the diagram node D label with" with "add
under the diagram, for the lean core, that node D is"; replace "Replace
:445-448 with" with "After :448 add", and begin that text with "In the lean
core, ".

### 7. The interface table exists; its install row is wrong and incomplete

**Claim.** S:343 says the table is absent, its Sections 13/14 and validator
cells unverified, and acceptance should "create it if still absent".

**Evidence.** `lean_core_interface.md` exists at this head, untracked, as a
"draft for maintainer review (LDG-3211 ...)" (:3), with a Section 10
Validator column (:349-372), Section 13 "Validation placement" (Guarantee /
Checked at / Trusted after, :458-477) and Section 14 "Recorded boundaries"
(:481-537). Section 13 cites seed v2 (:469-470); its Fold state (:467),
Diagnostic staging (:471) and post-risk (:472) rows state production checks
LR-16 and LR-17 make debug-only. Section 14 already copies captures
(:483-503), consistent with R13.

**Consequence.** "Create it if still absent" invites a second table beside
the LDG-3211 draft, which also lacks S's required columns.

**Patch (S:343, first two sentences).** Replace
"`inst/design/ledgr_v0_2_3_spec_packet/lean_core_interface.md` is absent
here; Sections 13/14 and current validator cells are **unverified**. At
acceptance create it if still absent, or install" with "At `33fc56eb`
`lean_core_interface.md` is an uncommitted LDG-3211 draft with a Section 10
Validator column, Section 13 (Guarantee / Checked at / Trusted after) and
Section 14; Section 13 cites seed v2. Do not create a second table. The
commit that lands or next edits it repoints seed v2 to this synthesis, marks
its Fold state, Diagnostic staging and post-risk rows debug-only under
LR-16 and LR-17, and installs".

### 8. The notice scope and the AGENTS.md text need one fix each

S:319 puts the notice on "each named record"; AGENTS.md is 149 lines under
a 150-line rule (AGENTS.md:62), so a literal installer breaks the cap. S:341
replaces AGENTS.md:50-52 three for three and leaves the dev-only note at
:15-16 intact, but its first line drops "for optimized or compiled paths"
(AGENTS.md:51), widening an operative rule; no other rule is lost.

**Patch (S:319).** Replace "Each named record gets" with "Each named design
record (K, L, T, A, X, M, S, B) gets"; after "acceptance date/provenance."
(S:323) add "AGENTS.md, decisions.md, the ledger, claims.yml, the interface
table and the pipeline row take only their given text."

**Patch (S:341).** Replace "canonical R is the normative executable oracle;"
with "canonical R is the normative executable oracle for optimized or
compiled paths;".

### 9. Floor v1 recomputes the effects R7 moves to P3

R11 charges floor-resident work to owners (S:200-201) but omits the effect
computation floor v1 runs at its boundary: `FP/lean.R:292` calls
`ledgr_fill_publication_deltas()` at the end of `fp_compact_fold()` (S:62
notes it). Under R7 that work is P3's; unnamed, the output family can claim
a saving P3 then pays, or it is subtracted twice.

**Patch (S:200-201).** Replace "output IDs, empty evidence and diagnostic
binding." with "output IDs, empty evidence and diagnostic binding; P3 owns
the effect computation floor v1 runs at its boundary (`FP/lean.R:292`)."

### 10. The routed `mark_age` decision has no installed home

S:442-445 keeps the fill `mark_age` gap with a separate maintainer decision
(RR:135-141), but no row in `rfc/README.md`, `decisions.md`, `horizon.md`,
`macro_plan.md` or `tickets.yml` mentions it (`rfc_cycle.md:192-199` keeps
later work in the pipeline). Once the pipeline row changes state, the
decision lives only in closed RFC files.

**Patch (S:346).** At the end of the Next/Route text add "The fill
`mark_age` read-validator gap (Section 8) awaits its separate maintainer
decision."

### 11. Citation fixes

- S:52: "FP/run.R:24 and FP/lean.R:29" -> "FP/run.R:31-44 and
  FP/lean.R:37-45" (:24 and :29 load source and read `reps`).
- S:378: "identity rule 5 wording at C:674" -> "... at C:677".
- S:272: "R/fold-engine.R:2056" -> "R/fold-engine.R:2057-2083".
- S:340: "Insert:" -> "Insert at the end of each section:" (one text, two
  targets, no position).

## What I checked

- Read S, V2, RR, the response (finding 4 in full), K, the cited parts of
  L, T, A, X, M and both manuals, AGENTS.md, `decisions.md`, the ledger,
  `rfc_cycle.md` and the governance-lifecycle supersession rule. Checked
  D1-D8 against R1-R13 and Sections 4-8.
- Corrections (a)-(c): C:193-200, :531-541, :749-755, :1426-1468;
  FE:110-129, :1178-1203, :1476-1506, :1544-1598; `R/backtest-runner.R:92-140`;
  `R/condition-reference.R:186`; `R/backtest-config.R:92-200`;
  `R/config-hash.R:20-66`; `R/walk-forward-identity.R:176-198`; probe.
- Section 2: recomputed all saved medians from raw (28, 10, 26 rows; max
  difference 0.048) and checked every cited CSV line and README number;
  1,196 occurs in no fold_plumbing file (its README gives 1,190 at :63 and
  1,244 at :175).
- Section 5: FE:1382-1664 and :1935-2098, OH:76-216 and :355-789,
  `R/fold-event-buffer.R:1-40`, `R/fold-phase-contract.R:155-210`,
  C:1524-1545. Apart from findings 2 and 3 the protocol matches.
- About 120 further citations resolve as claimed, among them every one in
  Sections 1, 4, 5 and 6: `R/fold-carrier.R` group lines 207-970; OH:44, 154,
  415, 466, 571, 643, 666, 699, 734, 761, 774; `R/lot-accounting.R`,
  `R/terminal-outcomes.R`, `R/sizing-evidence.R`, `R/strategy-helpers.R:688`,
  `R/strategy-preflight.R:392`; all K, L, T, A, X, M, manual, B, AGENTS.md,
  `decisions.md`, `tests/claims.yml`, `rfc/README.md:113` and ledger:30 line
  targets; contract rule groups at C:100-1689. Each install target exists;
  AGENTS.md stays at 149 lines; nothing installed changes a shipped contract
  rule or product code.
- S's own probe lives outside the repository
  (`C:/Users/maxth/ledgr-wt/pulse-plumbing-synthesis-out/`); its claims were
  re-derived here from repository code and a fresh probe.

## What I did not check

- No suite, package check or spike runner was run. Older real-loop medians
  without raw records (FP timing.csv:2,17) are **unverified**, as S says.
- Whether the P5 equality abort is reachable from user data is
  **unverified**; finding 1 does not depend on it.
- The 214 PMwR figure and the quickr and lean FIFO numbers beyond their
  READMEs are **unverified**.
- A repository-wide census of `execution_mode`/`db_live` surfaces, tests to
  remap and binding texts outside the records S names is **unverified**; S
  assigns it to the switch cut. Rendered anchors were not checked.

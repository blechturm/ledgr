PASS
Mode: Focused Type 2 re-review; independent fresh session; Cut 17 at ce97bb2d, reviewing efd39798..ce97bb2d.

R1 - resolved. Dropping the bypass is sound: decision (4) retains every constructor check at its current point, including after the notes update; decision (3) permits only equivalent cheaper operations. The matrix-axis and skip-then-overflow witnesses remain required. This removes the need for a bypass dependency proof without weakening the no-behaviour-change obligation (C:/Users/maxth/ledgr-wt/cut17-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2110; :2149; C:/Users/maxth/ledgr-wt/cut17-rereview/R/strategy-helpers.R:688; C:/Users/maxth/ledgr-wt/cut17-rereview/R/strategy-types.R:563).
R2 - resolved. Decision (5) specifies recursive comparison, numeric and encoding identity, ordered signals, notes on refusal, condition fields/calls and explicit trace exclusions, with separate failing mutations for each listed surface; both tickets and the close review carry these obligations (C:/Users/maxth/ledgr-wt/cut17-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2118; :2555; :5543; :5557).
R3 - resolved. The checked manifest asserts pin branch reach, covers both verbs and shared callers, retains unusual operands and precedence cases, and requires independent notes environments, snapshots, captured-view provenance and arm-resolution controls (C:/Users/maxth/ledgr-wt/cut17-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2135; :2157; :2163; :5543). The four direct check_names callers are signal, selection, weights and target (C:/Users/maxth/ledgr-wt/cut17-rereview/R/strategy-types.R:368; :488; :525; :563).
R4 - resolved. Decision (6) binds the existing shared harness, eight alternating fresh-process pairs, frozen repetitions, ratio of medians and the 1.02 helper bound; whole-run timing is descriptive, with an explicit narrowly limited adapter and failure demonstrations. LDG-3232 owns protocol validation and LDG-3233 owns candidate measurement (C:/Users/maxth/ledgr-wt/cut17-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2171; :2190; :5542; :5558). This agrees with C:/Users/maxth/ledgr-wt/cut17-rereview/AGENTS.md:117 and C:/Users/maxth/ledgr-wt/cut17-rereview/dev/bench/timing/protocol.R:75. N1 below is an optional summary-wording clarification.
R5 - resolved. Product scope is the six named functions, with no constructor bypass; required tools, records, additive tests, NEWS and ticket evidence are explicitly permitted. Validators, risk planning, sizing-evidence validation and execution code remain excluded. Site dispositions now include setequal, and the seven-shape close review remains required (C:/Users/maxth/ledgr-wt/cut17-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2082; :2092; :5544; :5560).
R6 - resolved. The committed callee-cell timings and separate 208/247 drill denominator are distinguished; all scratch estimates and encoding claims must be reproduced or superseded. Installed semantic-pin identity, immutable measurement-arm identities and current source-to-pin comparison remain evidence obligations (C:/Users/maxth/ledgr-wt/cut17-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2023; :2049; :2064; :5541).

N1 - advisory - Make the timing summaries explicitly preserve decision (6)'s descriptive-cell exception.

Claim: The new summaries say the shared checker passes, although the operative decision permits the reporting adapter to ignore the descriptive whole-run cell's ratio verdict. The intended rule is already explicit, so this does not require another design decision or block acceptance.

Evidence: C:/Users/maxth/ledgr-wt/cut17-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2555 and :5558 use the unqualified pass wording; :2197 permits the limited exception. C:/Users/maxth/ledgr-wt/cut17-rereview/dev/bench/timing/check.R:291 and :293 show that the unadapted checker fails any cell above its declared bound.

Consequence: A close reviewer reading only the summaries could mistakenly impose a whole-run speed gate or reject the expressly permitted adapter result. Reading them with decision (6) resolves the ambiguity; no acceptance obligation is waived.

Exact replacement text for the timing clause in workstream 35's review reason:

> the cut17-helper-1 record meets decision (6): all shared-checker validity checks pass, every helper cell is at or under 1.02, and only the descriptive whole-run cell's ratio verdict may be ignored by the demonstrated reporting adapter

Exact replacement text for "the shared checker passes" in LDG-3233's timing acceptance item:

> all shared-checker validity checks and helper ratio checks pass, with only the descriptive whole-run cell's ratio verdict eligible for the reporting adapter's exception under decision (6)

No new required finding, unmet specification obligation or acceptance item that cannot fail was found. The manifest, pin-reach assertions, per-surface mutations, arm controls and adapter refusals make the new proof obligations falsifiable. This verdict approves the revised brief; it does not certify the pending implementation or its evidence.

Verified the detached HEAD and full revision diff through Git's explicit worktree metadata path: only tickets.yml and the added review file changed. Read the original review, revised cut, workstream and tickets, relevant helper/type code, AGENTS.md and shared timing implementation/manual. No R execution, timing window, test suite or package check was run. No tracked file was edited and no commit was made.

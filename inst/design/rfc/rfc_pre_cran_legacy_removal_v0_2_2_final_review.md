# RFC Final Review: Pre-CRAN Legacy Removal for v0.2.2

- Mode: Type 1, verification, not design
- Reviewer: Claude, seed author; not the synthesis or response author
- Date: 2026-10-12
- Reviewed: `rfc_pre_cran_legacy_removal_v0_2_2_synthesis.md` (uncommitted,
  "Awaiting Type 1 final review")
- Checked at: `164e15ba`

## Verdict

PASS_AFTER_PATCHES. The synthesis is consistent with seed v2, the response
review and the maintainer's rebuild decision. Its design needs no new round.
Three patches are needed before acceptance; one of them would otherwise retire
current test coverage.

## Verified

- **Line citations.** Every line number in Sections 2 and 5 resolves at
  `164e15ba`:
  - `R/config-hash.R:48-52` (rule 1 when the field is missing);
  - `R/execution-timing.R:51-52` (the literal 2);
  - `R/sweep-persistence.R:345` (the `ledgr_invalid_store` parent);
  - `R/experiment-store-schema.R:566-579`;
  - `R/db-schema-create.R:26-33` and `:531-543`;
  - `R/db-schema-validate.R:785-825` and `:794-806`;
  - `contracts.md` lines 260, 288-291, 316-321, 411, 451-456, 670-672, 829,
    834-839, 886, 939, 1250 and 1314.

  The "Verification Contract" heading exists.
- **Fingerprint rule (2.2).** The pattern
  `^ledgr_[a-z_]+_(schema|rule)_version$` matches 20 namespace bindings.
  The atomic test keeps 18 and excludes the two functions,
  `ledgr_snapshot_hash_rule_version` and
  `ledgr_sweep_assert_parent_schema_version`, as the synthesis states.
- **D7.** The kept behaviours are current code, as checked in the response
  review.
- **Consistency.**
  - The Section 3 table matches seed v2 and the response review on each
    contested point.
  - The rebuild decision matches the macro plan amendment.
  - The WS5-A synthesis amendment matches seed v2 section 6.
- **Gates.** Every gate in Section 6 has a witness or census that fails on
  the pre-cut tree. The ladder gate relies on per-tree store builds, which the
  registered `ladder.sh` does.

## Patches Required

**P1. LCL-0158 and LCL-0159 must be rewritten, not retired (Section 6, gate
8).**
- LCL-0158 (LTB-0158) protects the current schema-2 corporate-action
  policy: deterministic maps, identity over label text, order, choice,
  haircut and fallback, malformed-shape refusal, presets, and v002
  held-terminal ids.
- LCL-0159 (LTB-0159) protects the current valuation exhaustion choice:
  default `freeze`, `refuse` kept distinct, mandatory `max_sessions`, and
  schema 2 in run and experiment identity.

Only their last clauses ("a schema-1 identity is never accepted as schema 2";
"never gives a schema-1 record an implicit exhausted value") are legacy.
Retiring them would remove fast coverage of current identity.

Patch: retire LCL-0028 (LTB-0033) and LCL-0160 (LTB-0160). Rewrite LCL-0158
and LCL-0159 without their schema-1 clauses.

**P2. LCL-0034's blocks are misattributed (Section 6, gate 8).** The text
"LCL-0034 and LCL-0237 (LTB-0239)" pairs LCL-0034 with LTB-0239. LCL-0034 is
detected by LTB-0039, LTB-0040 and LTB-0041, and its migration arm is the one
to drop. The trigger arm belongs to LCL-0237 (LTB-0239).

Patch: "LCL-0034 (LTB-0039 to LTB-0041) without its migration arm and
LCL-0237 (LTB-0239) without its migration and trigger arms".

**P3. Name the 18 constants (Section 2.2).** "18 today, from
`ledgr_fact_schema_version` to `ledgr_selection_rule_schema_version`" is a
range, not a list. Section 11 asks the final review to check the rule
enumerates exactly these. List them so the ticket cut and the fingerprint
test start from the same set:

- `business_objective`, `corporate_action_policy`, `cost`, `experiment_store`,
  `fact`, `fold_list`, `fold`, `identity_rule`, `objective_criterion`;
- `risk`, `saved_sweep`, `selection_rule`, `sweep_filter`, `sweep_retention`,
  `timing`, `valuation_policy`, `walk_forward_candidate`, `walk_forward`.

In each, read `ledgr_<name>_schema_version`, except `identity_rule`, which is
`ledgr_identity_rule_version`.

## Record-Only

- The fingerprint includes `ledgr_experiment_store_schema_version`, which the
  marker also stores under its own key. This is redundant but harmless; the
  spec cut may drop it from the fingerprint or keep it.
- Section 2.1 says "about twenty calls in nine files". At `164e15ba` there
  are 22 `check_schema` / `create_schema` call sites in 12 files, 19 of them
  in 10 files outside the schema code. The opener census (gate 2) is the
  binding count.
- A blank line is missing between Section 9's last bullet and the Section 10
  heading.

No finding routes to `NEEDS_TYPE_2`.

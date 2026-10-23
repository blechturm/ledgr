# Workstream 51 focused re-review

**Mode:** focused Type 1 re-review
**Range:** `af42634e..4da6d021`
**Verdict:** CHANGES_REQUIRED for one record-only correction

The original finding is resolved. LTB-0481 now calls public
`ledgr_walk_forward()` for the dense gapped `carry_test_state` experiment,
expects `ledgr_walk_forward_gapped_carry` with the shared
`ledgr_walk_forward_invalid_fold_window` parent, and asserts that no
`walk_forward_sessions` row was written.

Restricting the public check to availability-active experiments makes LTB-0481
fail three times: the dense call does not refuse, no parent condition exists,
and one session row is written. The owning continuity and control-plane files
pass unmodified; both YAML files parse; no product file changed, so the pinned
574-block timing record remains valid.

The correction range had trailing Markdown whitespace on two close-review
metadata lines. That record-only residue is removed directly without another
review round. The preregistered 106.4-second target miss remains a separate
maintainer disposition.

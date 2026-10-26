# Workstream 66 close review

Verdict: `CHANGES_REQUIRED` at `9400b7ef`.

The independent Type 1 Claude Opus review found no design concern and no
product defect. It verified:

- the `DESCRIPTION` version and the first NEWS heading;
- every current-only format number against its code constant: store schema
  124, snapshot hash rule 4, identity rule 4, valuation and corporate-action
  policy schema 2, saved-sweep 6, retention 2, provenance and reproduction-key
  v2, walk-forward candidate v2 and `ledgr_promotion_v3`;
- the Sharadar sentence (verbatim against the Documentation Contract and both
  articles) and the 1.89/4.46 GiB figures against README and Sweeps;
- that local `v0.2.2` (`f46de1f1`) and `origin/v0.2.2` (`c6374bb2`) are both
  ancestors of the candidate, and that no `v0.2.2` tag exists;
- removal of the three bridge rows. Every receiver anchor resolves,
  contracts.md keeps no "Accepted change pending" pointer to them, and no
  inbound link targets the removed `#history-manifestation` row;
- the governance-lifecycle M1 handoff to LDG-3118 and the v0.2.3 record.

The review ran focused suites test-project-metadata.R (14), test-release-claim-boundary.R (9) and
test-documentation-contracts.R (1,103) with no failures. Both YAML files
parse. `git diff --check` on the commit is clean.

Three corrections are required:

1. **The candidate fails a registered release gate.** `vignettes/sweeps.md:608`
   prints `Engine Version: 0.2.1.0`. That value comes from
   `utils::packageVersion("ledgr")` (`R/sweep-persistence-schema.R:31`), and
   `normalize_for_freshness()` in `tools/render-vignettes-gfm.R` does not mask
   it. The playbook's `Rscript tools/render-vignettes-gfm.R --check --all`
   gate will therefore fail on commit C. Since the version bump caused the
   drift, refresh the render under this workstream. Do not fix it after C, and
   do not relax the normalizer.
2. **A shipped article names the wrong release.**
   `vignettes/research-to-production.qmd:126` and its render
   `research-to-production.md:101` say "The v0.2.1.0 release line" under "What
   The Current Research Layer Delivers". The closeout says older version
   strings survive only where their age is meaningful, but this one is stale
   current prose. Make it version-neutral or say v0.2.2, and record both
   occurrences in the inventory.
3. **The NEWS upgrade guide asks for edits that cannot exist.** The
   "Upgrading from 0.2.1.0" bullet tells users to replace the history
   `na_action` argument and `ledgr_history_sufficient()`. Neither exists
   anywhere in v0.2.1.0, and `ledgr_history_matrix()` and
   `ledgr_history_frame()` were first exported in 0.2.2. No v0.2.1.0 code can
   contain those names. Drop them from the upgrade list and remove the
   matching development-diary sentence at `NEWS.md:329-330`. The upgrade list
   also leaves the removed cache helper unnamed. The ticket asks for removed
   public names, so name `ledgr_feature_cache_clear()`.

Record-only notes (not required):

- Some bullets about surfaces new in 0.2.2 still describe changes made during
  development: `NEWS.md:131-132`, `197-200`, `313-316` and `332-336`. They
  are not wrong, but a v0.2.1.0 reader has no "before" for them.
- The closeout says the recursive-indicator redirect now describes completed
  implementation, but this commit left it unchanged. It still reads "Cut 16
  owner are consolidated by ... LDG-3065 through LDG-3067", as does the
  session-axis redirect. Neither is wrong, but the closeout overstates what
  changed.
- `dev/governance_guard/baseline.yml` still lists
  `rfc/README.md#feature-map-read-surface` as a broken anchor, but it now
  resolves. That predates this workstream.

The review was read-only apart from this record. Its `pkgload::load_all()`
call caused line-ending-only churn in `R/cpp11.R` and `src/cpp11.cpp`; restore
it before the correction commit.

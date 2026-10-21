"""Mutation specs for Workstream 44 phase B (LTB-0408, LTB-0414, LTB-0415).

Writes specs_phase_b.json next to this file; mutate.py applies each one to a
source copy, runs the named blocks and restores the file byte for byte.
"""
import json
import os

here = os.path.dirname(os.path.abspath(__file__))
TEACH = ["test-history-teaching.R"]
PROOF = ["test-history-integrated-proof.R"]
ART = "vignettes/causal-history.qmd"
MD = "vignettes/causal-history.md"


def m(id, desc, file, old, new, test_files, blocks):
    return dict(id=id, desc=desc, file=file, old=old, new=new, test_files=test_files, blocks=blocks)


specs = [
    m("T1", "hello world no longer the first shown chunk", ART,
      "#| label: hello-world\n", "#| label: hello\n", TEACH, ["LTB-0414"]),
    m("T2", "portfolio example drops the keep of held excluded instruments", ART,
      "    ledgr_target_rebalance(ctx, equity_fraction = 0.95, keep = keep)",
      "    ledgr_target_rebalance(ctx, equity_fraction = 0.95)", TEACH, ["LTB-0414"]),
    m("T3", "portfolio example rebuilds instrument names by hand", ART,
      "  w <- min_variance(stats::cov(ledgr_history_matrix(returns)))",
      "  w <- min_variance(stats::cov(ledgr_history_matrix(returns)))\n  names(w) <- colnames(ledgr_history_matrix(returns))",
      TEACH, ["LTB-0414"]),
    m("T4", "a teaching chunk opts out of evaluation", ART,
      "#| label: carried-share\n", "#| label: carried-share\n#| eval: false\n", TEACH, ["LTB-0414"]),
    m("T5", "the default-read chunk lost (renamed), so defaults are no longer taught first", ART,
      "#| label: default-read\n", "#| label: default-read-moved\n", TEACH, ["LTB-0414"]),
    m("T6", "rendered article lost an executed indicator print", MD,
      "History class: history_dependent (package catalogue)", "History class: (not rendered)",
      TEACH, ["LTB-0414"]),
    m("T7", "help page no longer links the article", "man/ledgr_history_info.Rd",
      'vignette("causal-history", package = "ledgr")', 'vignette("indicators", package = "ledgr")',
      TEACH, ["LTB-0414"]),
    m("R1", "a v12 pending link is restored on Release Gates", "inst/design/contracts.md",
      '<a id="contract-verification-release-gates"></a>\n### Release Gates\n',
      '<a id="contract-verification-release-gates"></a>\n### Release Gates\n\nAccepted change pending:\n'
      '[point-in-time historical projection](decisions.md#point-in-time-historical-projection).\n',
      TEACH, ["LTB-0415"]),
    m("R2", "a current-tense rule-3 snapshot-hash statement", "inst/design/contracts.md",
      "- Backtests run against sealed snapshots.\n",
      "- Backtests run against sealed snapshots.\n- Snapshot hash rule 3 is the content-identity rule.\n",
      TEACH, ["LTB-0415"]),
    m("R3", "a receiver anchor no longer resolves", "inst/design/contracts.md",
      '<a id="contract-verification-store-and-codebase-gates"></a>',
      '<a id="contract-verification-store-gates"></a>', TEACH, ["LTB-0415"]),
    m("R4", "a decisions bridge row removed before release closeout", "inst/design/decisions.md",
      '<a id="recursive-indicator-boundary"></a>', '<a id="recursive-indicator-bound"></a>',
      TEACH, ["LTB-0415"]),
    m("O6", "LDG-3069 evidence no longer cites its transport block", "inst/design/ledgr_v0_2_2_spec_packet/tickets.yml",
      "LTB-0295 (LDG-3061's transport oracle, reused)", "the LDG-3061 transport oracle (reused)",
      PROOF, ["LTB-0408"]),
    m("O7", "LDG-3070 evidence no longer cites its segment-guard block", "inst/design/ledgr_v0_2_2_spec_packet/tickets.yml",
      "LTB-0291 (the segment-guard refusal it reuses)", "the segment-guard refusal it reuses",
      PROOF, ["LTB-0408"]),
    # Correction 1 (close review 44b F3 and F5): the review's surviving
    # mutations U2-U4 and effect mutations on the rendered article.
    m("U2", "portfolio assigns names without spaces", ART,
      "  w <- min_variance(stats::cov(ledgr_history_matrix(returns)))\n",
      "  w <- min_variance(stats::cov(ledgr_history_matrix(returns)))\n  names(w)<-names(returns)[-1]\n",
      TEACH, ["LTB-0414"]),
    m("U3", "walk-forward strategy no longer reads history in the test window", ART,
      '  sessions <- nrow(ledgr_history_frame(ctx, bar = "close"))',
      "  sessions <- 1L", TEACH, ["LTB-0414"]),
    m("U4", "late-fact chunk drops the restated bar read at the seventh session", ART,
      'read_ddd(days[[7L]], bar = "close")\n', "", TEACH, ["LTB-0414"]),
    m("E1", "rendered keep comparison: the no-keep run no longer sells at the gap", MD,
      "    12 2020-01-10 09:30:00 SELL 357", "    12 2020-01-16 09:30:00 SELL 357",
      TEACH, ["LTB-0414"]),
    m("E2", "rendered walk-forward: the first test window read only its own window", MD,
      "    1 2020-07-02 09:30:00       DEMO_05 130", "    1 2020-07-02 09:30:00       DEMO_05  63",
      TEACH, ["LTB-0414"]),
    m("E3", "rendered vintage read: the session-5 feature value restated", MD,
      "    5 2021-01-08 21:00:00  52.5     TRUE", "    5 2021-01-08 21:00:00  NA      FALSE",
      TEACH, ["LTB-0414"]),
]
with open(os.path.join(here, "specs_phase_b.json"), "w", encoding="utf-8") as f:
    json.dump(specs, f, indent=1)
print(len(specs), "specs")

# Governance Report Evidence

Role: record; Workstream 32 implementation evidence and reviewed fixtures.
Status: working
Authority: Cut 15 LDG-3042 and the accepted governance-lifecycle synthesis
Section 6 define this report-only tool and its evidence boundary.

From the repository root, run:

```text
Rscript tools/governance-report.R
```

The command reads tracked Markdown and Quarto sources at top-level
`inst/design` and recursively below `rfc/`, `manual/` and the current packet.
It also reads `tests/claims.yml`. It prints the baseline commit, every scanned
path, the population digest, counts and each finding. The claims identity is
the repository-root-relative path plus SHA-256 of its UTF-8 text normalized to
LF with one terminal newline; no checkout directory or platform line ending
enters successful report output. It never changes a file, offers no check mode
and returns success when structural findings exist. Missing or malformed
inputs are invocation errors.

`baseline.yml` is the measured, entry-specific debt baseline. Every entry is
stored in that file and identified by source file, literal target, occurrence
index and finding kind; no directory or target-wide exemption exists. Its 51
entries and 313-source identity were captured once from the accepted
governance-scope rows of
`dev/governance_census/records/links_broken.csv`: preserve census row order,
number each source-and-literal-target occurrence, and translate
`missing_file`/`broken_anchor` to the report kind. The report does not read the
historical census. A resolved entry is printed with its full identity, and a
kind change appears as a resolved old entry plus a new finding. The baseline
describes structural evidence, not semantic completeness.

`Receiver`, `Replacement`, `Operative remainder` and `Reason` are provisional
fixture labels used to exercise the accepted provenance requirements. They do
not settle Workstream 35's final header names. `fixtures/reviewed/` contains
the maintained pass cases and mutation substrate used by LTB-0273.

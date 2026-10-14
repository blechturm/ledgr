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
path, the population digest, counts and each finding. It never changes a file,
offers no check mode and returns success when structural findings exist.
Missing or malformed inputs are invocation errors.

`baseline.yml` is the measured, entry-specific debt baseline. Every entry is
identified by source file, literal target and occurrence index; no directory
or target-wide exemption exists. The baseline describes structural evidence,
not semantic completeness. `fixtures/reviewed/` contains the maintained pass
cases and mutation substrate used by LTB-0273.

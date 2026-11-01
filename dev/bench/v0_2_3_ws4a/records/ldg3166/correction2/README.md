# LDG-3166 correction 2 (checkpoint re-review 1, N1 and N2)

Product 167dc947 applies ws13_checkpoint_rereview_1.md N1 (arithmetic NaN in
fee and cash keeps the base accounting refusal) and N2 (evidence wording).
Run by the maintainer's session on 2026-10-31, one job at a time:

| Gate | Outcome |
| --- | --- |
| check.R --base=HEAD | 23 cases identical |
| guts.R (26 guts) | 26 of 26 fail as expected; invalid-base control refused |
| dense check.R | PASS, nine native arms identical |
| A0 record + compare | 295 of 295 PASS |
| full suite (stop_on_failure) | exit 0 |

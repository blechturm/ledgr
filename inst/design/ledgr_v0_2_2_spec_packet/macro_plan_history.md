# v0.2.2 Macro-plan History

**Role:** record; content-addressed historical navigation.
**Status:** accepted
**Authority:** None. Current order lives in [macro plan Section 7](macro_plan.md#7-remaining-order).

Workstream 34 removed the superseded amendment narratives from the live macro
plan. Their exact text remains in Git at source commit
`1cbc5166:inst/design/ledgr_v0_2_2_spec_packet/macro_plan.md`. Each row below
identifies the inclusive source lines and the SHA-256 of the UTF-8 text joined
with LF plus one final LF. The hash makes every moved narrative independently
recoverable and verifiable without copying a second sequencing account into a
living document.

| Amendment | Source lines | SHA-256 | Historical subject |
| --- | ---: | --- | --- |
| <a id="base-change-control-policy"></a>Base policy | 633-640 | `0e8c3e5517ada58fa400dae8cb3a762acf238a0b8fee21f55a66f4bad6b5ad11` | change-control scope before dated amendments |
| <a id="amendment-2026-10-03-1"></a>2026-10-03 (1) | 641-646 | `c6a564870ba5882ee642a356df438ac2e4fe5d92a3212cb1b3dda059163cb88e` | WS5 consumes the DuckDB projection design |
| <a id="amendment-2026-10-08-1"></a>2026-10-08 (1) | 647-660 | `4fec0c2e4f9b06bc357e7068105dadd9364baae00ca3ddf53525fb1e7936f489` | WS2 remainder before the history wave |
| <a id="amendment-2026-10-08-2"></a>2026-10-08 (2) | 661-689 | `f575308882753156470da834d59de4dd247088a25522ef153bf7690bdebcc1e7` | post-Workstream-21 sequence |
| <a id="amendment-2026-10-09-1"></a>2026-10-09 (1) | 690-700 | `76bdeb4351f4374f83e2c5321c40b51dea6e16d8568a6c3e86abce046035577e` | point-in-time universe audit |
| <a id="amendment-2026-10-09-2"></a>2026-10-09 (2) | 701-716 | `b69a82672a71cc1cbe315e46cbef5655e28057274e97a2e629404175cce51519` | post-Cut-11 five-item sequence |
| <a id="amendment-2026-10-10-1"></a>2026-10-10 (1) | 717-738 | `39fd920884aa5c570322409100ac7d43ecf5456b1794de565bcdfde2855e4c04` | post-audit correctness gate |
| <a id="amendment-2026-10-12-1"></a>2026-10-12 (1) | 739-749 | `ebf97f6662273bf7b3ae831d46f05a704e3dab4816282c098978fac8309049cf` | Workstream-25 review routing |
| <a id="amendment-2026-10-12-2"></a>2026-10-12 (2) | 750-770 | `2859485baea1094438d81a08fc9c3848a19930de4f271cc1147f6e9ff8dd7b0b` | WS5-A synthesis routing |
| <a id="amendment-2026-10-12-3"></a>2026-10-12 (3) | 771-803 | `7dec6996ec91e46e286e43881bd679d29a17bbdc764c35a68c7c9094b037a353` | pre-CRAN legacy-removal cut |
| <a id="amendment-2026-10-12-4"></a>2026-10-12 (4) | 804-839 | `646cb560946114569749f607d3245cf87acda13fa473084a2def4d50f6d99bc1` | codebase hygiene |
| <a id="amendment-2026-10-12-5"></a>2026-10-12 (5) | 840-861 | `a6e8180b693b09ba4017640a3f24197310c88dc9096023fc06fadb2fe8a10643` | one-execution-mode probe placement |
| <a id="amendment-2026-10-13-1"></a>2026-10-13 (1) | 862-954 | `2028da2f14e8441e70c85712e268d49770261b2268fc0feff71bcdc8590f14bf` | planning-document cleanup |
| <a id="amendment-2026-10-14-1"></a>2026-10-14 (1) | 955-972 | `74a9c96024acea4ec8b08e989a23c5adf99c1c83d1a936418027d4959458a242` | unowned-debt routing |
| <a id="amendment-2026-10-14-2"></a>2026-10-14 (2) | 973-1002 | `40c16b8781c9df9265d0a0466410aae7835f71ab3ece9f6eb9cd62e62627e34e` | fold phase extraction |
| <a id="amendment-2026-10-14-3"></a>2026-10-14 (3) | 1003-1012 | `cc6dcc6e8100ce83f509f4b53a9ef3afb80421d0614d7076723a0b8f4b8955a6` | feature-keeping probe placement |
| <a id="amendment-2026-10-14-4"></a>2026-10-14 (4) | 1013-1084 | `15fba950a25415237e641a70b7720efcf168c8d7ab3942f5ba022fd0948b3adb` | one-execution-mode result |
| <a id="amendment-2026-10-14-5"></a>2026-10-14 (5) | 1085-1116 | `81154c03600094785e4be49401328de6b1eb781f688cbf1cb895e6dacb26b760` | growth-shape matrix result |
| <a id="amendment-2026-10-14-6"></a>2026-10-14 (6) | 1117-1140 | `54f59767ed436d096f76a1a1b7c0843b915c7f00c39532d055b077c8c8ceeea3` | feature-keeping result |
| <a id="amendment-2026-10-14-7"></a>2026-10-14 (7) | 1141-1158 | `e3a5330062bf73acee3685e1d32b9ac6bca5ab5a6cfc07ddbeabe1ec62e9f20d` | Cut 15 ownership and design-tree decision |

To verify one row, read the stated lines from the source commit without
rewrapping them, append one LF, and hash the UTF-8 bytes. These entries are
history redirects only; they do not modify the current Remaining order.

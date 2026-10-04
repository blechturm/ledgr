# LDG-2952 candidate record

This isolated record compares committed post-LDG-2951 baseline
`9896a71f9ea5298d5f9ba625d9e33eacf8f2d074` with LDG-2952 candidate
`5f327a8535d4ab43cb62e7c3c8256402afef1f87`. The candidate differs from the
baseline only by the LDG-2952 registered gate, strict-dispatch hoist, detector
and expected provenance repin. The checker passed without invoking the retry.

The same 1,514-session, 600-instrument, 500-member and three-return fixture
produced these independent persistence results:

| persistence | elapsed ratio | feature-phase peak ratio | process RSS ratio |
| --- | ---: | ---: | ---: |
| off | 0.9466 | 0.9570 | 0.9983 |
| on | 0.9504 | 0.9568 | 1.0027 |

The binding unmarked elapsed gate therefore improved 5.3% with persistence off
and 5.0% with persistence on. The separately and symmetrically marked feature
phase ended at 565.4 and 565.3 MiB, versus 590.8 MiB in both baseline arms,
about 4.3% lower. Whole-process RSS was diagnostic and essentially unchanged,
as expected after LDG-2951 moved the run's peak outside this repeated work.

A supporting base-R `Rprofmem()` measurement over the registered three returns
definitions and 600 instruments attributes 270,552,976 allocation bytes to
1,800 per-instrument kind resolutions and 451,456 bytes to three
per-definition resolutions. That is a 99.83% reduction for the dispatch work,
not for the whole run. The public elapsed and phase rows above remain the
binding effect evidence.

Separate oracle runs compare completion, equity, fills, trades, diagnostics,
decoded strategy state, persisted feature rows and availability output
exactly. The dense witness also matches exactly, and the mutation self-test is
detected. The availability feature-engine digest changes from
`90e2932cc2794212119b60d7be4abd5ea7fd4ead28119adbc278247f2bad267e` to
`6bd61d705a94f2cd955b5eab2a526f65e36419393de0baef4d95c64718658a76`.
The dense digest and the SMA and returns indicator fingerprints remain
byte-identical.

The record used R 4.6.1, DuckDB 1.5.6.9000 and collapse 2.1.8. The compact
checked-in record excludes generated DuckDB fixtures and child stdout and
stderr files. Its CSV and JSON files retain every measured row and every value
consumed by the checker.

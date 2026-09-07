# Fixture Packets

Create one directory per witness, W01-W31. Each directory contains a
`manifest.md` plus the smallest deterministic source tables needed by that
witness. Follow `../witness_spec.md` exactly.

Do not derive fixture facts from prototype output. Do not include private or
reconstructive vendor data. Synthetic assumptions must be labeled and bounded.
Use Markdown for prose notes; the pre-prototype `.txt` tripwire is reserved for
detecting disguised executable content.

## Approved Packet Conventions (2026-09-07)

Each `Wxx/manifest.md` embeds its source tables so the hashed manifest is the
complete fixture. The shared synthetic world is venue `XSYN` with sessions
2024-01-02 to 2024-01-12, 14:30:00Z opens and 21:00:00Z closes, decisions at
closes and execution at next opens, stable IDs `A01` to `A06` with aliases
`AAA` to `EEE`, flat prices unless a witness states otherwise, zero costs
except the dense control `W21`, and no vendor data of any kind. Every case
that expects a fill states an effective active-status assertion in its own
manifest.

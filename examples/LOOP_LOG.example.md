# PeptidePal loop log (worked example)

One line per cycle: timestamp · row # · what shipped + how it was verified · sha ·
deploy result · approx tokens. This is the audit ledger — terse, evidence-first.

2026-06-18 14:02 UTC | row 0 | baseline green (install + build + test exit 0; / returns 200) | sha 1a2b3c4 | n/a | ~12k | done
2026-06-18 14:20 UTC | row 1 | reconstitution math (pure fn) — 6 tests incl. spec values (5mg/2mL→5u) + ÷0 guard; CHECK confirmed subagent's files on disk (test count 0→6) + reran build myself; VERIFY ran the caller, matched spec table | sha 5d6e7f8 | git | ~40k | done
2026-06-18 14:41 UTC | row 2 | calc UI — RESUMED mid-row (prior cycle left green WIP uncommitted → committed first). Wires to row-1 fn, no re-impl; RTL asserts 5u; /calc 200 | sha 9a0b1c2 | vercel-prod, live 200 | ~55k | done
2026-06-18 14:58 UTC | row 4 | CSV export — adversarial verifier flagged the deny path still hit the DB before the 403; fixed to fail-closed, re-verified 403 (no query) + attachment CSV bytes | sha 3d4e5f6 | git | ~60k | done
2026-06-18 15:10 UTC | row 6 | email plan — BLOCKED (real outbound + needs ESP cred). Built render+log behind a stub; marked live-send blocked for human. | — | — | ~8k | blocked

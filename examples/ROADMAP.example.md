# PeptidePal — Roadmap (worked example)

> A worked example for a small Next.js + Prisma app. Notice what makes rows good:
> each is **one PR**, the acceptance is **testable** (a command or HTTP code proves
> it), and the loop owns the **Status** column. Copy the shape, not the content.

Goals: PeptidePal is a clinician dosing helper — a peptide reference + a
reconstitution calculator. The loop re-reads this every cycle.

The loop owns **Status**: `todo` · `in_progress` · `done` · `blocked` · `failed`.
One row = one tight spec = one PR. Keep "Goal / acceptance" provable.

| # | Task | Goal / acceptance (must be testable) | Status | Notes |
|---|------|--------------------------------------|--------|-------|
| 0 | Baseline green | `npm install` + `npm run build` (tsc strict) + `npm test` all exit 0; dev server boots and `/` returns 200. No features — a known-good baseline. | done | sha 1a2b3c4. Reproducible start point. |
| 1 | Reconstitution math (pure) | `reconstitute({vialMg, bacWaterMl, doseMcg})` returns `{unitsOnU100, mlPerDose}`; unit-tested incl. the worked spec values (5mg vial + 2mL → 250mcg = 5 units) and a divide-by-zero guard. | done | sha 5d6e7f8. Pure fn first — no UI yet. 6 tests. VERIFY: ran the caller, values match the spec table. |
| 2 | Calculator UI wired to the math | `/calc` renders the form, computes live via the row-1 fn (no re-implementation), and shows units + mL/dose. RTL test asserts 5mg/2mL/250mcg → "5 units". Page returns 200. | in_progress | claimed this cycle. UI only — math already verified in row 1. |
| 3 | Peptide reference list from DB | `/peptides` lists peptides from Prisma (not a mock array); seed provides ≥10; page renders the seeded count. Test mocks Prisma and asserts the mapped shape. | todo | Reads live data — VERIFY must load the page and see real rows, not the empty state. |
| 4 | CSV export of a dosing plan | `GET /api/plan/export?id=…` returns a non-empty `text/csv` with `Content-Disposition: attachment`; capability-gated (unauthorized → 403, no DB read). E2E test covers 403 + the CSV path. | todo | Artifact row — VERIFY by actually hitting the route and checking the bytes, not just the serializer test. |
| 5 | Publish the dosing reference as a shareable page | Build emits `dist/reference.html`, non-empty, contains every seeded peptide name; publish + curl the live URL → 200. | todo | Classic "green tests ≠ artifact" trap — VERIFY runs the build and curls the URL. |
| 6 | Email a plan to the patient | Patient receives their dosing plan by email on request. | blocked | Real outbound — drafting/render+log is fine, sending is a hard stop. Needs human + an ESP cred. |

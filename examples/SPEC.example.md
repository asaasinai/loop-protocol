# PeptidePal — System Spec (worked example)

> A deliberately small **archetype-A** spec that shows every actionable device
> (D1–D9) the spec engine now requires. It ties to `ROADMAP.example.md` in this
> folder — the roadmap's `T#`/`INV#` refs point back here. Copy the *shape and the
> devices*, not the content. Real specs are longer; the devices are the point.

---

## §0 · Status Header  [D1]
- **Name:** PeptidePal · **Version:** v1.0 · **Archetype:** A (Standalone System)
- **Status:** FROZEN · **Date:** 2026-07-01 · **Owner:** Marshall
- One-line: a clinician dosing helper — a peptide reference + a reconstitution
  calculator, no agents, no PHI stored.

## §1 · Engineering Principles / Priority Ladder  [D2]
When two goods conflict mid-build, resolve in THIS order (higher wins):
1. **Dosing correctness** — a wrong number is the only unacceptable failure.
2. **Fail-closed safety** — deny/blank beats a plausible-but-unverified answer.
3. **Data integrity** — never silently coerce or lose a value.
4. **Simplicity** — fewer moving parts over cleverness.
5. **Speed / polish** — last; never traded against 1–4.

## §2 · Executive Summary & Mission
Clinicians hand-calculate peptide reconstitution and mis-dose. PeptidePal makes the
math deterministic and the reference searchable. Success at 90 days: the calc is the
team's default tool; zero math-correctness bugs reported.

## §3 · Non-Goals  [D3]
Explicitly NOT in v1: patient accounts, storing any PHI, e-commerce/checkout,
mobile-native apps, multi-tenant orgs, AI/LLM suggestions. These are Backlog (§19),
not "coming soon" — do not build toward them.

## §4 · Invariants  [D4]  (numbered, testable, MUST/NEVER — never optimize away)
- **INV1** — The UI MUST NEVER display a dose that did not come from the single
  guarded `reconstitute()` function; a divide-by-zero or bad input yields a blank +
  error, NEVER a number. *(FR2, FR3 depend on this.)*
- **INV2** — Export/plan endpoints are capability-gated and **fail-closed**:
  unauthorized → HTTP 403 with no DB read, never a hidden button over live data.
- **INV3** — No PHI is ever persisted; a "plan" exists only in the request/response,
  never written to the DB or logs.
- **INV4** — Reference data renders from the database, never from a hardcoded array.

## §5 · Personas & User Journeys
- **Clinician (primary):** opens `/calc`, enters vial mg + BAC water mL + target
  dose → reads units + mL/dose. Opens `/peptides` to look one up.
- Journey states covered per screen in §10.

## §6 · Functional Requirements  (FR#, testable, MoSCoW; cross-ref'd [D9])
- **FR1 (Must):** `reconstitute({vialMg, bacWaterMl, doseMcg}) → {unitsOnU100,
  mlPerDose}`; pure, unit-tested. *(upholds INV1)*
- **FR2 (Must):** `/calc` computes live via FR1 (no re-implementation). *(INV1)*
- **FR3 (Must):** `/peptides` lists ≥10 seeded peptides from the DB. *(INV4)*
- **FR4 (Should):** `GET /api/plan/export?id=` returns a CSV attachment;
  unauthorized → 403. *(INV2, INV3)*
- **FR5 (Should):** build emits a static `dist/reference.html` of all peptides.
- **FR6 (Could):** email a plan to a patient. *(blocked — see §18/Backlog)*

## §7 · System Architecture  (+ ASCII diagram)
```
[Browser] → Next.js (app router)
              ├── /calc      → lib/reconstitute.ts   (pure, FR1/INV1)
              ├── /peptides  → Prisma → Postgres      (FR3/INV4)
              └── /api/plan/export → capability check (INV2) → CSV
[build] scripts/emit-reference.ts → dist/reference.html (FR5)
```

## §8 · Data Model  (+ IMMUTABLE vs MUTABLE table)
`Peptide { id, name, defaultVialMg, halfLifeHrs, category }`
| Class | Data | Rule |
|-------|------|------|
| Immutable | seeded `Peptide` reference rows | write-once via seed/migration; edits are new rows |
| Mutable | none in v1 | (no user data persisted — INV3) |

## §9 · API Contracts
- `GET /api/plan/export?id=<peptideId>` → 200 `text/csv` + `Content-Disposition:
  attachment` for an authorized caller; **403** otherwise (INV2), no body leak.

## §10 · UX Spec  (screen-by-screen with states)
- `/calc` — primary action: compute. States: empty (no inputs), success (units +
  mL/dose shown), error (bad/zero input → blank result + inline message, INV1).
- `/peptides` — states: loading, populated (seeded count), empty (must not happen in
  v1 given the seed — if empty, that's a VERIFY fail on FR3).

## §11 · Security & Permissions  (role matrix — expands §4 INVs)
| Role | /calc | /peptides | /api/plan/export |
|------|-------|-----------|------------------|
| anonymous | view | view | **403** (INV2) |
| clinician | view | view | download |

## §12 · Non-Functional Requirements
tsc strict, `npm run build` exits 0, calc renders < 100ms, no PHI in logs (INV3).

## §13 · Deployment & Infrastructure
Vercel; Postgres via Prisma; deploy per the manifest `deploy` field; verify the live
URL returns 200 after ship.

## §14 · Seed Dataset  [D7]
Load **≥10 real peptides** (name, defaultVialMg, halfLifeHrs, category) from
`prisma/seed.ts` (source: the internal reference sheet). VERIFY loads `/peptides`
and asserts the rendered count ≥ the seeded count — proving live data, not a stub.

## §15 · Build Plan  (phased + per-phase Definition of Done [D5])
> **Nothing in a later phase blocks an earlier one.** Ship phase 1 alone if needed.

**Phase 1 — Core calc (FR1, FR2).** Definition of Done:
- [ ] `reconstitute()` unit tests green incl. `5mg vial + 2mL → 250mcg = 5 units`
- [ ] divide-by-zero input → blank + error, no number rendered (INV1)
- [ ] `/calc` returns 200 and computes via FR1 (no duplicated math)

**Phase 2 — Reference + export (FR3, FR4, FR5).** Definition of Done:
- [ ] `/peptides` renders ≥10 seeded rows from the DB, not a mock (INV4)
- [ ] export returns a non-empty CSV attachment for an authorized caller
- [ ] unauthorized export → 403 with no DB read (INV2), covered by an E2E test
- [ ] `dist/reference.html` is emitted, non-empty, contains every seeded name

## §16 · Dev Task List  [D6]  (T#; each ≈ one PR / one ROADMAP row)
| T# | Goal | Satisfies | Acceptance test | Blocker |
|----|------|-----------|-----------------|---------|
| T1 | pure `reconstitute()` | FR1, INV1 | unit tests incl. spec values + zero-guard | — |
| T2 | `/calc` UI on FR1 | FR2, INV1 | RTL: 5mg/2mL/250mcg → "5 units"; page 200 | — |
| T3 | `/peptides` from DB | FR3, INV4 | seed ≥10; page renders seeded count | — |
| T4 | CSV export gated | FR4, INV2, INV3 | E2E: 403 path + CSV bytes | — |
| T5 | static reference page | FR5 | build emits non-empty html; live URL 200 | — |
| T6 | email a plan | FR6 | patient receives email | real outbound + ESP cred |

## §17 · Ownership & Testing Gate
- Owner: Marshall (all subsystems, v1). Gate command: `npm test && npm run build`
  must exit 0 before any row is `done`; artifact rows also assert the real artifact.

## §18 · Open Questions & Assumptions  (must be blocker-free at LOCK)
- Assumption: single-clinic, no auth provider yet → "authorized" = a shared
  capability token in v1 (INV2 still enforced). *(accepted default, not a blocker.)*

## §19 · Deferred / RFC Backlog  [D8]  (parked — NOT open questions)
Patient accounts + PHI storage; e-commerce; native mobile; LLM dosing suggestions;
T6 email once an ESP cred exists. Good ideas, explicitly out of v1 scope.

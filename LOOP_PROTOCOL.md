# The Loop Protocol (v2) — team edition

A self-contained guide to running an autonomous **build-and-SHIP loop**: a
self-driving `/loop` that walks a project's roadmap row by row, specs each row,
builds it test-first, verifies the real result, and ships it — then does a 360
spec-coverage review when the roadmap is done. Everything you need is in this one
doc (the prompts are inline at the bottom; copy-paste them).

**Per row:** PLAN → DO → CHECK → VERIFY → ACT+SHIP. **At the end:** a 360 review.

---

## Core ideas

1. **Roadmap = source of truth.** A `ROADMAP.md` table in the repo. The loop owns
   the `Status` column (`todo · in_progress · done · blocked · failed`). One row =
   one tight, testable spec = one PR. Opus's first job is to say *no* to scope creep.
2. **Spec with Opus, build with Sonnet.** The orchestrator (Opus) plans + verifies;
   delegated subagents (Sonnet) implement one module each, test-first.
3. **Isolation via git worktrees.** Each project's loop runs in its own worktree on
   its own branch — that's what lets N loops run in parallel without colliding. Use
   worktree isolation *within* a project only when parallel subagents touch
   disjoint files; if they share a file (a seed, the schema, the build), run them
   sequentially — merging two worktrees that both edited it just conflicts.
4. **Full tool surface.** A row may need live data, an MCP call, a generated asset,
   or a publish step — do the real work (load tool schemas via ToolSearch), don't
   stub it. Drafting outbound is fine; **sending is not**.
5. **Verify reality, not reports.** Green tests, a subagent's "done", and a passing
   build summary are all *claims*. The loop only advances on first-hand evidence.
6. **A stop is a handoff.** Whenever the loop halts, it leaves a `HANDOFF.md` so a
   human dev can take over cold. git carries the code; the handoff carries what git
   can't — the why, the dead-ends, the run/deploy gotchas, and the next-actions.

---

## The five hard lessons (why the gates exist)

1. **Green tests ≠ a working thing.** A run once finished 8/8 rows, 64/64 tests
   green, *zero artifacts on disk* — it tested the serializers but never ran the
   build to emit files. → **VERIFY** runs the real build and asserts a real artifact.
2. **A subagent's "done" can be fiction.** A build subagent returned a detailed
   success report (≈12 files, tests green) with `tool_uses: 1` and **nothing** on
   disk. → **CHECK** confirms the work against the filesystem (`git status`, files
   exist, test count moved) and re-runs the build *itself*. Never paste a
   subagent's word as evidence.
3. **"All rows done" ≠ "the spec is met."** → a **360 review** maps the full spec
   surface, and classifies every gap as MISS vs DEFERRED-by-the-rollout vs
   OVER-DELIVERED vs INFRA-gated vs POLISH. Most "gaps" are deferred scope, not
   misses — verify against the spec's own milestone plan.
4. **Read-only audit agents over-hedge and contradict.** Re-verify every flag in
   the code yourself before it lands in a report.
5. **Resume on a known tree.** Picking up a mid-flight loop: read the log, run the
   full suite/build, confirm green, commit any green WIP — *then* continue.

Small sharp ones: clear a **stale build cache** before believing a "route not
found" prod-build failure; a **dev server spawned in a tool call gets reaped** (run
it as a tracked background task and poll, or verify against a clean `build && start`);
on a **mock→real swap**, split authored *content* / per-record *services* /
empty-state *samples*; on a design pass, check **tokens hex-by-hex** vs the spec.

---

## How to run it

```bash
# one-time per project
cd ~/<project>
git worktree add ../<project>-loop -b loop/<project>
cp ROADMAP.template.md ../<project>-loop/ROADMAP.md   # then fill testable rows

# then, in the worktree, paste the LOOP PROMPT (Prompt 1 below).
cd ~/<project>-loop
```

Fan out across projects: one worktree + one pane per project; they're independent.
Teardown a finished loop: `git worktree remove ../<project>-loop`.

**Hard stops** (halt, summarize, wait for a human): ~1M tokens or ~3h wall-clock; a
DB **migration** against an unconfirmed/PROD target — migrations are OK against a
confirmed non-prod dev DB when the rule authorizes it, but PREFLIGHT first (echo the
`DATABASE_URL` host, confirm it's the dev DB; a managed prod host = STOP); a missing
**credential**/decision
(→ blocked, skip the row); a write to a **read-only** system; **real outbound**
(email/SMS/ads/social — drafting is fine, sending is not). For a compliance build,
add: never put PHI in logs or tests.

---

## Prompt 1 — the loop (paste into the worktree)

```
/loop You are helping build out <APP> — and SHIP it, not just write code. The
roadmap for this session is ROADMAP.md in this repo. Project goal / hard rule:
<RULE>. Deploy method: <git | vercel-prod | vercel-deploy-prod>. You run inside a
git worktree on branch loop/<APP>; you own this branch, never touch main except to
merge a finished, green PR. Use the FULL tool surface (Bash/files/git, Web,
MCP via ToolSearch, publish via ~/bin/publish-doc.mjs) — do real work, don't stub.

RESUME CHECK (first turn only): if work is already in flight, read LOOP_LOG.md +
ROADMAP.md, run the full test suite + build, confirm green, and commit any
green-but-uncommitted WIP BEFORE continuing. Never build on an unknown/red tree.

PLAN (you, Opus): claim the first non-terminal row (set it in_progress). Write a
TIGHT, self-contained, TEST-FIRST spec for that ONE row — files, the exact tests,
any tools to call, and the REAL artifact it must produce. The spec is the whole
handoff; the builder sees none of your context.

DO (delegate to Sonnet): spawn a subagent with the spec verbatim (see Prompt 4).
Failing tests first, then code to pass them, nothing outside the spec. It returns
diff + test output + artifact paths.

CHECK (you): FIRST confirm the subagent actually did the work — git status, files
exist, test count went up. Do not trust its self-report (a subagent can claim done
with nothing on disk). Then run the FULL suite + linter/build YOURSELF. A
route-not-found on a prod build that looks impossible = suspect a stale cache; clear
it and re-run. Fail → back to Sonnet, max twice, else row "failed".

VERIFY (you): RUN the thing and assert the real artifact (file non-empty, rows>0,
URL 200, expected status codes incl. 403 on unauthorized). For spec-driven rows,
also run an adversarial spec-verifier (Prompt 2) until every criterion PASSes.
Can't produce it (missing data/cred) → "blocked". (Dev server reaped? run it as a
tracked background task / verify against a clean build && start.)

ACT + SHIP (you): tests green AND artifact verified → commit, PR, squash-merge to
main, pull back. Ship per deploy method, then curl/stat the live URL/file to
confirm. Set the row "done" (sha + shipped+verified) and append one line to
LOOP_LOG.md. Next cycle → PLAN.

ROADMAP COMPLETE → run the 360 capstone (Prompt 3).

HANDOFF (whenever the loop stops — completion, hard stop, or a pile-up of blocked
rows): write HANDOFF.md in the repo root and commit+push it with the branch. git
already gives a dev the code; HANDOFF.md carries what git does NOT — STATE (row
counts + each blocked/failed row's one-line why), LAND HERE (branch, worktree path,
last sha, how to fetch it), RUN IT (env/dev-DB host, test + build + deploy command
incl. its trap), WHY/DECISIONS (non-obvious calls + approaches tried-and-abandoned
this session), GOTCHAS (project rule + traps hit), and an ordered NEXT ACTIONS
punch-list (unblock steps first, then todo rows). Don't restate the diff; overwrite
HANDOFF.md on each stop, don't append.

HARD STOPS: ~1M tokens / ~3h; DB migration against an unconfirmed/PROD target
(preflight the DATABASE_URL host first; dev DB authorized by the rule = OK, prod =
blocked + human sign-off); missing cred/decision (blocked, skip); write to a
read-only system (blocked); real outbound
(blocked — drafting ok, sending not).
```

## Prompt 2 — adversarial spec-verifier (subagent; opus for compliance)

```
You are an ADVERSARIAL spec-verifier. REFUTE that this is done; default every
criterion to FAIL until you have first-hand evidence. Trust only what you run/read.
WHAT WAS BUILT: <one line>.
CRITERIA (numbered, testable — paste them): <FRs / acceptance>.
EXERCISE IT: run <test cmd> + <build cmd> (exit 0); run/curl <route/page/seed+query>,
auth as <…>; inspect the real artifact <file/rows/URL/status>.
RULES: per criterion return PASS or FAIL + evidence (output, file:line, HTTP code);
no evidence → FAIL. Verify migrations applied, routes return the demanded codes
(e.g. unauthorized → 403, not just hidden), pages render LIVE data. Probe the
negative space — does the gate BLOCK or only hide? Don't trust the builder or a log.
RETURN: `criterion | PASS/FAIL | evidence`, then a GAPS section of every FAIL.
```

## Prompt 3 — the 360 capstone review

```
/loop-360 Run a full 360 spec-coverage audit of <APP>. Source specs: <files>.
1. Map the FULL requirement surface (every FR, the NFRs, compliance/domain rules,
   design tokens, UX states) and find the spec's OWN rollout/milestone/cut-line
   section — that's the scope oracle.
2. Audit coverage with read-only agents (one per spec region, file:line evidence,
   adversarial, default PARTIAL/MISSING). They over-hedge and contradict — re-verify
   every flag yourself in the code before trusting it.
3. Classify each finding: MISS (real, in current scope) · DEFERRED (later milestone
   per the rollout — cite the line) · OVER-DELIVERED · INFRA/human-gated · POLISH.
   Spot-check design tokens hex-by-hex; flag intentional vs accidental divergence.
4. Write docs/SPEC_COVERAGE_360.md and publish it. For a product, also draft the
   forward backlog (deferred by milestone) + any compliance/launch-prep list.
```

## Prompt 4 — module spec (delegated build subagent)

```
You are a build subagent on <APP>, working dir <worktree>. Build EXACTLY this
module — nothing else. I WILL re-verify your work against the filesystem, so do
real work and report real command output.
STACK & CONVENTIONS: <framework, lint, data/service pattern, read-only @core, etc.>
SCOPE: <module goal>. Files you OWN (touch nothing else): <files>.
STEPS (test-first): 1) read <files> for the exact shapes/patterns; 2) write FAILING
tests for the acceptance criteria; 3) minimum code to pass; 4) use real tools if the
spec says so (ToolSearch first) — don't stub.
ACCEPTANCE: <criteria your tests encode>.
GATE (run + paste the tail): <test cmd> (all green), <build cmd> (exit 0), any
artifact assertion. CONSTRAINTS: never touch main; leave changes in the tree (I
commit); no deps; no outbound; no migration unless authorized.
RETURN: files created/modified, verbatim test+build output, artifact paths, and any
criterion you could NOT meet — honesty about a gap beats a false "complete".
```

---

## Spec-driven variant (for products with a PRD)

When the project has a real spec (a PRD with numbered FRs per epic), the roadmap
rows map to spec epics, each row's acceptance IS its epic's FR list, and the
**adversarial spec-verifier (Prompt 2) is mandatory** for the row to count as done
(use opus for security/compliance epics). Keep a `LOOP_LOG.md` ledger (one line per
phase: FRs passed, sha, notes) and treat the PRD's rollout section as the scope
oracle for the eventual 360. This is exactly how a 12-phase HIPAA build shipped end
to end with per-phase FR conformance.
```

# The Loop Playbook

**Autonomous build-and-SHIP loops, one per project, running in parallel.**
Per row: **PLAN → DO → CHECK → VERIFY → ACT+SHIP.**
At roadmap completion: **a 360 capstone review.**

> **v2 (hardened on a 12-phase, spec-driven HIPAA build):** added (1) *verify the
> subagent, not just the artifact* — delegated agents can fabricate a "done"
> report; (2) an *adversarial spec-verifier* gate for spec-driven rows; (3) a
> *resume check* before continuing a mid-flight loop; (4) a *360 capstone review*
> at the end; (5) runtime-verification gotchas (stale caches, reaped dev servers).
> Reusable prompts live beside this file: `LOOP_PROMPT.template.txt`,
> `VERIFIER_PROMPT.template.txt`, `360_REVIEW_PROMPT.template.txt`,
> `MODULE_SPEC.template.txt`.

The problem this solves: you have 10 ideas but can only ship one at a time because parallel work fights over the same working tree, branch, and DB. The fix is three layers:

1. **The loop** — a self-driving `/loop` that walks a project's roadmap row-by-row, specs with Opus, builds with Sonnet, runs TDD, **runs the build to verify the real artifact exists, then deploys per the project's declared method.** (This is your friend's concept, hardened into a full ship engine.)
2. **The full tool surface** — the loop is not a code-only bot. A row can require fetching live data, calling an MCP server (Metorik, GSC, ScrapeCreators, Higgsfield media gen, Canva, Gmail), web search/fetch, or publishing to smashforms. The loop loads those tool schemas via ToolSearch and uses them; it does the real work instead of stubbing it.
3. **Isolation** — every loop runs in its **own git worktree on its own branch**. That is what kills the race conditions. You can run 10 loops in 10 tmux panes and they never touch each other's files, branch, or migrations.

> **Why VERIFY exists (learned the hard way):** the first owenator run finished 8/8 rows with 64/64 tests green — and **zero artifacts on disk**, because the loop unit-tested the CSV/HTML *serializers* but never *ran the build* to emit the files. Green tests ≠ a working thing. The VERIFY step now forces the loop to run the build/generate/publish script and assert the real output (file non-empty, row count > 0, URL 200) before a row counts as done.

---

## Lessons hardened in v2 (a 12-phase, spec-driven build + its 360 review)

The owenator lesson was "green tests ≠ a working thing." The bigger spec-driven run
added five more, each now baked into the prompts:

1. **Verify the SUBAGENT, not just the artifact.** A delegated build subagent
   returned a detailed, confident "done — created/modified ~12 files, build + tests
   green" while `tool_uses` was 1 and **nothing** was on disk (clean `git status`,
   unchanged test count). The orchestrator must confirm a subagent's work against
   the filesystem itself — `git status`, files exist, test count moved — before
   accepting it. Re-run the linter/build yourself, never paste the subagent's word.
   A subagent's self-report is a claim, not evidence.

2. **An adversarial spec-verifier is the real gate for spec-driven work.** When a
   row maps to numbered acceptance criteria (FRs from a PRD/spec), artifact-exists
   isn't enough — spawn a separate verifier whose job is to REFUTE "done" FR-by-FR,
   defaulting every criterion to FAIL without first-hand evidence (use opus for
   security/compliance criteria). It catches "plausible but not actually wired."

3. **Resume discipline.** Picking up a mid-flight loop: establish state FIRST — read
   the log + roadmap, run the full suite/build, confirm green, and commit any
   green-but-uncommitted WIP — before building anything new. Never build on an
   unknown tree.

4. **Verify against the ROLLOUT plan, not just the FR list (the 360).** At the end,
   most "gaps" a read-only audit flags turn out to be **deliberately deferred** by
   the spec's own milestone plan (V1.1/V2), not misses. The 360's real work is
   classifying each finding: MISS vs DEFERRED vs OVER-DELIVERED vs INFRA-gated vs
   POLISH — and catching where the build ran *ahead* of scope, too.

5. **Don't trust read-only audit agents either.** They over-hedge ("not traced" for
   things that exist) and contradict each other. Re-verify every flagged gap in the
   code yourself before it lands in a report.

Plus the small sharp ones: a **stale build cache** (e.g. `.next`) throws false
"route not found" failures — clear it before believing a prod build broke; a **dev
server spawned in a tool call gets reaped** — run it as a tracked background task
and poll, or verify against a clean `build && start`; on a **mock→real data swap**,
split authored *content* (ships as-is), per-record *services* (real backend), and
*empty-state samples* (fallback only) — don't blindly backend-ify content; and on a
design pass, check the **design tokens hex-by-hex** against the spec and flag
intentional vs accidental divergence.

---

## The 360 capstone review (run when the roadmap is complete)

A roadmap finishing is not the end — run a full spec-coverage back-check so "all
rows done" doesn't get mistaken for "the spec is met." Prompt:
`~/playbooks/360_REVIEW_PROMPT.template.txt`. Shape:

1. **Map the full requirement surface** from the source specs — every FR, the NFRs,
   compliance/domain rules, design tokens, UX states — and find the spec's own
   **rollout/milestone/cut-line** section (the scope oracle).
2. **Audit coverage in parallel** (read-only agents, one per spec region, file:line
   evidence, adversarial). Then **re-verify every flag yourself.**
3. **Classify** each finding: MISS (real, fix it) · DEFERRED (later milestone, cite
   the line) · OVER-DELIVERED · INFRA/human-gated · POLISH.
4. **Publish** `SPEC_COVERAGE_360.md` to smashforms; for a real product also draft
   the forward backlog (deferred by milestone) and any compliance/launch-prep list
   as their own docs, so the human has a clear "what's next + what's needed to ship."

---

## Handing off to a dev (HANDOFF.md)

Whenever the loop **stops** — roadmap complete, a hard stop, or a pile-up of blocked
rows a human must clear — it writes a `HANDOFF.md` in the repo root, committed and
pushed with the branch. The point: a dev who clones the branch already has the code
and commit log from git, so HANDOFF.md only carries **what git can't** —

- **STATE** — row counts (done/in_progress/blocked/failed) + each blocked/failed row
  with its one-line *why*; what works, what's stubbed.
- **LAND HERE** — branch, worktree path, last sha, how to fetch the tree.
- **RUN IT** — env/dev-DB host (never a prod URL), install, test cmd, build/dev cmd,
  and the deploy command for this project's method *with its trap* (e.g. `vercel --prod`,
  not a git push).
- **WHY / DECISIONS** — the non-obvious calls + any approaches **tried and abandoned**
  this session, so the dev doesn't re-walk them. This never lands in commits.
- **GOTCHAS** — the project rule + traps hit this session (stale `.next`, local-DB
  `sslmode=no-verify`, a flaky step).
- **NEXT ACTIONS** — an ordered punch-list: unblock steps for each blocked row first,
  then the remaining todo rows; say what to do *first*.

Don't restate the diff; link the 360 report if one ran; overwrite (don't append) on
each stop. This is the bridge between an autonomous loop and a human picking it up —
and unlike a live-session share, it works headless and rides along with the git push.

---

## TL;DR — how to run it

```bash
# 1. one-time per project: create a worktree + roadmap
cd ~/<project>
git worktree add ../<project>-loop -b loop/<project>
cp ~/playbooks/ROADMAP.template.md ../<project>-loop/ROADMAP.md   # then fill in rows

# 2. open a pane, cd into the worktree, paste the loop prompt (below)
cd ~/<project>-loop
# paste: /loop you are helping Marshall build out <project> ...

# 3. repeat per project in its own pane. They run fully in parallel.
```

Hard stops are baked in: **1M tokens, 3 hours, or any DB migration** halts the loop and waits for you. On any stop it leaves a **HANDOFF.md** so you (or a dev) can pick it up cold.

---

## The roadmap (source of truth)

The loop reads work from a **roadmap**. Two supported formats — pick per project:

### Format A — `ROADMAP.md` in the repo (default, no external deps)

A markdown table. The loop owns the `Status` column. This is the default because it lives in the repo, versions with the code, and needs no API keys.

```markdown
| # | Task | Goal / acceptance | Status | Notes |
|---|------|-------------------|--------|-------|
| 1 | Add dosing CSV export | User can export the dosing table as CSV; covered by a unit test on the serializer | todo | |
| 2 | Cache the peptide search index | Search p95 < 50ms on 36-row dataset; test asserts index built once | todo | |
| 3 | Dark-mode toggle persists | Toggle survives reload via localStorage; RTL test | todo | |
```

**Status values** (the state machine):
- `todo` — not started
- `in_progress` — a loop has claimed it (prevents double-pickup)
- `done` — merged to main, tests green
- `blocked` — needs a human / external dependency (creds, decision, DB migration)
- `failed` — failed TDD twice; left for review

### Format B — Google Sheet (when non-engineers edit the roadmap)

Same columns, lives in a Sheet tab. The loop reads/writes via the Sheets API. Use this only when someone who won't touch the repo needs to manage the queue. Heavier (auth, rate limits, no diff history). The prompt template auto-detects which you handed it.

---

## The loop prompt (master template)

The canonical prompt lives in **`~/playbooks/LOOP_PROMPT.template.txt`** — `loop-new.sh`
renders it per project, substituting `{{APP}}`, `{{ROADMAP}}`, `{{RULE}}`, and
`{{DEPLOY}}` (from the manifest). Do **not** hand-paste a copy here — it drifts.
To read the current prompt for any project, open its rendered `LOOP_PROMPT.txt`
in the worktree.

The five-phase cycle the prompt drives:

| Phase | Who | What |
|---|---|---|
| **PLAN** | Opus | Claim the first non-terminal roadmap row; write a tight, self-contained, TDD spec — including any tools the row needs (web/MCP/media/publish) and the **real artifact** it must produce. |
| **DO** | Sonnet | Build exactly the spec, test-first. Uses the full tool surface (loads MCP/web schemas via ToolSearch) when the row needs live data, an asset, or an API call. Returns diff + test output + artifact paths. |
| **CHECK** | Opus | **Confirm the subagent actually did the work** (`git status`, files exist, test count moved — never trust its self-report), then run the full suite + new tests + linter/build *yourself*. Stale-cache false failures → clear & re-run. Two strikes back to Sonnet → else row `failed`. |
| **VERIFY** | Opus | **Run the build/generate/publish and assert the real artifact exists** (file non-empty, rows > 0, asset present, API 200). For spec-driven rows, also run an **adversarial spec-verifier** (FR-by-FR PASS/FAIL, defaults to FAIL; opus for compliance). Green tests alone never count as done. |
| **ACT + SHIP** | Opus | Squash-merge to main, then deploy per the manifest `deploy` field (`git` = run the publish script; `vercel-prod` / `vercel-deploy-prod` = Vercel CLI), then **verify the live URL/file**. Log the cycle. |
| **360 REVIEW** | Opus | *Once the whole roadmap is done* — full spec-coverage back-check; classify gaps MISS/DEFERRED/OVER-DELIVERED/INFRA/POLISH; publish the report + forward backlog. |

Hard stops baked into the prompt: ~1M tokens, 3 hours, DB migration (blocked,
human sign-off), missing cred (blocked, skip), write to a read-only system
(Finale/Metorik → blocked), and **real outbound** (email/SMS/ads/social → blocked;
drafting to Gmail Drafts is fine, sending is not).

---

## Why worktrees are the whole game

Your original loop is **sequential within a project** — it does row 1, then row 2. That's correct: rows in one project often depend on each other and share a DB.

The parallelism you actually want is **across projects**. Ten projects = ten worktrees = ten branches = ten loops, each isolated:

| Without worktrees | With worktrees |
|---|---|
| One working tree, one branch | N trees, N branches |
| Loop B's edits collide with Loop A's uncommitted files | Each loop has its own files |
| Two loops `git checkout` fight | Each pinned to its own branch |
| Shared dev DB → migration races | Each worktree points at its own DB (or skips migrations per hard-stop) |

```bash
git worktree add ../peptidepedia-loop  -b loop/peptidepedia
git worktree add ../owenator-loop      -b loop/owenator
git worktree add ../neuronova-loop     -b loop/neuronova
# 3 panes, 3 loops, zero collisions
```

Cleanup when a loop is done: `git worktree remove ../<project>-loop`.

> Note: per your infra notes, several projects deploy **only** via `vercel deploy --prod` or `vercel --prod` (Peptidepedia, GotXRing, iHeart Workbench, Creative Variation Engine) because git-push deploys wedge. The loop handles this automatically: set the manifest `deploy` field to `vercel-prod` or `vercel-deploy-prod` and the ACT+SHIP step runs the right Vercel CLI command explicitly (never a git-triggered deploy), then verifies the live URL.

---

## Guardrails (learned from your stack)

- **DB migrations are a hard stop, always.** Your notes are littered with migration/superuser blockers (QBVault, Venture Launch OS). Never let an autonomous loop run one.
- **Never inline base64 blobs into Postgres** (Neon 64MB cap — Creative Variation Engine). If a spec implies storing images in a DB column, mark blocked.
- **Keep the spec to one row.** The single biggest failure mode of autonomous loops is scope creep. Opus's job in PLAN is to say no.
- **TDD is the gate, not a suggestion.** "Tests pass" is the only thing that lets ACT merge. No tests written → the row is underspecified → bounce it back in PLAN.
- **Read-only integrations stay read-only** (Finale, Metorik). A row that implies a write to a read-only system → blocked.
- **Two strikes = failed.** Don't let a loop grind on one row forever; that's how you burn 1M tokens on a typo.
- **VERIFY the artifact, always.** Tests green is necessary, not sufficient. A row is done only after the loop *ran* the build/generate/publish and confirmed a real, non-empty artifact (file/rows/asset/URL). This is the gap that bit the first owenator run.
- **Tools are fair game, sending is not.** The loop may read live data, call read-only MCPs, generate assets, fetch docs, and publish dashboards. It may **draft** outbound into Gmail Drafts. It must **never auto-send** email/SMS/ads/social posts or run a DB migration — those are blocked for human sign-off.

---

## Per-project instantiation

Each active project gets: a roadmap source, a one-line goal statement, and any project-specific hard rule. Fill `ROADMAP.md` rows, then fire the loop. Table below is the starting map — projects with an existing build list reuse it; the rest get a fresh `ROADMAP.md`.

| Project | Repo | Roadmap source | Project-specific rule for the loop |
|---|---|---|---|
| Peptidepedia | `~/peptidepedia` | new `ROADMAP.md` | deploy via `vercel --prod` only; data = two flat TS arrays |
| OWENATOR | `~/owenator` | new `ROADMAP.md` | ArcGIS feed is live; Places match is ¼-mi radius |
| NeuroNova | `~/neuronova` | existing `BUILD_LIST.md` | schema + stages 1–2 next; Neon state machine |
| GotXRing | `~/gotxring-com` | new `ROADMAP.md` | deploy ONLY `vercel deploy --prod` |
| Creative Variation Engine | (CVE repo) | new `ROADMAP.md` | never base64 PNGs into Postgres; work on its feature branch |
| iHeart Content Workbench | (seo repo) | new `ROADMAP.md` | deploy ONLY `vercel deploy --prod` |
| Deal Intake | `~/deal-intake` | the 24-finding security JSON | security fixes are pre-approved; execute on "go" |
| ServantX | (servantx repo) | new `ROADMAP.md` | HIPAA — no PHI in logs/tests |
| Mindwave | `~/tribe-internal` | new `ROADMAP.md` | api.mndwv.com contract is fixed |
| QBVault | `~/qbvault` | new `ROADMAP.md` | **DB work is blocked** until superuser DB created |
| Redbird app | (rbrd repo) | new `ROADMAP.md` | Wintelligence DB is read-only for app features |

(Add the rest of the portfolio the same way — one row per project, same template.)

---

## The repeatable process (SOP)

The whole thing is a registry + four scripts + one slash command. Onboarding a new
project is **add one line, run two commands.** Nothing is re-derived by hand.

**Source of truth:** `~/playbooks/loops.manifest` — one line per project:
`name | repo_path | deploy | rule`. Add a line to add a project.

**The scripts** (`~/playbooks/bin/`, all idempotent):

| Command | Does |
|---|---|
| `loop-new.sh <proj>` / `--all` | creates worktree + branch, scaffolds `ROADMAP.md` (never clobbers), `LOOP_LOG.md`, renders `LOOP_PROMPT.txt` with the rule baked in |
| `loop-launch.sh <proj>` / `--all` | one tmux window per project, starts `claude`, loads its prompt into the pane's paste buffer |
| `loop-status.sh` | the board — per-project todo/in_progress/done/failed/blocked counts + last log line |
| `loop-cleanup.sh <proj>` | tears down a finished worktree + branch (warns on unmerged commits) |

**The judgment step** stays with Claude: `/loop-roadmap <proj>` drafts real, testable
roadmap rows from the project's current state (memory, BUILD_LIST, security JSON, repo).

### The 6-step cycle (same every time)

```bash
# 1. register — add a line to ~/playbooks/loops.manifest
# 2. scaffold
~/playbooks/bin/loop-new.sh <proj>
# 3. fill the roadmap (in Claude Code)
/loop-roadmap <proj>          # then eyeball the rows, prune scope creep
# 4. launch
~/playbooks/bin/loop-launch.sh <proj>     # or --all to fan out
#    attach, press  prefix + ]  in each pane to paste the loop prompt, Enter
# 5. watch
~/playbooks/bin/loop-status.sh
# 6. teardown when the roadmap is all done/blocked
~/playbooks/bin/loop-cleanup.sh <proj>
```

Fan everything out at once: `loop-new.sh --all` → `/loop-roadmap` each →
`loop-launch.sh --all`. The split — deterministic plumbing in shell, judgment in
Claude — is what makes it repeatable instead of a one-off paste.

## Operating it

- **Start small:** run the loop on ONE project end-to-end, watch one full PLAN→ACT cycle merge, then fan out.
- **Fan out:** one tmux pane per project, each in its worktree. They're independent.
- **Audit:** `LOOP_LOG.md` per worktree gives you the per-cycle ledger; the Status column gives you the live board.
- **Resume:** a loop that hit a hard stop can be re-run later — it picks up at the first non-terminal row.
```

# Loop Protocol

Autonomous **build-and-SHIP loops** for AI coding agents: a self-driving `/loop`
that walks a project's roadmap row by row, specs each row, builds it test-first,
verifies the *real* result, ships it — then runs a 360 spec-coverage review when the
roadmap is done.

**Per row:** PLAN → DO → CHECK → VERIFY → ACT+SHIP. **At the end:** a 360 review.

## Start here

- **[`LOOP_PROTOCOL.md`](LOOP_PROTOCOL.md)** — the self-contained guide. Doctrine,
  the five hard lessons, how to run it, and all four prompts inline. **Read this
  first.** (Web view: https://preview.smashforms.com/sites/loop-protocol/)
- **[`loop-build-playbook.md`](loop-build-playbook.md)** — the longer playbook:
  worktree isolation, the registry+scripts SOP, guardrails.
  (Web view: https://preview.smashforms.com/sites/loop-playbook/)

## Prompts (copy-paste these)

| File | Use |
|------|-----|
| [`SPEC_ENGINE_PROMPT.template.txt`](SPEC_ENGINE_PROMPT.template.txt) | The spec engine — triage (A Standalone / B Agent-Driven / C Agents-Only) → discovery modules → archetype-matched, LOCKed spec. Run via `/loop-spec <proj>`. |
| [`LOOP_PROMPT.template.txt`](LOOP_PROMPT.template.txt) | The master loop prompt. Paste into a project worktree. Opens with a SPEC CHECK gate. |
| [`VERIFIER_PROMPT.template.txt`](VERIFIER_PROMPT.template.txt) | Adversarial spec-verifier subagent (refute "done" FR-by-FR). |
| [`360_REVIEW_PROMPT.template.txt`](360_REVIEW_PROMPT.template.txt) | The 360 capstone spec-coverage audit. |
| [`MODULE_SPEC.template.txt`](MODULE_SPEC.template.txt) | Handoff spec for a delegated build subagent. |
| [`ROADMAP.template.md`](ROADMAP.template.md) | The roadmap table (loop's source of truth). |

## Scaffolding scripts (`bin/`)

Deterministic plumbing; judgment stays with the agent.

| Script | Does |
|--------|------|
| `bin/loop-new.sh <proj>` | worktree + branch, scaffold ROADMAP.md / LOOP_LOG.md / render LOOP_PROMPT.txt |
| `bin/loop-launch.sh <proj>` | tmux window per project, starts the agent, loads the prompt |
| `bin/loop-status.sh` | the board — per-project todo/in_progress/done/failed/blocked |
| `bin/loop-cleanup.sh <proj>` | tear down a finished worktree + branch |

Project registry lives in `loops.manifest` (one line per project:
`name | repo_path | deploy | rule`). It's gitignored — copy `loops.manifest.example`
to `loops.manifest` and add your own projects.

## Quickstart

```bash
# 1. register your project in loops.manifest (see the .example)
# 2. scaffold a worktree + roadmap + specs/
bin/loop-new.sh <project>
# 3. lock a spec (skip if the project already has a BIBLE/PRD)
/loop-spec <project>     # triage → discovery → specs/<project>-spec.md → LOCK
# 4. fill ROADMAP.md with tight, testable rows (mapped to the spec's Build Plan)
/loop-roadmap <project>
# 5. open the worktree, paste LOOP_PROMPT.txt, let it run
#    (its SPEC CHECK builds against the locked spec; if none, it offers the engine)
# 6. watch the board
bin/loop-status.sh
```

## Worked example

See **[`examples/`](examples/)** for a filled-in `ROADMAP.example.md` (good rows
across every status — testable acceptance, one-PR-each) and a matching
`LOOP_LOG.example.md` ledger that shows what each cycle's audit line looks like.

## Contributing

See **[`CONTRIBUTING.md`](CONTRIBUTING.md)** — the protocol gets better every time a
loop teaches us something. The rule: a lesson with no prompt change is just a story;
wire the fix into the prompt.

---

The whole thing is provider-agnostic — the prompts work with any capable coding
agent that can spawn subagents, run a shell, and edit files.

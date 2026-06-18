# Contributing

This repo is a living methodology — the prompts get better every time a loop
teaches us something. Keep it tight and evidence-driven.

## What to contribute

- **A hard lesson.** If a loop failed in a new way (a false "done", a gate that
  didn't gate, a verification gap), add it to the "five hard lessons" in
  `LOOP_PROTOCOL.md` *and* bake the fix into the relevant prompt step. A lesson
  with no prompt change is just a story — wire it in.
- **A prompt improvement.** Tighten a step, close a loophole, or clarify a handoff.
  Keep prompts copy-pasteable and provider-agnostic (no tool names that only exist
  in one agent).
- **A script fix** in `bin/` (keep them idempotent — safe to re-run).
- **A worked example** under `examples/` if you ran a loop that's instructive.

## House rules

1. **Evidence over assertion.** The whole protocol exists because green tests, a
   subagent's "done", and a clean build summary are all *claims*. Hold contributions
   to the same bar — show the failure/output that motivated a change.
2. **One concern per PR.** Same discipline the loop enforces on itself: one tight,
   reviewable change.
3. **Don't commit personal state.** `loops.manifest` (your real project list) is
   gitignored — edit `loops.manifest.example` if the *format* changes, never commit
   your live registry, repo paths, or credentials.
4. **Generalize.** Strip project- or org-specific details from anything that lands
   in a prompt or the protocol doc — it should read clean for a dev on day one.

## Flow

```bash
git checkout -b lesson/<short-name>     # or prompt/… or fix/…
# make the change + update LOOP_PROTOCOL.md if it changes behavior
git commit -m "lesson: <what the loop taught us>"
# open a PR; in the body, paste the output/failure that motivated it
```

If you change the cycle or a gate, mirror it in both `LOOP_PROTOCOL.md` (the
self-contained guide) and `loop-build-playbook.md` so they don't drift.

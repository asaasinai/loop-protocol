# {APP} — Roadmap

Goals: {one or two sentences on what {APP} is for — the loop re-reads this every cycle}

The loop owns the **Status** column. Values: `todo` · `in_progress` · `done` · `blocked` · `failed`.
One row = one tight spec = one PR. Keep "Goal / acceptance" testable.

If a locked spec exists, source rows 1:1 from its **Dev Task List (T#)** — put the
spec's T# in **Spec ref** and use that task's **Definition of Done** items as the
row's testable "Goal / acceptance". A row without a testable acceptance is not ready.

| # | Spec ref (T# / INV#) | Task | Goal / acceptance (must be testable) | Status | Notes |
|---|----------------------|------|--------------------------------------|--------|-------|
| 1 |                      |      |                                      | todo   |       |
| 2 |                      |      |                                      | todo   |       |
| 3 |                      |      |                                      | todo   |       |

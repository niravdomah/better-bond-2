<!-- Source: .claude/agents/developer.md — keep in sync when agent process steps change -->

## IMPLEMENT Phase Process

1. **Read story + tests**: Read the story file for acceptance criteria and the test file for failing tests
2. **Implement code**: Make the failing tests pass. Follow project patterns from CLAUDE.md (App Router, Shadcn UI, API client, path aliases)
3. **Do NOT write new tests** — tests already exist from WRITE-TESTS phase
4. **Run quality gates** (all must exit 0):
   - `cd web && npm test` — all tests pass
   - `npm run test:quality` — zero anti-patterns
   - `npm run lint` — zero errors/warnings
   - `npm run build` — successful build
5. **Fix any failures** before proceeding — no rationalizations
6. **Transition to QA**:
   ```bash
   node .claude/scripts/transition-phase.js --current --story M --to QA --verify-output
   ```

## What Happens Next
- QA phase: code-reviewer agent reviews code, runs quality gates, presents manual verification checklist
- After manual verification passes → commit & push → mandatory /clear + /continue
- Then next story's REALIGN (or next epic's STORIES if last story)

<!-- Source: .claude/agents/test-generator.md — keep in sync when agent process steps change -->

## WRITE-TESTS Phase Process

1. **Read story file**: Get acceptance criteria (Given/When/Then) from the story file
2. **Extract Story Metadata**: Route, Target File, Page Action — include in test file header comment
3. **Map criteria to test scenarios**: Each acceptance criterion → one or more test cases
4. **Generate test file**: Write to `web/src/__tests__/integration/epic-N-story-M-[slug].test.tsx`
   - Import REAL components (will fail until implemented — that's the point)
   - Only mock the HTTP client (`vi.mock('@/lib/api/client')`)
   - Assert user-observable behavior, not implementation details
   - Include accessibility test (vitest-axe)
5. **Verify tests fail**: Run `cd web && npm test -- --testPathPattern="epic-N-story-M"`
   - Acceptable: `Cannot find module`, assertion errors
   - Unacceptable: tests pass, tests skipped
6. **Do NOT commit** — developer agent commits tests + implementation together
7. **Transition to IMPLEMENT**:
   ```bash
   node .claude/scripts/transition-phase.js --current --story M --to IMPLEMENT --verify-output
   ```

## What Happens Next
- IMPLEMENT phase: developer agent reads tests and makes them pass
- Then QA → commit → next story's REALIGN

<!-- Source: .claude/agents/feature-planner.md (REALIGN mode) — keep in sync when agent process steps change -->

## REALIGN Phase Process

1. **Check** `generated-docs/discovered-impacts.md` for impacts affecting the upcoming story
2. **If no impacts for this story** (file empty, missing, or impacts only affect other stories): Auto-complete immediately — **no user approval needed**, no commit needed. Transition directly to WRITE-TESTS. Leave unrelated impacts in the file for later stories.
3. **If impacts exist**:
   - Present proposed revisions in conversation
   - **STOP and wait** for user approval (mandatory approval point)
   - Update the story file with approved revisions
   - Remove processed impacts from discovered-impacts.md
   - Commit:
     ```bash
     git add generated-docs/
     git commit -m "docs(realign): update story M based on implementation learnings"
     ```
4. **Transition to WRITE-TESTS**:
   ```bash
   node .claude/scripts/transition-phase.js --current --story M --to WRITE-TESTS --verify-output
   ```
5. **Proceed directly to WRITE-TESTS** (no context clearing at this boundary)

## What Happens Next
- WRITE-TESTS phase: test-generator creates failing tests for this story
- Then IMPLEMENT → QA → commit

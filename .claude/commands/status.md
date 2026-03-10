---
description: Show current workflow progress - displays which phase you're in and what's completed
model: haiku
---

You are showing a developer their current position in the TDD workflow. This is display-only - do not take any action.

## Step 1: Check Authoritative State

First, check the authoritative workflow state file:

```bash
node .claude/scripts/transition-phase.js --show
```

This returns the state from `generated-docs/context/workflow-state.json`, which is the **source of truth** for workflow progress.

The state includes:
- `currentPhase` - The phase the story/epic is at
- `phaseStatus` - Whether work has started: `"ready"`, `"in_progress"`, or `"complete"`

## Step 2: Get Supplementary Context

For additional context (epic details, acceptance test counts), run the detection script:

```bash
node .claude/scripts/detect-workflow-state.js json
```

## Step 3: Display Status

Parse the JSON output and display a human-readable summary.

### If No Spec Found (error: "no_spec")

```
=== Workflow Status ===

No feature spec found in documentation/

To get started:
  1. Create a feature spec in documentation/
  2. Run /start to begin the TDD workflow
```

### If Epics Exist

Display:
1. **Feature spec path** from `spec`
2. **Wireframe count** from `wireframes`
3. **Epic table** from `epics[]` array showing:
   - Epic name
   - Current phase
   - Story count
   - Test count
   - Acceptance tests (checked/total)
4. **Current position** from `resume` object
5. **Phase status** - Use the `phaseStatus` field to determine the label:
   - `"in_progress"` → **"Current Phase: {PHASE}"** (work is actively happening)
   - `"ready"` → **"Next Phase: {PHASE}"** (transitioned but work not yet started)
   - `"complete"` → **"Feature Complete"**
6. **Next steps** based on current phase

Example output:

```
=== Workflow Status ===

Feature: documentation/my-feature.md
Wireframes: 4

=== Epic Progress ===

Epic                  | Phase    | Stories      | Current Story
--------------------- | -------- | ------------ | ---------------
epic-1-dashboard      | COMPLETE | 3/3 complete | -
epic-2-payments       | IMPLEMENT| 1/4 complete | story-2-form (IMPLEMENT)
epic-3-reports        | PENDING  | 0/? defined  | -

=== Current Position ===

Resume: Epic 2 (epic-2-payments), Story 2 (story-2-form)
Current Phase: IMPLEMENT
Action: Run /continue to resume workflow

=== Commands ===

/continue      - Resume workflow from current position
/quality-check - Run all quality gates
```

**Alternative: If `phaseStatus` is `"ready"` (work not yet started):**

```
=== Current Position ===

Resume: Epic 2 (epic-2-payments), Story 2 (story-2-form)
Next Phase: IMPLEMENT
Action: Run /continue to start implementation
```

### If All Complete

```
=== Workflow Status ===

Feature: documentation/my-feature.md

Feature complete!

Total: 3 epics, 9 stories (all complete), 35 acceptance tests passed

Next step: Start a new feature with /start
```

## Phase Descriptions

If the user needs clarification, explain phases in plain language:

| Phase | Level | Description |
|-------|-------|-------------|
| INTAKE | Feature | Gathering requirements and producing the Feature Requirements Specification (mandatory, once) |
| DESIGN | Feature | Generating missing artifacts and copying user-provided ones (mandatory, once) |
| SCOPE | Feature | Breaking down the feature into epics (no stories yet) |
| STORIES | Epic | Defining stories and acceptance criteria for the current epic |
| REALIGN | Story | Reviewing discovered impacts before the current story (auto-completes if none) |
| WRITE-TESTS | Story | Generating executable tests for the current story |
| IMPLEMENT | Story | Writing code to make the current story's tests pass |
| QA | Story | Code review, quality gates, and committing the current story |
| COMPLETE | Story | Story complete, advancing to next story or next epic |
| PENDING | Story | Story not yet started |

**Workflow (4 stages):**
1. INTAKE (once) → DESIGN (once) → SCOPE (epics only)
2. Per-Epic: STORIES (define stories for current epic)
3. Per-Story: REALIGN → WRITE-TESTS → IMPLEMENT → QA → commit

## DO

- Show clear, formatted output
- Include acceptance test progress (checked/total)
- Always suggest next action (`/continue` or `/start`)
- Keep output concise

## DON'T

- Take any action (this is display-only)
- Run tests (that's for `/continue` to do)
- Resume or launch agents
- Show raw JSON to the user

## Related Commands

- `/continue` - Resume workflow from current position
- `/start` - Start TDD workflow from beginning
- `/quality-check` - Run all quality gates

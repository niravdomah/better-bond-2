---
description: Resume interrupted TDD workflow
---

You are helping a developer resume the TDD workflow from where it was interrupted.

**Read and follow all rules in [orchestrator-rules.md](../shared/orchestrator-rules.md) — they are mandatory.**

## Workflow Reminder

The TDD workflow has four stages:

0. **Requirements gathering**: INTAKE (intake-agent → intake-brd-review-agent)
1. **One-time setup**: DESIGN (mandatory) → SCOPE (define all epics, no stories yet)
2. **Per-epic**: STORIES (define stories for the current epic only)
3. **Per-story iteration**: REALIGN → WRITE-TESTS → IMPLEMENT → QA → commit → (next story)

After QA passes for a story:

- If more stories in epic → REALIGN for next story
- If no more stories but more epics → STORIES for next epic
- If no more stories and no more epics → Feature complete!

## Step 1: Validate Workflow State

First, check if workflow state exists and is valid:

```bash
node .claude/scripts/transition-phase.js --show
```

### If `status: "no_state"` or state appears stale:

**Automatically attempt to repair the state first:**

```bash
node .claude/scripts/transition-phase.js --repair
```

If repair succeeds, show the user the detected state and ask them to confirm before proceeding.

If repair fails (no artifacts found), ask the user:

> "No workflow state or artifacts found. Would you like to start fresh with `/start`, or describe the current state so I can help you continue?"

**Important:** After repair, check the **confidence level** in the output:

- `"confidence": "high"` - State is reliable, show summary and proceed
- `"confidence": "medium"` - Show the `detected` and `assumed` arrays, ask user to confirm
- `"confidence": "low"` - **REQUIRE** user to verify before proceeding, show warning prominently

### If state exists (high confidence):

Display a brief summary and **proceed immediately** — no confirmation needed:

```
Resuming: Epic [N], Story [M], Phase: [phase]
```

### If state exists (medium/low confidence or user reports incorrect):

Ask the user to confirm. If wrong, use `--repair` or ask them to describe the correct state.

## Step 1.5: Reconstruct Progress Display

After validating workflow state, reconstruct the TodoWrite progress display (see shared rules for the script command and pattern). This is essential because TodoWrite state is lost on `/clear`.

## Step 2: Detect Detailed State (optional)

For supplementary context beyond `workflow-state.json`, you can run the detection script. **Skip this step if `workflow-state.json` provided high-confidence state in Step 1** — it's only useful when you need artifact-level detail (e.g., story-by-story progress within an epic).

```bash
node .claude/scripts/detect-workflow-state.js json
```

This provides:

- `spec`: Path to feature specification
- `intake`: Manifest and FRS presence
- `design`: Which design artifacts exist
- `epics[]`: Array with each epic's name, phase, story-level states, acceptance test progress
- `resume.epic` / `resume.phase` / `resume.action`: Where to pick up

**Note:** The `workflow-state.json` file is authoritative. The detection script provides supplementary information but should not override the state file.

## Step 3: Resume with Appropriate Agent

Based on `workflow-state.json`, determine the agent and context:

| Phase | Agent | Context to Provide |
|-------|-------|-------------------|
| INTAKE | `intake-agent` or `intake-brd-review-agent` | See INTAKE routing below |
| SCOPE | `feature-planner` | Spec path |
| DESIGN | See DESIGN routing below | Manifest-driven |
| STORIES | `feature-planner` | Epic number, spec path |
| REALIGN | `feature-planner` | Epic number, story number, discovered-impacts.md path |
| WRITE-TESTS | `test-generator` | Epic number, story number, story file path |
| IMPLEMENT | `developer` | Epic, story, test file path, failing tests (see below) |
| QA | `code-reviewer` | Epic number, story number, files changed |
| COMPLETE | — | Check next action from transition output |

Always provide: current epic number/name, current story number/name (from state), relevant file paths.

### For INTAKE phase:

INTAKE has two sequential agents. Determine which one to resume based on artifacts:

1. **Check if `generated-docs/context/intake-manifest.json` exists:**
   - **No** → Recover onboarding context (see below), then resume with **intake-agent** using scoped calls (see start.md Step 4a for the up-to-3-call pattern)
   - **Yes** → Check step 2

2. **Check if `generated-docs/specs/feature-requirements.md` exists:**
   - **No** → Resume with **intake-brd-review-agent** using scoped calls (see start.md Step 4b for the up-to-3-call pattern)
   - **Yes** → INTAKE is complete. The state should be DESIGN, not INTAKE — check if the transition was missed. If both artifacts exist, inform the user that INTAKE appears complete and proceed to the next phase (DESIGN).

#### Recovering onboarding context (no manifest yet)

The `onboardingPath` and `projectDescription` variables from `/start` are session-only and lost on `/clear`. When resuming intake-agent before the manifest exists, recover them:

**Step 1 — Infer `onboardingPath` from `documentation/`:**
- If `documentation/prototype-src/` contains subdirectories → `onboardingPath = "prototype"`
- Else if `documentation/` contains substantive files (not just `.gitkeep`) → `onboardingPath = "docs"`
- Else → `onboardingPath = "qa"`

**Step 2 — Recover `projectDescription`:**
- If `onboardingPath` is `"docs"` or `"prototype"` → `projectDescription = null` (the docs serve as the project description)
- If `onboardingPath` is `"qa"` → the user's free-text description is lost. Re-ask:
  > "We're picking up where we left off on requirements. I don't have the project description from last session — could you give me the elevator pitch again? Who's it for, what does it do, what's the core problem it solves."

  Capture the response as `projectDescription`.

**Step 3 — Resume the up-to-3-call pattern from the beginning.** Call A (scan) is idempotent and safe to re-run. Pass the recovered `onboardingPath` and `projectDescription` into Call B exactly as start.md Step 4a specifies.

After the resumed agent completes:
- If intake-agent just finished → invoke intake-brd-review-agent (same scoped-call pattern as start.md Step 4b)
- If intake-brd-review-agent just finished → instruct user to `/clear` then `/continue` (clearing boundary #1)

### For DESIGN phase:

DESIGN is a multi-agent phase that uses **parallel Call A execution**. See the [DESIGN Execution Model](../shared/orchestrator-rules.md#design-execution-model--parallel-call-a) in orchestrator-rules.md for the full launch sequence.

1. **Read the intake manifest:**
   ```bash
   cat generated-docs/context/intake-manifest.json
   ```

2. **Check which artifacts with `generate == true` are still missing.** Use the artifact-to-agent mapping table in [orchestrator-rules.md § DESIGN Artifact-to-Agent Mapping](../shared/orchestrator-rules.md#design-artifact-to-agent-mapping) to determine output paths and which agent handles each artifact. Check whether each agent's expected output file exists on disk.

3. **For user-provided files that need copying** (`generate == false` + `userProvided` set): use the copy script to copy to `generated-docs/specs/` with a source header before invoking agents:
   ```bash
   node .claude/scripts/copy-with-header.js --from "<userProvided-path>" --to "generated-docs/specs/<target-filename>"
   ```
   See the shared rules mapping for the copy-vs-generate decision logic.

4. **Determine resumption strategy based on what exists:**

   a. **No outputs exist yet** — DESIGN hasn't produced anything. Follow the full parallel execution model: launch all needed Call A invocations in parallel (Step 3 of the execution model).

   b. **Some outputs exist, some don't** — Partial completion (interruption occurred between agent completions). Launch Call A **only for agents whose output is missing**. Also check for `web/src/types/api-generated.ts` — if `api-spec.yaml` exists but `api-generated.ts` doesn't, include `type-generator-agent` in the set of agents to re-run. When they return, present approvals for all agents — for already-complete agents, read their existing output files and construct summaries. Follow the execution model from Step 4 onward.

   c. **All agent outputs exist but dependent agents haven't run** — Check for both: `web/src/mocks/handlers.ts` (when `mockHandlers == true`) and `web/src/types/api-generated.ts` (when `api-spec.yaml` exists). Launch whichever agents are missing — `mock-setup-agent` and/or `type-generator-agent`. They can run in parallel since they write to different paths.

   d. **All outputs exist and DESIGN → SCOPE transition wasn't run** — DESIGN is complete. Run the finalize step (commit any uncommitted files, transition to SCOPE).

5. **If all generated artifacts exist and transition was already run:** DESIGN is fully complete — the state should be SCOPE, not DESIGN. Inform the user and proceed to SCOPE.

For the scoped-call patterns and finalize procedure, see [orchestrator-rules.md § DESIGN Scoped Calls](../shared/orchestrator-rules.md#design-scoped-calls) and [Finalize DESIGN](../shared/orchestrator-rules.md#finalize-design) in the shared rules.

### For SCOPE through COMPLETE phases:

Use the scoped-call patterns defined in [orchestrator-rules.md § Per-Phase Scoped Call Prompts](../shared/orchestrator-rules.md#per-phase-scoped-call-prompts). The shared rules contain the full call prompts for: SCOPE, STORIES, REALIGN, WRITE-TESTS, IMPLEMENT, QA, and COMPLETE.

## Step 4: Remind Agent to Update State

**Critical:** Before handing off to an agent, remind them:

> "When you complete this phase, you MUST update the workflow state by running:
> ```bash
> # For epic-level phases (SCOPE, STORIES):
> node .claude/scripts/transition-phase.js --epic [N] --to [NEXT_PHASE]
>
> # For story-level phases (REALIGN, WRITE-TESTS, IMPLEMENT, QA):
> node .claude/scripts/transition-phase.js --epic [N] --story [M] --to [NEXT_PHASE]
> ```
> Do not proceed to the next phase without running this command."

## Script Execution Verification

**All transition scripts output JSON. Always verify the result before proceeding** (see [orchestrator-rules.md § Script Execution Verification](../shared/orchestrator-rules.md#script-execution-verification) for the full rules):

1. `"status": "ok"` = Success, proceed to next step
2. `"status": "error"` = **STOP**, report the error to the user
3. `"status": "warning"` = Proceed with caution, inform user

**Troubleshooting:**
- Check current state: `node .claude/scripts/transition-phase.js --show`
- Validate artifacts: `node .claude/scripts/validate-phase-output.js --phase <PHASE> --epic <N>`
- Repair if needed: `node .claude/scripts/transition-phase.js --repair`

## Error Handling

- **State file missing:** Use `--repair` to reconstruct from artifacts
- **State appears wrong:** Ask user to confirm or correct
- **Script fails:** Ask user to describe current state manually
- **Invalid transition:** Show allowed transitions and ask user what to do

## DO

- Always validate state at the start of the session
- Auto-proceed on high confidence state (no confirmation needed)
- Commit work before handing off to the next agent
- Remind agents to use the transition script
- Use scoped calls for ALL interactive agents (not just IMPLEMENT and QA)

## DON'T

- Auto-approve anything on behalf of the user
- Skip state validation
- Trust artifact detection over the state file
- Proceed if the user says the state is wrong
- Stop for context clearing at non-boundary phase transitions

## Related Commands

- `/start` - Start TDD workflow from the beginning
- `/status` - Show current progress without resuming
- `/quality-check` - Validate all 5 quality gates

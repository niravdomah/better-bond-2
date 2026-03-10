---
description: Start the TDD workflow - begins with INTAKE to gather requirements, then proceeds through DESIGN, SCOPE, and implementation
---

Start the feature development workflow.

**Read and follow all rules in [orchestrator-rules.md](../shared/orchestrator-rules.md) — they are mandatory.**

## Workflow Overview

The workflow has four stages:

**Stage 0: Requirements gathering (INTAKE)**
```
/start → [onboarding routing] → [intake-agent] → [intake-brd-review-agent]
                                              INTAKE
```
- Orchestrator: Welcomes user, routes between "share docs", "prototype import", and "guided Q&A" paths
- intake-agent: Scans `documentation/`, orchestrator asks checklist questions (with project context), agent produces manifest
- intake-brd-review-agent: Reviews completeness, orchestrator asks clarifying questions, agent produces FRS

**Stage 1: One-time setup (DESIGN → SCOPE)**
```
/continue → [design-api-agent]       ─┐
            [design-style-agent]    ├─ parallel Call A → sequential approvals → parallel Call B ─┐
            [design-wireframe-agent] ─┘        DESIGN (conditional per manifest)                 ├─ feature-planner
            [type-generator-agent]  ── autonomous (after spec approved) ─────────────────────────┘    SCOPE
```
- DESIGN (mandatory): Orchestrator reads intake manifest, launches agents in parallel (API + Style + Wireframe Call A simultaneously), copies user-provided files when generate=false. After spec approval, type-generator-agent runs autonomously to produce typed API endpoints
- SCOPE: Define ALL epics (no stories yet) → user approves the epic list

**Stage 2: Per-epic (STORIES)**
```
For each epic:
  feature-planner (STORIES) → Define stories for THIS epic → user approves
```

**Stage 3: Per-story iteration (REALIGN → WRITE-TESTS → IMPLEMENT → QA)**
```
For each story in the epic:
  feature-planner → test-generator → developer → code-reviewer → commit & push
      REALIGN         WRITE-TESTS     IMPLEMENT      QA
```

**REALIGN:** Reviews any discovered impacts from previous stories and revises the upcoming story. Auto-completes if no impacts exist.

This ensures:
- Requirements gathered and reviewed before any development
- Full epic scope visibility before story implementation begins
- Stories defined per-epic (not all upfront) for flexibility
- Tests written immediately before each story (true TDD)
- Quality gates always pass (no skipped tests)
- One commit per story after QA passes
- Early feedback through per-story review
- Faster pivots - discover issues per-story, not per-epic
- Implementation learnings feed back into future story planning via REALIGN

## What to Do

### Step 0: Ensure Setup Is Complete

Before starting the workflow, verify that the project environment is ready. Check these two indicators:

1. `web/node_modules/` exists (dependencies installed)
2. `.claude/preferences.json` exists (git preferences configured)

If **both** exist, skip to Step 1 with a brief note: "Project setup is complete. Starting workflow."

If **either** is missing, run `/setup` first (invoke it via the Skill tool). If setup fails, stop and help the user resolve the issue — do not proceed into the workflow with a broken environment.

> **CRITICAL — DO NOT STOP AFTER SETUP:** When `/setup` completes successfully, you MUST immediately continue to Step 1 below in the same response. Do NOT output `[Logs saved]` and wait. Do NOT treat setup completion as a stopping point. Do NOT ask the user what to do next. The `/setup` skill handles only environment setup — your job in `/start` is not done until you reach the STOP marker at Step 5. After the Skill tool returns, proceed directly to Step 1.

### Step 1: Initialize Workflow State

**Initialize the workflow state file.** This ensures `/continue` can resume the workflow if interrupted.

**Important:** This command must run from the **project root** (not `web/`). If setup just completed, the working directory may have shifted. Do NOT prepend `cd ..` — instead, use the project root path directly:

```bash
node .claude/scripts/transition-phase.js --init INTAKE
```

If state already exists, the script returns `"status": "exists"` - this is fine, proceed with the workflow.

### Step 2: Initialize Progress Display

After initializing workflow state, display the TodoWrite progress list (see shared rules for the script command and pattern).

---

### Step 3: Welcome and Onboarding Routing

Display a welcome message to the user:

> "Welcome to Stadium 8. We'll guide you through requirements, architecture, and test-first development. Let's start by capturing what you're building."

Then ask a routing question using `AskUserQuestion`:

- **Question:** "How would you like to get started?"
- **Options:**
  - "I have existing docs to share" — description: "Copy project materials (specs, requirements, wireframes, API docs) into the documentation/ folder"
  - "I have a prototype repo to import" — description: "Import artifacts from a prototyping tool repo (docs, design tokens, React source)"
  - "Let's build requirements together" — description: "I'll ask questions and we'll define the requirements from scratch"

---

#### Option A: Share Existing Materials

If the user chose "I have existing docs to share":

1. Tell the user:
   > "Drop whatever you have into the `documentation/` folder — feature specs, requirements docs, API schemas, wireframes, design files, meeting notes. Anything goes. I'll work with whatever's there."

2. Use `AskUserQuestion`:
   - **Question:** "Let me know when your files are in place."
   - **Options:** "Ready, I've added my files" / "Actually, let's do guided Q&A instead"

3. If "Ready": Proceed to **Step 4** (Call A will detect Mode 1 or 2 based on what was added).

4. If "Actually, let's do guided Q&A instead": Switch to the **Option C** flow below.

Store the routing result: `onboardingPath = "docs"`. Set `projectDescription = null` (the docs serve as the project description).

---

#### Option B: Prototype Import

If the user chose "I have a prototype repo to import":

1. Ask for the path as a **plain-text prompt** — output the question as regular text, do NOT use `AskUserQuestion` (see [shared rules § Open-ended prompt exception](../shared/orchestrator-rules.md#user-questions-mandatory)):
   > "What's the path to your prototype repo? You can use an absolute path (`C:\Git\my-prototype`) or a relative path (`../my-prototype`)."

2. Run the import script:
   ```bash
   node .claude/scripts/import-prototype.js --from "<user-provided-path>"
   ```

3. If `status: "ok"`: Display the summary (file counts, prototype names detected). Then proceed to **Step 4** (Call A will detect Mode 1 from the imported docs).

4. If `status: "error"`: Display the error message and suggestion. Use `AskUserQuestion`:
   - **Question:** "The import didn't work. What would you like to do?"
   - **Options:** "Let me fix the path and try again" / "I'll copy files manually instead" / "Let's do guided Q&A instead"
   - If "fix the path": re-ask for the path and retry
   - If "copy files manually": switch to **Option A** flow
   - If "guided Q&A": switch to **Option C** flow

Store the routing result: `onboardingPath = "prototype"`. Set `projectDescription = null` (the imported docs serve as the project description).

---

#### Option C: Guided Q&A

If the user chose "Let's build requirements together":

1. Ask for the project description as a **plain-text prompt** (see [shared rules § Open-ended prompt exception](../shared/orchestrator-rules.md#user-questions-mandatory)):
   > "What are you building? Give me the elevator pitch — who's it for, what does it do, and what's the core problem it solves. As much or as little detail as you like."

2. Capture the user's response as `projectDescription`.

3. Store the routing result: `onboardingPath = "qa"`. Proceed to **Step 4**.

---

### Step 4: INTAKE Phase — Gather Requirements

INTAKE is always the first phase. It runs two agents sequentially, each using scoped calls with orchestrator-driven user interaction.

#### Step 4a: Intake Agent (up to 3 scoped calls)

**Call A — Scan + Analyze:**

Launch `intake-agent` with prompt:
> "This is Call A — Scan + Analyze. Scan documentation/ for existing specs, catalog what you find, detect operating mode, and return structured results. Do NOT produce the manifest. Do NOT use AskUserQuestion. Do NOT commit."

The agent returns structured scan results including:
- `scan_summary`: what was found in documentation/
- `mode`: 1 (existing specs), 2 (partial), or 3 (from scratch)
- `inferred_answers`: pre-filled checklist answers if docs provide them (Mode 1)
- `has_wireframes`: boolean
- `wireframe_paths`: file paths if applicable

**Orchestrator — Checklist Questions:**

Display the scan summary to the user, then ask the 3 mandatory checklist questions (and one conditional checklist question) sequentially using `AskUserQuestion`.

> **Prototype Assumptions Warning:** When the scan detects prototype docs (`has_prototype_docs: true`), the orchestrator MUST explicitly verify prototype-scoped assumptions with the user. Prototyping tools generate documentation for demo/prototype purposes — their requirements often specify mock APIs, localStorage persistence, simplified auth, or other shortcuts that are appropriate for a demo but NOT for production. This repository builds production-ready, test-driven applications. The checklist questions below are the verification point — do not silently inherit prototype assumptions. When inferred answers come from prototype docs, frame confirmations to surface this distinction (e.g., "The prototype spec says mock API with localStorage — is that what you want for the real app, or will there be a backend API?").

If the user came through **Option B** (prototype import), the scan results will be rich — prototype docs typically define roles, styling, data models, and UI patterns in detail. Leverage this context the same way you would a project description: reference specific prototype findings when asking confirmations (e.g., "The prototype's business-requirements.md defines admin and broker roles with these permissions. Is that the complete picture for the production app?").

If the user came through **Option C** (guided Q&A), they already provided a project description. Use it to make these questions more specific and relevant. For example, if the user described "a commission payments dashboard for brokers and admins," reference that context: "Based on what you've described, it sounds like there are at least broker and admin roles. Who else uses this, and what can each role see and do?"

1. **Roles/Permissions:**
   - If Mode 1 (inferred from docs): "I see the spec mentions [inferred roles]. Is that the complete list, or is there more?"
     - Options: "Yes, that covers it" / "Let me clarify"
   - If Mode 2/3: Reference the project description (if available) to suggest likely roles, then ask: "Who uses this application? What distinct roles exist, and what can each role see and do?"
     - Options provide common patterns; user can use "Other" for free text

2. **Styling/Branding:**
   - If Mode 1: "There's [inferred styling info]. Anything to override or add?"
     - Options: "Use as-is" / "I have additions"
   - If Mode 2/3: "Any specific colors, themes, or design system preferences? Dark mode, light mode, or both?"
     - Options: "No specific preferences" / "Let me describe"

3. **Data Source:**
   - If prototype docs exist and specify mock/localStorage: "The prototype spec calls for mock data with localStorage — that's typical for prototypes. For the production app, what's the real data source?"
   - Options: "Existing backend API" / "New API needs to be designed" / "Backend API in development (mock layer needed)" / "Mock data only"

3a. **Spec completeness** (only if user chose "Backend API in development" AND `has_api_spec: true` from scan results):
   - Ask: "I found an API spec at [api_spec_paths]. Does this cover all the endpoints your app will need, or are there still endpoints being designed?"
   - Options: "It covers everything" / "Some endpoints are still being designed"
   - Capture as `specCompleteness: "complete" | "partial"` and include in the Call B user answers block
   - If skipped (no spec found or different data source): pass `3a. Spec Completeness: N/A` — the intake-agent will set `generate: true` and `userProvided: null`, designing the full spec from scratch

4. **Wireframe quality** (only if `has_wireframes` is true):
   - "Are these wireframes rough references or detailed enough for implementation?"
   - Options: "Rough references" / "Detailed, use as-is"

**Call B — Produce Manifest:**

Launch `intake-agent` with prompt:
> "This is Call B — Produce Manifest. Here are the scan results and user answers:
>
> [paste scan results from Call A]
>
> Onboarding path: [docs, prototype, or qa]
> Project description: [projectDescription text, or "N/A — user provided documentation files" if Option A/B]
>
> User answers:
> 1. Roles/Permissions: [answer]
> 2. Styling/Branding: [answer]
> 3. Data Source: [answer]
> 3a. Spec Completeness: [complete|partial|N/A — only present if Data Source is "Backend API in development" and a spec was found]
> 4. Wireframe Quality: [answer or N/A]
>
> Produce the intake manifest and write it to generated-docs/context/intake-manifest.json. Include the project description in `context.projectDescription` (set to `null` if N/A). Return a human-readable summary. Do NOT commit. Do NOT use AskUserQuestion."

**Orchestrator — Manifest Approval (two-step — display THEN ask):**

> **CRITICAL — You MUST complete BOTH steps below. Skipping step 1 is a known failure mode where the user sees an approval prompt with nothing to review.**

**Step 1 — Display the summary (MANDATORY, do this FIRST):**

Take the human-readable summary that the intake-agent returned from Call B and output it as regular conversation text. Use this format:

```
Here's what I've gathered:

**Project:** [name and 1-sentence description]

**What's already provided:**
- [file name] — [1-sentence description of what it contains]
- [file name] — [1-sentence description]

**What the DESIGN phase will generate:**
- [artifact] — [why it's needed]
- [artifact] — [why it's needed]

**Notes:** [any caveats, e.g., "API is in development — spec covers current endpoints; backend team will add more over time"]
```

**Step 2 — Ask for approval (ONLY after step 1 text is output):**

Call `AskUserQuestion`:
   - "Does this look right? Anything to add or change before we move on?"
   - Options: "Looks good" / "I have changes"

> **Do NOT skip step 1.** The user cannot approve what they haven't seen. The summary must appear as regular text output above the `AskUserQuestion` prompt — never embed it inside the question text, and never call `AskUserQuestion` without displaying the summary first. If the agent's return message is empty or unclear, read `generated-docs/context/intake-manifest.json` and construct the summary yourself.

If "Looks good": proceed directly to **Step 4b** (no Call C needed).

If "I have changes": collect the user's feedback text, then launch Call C.

**Call C — Revise (only if changes requested):**

> "This is Call C — Revise. The user wants these changes: [feedback]. Update the manifest accordingly and return the updated summary. Do NOT commit. Do NOT use AskUserQuestion."

After Call C returns, re-display the updated summary and re-ask approval. Loop until approved.

#### Step 4b: BRD Review Agent (up to 3 scoped calls)

**Call A — Gap Analysis:**

Launch `intake-brd-review-agent` with prompt:
> "This is Call A — Gap Analysis Only. Read the intake manifest, FRS template, and documentation. Review completeness section by section. Return a structured gap analysis with:
> - mode: A (docs exist) or B (no docs)
> - For each of the 8 FRS template sections: coverage status (covered/partial/missing) and specific clarifying questions if any
>
> Be specific with questions: 'What happens when a viewer tries to access admin settings?' NOT 'Tell me about permissions.' Offer sensible defaults where possible.
>
> Do NOT write the FRS. Do NOT commit. Do NOT use AskUserQuestion."

**Orchestrator — Clarifying Questions:**

Display the gap analysis summary. For each section that has questions:
- Present the section context (what's covered, what's missing)
- Use `AskUserQuestion` with the specific question(s) for that section
- Collect answers

Accumulate all answers into a structured block.

**Call B — Produce FRS:**

Launch `intake-brd-review-agent` with prompt:
> "This is Call B — Produce FRS. Here is the gap analysis and all user answers:
>
> [paste gap analysis from Call A]
>
> User answers per section:
> [structured answers block]
>
> Write the Feature Requirements Specification to generated-docs/specs/feature-requirements.md with source traceability. Amend the manifest if new artifact needs were discovered. Return a summary (requirement count, business rule count, key sections). Do NOT commit. Do NOT use AskUserQuestion."

**Orchestrator — FRS Approval (two-step — display THEN ask):**

1. **Output the FRS summary as regular conversation text** — requirement count, business rule count, key sections covered, and the file path (`generated-docs/specs/feature-requirements.md`).

2. **Then** call `AskUserQuestion`:
   - "Does this capture everything we need to build?"
   - Options: "Looks complete" / "I have changes"

> Same rule as manifest approval: never call `AskUserQuestion` without displaying the summary first.

If "I have changes": collect feedback.

**Call C — Finalize:**

If approved:
> "This is Call C — Finalize. The user approved the FRS. Commit all INTAKE artifacts (FRS, manifest, logs), run the state transition to DESIGN, and push. Do NOT use AskUserQuestion."

If changes requested:
> "This is Call C — Revise. Apply these changes: [feedback]. Update the FRS and traceability table. Return the updated summary. Do NOT commit yet. Do NOT use AskUserQuestion."

If revised, re-display and re-ask approval. When finally approved, launch another finalize call to commit.

### Step 5: INTAKE Complete — Context Clearing Boundary

After both agents have completed, INTAKE is done. This is **clearing boundary #1**.

Tell the user (conversationally):

> "That wraps up requirements gathering — the Feature Requirements Specification and intake manifest are ready. Next up is the design phase.
>
> Run `/clear` then `/continue` when you're ready to move on."

**STOP** — do not launch the next agent.

---

## After INTAKE (Reference Only — Handled by /continue)

> **DO NOT EXECUTE these phases from `/start`.** The sections below describe what happens when the user runs `/clear` + `/continue`. They are here for context only. Your job in `/start` ends at the STOP above.

After the user runs `/clear` + `/continue`, the workflow enters the mandatory DESIGN phase. The orchestrator reads the intake manifest, launches design agents in parallel (API + Style + Wireframe Call A simultaneously), and copies user-provided files when `generate=false`. See [continue.md](./continue.md) for resumption logic and [orchestrator-rules.md](../shared/orchestrator-rules.md#design-scoped-calls) for the full scoped-call patterns.

## After DESIGN (Handled by /continue)

After the user runs `/clear` + `/continue`, the workflow continues with:

1. **SCOPE**: The feature-planner defines all epics from the FRS
2. **Per-epic and per-story phases**: STORIES, REALIGN, WRITE-TESTS, IMPLEMENT, QA

These phases are managed by `/continue` based on the workflow state. See [continue.md](./continue.md) for resumption logic and [orchestrator-rules.md](../shared/orchestrator-rules.md#per-phase-scoped-call-prompts) for the full scoped-call patterns.

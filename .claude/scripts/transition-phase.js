#!/usr/bin/env node
/**
 * transition-phase.js
 * Manages workflow state transitions with validation
 *
 * Usage:
 *   node .claude/scripts/transition-phase.js --to <PHASE> [--verify-output]                          # Global phases (INTAKE, DESIGN, SCOPE) — no --epic needed
 *   node .claude/scripts/transition-phase.js --epic <N> --to <PHASE> [--story <M>] [--validate] [--verify-output]
 *   node .claude/scripts/transition-phase.js --current --to <PHASE> [--story <M>] [--validate] [--verify-output]
 *   node .claude/scripts/transition-phase.js --mark-started
 *   node .claude/scripts/transition-phase.js --show
 *   node .claude/scripts/transition-phase.js --repair
 *
 * Phases: INTAKE, SCOPE, DESIGN, STORIES, REALIGN, WRITE-TESTS, IMPLEMENT, QA, COMPLETE
 *
 * Workflow Structure (4 Stages):
 *   Stage 1: INTAKE (gather requirements, produce FRS) → DESIGN (multi-agent: API spec, style tokens, wireframes) → SCOPE (define epics only)
 *   Stage 2: Per-Epic: STORIES (define stories for current epic)
 *   Stage 3: Per-Story: REALIGN → WRITE-TESTS → IMPLEMENT → QA
 *
 * Phase Status:
 *   Transitions set phaseStatus to "ready". Agents call --mark-started to set "in_progress".
 *
 * Options:
 *   --validate       Validate prerequisites before transitioning
 *   --verify-output  After transition, verify the FROM phase created expected outputs
 *   --mark-started   Mark current phase as in_progress (agent calls when starting work)
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const STATE_FILE = 'generated-docs/context/workflow-state.json';
const STATE_DIR = 'generated-docs/context';
const VALIDATE_SCRIPT = '.claude/scripts/validate-phase-output.js';

// Valid phases in order
const PHASES = ['INTAKE', 'SCOPE', 'DESIGN', 'STORIES', 'REALIGN', 'WRITE-TESTS', 'IMPLEMENT', 'QA', 'COMPLETE', 'PENDING'];

// Global phases run once for the entire feature (not per-epic).
// They should never create or modify epic-level state.
const GLOBAL_PHASES = ['INTAKE', 'DESIGN', 'SCOPE'];

// Valid transitions (from → [allowed destinations])
// New 4-stage workflow:
//   Stage 1: INTAKE (gather requirements, produce FRS) → DESIGN (multi-agent: API spec, style tokens, wireframes) → SCOPE (define epics only)
//   Stage 2: Per-Epic: STORIES (define stories for current epic)
//   Stage 3: Per-Story: REALIGN → WRITE-TESTS → IMPLEMENT → QA
const VALID_TRANSITIONS = {
  'INTAKE': ['DESIGN'],                     // After intake (FRS produced), proceed to design (API spec, style tokens, wireframes)
  'SCOPE': ['DESIGN', 'STORIES'],           // After scope (epics defined), design artifacts or start stories
  'DESIGN': ['SCOPE', 'STORIES'],           // After design (all sub-agents complete), proceed to scope or stories
  'STORIES': ['REALIGN', 'WRITE-TESTS'],    // After stories defined, realign or write tests for first story
  'REALIGN': ['WRITE-TESTS'],               // After realign, proceed to write tests
  'WRITE-TESTS': ['IMPLEMENT'],             // After writing tests, implement
  'IMPLEMENT': ['QA'],                      // After implementation, QA (review + quality gates)
  'QA': ['COMPLETE', 'IMPLEMENT'],          // After QA, story complete (or back to implement if issues)
  'COMPLETE': ['REALIGN', 'STORIES'],       // After story complete, next story's realign or next epic's stories
  'PENDING': ['REALIGN', 'WRITE-TESTS'],    // Pending story can start realign or write tests
  'NONE': ['INTAKE', 'STORIES', 'REALIGN']            // Initial state (INTAKE is the mandatory entry point)
};

// =============================================================================
// HELPERS
// =============================================================================

function ensureStateDir() {
  if (!fs.existsSync(STATE_DIR)) {
    fs.mkdirSync(STATE_DIR, { recursive: true });
  }
}

function readState() {
  if (!fs.existsSync(STATE_FILE)) {
    return null;
  }
  try {
    const content = fs.readFileSync(STATE_FILE, 'utf-8');
    return JSON.parse(content);
  } catch (e) {
    console.error(`Error reading state file: ${e.message}`);
    return null;
  }
}

function writeState(state) {
  ensureStateDir();
  state.lastUpdated = new Date().toISOString();
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

function findFeatureSpec() {
  // Canonical location (produced by INTAKE's intake-brd-review-agent)
  const canonicalFRS = 'generated-docs/specs/feature-requirements.md';
  if (fs.existsSync(canonicalFRS)) return canonicalFRS;

  // Fallback: scan documentation/ for user-provided specs
  const docDir = 'documentation';
  if (!fs.existsSync(docDir)) return null;

  const files = fs.readdirSync(docDir)
    .filter(f => f.endsWith('.md') && f !== 'README.md');

  return files.length > 0 ? path.join(docDir, files[0]) : null;
}

function getEpicInfo(epicNum) {
  const epicDirs = [];
  const storiesDir = 'generated-docs/stories';

  if (fs.existsSync(storiesDir)) {
    const entries = fs.readdirSync(storiesDir);
    for (const entry of entries) {
      const match = entry.match(/^epic-(\d+)/);
      if (match) {
        epicDirs.push({
          num: parseInt(match[1]),
          name: entry,
          path: path.join(storiesDir, entry)
        });
      }
    }
  }

  epicDirs.sort((a, b) => a.num - b.num);

  if (epicNum) {
    return epicDirs.find(e => e.num === epicNum) || null;
  }
  return epicDirs;
}

function validateTransition(currentPhase, targetPhase, state, epicNum, storyNum) {
  const from = currentPhase || 'NONE';
  const allowed = VALID_TRANSITIONS[from] || [];

  // Special case: STORIES for epic 2+ requires previous epic to be COMPLETE
  if (targetPhase === 'STORIES' && epicNum > 1) {
    if (!state || !state.epics[epicNum - 1] || state.epics[epicNum - 1].phase !== 'COMPLETE') {
      return {
        valid: false,
        message: `Cannot start Epic ${epicNum} STORIES: Epic ${epicNum - 1} is not COMPLETE`
      };
    }
  }

  // Special case: REALIGN/WRITE-TESTS for story 2+ requires previous story to be COMPLETE
  if (storyNum && storyNum > 1 && ['REALIGN', 'WRITE-TESTS'].includes(targetPhase)) {
    const epicState = state?.epics?.[epicNum];
    const prevStory = epicState?.stories?.[storyNum - 1];
    if (!prevStory || prevStory.phase !== 'COMPLETE') {
      return {
        valid: false,
        message: `Cannot start Story ${storyNum}: Story ${storyNum - 1} is not COMPLETE`
      };
    }
    return { valid: true };
  }

  // Special case: Allow REALIGN/STORIES from COMPLETE (next story or next epic)
  if (from === 'COMPLETE' && ['REALIGN', 'STORIES'].includes(targetPhase)) {
    return { valid: true };
  }

  if (!allowed.includes(targetPhase)) {
    return {
      valid: false,
      message: `Invalid transition: ${from} → ${targetPhase}. Allowed transitions from ${from}: ${allowed.join(', ') || 'none'}`
    };
  }

  return { valid: true };
}

// Phase prerequisites - what must exist before transitioning TO a phase
const PHASE_PREREQUISITES = {
  'INTAKE': [], // Can start intake anytime (entry point)
  'SCOPE': [], // Can start scoping anytime
  'DESIGN': [], // Can start design anytime
  'STORIES': ['SCOPE'], // Need epics defined before defining stories
  'REALIGN': ['STORIES'], // Need stories defined for current epic
  'WRITE-TESTS': ['STORIES'], // Need stories to generate tests from
  'IMPLEMENT': ['WRITE-TESTS'], // Need tests to implement against
  'QA': ['IMPLEMENT'], // Need implementation to review and validate
  'COMPLETE': ['QA'] // Need QA complete
};

function runValidationScript(phase, epicNum) {
  // Run the validate-phase-output.js script and return its result
  if (!fs.existsSync(VALIDATE_SCRIPT)) {
    return {
      status: 'skipped',
      message: 'Validation script not found',
      path: VALIDATE_SCRIPT
    };
  }

  try {
    const epicArg = epicNum ? `--epic ${epicNum}` : '';
    const cmd = `node ${VALIDATE_SCRIPT} --phase ${phase} ${epicArg}`;
    const output = execSync(cmd, { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
    return JSON.parse(output);
  } catch (error) {
    // Script exited with non-zero - parse the output if possible
    if (error.stdout) {
      try {
        return JSON.parse(error.stdout);
      } catch {
        // Couldn't parse output
      }
    }
    return {
      status: 'error',
      message: `Validation script failed: ${error.message}`,
      exitCode: error.status || 1
    };
  }
}

function validatePrerequisites(targetPhase, epicNum) {
  // Check that prerequisites for the target phase are met
  const prereqs = PHASE_PREREQUISITES[targetPhase] || [];

  if (prereqs.length === 0) {
    return { valid: true, message: 'No prerequisites required' };
  }

  const results = [];
  let allValid = true;

  for (const prereqPhase of prereqs) {
    const validation = runValidationScript(prereqPhase, epicNum);

    if (validation.status === 'invalid' || validation.status === 'error') {
      allValid = false;
    }

    results.push({
      phase: prereqPhase,
      ...validation
    });
  }

  return {
    valid: allValid,
    message: allValid
      ? `All prerequisites for ${targetPhase} are met`
      : `Prerequisites for ${targetPhase} not met`,
    prerequisites: results
  };
}

// =============================================================================
// COMMANDS
// =============================================================================

function showState() {
  const state = readState();

  if (!state) {
    console.log(JSON.stringify({
      status: 'no_state',
      message: 'No workflow state found. Run /start to begin.',
      suggestion: 'Use --repair to initialize state from artifacts'
    }, null, 2));
    return;
  }

  console.log(JSON.stringify({
    status: 'ok',
    state
  }, null, 2));
}

function repairState() {
  // Attempt to reconstruct state from filesystem artifacts
  const spec = findFeatureSpec();
  const epics = getEpicInfo();

  if (!spec) {
    console.log(JSON.stringify({
      status: 'error',
      message: 'No feature spec found in generated-docs/specs/ or documentation/. Cannot repair state.'
    }, null, 2));
    process.exit(1);
  }

  // Track what we detected vs what we assumed for confidence calculation
  const detected = [];
  const assumed = [];
  let confidenceScore = 100; // Start at 100, deduct for assumptions

  // Determine current state by scanning artifacts
  let currentEpic = null;
  let currentStory = null;
  let currentPhase = 'SCOPE';
  let epicStates = {};

  // Check for feature overview
  const featureOverviewPath = 'generated-docs/stories/_feature-overview.md';
  const hasFeatureOverview = fs.existsSync(featureOverviewPath);
  if (hasFeatureOverview) {
    detected.push('Feature overview file exists');
  } else {
    assumed.push('No feature overview - assuming PLAN phase needed');
    confidenceScore -= 10;
  }

  // Check for quality gate status (indicates QA completed)
  const qualityGateStatus = 'generated-docs/context/quality-gate-status.json';
  const hasQualityGate = fs.existsSync(qualityGateStatus);
  if (hasQualityGate) {
    detected.push('Quality gate status file exists');
  }

  for (const epic of epics) {
    const hasOverview = fs.existsSync(path.join(epic.path, '_epic-overview.md'));
    let storyFiles = [];
    try {
      storyFiles = fs.readdirSync(epic.path).filter(f => f.startsWith('story-') && f.endsWith('.md'));
    } catch {
      // Directory exists but can't read it
      assumed.push(`Could not read epic-${epic.num} directory`);
      confidenceScore -= 15;
    }

    // Check for test files (flexible matching)
    let hasTests = false;
    let testFileCount = 0;
    const testDirs = ['web/src/__tests__/integration', 'web/src/__tests__'];
    for (const testDir of testDirs) {
      if (fs.existsSync(testDir)) {
        try {
          const testFiles = fs.readdirSync(testDir, { recursive: true })
            .filter(f => typeof f === 'string' && f.includes(`epic-${epic.num}`) && (f.endsWith('.test.tsx') || f.endsWith('.test.ts')));
          if (testFiles.length > 0) {
            hasTests = true;
            testFileCount = testFiles.length;
            break;
          }
        } catch {
          // Can't read test dir
        }
      }
    }

    // Also check for epic-specific test directories
    const epicTestDir = `web/src/__tests__/epic-${epic.num}`;
    if (fs.existsSync(epicTestDir)) {
      hasTests = true;
    }

    // Check for review marker
    const reviewMarker = `generated-docs/reviews/epic-${epic.num}-review.md`;
    const hasReviewMarker = fs.existsSync(reviewMarker);

    // Check for review findings in context
    let hasReviewFindings = false;
    const reviewFindingsPath = 'generated-docs/context/review-findings.json';
    if (fs.existsSync(reviewFindingsPath)) {
      try {
        const findings = JSON.parse(fs.readFileSync(reviewFindingsPath, 'utf-8'));
        if (findings.recommendation) {
          hasReviewFindings = true;
        }
      } catch {
        // Invalid JSON
      }
    }

    // Determine epic phase with confidence tracking
    let epicPhase;
    let phaseConfidence = 'high';
    let storyStates = {};
    let totalStories = storyFiles.length;

    if (!hasOverview || storyFiles.length === 0) {
      epicPhase = 'STORIES'; // Needs story definition
      if (!hasOverview && storyFiles.length === 0) {
        detected.push(`Epic ${epic.num}: No overview or stories - STORIES phase`);
      } else {
        assumed.push(`Epic ${epic.num}: Partial artifacts - assuming STORIES`);
        phaseConfidence = 'medium';
        confidenceScore -= 10;
      }
    } else {
      // Has stories - determine story-level phases
      let allStoriesComplete = true;
      let firstIncompleteStory = null;

      for (let i = 0; i < storyFiles.length; i++) {
        const storyFile = storyFiles[i];
        const storyNum = i + 1;
        const storyPath = path.join(epic.path, storyFile);
        const storyContent = fs.readFileSync(storyPath, 'utf-8');

        // Check for unchecked acceptance criteria
        const hasUncheckedCriteria = /^\s*[-*] \[ \]/m.test(storyContent);

        // Check for story-specific tests
        let storyHasTests = false;
        for (const testDir of testDirs) {
          if (fs.existsSync(testDir)) {
            try {
              const storyTestFiles = fs.readdirSync(testDir, { recursive: true })
                .filter(f => typeof f === 'string' &&
                  f.includes(`epic-${epic.num}`) &&
                  f.includes(`story-${storyNum}`) &&
                  (f.endsWith('.test.tsx') || f.endsWith('.test.ts')));
              if (storyTestFiles.length > 0) {
                storyHasTests = true;
                break;
              }
            } catch { /* ignore */ }
          }
        }

        // Determine story phase
        let storyPhase;
        if (!hasUncheckedCriteria) {
          storyPhase = 'COMPLETE';
        } else if (!storyHasTests) {
          storyPhase = 'WRITE-TESTS';
          allStoriesComplete = false;
          if (!firstIncompleteStory) firstIncompleteStory = storyNum;
        } else {
          storyPhase = 'IMPLEMENT'; // Has tests but incomplete criteria
          allStoriesComplete = false;
          if (!firstIncompleteStory) firstIncompleteStory = storyNum;
        }

        storyStates[storyNum] = {
          name: storyFile.replace('.md', ''),
          phase: storyPhase
        };
      }

      if (allStoriesComplete) {
        epicPhase = 'COMPLETE';
        detected.push(`Epic ${epic.num}: All ${storyFiles.length} stories complete - COMPLETE`);
      } else if (hasReviewMarker || (hasQualityGate && hasReviewFindings)) {
        epicPhase = 'QA';
        detected.push(`Epic ${epic.num}: Has review artifacts - QA phase`);
      } else {
        epicPhase = storyStates[firstIncompleteStory]?.phase || 'IMPLEMENT';
        detected.push(`Epic ${epic.num}: Story ${firstIncompleteStory} in ${epicPhase} phase`);
      }
    }

    epicStates[epic.num] = {
      name: epic.name,
      phase: epicPhase,
      totalStories,
      stories: storyStates,
      tests: testFileCount,
      phaseConfidence
    };

    // Track first incomplete epic
    if (!currentEpic && epicPhase !== 'COMPLETE') {
      currentEpic = epic.num;
      currentPhase = epicPhase;
    }
  }

  // If no epics found, confidence is low
  if (epics.length === 0) {
    assumed.push('No epic directories found - starting fresh');
    confidenceScore -= 20;
  }

  // Calculate overall confidence level
  let confidence;
  let confidenceReason;
  if (confidenceScore >= 80) {
    confidence = 'high';
    confidenceReason = 'Most artifacts clearly indicate current state';
  } else if (confidenceScore >= 50) {
    confidence = 'medium';
    confidenceReason = 'Some artifacts found but state partially inferred';
  } else {
    confidence = 'low';
    confidenceReason = 'Many assumptions made - manual verification strongly recommended';
  }

  // Determine current story from the first incomplete story in current epic
  if (currentEpic && epicStates[currentEpic]?.stories) {
    const stories = epicStates[currentEpic].stories;
    for (const [num, story] of Object.entries(stories)) {
      if (story.phase !== 'COMPLETE') {
        currentStory = parseInt(num);
        currentPhase = story.phase;
        break;
      }
    }
  }

  // Build repaired state
  const repairedState = {
    featureName: path.basename(spec, '.md'),
    specPath: spec,
    currentEpic: currentEpic || (epics.length > 0 ? epics[epics.length - 1].num : 1),
    currentStory: currentStory,
    currentPhase: currentEpic ? currentPhase : 'COMPLETE',
    epics: epicStates,
    repairedAt: new Date().toISOString(),
    repairNote: 'State reconstructed from artifacts.'
  };

  writeState(repairedState);

  // Build detailed response
  const response = {
    status: 'repaired',
    message: 'State file repaired from artifacts.',
    confidence,
    confidenceScore,
    confidenceReason,
    detected,
    assumed,
    state: repairedState
  };

  // Add warning based on confidence
  if (confidence === 'low') {
    response.warning = 'LOW CONFIDENCE: Many assumptions were made. Please verify the state manually before proceeding.';
  } else if (confidence === 'medium') {
    response.warning = 'MEDIUM CONFIDENCE: Some state was inferred. Review the detected state and confirm it matches your expectations.';
  } else {
    response.note = 'High confidence repair. State appears accurate based on artifacts found.';
  }

  console.log(JSON.stringify(response, null, 2));
}

function transitionPhase(epicNum, targetPhase, storyNum, options = {}) {
  const { validate = false, verifyOutput = false } = options;

  if (!PHASES.includes(targetPhase)) {
    console.log(JSON.stringify({
      status: 'error',
      message: `Invalid phase: ${targetPhase}. Valid phases: ${PHASES.join(', ')}`
    }, null, 2));
    process.exit(1);
  }

  let state = readState();

  // Initialize state if it doesn't exist
  if (!state) {
    const spec = findFeatureSpec();
    if (!spec && targetPhase !== 'INTAKE') {
      console.log(JSON.stringify({
        status: 'error',
        message: 'No feature spec found in generated-docs/specs/ or documentation/. Create a spec first or use --init INTAKE to gather requirements.'
      }, null, 2));
      process.exit(1);
    }

    const isGlobal = GLOBAL_PHASES.includes(targetPhase);
    state = {
      featureName: spec ? path.basename(spec, '.md') : 'pending-intake',
      specPath: spec || null,
      currentEpic: isGlobal ? null : epicNum,
      currentStory: storyNum || null,
      currentPhase: 'NONE',
      phaseStatus: 'ready',
      epics: {}
    };
  }

  // Determine current phase - consider story-level phase if transitioning a story
  const isGlobalTarget = GLOBAL_PHASES.includes(targetPhase);
  let currentPhase;
  if (isGlobalTarget) {
    // Global phases use the top-level currentPhase (no epic association)
    currentPhase = state.currentPhase || 'NONE';
  } else if (storyNum && state.epics[epicNum]?.stories?.[storyNum]) {
    currentPhase = state.epics[epicNum].stories[storyNum].phase || 'PENDING';
  } else if (state.currentEpic === epicNum && state.currentStory === storyNum) {
    currentPhase = state.currentPhase;
  } else {
    currentPhase = state.epics[epicNum]?.phase || 'NONE';
  }

  const validation = validateTransition(currentPhase, targetPhase, state, epicNum, storyNum);
  if (!validation.valid) {
    console.log(JSON.stringify({
      status: 'error',
      message: validation.message,
      currentState: {
        epic: epicNum,
        story: storyNum || null,
        phase: currentPhase
      }
    }, null, 2));
    process.exit(1);
  }

  // If --validate flag is set, check prerequisites
  if (validate) {
    const prereqCheck = validatePrerequisites(targetPhase, epicNum);
    if (!prereqCheck.valid) {
      console.log(JSON.stringify({
        status: 'error',
        message: prereqCheck.message,
        prerequisites: prereqCheck.prerequisites,
        suggestion: 'Complete the prerequisite phases before transitioning'
      }, null, 2));
      process.exit(1);
    }
  }

  // If --verify-output flag is set, validate that the FROM phase created expected outputs
  let outputValidation = null;
  if (verifyOutput && currentPhase !== 'NONE' && currentPhase !== 'PENDING') {
    outputValidation = runValidationScript(currentPhase, epicNum);
  }

  // Initialize epic state if needed (skip for global phases — they have no epic)
  if (!isGlobalTarget) {
    if (!state.epics[epicNum]) {
      state.epics[epicNum] = { stories: {} };
    }
    if (!state.epics[epicNum].stories) {
      state.epics[epicNum].stories = {};
    }
  }

  // Update state based on whether this is a story-level, global, or epic-level transition
  const isStoryPhase = ['REALIGN', 'WRITE-TESTS', 'IMPLEMENT', 'QA', 'COMPLETE'].includes(targetPhase) && storyNum;

  if (isStoryPhase) {
    // Story-level transition
    if (!state.epics[epicNum].stories[storyNum]) {
      state.epics[epicNum].stories[storyNum] = {};
    }
    state.epics[epicNum].stories[storyNum].phase = targetPhase;
    state.currentStory = storyNum;
    state.currentPhase = targetPhase;
    state.currentEpic = epicNum;
    state.phaseStatus = 'ready'; // Phase transitioned but work not yet started

    // Handle story completion
    if (targetPhase === 'COMPLETE') {
      const epicState = state.epics[epicNum];
      const totalStories = epicState.totalStories || Object.keys(epicState.stories).length;

      // Check if all stories in epic are complete
      const completedStories = Object.values(epicState.stories)
        .filter(s => s.phase === 'COMPLETE').length;

      if (completedStories >= totalStories) {
        // Epic complete - all stories done
        epicState.phase = 'COMPLETE';

        // Auto-detect totalEpics if not set
        if (!state.totalEpics) {
          const epicDirs = getEpicInfo();
          if (epicDirs.length > 0) {
            state.totalEpics = epicDirs.length;
          }
        }

        // Check if this is the final epic
        if (state.totalEpics && epicNum >= state.totalEpics) {
          state.featureComplete = true;
          state.currentPhase = 'COMPLETE';
          state.phaseStatus = 'complete'; // Feature fully complete
        } else {
          // More epics - advance to STORIES for next epic
          state.currentEpic = epicNum + 1;
          state.currentStory = null;
          state.currentPhase = 'STORIES';
          state.phaseStatus = 'ready'; // Next epic ready to start
        }
      } else {
        // More stories - advance to REALIGN for next story
        state.currentStory = storyNum + 1;
        state.currentPhase = 'REALIGN';
        state.phaseStatus = 'ready'; // Next story ready to start
        // Mark next story as PENDING if it doesn't exist
        if (!epicState.stories[storyNum + 1]) {
          epicState.stories[storyNum + 1] = { phase: 'PENDING' };
        }
      }
    }
  } else if (isGlobalTarget) {
    // Global phase transition (INTAKE, DESIGN, SCOPE) — no epic association
    state.currentEpic = null;
    state.currentStory = null;
    state.currentPhase = targetPhase;
    state.phaseStatus = 'ready'; // Phase transitioned but work not yet started
  } else {
    // Epic-level transition (STORIES)
    state.currentEpic = epicNum;
    state.currentPhase = targetPhase;
    state.epics[epicNum].phase = targetPhase;
    state.phaseStatus = 'ready'; // Phase transitioned but work not yet started

    // If starting STORIES phase, reset story tracking
    if (targetPhase === 'STORIES') {
      state.currentStory = null;
    }
  }

  // Record transition history
  if (!state.history) {
    state.history = [];
  }
  state.history.push({
    timestamp: new Date().toISOString(),
    epic: isGlobalTarget ? null : epicNum,
    story: storyNum || null,
    from: currentPhase,
    to: targetPhase
  });

  // Keep only last 30 history entries (increased for story-level tracking)
  if (state.history.length > 30) {
    state.history = state.history.slice(-30);
  }

  writeState(state);

  // Build response message
  let message;
  if (storyNum) {
    message = `Transitioned Epic ${epicNum}, Story ${storyNum} from ${currentPhase} to ${targetPhase}`;
  } else if (isGlobalTarget) {
    message = `Transitioned from ${currentPhase} to ${targetPhase}`;
  } else {
    message = `Transitioned Epic ${epicNum} from ${currentPhase} to ${targetPhase}`;
  }

  const response = {
    status: 'ok',
    message,
    state: {
      epic: state.currentEpic,
      story: state.currentStory,
      phase: state.currentPhase
    }
  };

  // Add next action hint
  if (targetPhase === 'COMPLETE' && storyNum) {
    const epicState = state.epics[epicNum];
    const totalStories = epicState.totalStories || Object.keys(epicState.stories).length;
    const completedStories = Object.values(epicState.stories)
      .filter(s => s.phase === 'COMPLETE').length;

    if (completedStories >= totalStories) {
      if (state.featureComplete) {
        response.nextAction = 'Feature complete! All epics and stories done.';
      } else {
        response.nextAction = `Epic ${epicNum} complete. Start STORIES for Epic ${epicNum + 1}.`;
      }
    } else {
      response.nextAction = `Start REALIGN for Story ${storyNum + 1}.`;
    }
  }

  // Add feature complete info if applicable
  if (state.featureComplete) {
    response.featureComplete = true;
    response.message = `Story ${storyNum} complete. Feature finished! All ${state.totalEpics} epics done.`;
  }

  // Include output validation results if --verify-output was used
  if (outputValidation) {
    response.outputValidation = outputValidation;
    if (outputValidation.status !== 'valid') {
      response.warning = `Previous phase (${currentPhase}) may have incomplete outputs. Review before proceeding.`;
    }
  }

  console.log(JSON.stringify(response, null, 2));
}

function markStarted() {
  const state = readState();

  if (!state) {
    console.log(JSON.stringify({
      status: 'error',
      message: 'No workflow state found. Cannot mark phase as started.'
    }, null, 2));
    process.exit(1);
  }

  if (state.phaseStatus === 'in_progress') {
    console.log(JSON.stringify({
      status: 'ok',
      message: 'Phase already marked as in progress',
      state: {
        epic: state.currentEpic,
        story: state.currentStory,
        phase: state.currentPhase,
        phaseStatus: state.phaseStatus
      }
    }, null, 2));
    return;
  }

  const previousStatus = state.phaseStatus || 'ready';
  state.phaseStatus = 'in_progress';
  writeState(state);

  console.log(JSON.stringify({
    status: 'ok',
    message: `Phase ${state.currentPhase} marked as in progress`,
    previousStatus,
    state: {
      epic: state.currentEpic,
      story: state.currentStory,
      phase: state.currentPhase,
      phaseStatus: state.phaseStatus
    }
  }, null, 2));
}

function setTotalEpics(total) {
  let state = readState();

  if (!state) {
    console.log(JSON.stringify({
      status: 'error',
      message: 'No workflow state found. Initialize state first by transitioning to SCOPE.'
    }, null, 2));
    process.exit(1);
  }

  state.totalEpics = total;
  writeState(state);

  console.log(JSON.stringify({
    status: 'ok',
    message: `Set total epics to ${total}`,
    totalEpics: total
  }, null, 2));
}

function setTotalStories(epicNum, total) {
  let state = readState();

  if (!state) {
    console.log(JSON.stringify({
      status: 'error',
      message: 'No workflow state found. Initialize state first.'
    }, null, 2));
    process.exit(1);
  }

  if (!state.epics[epicNum]) {
    state.epics[epicNum] = { stories: {} };
  }

  state.epics[epicNum].totalStories = total;

  // Initialize story entries as PENDING if they don't exist
  for (let i = 1; i <= total; i++) {
    if (!state.epics[epicNum].stories[i]) {
      state.epics[epicNum].stories[i] = { phase: 'PENDING' };
    }
  }

  writeState(state);

  console.log(JSON.stringify({
    status: 'ok',
    message: `Set total stories for Epic ${epicNum} to ${total}`,
    epic: epicNum,
    totalStories: total
  }, null, 2));
}

function initState(initialPhase) {
  // Check if state already exists
  const existingState = readState();
  if (existingState) {
    console.log(JSON.stringify({
      status: 'exists',
      message: 'Workflow state already exists. Use --show to view or --repair to reconstruct.',
      state: existingState
    }, null, 2));
    return;
  }

  // Find the feature spec (optional for INTAKE — specs may not exist yet)
  const spec = findFeatureSpec();
  if (!spec && initialPhase !== 'INTAKE') {
    console.log(JSON.stringify({
      status: 'error',
      message: 'No feature spec found in generated-docs/specs/ or documentation/. Create a spec first or use --init INTAKE to gather requirements.'
    }, null, 2));
    process.exit(1);
  }

  // Create initial state
  // INTAKE is a global phase (not per-epic), so don't initialize epic state
  const isGlobalPhase = initialPhase === 'INTAKE';
  const state = {
    featureName: spec ? path.basename(spec, '.md') : null,
    specPath: spec || null,
    currentEpic: isGlobalPhase ? null : 1,
    currentStory: null,
    currentPhase: initialPhase,
    phaseStatus: 'ready', // Phase set but work not yet started
    epics: isGlobalPhase ? {} : {
      1: { phase: initialPhase, stories: {} }
    },
    history: [{
      timestamp: new Date().toISOString(),
      epic: isGlobalPhase ? null : 1,
      story: null,
      from: 'NONE',
      to: initialPhase,
      note: 'Workflow initialized'
    }]
  };

  writeState(state);

  console.log(JSON.stringify({
    status: 'ok',
    message: `Workflow initialized at ${initialPhase} phase`,
    state
  }, null, 2));
}

// =============================================================================
// CLI
// =============================================================================

function printUsage() {
  console.log(`
Usage:
  node .claude/scripts/transition-phase.js --to <PHASE> [--verify-output]                          # Global phases (INTAKE, DESIGN, SCOPE)
  node .claude/scripts/transition-phase.js --epic <N> --to <PHASE> [--story <M>] [--validate] [--verify-output]
  node .claude/scripts/transition-phase.js --current --to <PHASE> [--story <M>] [--validate] [--verify-output]
  node .claude/scripts/transition-phase.js --mark-started
  node .claude/scripts/transition-phase.js --init [INTAKE|DESIGN|SCOPE]
  node .claude/scripts/transition-phase.js --set-total-epics <N>
  node .claude/scripts/transition-phase.js --set-total-stories <N> --epic <E>
  node .claude/scripts/transition-phase.js --show
  node .claude/scripts/transition-phase.js --repair

Workflow Structure (4 Stages):
  Stage 1: INTAKE (gather requirements, produce FRS) → DESIGN (multi-agent: API spec, style tokens, wireframes) → SCOPE (define epics only)
  Stage 2: Per-Epic: STORIES (define stories for current epic)
  Stage 3: Per-Story: REALIGN → WRITE-TESTS → IMPLEMENT → QA

Phase Status:
  When transitioning to a phase, phaseStatus is set to "ready" (work not yet started).
  When an agent begins work, it calls --mark-started to set phaseStatus to "in_progress".
  This allows /status to distinguish between "ready for X" vs "X in progress".

Options:
  --epic <N>              Epic number for transitions
  --current               Use current epic from state (alternative to --epic)
  --to <PHASE>            Target phase: ${PHASES.join(', ')}
  --story <M>             Story number for per-story phases (REALIGN through QA)
  --validate              Check prerequisites before allowing transition
  --verify-output         Validate that the FROM phase created expected outputs
  --mark-started          Mark current phase as in_progress (call when agent starts work)
  --init [PHASE]          Initialize workflow state (INTAKE, DESIGN, or SCOPE; defaults to INTAKE)
  --set-total-epics <N>   Set the total number of epics for this feature
  --set-total-stories <N> Set total stories for an epic (requires --epic)
  --show                  Display current workflow state
  --repair                Attempt to reconstruct state from artifacts

Examples:
  # Initialize workflow
  node .claude/scripts/transition-phase.js --init INTAKE
  node .claude/scripts/transition-phase.js --init DESIGN
  node .claude/scripts/transition-phase.js --init SCOPE

  # Global phase transitions (no --epic needed)
  node .claude/scripts/transition-phase.js --to DESIGN --verify-output
  node .claude/scripts/transition-phase.js --to SCOPE --verify-output

  # Epic-level transitions
  node .claude/scripts/transition-phase.js --set-total-epics 3
  node .claude/scripts/transition-phase.js --epic 1 --to STORIES

  # Story-level transitions
  node .claude/scripts/transition-phase.js --set-total-stories 4 --epic 1
  node .claude/scripts/transition-phase.js --epic 1 --story 1 --to REALIGN
  node .claude/scripts/transition-phase.js --current --story 1 --to WRITE-TESTS --verify-output
  node .claude/scripts/transition-phase.js --current --story 1 --to IMPLEMENT
  node .claude/scripts/transition-phase.js --current --story 1 --to QA
  node .claude/scripts/transition-phase.js --current --story 1 --to COMPLETE

  # Mark phase as started (agent calls this when beginning work)
  node .claude/scripts/transition-phase.js --mark-started

  # Show state
  node .claude/scripts/transition-phase.js --show
`);
}

function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    printUsage();
    process.exit(0);
  }

  if (args.includes('--show')) {
    showState();
    return;
  }

  if (args.includes('--repair')) {
    repairState();
    return;
  }

  if (args.includes('--mark-started')) {
    markStarted();
    return;
  }

  // Handle --init
  const initIdx = args.indexOf('--init');
  if (initIdx !== -1) {
    // Default to INTAKE if no phase specified, or use the provided phase
    let initialPhase = 'INTAKE';
    const nextArg = args[initIdx + 1];
    if (nextArg && !nextArg.startsWith('--')) {
      initialPhase = nextArg.toUpperCase();
      if (!['INTAKE', 'DESIGN', 'SCOPE'].includes(initialPhase)) {
        console.log(JSON.stringify({
          status: 'error',
          message: `Invalid initial phase: ${initialPhase}. Use INTAKE, DESIGN, or SCOPE.`
        }, null, 2));
        process.exit(1);
      }
    }
    initState(initialPhase);
    return;
  }

  // Handle --set-total-epics
  const totalEpicsIdx = args.indexOf('--set-total-epics');
  if (totalEpicsIdx !== -1 && args[totalEpicsIdx + 1]) {
    const total = parseInt(args[totalEpicsIdx + 1]);
    if (isNaN(total) || total < 1) {
      console.log(JSON.stringify({
        status: 'error',
        message: 'Invalid total epics value. Must be a positive integer.'
      }, null, 2));
      process.exit(1);
    }
    setTotalEpics(total);
    return;
  }

  // Handle --set-total-stories (requires --epic)
  const totalStoriesIdx = args.indexOf('--set-total-stories');
  if (totalStoriesIdx !== -1 && args[totalStoriesIdx + 1]) {
    const total = parseInt(args[totalStoriesIdx + 1]);
    if (isNaN(total) || total < 1) {
      console.log(JSON.stringify({
        status: 'error',
        message: 'Invalid total stories value. Must be a positive integer.'
      }, null, 2));
      process.exit(1);
    }

    // Find --epic argument
    const epicIdx = args.indexOf('--epic');
    if (epicIdx === -1 || !args[epicIdx + 1]) {
      console.log(JSON.stringify({
        status: 'error',
        message: '--set-total-stories requires --epic <N> to specify which epic.'
      }, null, 2));
      process.exit(1);
    }

    const epicNum = parseInt(args[epicIdx + 1]);
    if (isNaN(epicNum) || epicNum < 1) {
      console.log(JSON.stringify({
        status: 'error',
        message: 'Invalid epic number. Must be a positive integer.'
      }, null, 2));
      process.exit(1);
    }

    setTotalStories(epicNum, total);
    return;
  }

  // Parse transition arguments
  let epicNum = null;
  let targetPhase = null;
  let storyNum = null;
  let useCurrent = false;
  let validate = false;
  let verifyOutput = false;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--epic' && args[i + 1]) {
      epicNum = parseInt(args[i + 1]);
      i++;
    } else if (args[i] === '--current') {
      useCurrent = true;
    } else if (args[i] === '--to' && args[i + 1]) {
      targetPhase = args[i + 1].toUpperCase();
      i++;
    } else if (args[i] === '--story' && args[i + 1]) {
      storyNum = parseInt(args[i + 1]);
      if (isNaN(storyNum)) {
        console.log(JSON.stringify({
          status: 'error',
          message: 'Invalid story number. Must be a positive integer.'
        }, null, 2));
        process.exit(1);
      }
      i++;
    } else if (args[i] === '--validate') {
      validate = true;
    } else if (args[i] === '--verify-output') {
      verifyOutput = true;
    }
  }

  // Handle --current flag
  if (useCurrent) {
    const state = readState();
    if (!state) {
      console.log(JSON.stringify({
        status: 'error',
        message: 'No workflow state found. Cannot use --current. Use --epic <N> instead or run --repair first.'
      }, null, 2));
      process.exit(1);
    }
    epicNum = state.currentEpic;
    // currentEpic is null during global phases — that's OK if the target is also global
    if (!epicNum && targetPhase && !GLOBAL_PHASES.includes(targetPhase)) {
      console.log(JSON.stringify({
        status: 'error',
        message: 'No current epic in state (currently in a global phase). Use --epic <N> to specify explicitly.'
      }, null, 2));
      process.exit(1);
    }
  }

  // Global phases (INTAKE, DESIGN, SCOPE) don't require --epic
  const isGlobalCli = targetPhase && GLOBAL_PHASES.includes(targetPhase);

  if (!isGlobalCli && !epicNum) {
    if (!targetPhase) {
      console.log(JSON.stringify({
        status: 'error',
        message: 'Missing required arguments. Need --epic <N> (or --current) and --to <PHASE>'
      }, null, 2));
    } else {
      console.log(JSON.stringify({
        status: 'error',
        message: `Missing --epic <N> (or --current). Required for non-global phase: ${targetPhase}`
      }, null, 2));
    }
    printUsage();
    process.exit(1);
  }

  if (!targetPhase) {
    console.log(JSON.stringify({
      status: 'error',
      message: 'Missing required argument: --to <PHASE>'
    }, null, 2));
    printUsage();
    process.exit(1);
  }

  // Validate that story-level phases have a story number
  const storyLevelPhases = ['REALIGN', 'WRITE-TESTS', 'IMPLEMENT', 'QA'];
  if (storyLevelPhases.includes(targetPhase) && !storyNum) {
    // Try to use current story from state if available
    const state = readState();
    if (state && state.currentStory) {
      storyNum = state.currentStory;
    }
  }

  transitionPhase(epicNum, targetPhase, storyNum, { validate, verifyOutput });
}

main();

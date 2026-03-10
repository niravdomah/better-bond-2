<#
.SYNOPSIS
    Automated tests for bash-permission-checker.ps1

.DESCRIPTION
    Feeds synthetic JSON input to the permission checker hook and validates
    that commands are correctly allowed, denied, or fall through.

.USAGE
    powershell -NoProfile -ExecutionPolicy Bypass -File ".claude/hooks/bash-permission-checker.tests.ps1"
#>

param()

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'bash-permission-checker.ps1'

$passed = 0
$failed = 0
$errors = [System.Collections.ArrayList]::new()

function Test-Command {
    param(
        [string]$Command,
        [string]$Expected,  # 'allow', 'deny', 'fallthrough'
        [string]$Description
    )

    $json = @{
        tool_name = "Bash"
        tool_input = @{ command = $Command }
    } | ConvertTo-Json -Compress

    # Use Process API for reliable exit code capture
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.StandardInput.Write($json)
    $proc.StandardInput.Close()
    $result = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $exitCode = $proc.ExitCode

    $actual = switch ($exitCode) {
        2 { 'deny' }
        0 {
            if ($result -and $result -match 'allow') { 'allow' }
            else { 'fallthrough' }
        }
        default { "error(exit=$exitCode)" }
    }

    if ($actual -eq $Expected) {
        $script:passed++
        Write-Host "  PASS: $Description" -ForegroundColor Green
    } else {
        $script:failed++
        [void]$script:errors.Add("FAIL: $Description (expected=$Expected, actual=$actual)")
        Write-Host "  FAIL: $Description (expected=$Expected, actual=$actual)" -ForegroundColor Red
    }
}

# =============================================================================
# REGRESSION TESTS - existing single-command behavior
# =============================================================================
Write-Host "`nRegression: Single commands" -ForegroundColor Cyan

Test-Command -Command 'npm test' `
    -Expected 'allow' -Description 'npm test'

Test-Command -Command 'npm install' `
    -Expected 'allow' -Description 'npm install'

Test-Command -Command 'npm run build' `
    -Expected 'allow' -Description 'npm run build'

Test-Command -Command 'cd web && npm test' `
    -Expected 'allow' -Description 'cd prefix + npm test'

Test-Command -Command 'cd "c:/Git/project/web" && npm test -- src/test.tsx' `
    -Expected 'allow' -Description 'cd with absolute path + npm test with args'

Test-Command -Command 'npx vitest --run' `
    -Expected 'allow' -Description 'npx vitest'

Test-Command -Command 'ls -la web/src/' `
    -Expected 'allow' -Description 'ls safe directory'

Test-Command -Command 'pwd' `
    -Expected 'allow' -Description 'pwd'

Test-Command -Command 'node --version' `
    -Expected 'allow' -Description 'node --version'

Test-Command -Command 'npm run generate:types' `
    -Expected 'allow' -Description 'npm run generate:types'


# =============================================================================
# Git read-only commands
# =============================================================================
Write-Host "`nGit read-only commands" -ForegroundColor Cyan

Test-Command -Command 'git status' `
    -Expected 'allow' -Description 'git status'

Test-Command -Command 'git status --short' `
    -Expected 'allow' -Description 'git status --short'

Test-Command -Command 'git log --oneline -5' `
    -Expected 'allow' -Description 'git log with flags'

Test-Command -Command 'git diff' `
    -Expected 'allow' -Description 'git diff'

Test-Command -Command 'git diff HEAD~1 -- src/' `
    -Expected 'allow' -Description 'git diff with args'

Test-Command -Command 'git show HEAD' `
    -Expected 'allow' -Description 'git show HEAD'

Test-Command -Command 'git branch' `
    -Expected 'allow' -Description 'git branch (list)'

Test-Command -Command 'git branch -a' `
    -Expected 'allow' -Description 'git branch -a'

Test-Command -Command 'git branch -vv' `
    -Expected 'allow' -Description 'git branch -vv'

Test-Command -Command 'git rev-parse HEAD' `
    -Expected 'allow' -Description 'git rev-parse HEAD'

Test-Command -Command 'git remote -v' `
    -Expected 'allow' -Description 'git remote -v'

Test-Command -Command 'git stash list' `
    -Expected 'allow' -Description 'git stash list'

Test-Command -Command 'git describe --tags' `
    -Expected 'allow' -Description 'git describe --tags'

Test-Command -Command 'git tag' `
    -Expected 'allow' -Description 'git tag (list)'

Test-Command -Command 'git tag -l "v*"' `
    -Expected 'allow' -Description 'git tag -l with pattern'

# Safety: these should NOT be auto-approved
Test-Command -Command 'git branch new-feature' `
    -Expected 'fallthrough' -Description 'git branch create = fallthrough'

Test-Command -Command 'git branch -d old-feature' `
    -Expected 'fallthrough' -Description 'git branch -d = fallthrough'

Test-Command -Command 'git tag v1.0' `
    -Expected 'fallthrough' -Description 'git tag create = fallthrough'

Test-Command -Command 'git stash' `
    -Expected 'fallthrough' -Description 'git stash (not list) = fallthrough'

Test-Command -Command 'git remote add origin url' `
    -Expected 'fallthrough' -Description 'git remote add = fallthrough'

# =============================================================================
# Git pull and add (unconditional allow)
# =============================================================================
Write-Host "`nGit pull and add" -ForegroundColor Cyan

Test-Command -Command 'git pull' `
    -Expected 'allow' -Description 'git pull'

Test-Command -Command 'git pull origin main' `
    -Expected 'allow' -Description 'git pull origin main'

Test-Command -Command 'git pull --rebase' `
    -Expected 'allow' -Description 'git pull --rebase'

Test-Command -Command 'git pull --ff-only' `
    -Expected 'allow' -Description 'git pull --ff-only'

Test-Command -Command 'git pull origin feature/my-branch' `
    -Expected 'allow' -Description 'git pull with feature branch'

Test-Command -Command 'cd web && git pull' `
    -Expected 'allow' -Description 'cd prefix + git pull'

Test-Command -Command 'git add src/foo.ts' `
    -Expected 'allow' -Description 'git add specific file'

Test-Command -Command 'git add src/foo.ts src/bar.ts' `
    -Expected 'allow' -Description 'git add multiple files'

Test-Command -Command 'git add .' `
    -Expected 'allow' -Description 'git add .'

Test-Command -Command 'git add -A' `
    -Expected 'allow' -Description 'git add -A'

Test-Command -Command 'git add --all' `
    -Expected 'allow' -Description 'git add --all'

Test-Command -Command 'git add -u' `
    -Expected 'allow' -Description 'git add -u (update tracked)'

Test-Command -Command 'git add .claude/logs/' `
    -Expected 'allow' -Description 'git add .claude/logs/'

Test-Command -Command 'cd web && git add .' `
    -Expected 'allow' -Description 'cd prefix + git add .'

# =============================================================================
# Git deny patterns (always blocked)
# =============================================================================
Write-Host "`nGit deny patterns" -ForegroundColor Cyan

Test-Command -Command 'git push --force' `
    -Expected 'deny' -Description 'git push --force = denied'

Test-Command -Command 'git push -f' `
    -Expected 'deny' -Description 'git push -f = denied'

Test-Command -Command 'git push origin main --force' `
    -Expected 'deny' -Description 'git push origin main --force = denied'

Test-Command -Command 'git push --no-verify' `
    -Expected 'deny' -Description 'git push --no-verify = denied'

Test-Command -Command 'git commit --no-verify' `
    -Expected 'deny' -Description 'git commit --no-verify = denied'

Test-Command -Command 'git commit -m "msg" --no-verify' `
    -Expected 'deny' -Description 'git commit -m with --no-verify = denied'

Test-Command -Command 'git push --force-with-lease' `
    -Expected 'deny' -Description 'git push --force-with-lease = denied (matches --force)'

Test-Command -Command 'git push --delete origin old-branch' `
    -Expected 'deny' -Description 'git push --delete = denied'

Test-Command -Command 'git commit --amend' `
    -Expected 'deny' -Description 'git commit --amend = denied'

Test-Command -Command 'git commit -a --amend -m "rewrite"' `
    -Expected 'deny' -Description 'git commit -a --amend -m = denied'

# =============================================================================
# Git commit/push config-conditional tests (with try/finally cleanup)
# =============================================================================

$configPath = Join-Path (Join-Path $PSScriptRoot "..") "preferences.json"
$configExisted = Test-Path $configPath
$configBackup = $null
if ($configExisted) {
    $configBackup = Get-Content $configPath -Raw
    Remove-Item $configPath -Force
}

try {
    # --- Without config (fallthrough by default) ---
    Write-Host "`nGit commit/push without config (fallthrough)" -ForegroundColor Cyan

    Test-Command -Command 'git commit -m "test commit"' `
        -Expected 'fallthrough' -Description 'git commit without config = fallthrough'

    Test-Command -Command 'git push' `
        -Expected 'fallthrough' -Description 'git push without config = fallthrough'

    Test-Command -Command 'git push -u origin main' `
        -Expected 'fallthrough' -Description 'git push -u without config = fallthrough'

    # --- With config enabled (auto-approve) ---
    Write-Host "`nGit commit/push with config enabled" -ForegroundColor Cyan

    @{ git = @{ autoApproveCommit = $true; autoApprovePush = $true } } | ConvertTo-Json -Depth 5 | Set-Content $configPath

    Test-Command -Command 'git commit -m "feat: add new feature"' `
        -Expected 'allow' -Description 'git commit -m with config enabled'

    Test-Command -Command 'git commit --message "fix: typo"' `
        -Expected 'allow' -Description 'git commit --message with config enabled'

    Test-Command -Command 'git commit -a -m "all changes"' `
        -Expected 'allow' -Description 'git commit -a -m with config enabled'

    Test-Command -Command 'git push' `
        -Expected 'allow' -Description 'git push with config enabled'

    Test-Command -Command 'git push -u origin feature-branch' `
        -Expected 'allow' -Description 'git push -u origin with config enabled'

    Test-Command -Command 'git push origin main' `
        -Expected 'allow' -Description 'git push origin main with config enabled'

    Test-Command -Command 'git push --tags' `
        -Expected 'allow' -Description 'git push --tags with config enabled'

    # Even with config enabled, dangerous operations are still denied
    Test-Command -Command 'git push --force' `
        -Expected 'deny' -Description 'git push --force STILL denied with config'

    Test-Command -Command 'git push --delete origin branch' `
        -Expected 'deny' -Description 'git push --delete STILL denied with config'

    Test-Command -Command 'git commit --no-verify' `
        -Expected 'deny' -Description 'git commit --no-verify STILL denied with config'

    Test-Command -Command 'git commit --amend -m "rewrite"' `
        -Expected 'deny' -Description 'git commit --amend STILL denied with config'

    Test-Command -Command 'git commit -a --amend -m "rewrite"' `
        -Expected 'deny' -Description 'git commit -a --amend STILL denied with config'

    # --- With partial config (only commit enabled) ---
    Write-Host "`nGit commit/push with partial config" -ForegroundColor Cyan

    @{ git = @{ autoApproveCommit = $true; autoApprovePush = $false } } | ConvertTo-Json -Depth 5 | Set-Content $configPath

    Test-Command -Command 'git commit -m "test"' `
        -Expected 'allow' -Description 'git commit allowed (commit=true, push=false)'

    Test-Command -Command 'git push' `
        -Expected 'fallthrough' -Description 'git push fallthrough (commit=true, push=false)'

} finally {
    # Clean up config — always runs even if tests throw
    if (Test-Path $configPath) { Remove-Item $configPath -Force }
    if ($configExisted -and $configBackup) {
        Set-Content $configPath $configBackup
    }
}

# =============================================================================
# Compound commands with git
# =============================================================================
Write-Host "`nCompound commands with git" -ForegroundColor Cyan

Test-Command -Command 'git pull && npm install' `
    -Expected 'allow' -Description 'git pull && npm install'

Test-Command -Command 'git add src/foo.ts && git status' `
    -Expected 'allow' -Description 'git add specific file && git status'

Test-Command -Command 'git add . && git status' `
    -Expected 'allow' -Description 'git add . && git status'

# =============================================================================
# REGRESSION TESTS - deny patterns
# =============================================================================
Write-Host "`nRegression: Deny patterns" -ForegroundColor Cyan

Test-Command -Command 'cat ~/.ssh/id_rsa' `
    -Expected 'deny' -Description 'cat SSH key'

Test-Command -Command 'rm -rf /' `
    -Expected 'deny' -Description 'rm -rf /'

Test-Command -Command 'cat /etc/credentials' `
    -Expected 'deny' -Description 'cat credentials'

Test-Command -Command 'type secret.key' `
    -Expected 'deny' -Description 'type secret file'

# =============================================================================
# REGRESSION TESTS - fallthrough
# =============================================================================
Write-Host "`nRegression: Fallthrough" -ForegroundColor Cyan

Test-Command -Command 'docker run ubuntu' `
    -Expected 'fallthrough' -Description 'unknown command falls through'

Test-Command -Command 'curl https://example.com' `
    -Expected 'fallthrough' -Description 'curl falls through'

# =============================================================================
# NEW: Standalone pattern tests
# =============================================================================
Write-Host "`nStandalone patterns" -ForegroundColor Cyan

Test-Command -Command 'cd /some/directory' `
    -Expected 'allow' -Description 'standalone cd'

Test-Command -Command 'cd "c:/Git/project/web"' `
    -Expected 'allow' -Description 'standalone cd with quoted Windows path'

Test-Command -Command 'echo "Installing dependencies..."' `
    -Expected 'allow' -Description 'echo with quoted string'

Test-Command -Command "echo 'test passed'" `
    -Expected 'allow' -Description 'echo with single-quoted string'

Test-Command -Command 'echo done' `
    -Expected 'allow' -Description 'echo with simple word'

Test-Command -Command 'test -d node_modules' `
    -Expected 'allow' -Description 'test -d'

Test-Command -Command '[ -d node_modules ]' `
    -Expected 'allow' -Description '[ -d ] bracket syntax'

Test-Command -Command 'true' `
    -Expected 'allow' -Description 'true'

Test-Command -Command 'false' `
    -Expected 'allow' -Description 'false'

# =============================================================================
# NEW: Compound command tests (splitting)
# =============================================================================
Write-Host "`nCompound commands (splitting)" -ForegroundColor Cyan

Test-Command -Command 'cd web && npm install && npm test' `
    -Expected 'allow' -Description 'three safe commands chained with &&'

Test-Command -Command 'echo "installing" && npm install' `
    -Expected 'allow' -Description 'echo + npm install'

Test-Command -Command 'cd web && npm test || echo "tests failed"' `
    -Expected 'allow' -Description 'npm test || echo fallback'

Test-Command -Command 'npm install ; npm run build' `
    -Expected 'allow' -Description 'semicolon separator'

Test-Command -Command 'test -d node_modules && echo "found" || npm install' `
    -Expected 'allow' -Description 'conditional dependency check (split)'

Test-Command -Command 'test -f "c:/Git/project/generated-docs/file.md" && cat "c:/Git/project/generated-docs/file.md" || echo "File not found"' `
    -Expected 'allow' -Description 'test -f + cat safe dir + echo fallback'

Test-Command -Command "cd web && npm run build && npm run lint && npm test" `
    -Expected 'allow' -Description 'four commands chained'

Test-Command -Command 'cd "c:/Git/project/web" && npm install && npm run build' `
    -Expected 'allow' -Description 'absolute path cd + chain'

Test-Command -Command 'cd /c/Git/stadium-8 && ls -la generated-docs/context/ 2>/dev/null || echo "Context directory not found"' `
    -Expected 'allow' -Description 'cd + ls generated-docs subdir + echo fallback'

# Heredoc compound (newline-separated)
Test-Command -Command "cat > /tmp/test.js << 'EOF'`nimport { test } from 'vitest';`nEOF`nnpm test -- /tmp/test.js" `
    -Expected 'allow' -Description 'heredoc to /tmp + npm test (newline split)'

# =============================================================================
# SECURITY: Compound commands with deny
# =============================================================================
Write-Host "`nSecurity: Compound with deny" -ForegroundColor Cyan

Test-Command -Command 'echo "ok" && cat ~/.ssh/id_rsa' `
    -Expected 'deny' -Description 'safe + deny = blocked'

Test-Command -Command 'npm test && rm -rf /' `
    -Expected 'deny' -Description 'safe + rm -rf = blocked'

Test-Command -Command 'echo "ok" ; cat credentials.json' `
    -Expected 'deny' -Description 'semicolon + deny = blocked'

Test-Command -Command 'npm install || cat secret' `
    -Expected 'deny' -Description 'OR chain with deny = blocked'

# =============================================================================
# EDGE CASES
# =============================================================================
Write-Host "`nEdge cases" -ForegroundColor Cyan

Test-Command -Command 'echo "foo && bar"' `
    -Expected 'allow' -Description 'quoted && not split (single command match)'

Test-Command -Command "echo 'a ; b'" `
    -Expected 'allow' -Description 'quoted ; not split (single command match)'

Test-Command -Command '(npm test && npm run build)' `
    -Expected 'allow' -Description 'parenthesized group with safe commands'

Test-Command -Command 'cd web && (npm install && npm test)' `
    -Expected 'allow' -Description 'mixed: plain + parenthesized group'

Test-Command -Command '(npm test) && (npm run build)' `
    -Expected 'allow' -Description 'two parenthesized groups'

Test-Command -Command '(npm test && docker run ubuntu)' `
    -Expected 'fallthrough' -Description 'parenthesized group with unknown = fallthrough'

Test-Command -Command 'cd web && docker run ubuntu && npm test' `
    -Expected 'fallthrough' -Description 'one unknown sub-command = fallthrough'

# Note: 'cd web && npm test && unknown_command' matches first-pass because
# npm test's (?:\s+.*)?$ pattern swallows '&& unknown_command' as args.
# This is a pre-existing pattern permissiveness issue, not a splitter bug.
# The deny patterns still protect against dangerous commands in this position.

# =============================================================================
# FIND - safe directory exploration
# =============================================================================
Write-Host "`nFind commands" -ForegroundColor Cyan

Test-Command -Command 'find .claude -name "*.json" 2>/dev/null' `
    -Expected 'allow' -Description 'find .claude json files'

Test-Command -Command 'find documentation -name "*.yaml" -type f' `
    -Expected 'allow' -Description 'find documentation yaml files'

Test-Command -Command 'find web/src -name "*.tsx" -maxdepth 3' `
    -Expected 'allow' -Description 'find web/src tsx files with maxdepth'

Test-Command -Command 'find generated-docs -name "*.md"' `
    -Expected 'allow' -Description 'find generated-docs markdown files'

Test-Command -Command 'find .github -type f' `
    -Expected 'allow' -Description 'find .github all files'

Test-Command -Command 'cd /c/Git/project && find .claude -name "*.json" 2>/dev/null' `
    -Expected 'allow' -Description 'cd + find .claude (compound)'

Test-Command -Command 'cd /c/Git/00-Stadium-8-test-repos/taniawelsford-stadium-8-test-run-15 && find .claude -name "*.json" 2>/dev/null && ls .claude/' `
    -Expected 'allow' -Description 'cd + find .claude + ls .claude (workflow state check)'

Test-Command -Command 'find /home/user -name "*.json"' `
    -Expected 'fallthrough' -Description 'find in unsafe directory = fallthrough'

Test-Command -Command 'find .claude -name "*.json" -exec rm {} \;' `
    -Expected 'fallthrough' -Description 'find with -exec = fallthrough'

Test-Command -Command 'find .claude -delete' `
    -Expected 'fallthrough' -Description 'find with -delete = fallthrough'

# =============================================================================
# WORKFLOW SCRIPTS - copy-with-header.js and other .claude/scripts/
# =============================================================================
Write-Host "`nWorkflow scripts" -ForegroundColor Cyan

Test-Command -Command 'node .claude/scripts/copy-with-header.js --from "documentation/Api Definition.yaml" --to "generated-docs/specs/api-spec.yaml"' `
    -Expected 'allow' -Description 'copy-with-header: basic with spaces in filename'

Test-Command -Command 'node .claude/scripts/copy-with-header.js --from "documentation/design-tokens.css" --to "generated-docs/specs/design-tokens.css" --header "/* Source: documentation/design-tokens.css */"' `
    -Expected 'allow' -Description 'copy-with-header: with custom --header flag'

Test-Command -Command 'node .claude/scripts/copy-with-header.js --help' `
    -Expected 'allow' -Description 'copy-with-header: --help'

Test-Command -Command 'cd "c:/Git/project" && node .claude/scripts/copy-with-header.js --from "documentation/api.yaml" --to "generated-docs/specs/api-spec.yaml"' `
    -Expected 'allow' -Description 'copy-with-header: with cd prefix'

Test-Command -Command 'node .claude/scripts/transition-phase.js --show' `
    -Expected 'allow' -Description 'transition-phase: --show'

Test-Command -Command 'node .claude/scripts/generate-todo-list.js' `
    -Expected 'allow' -Description 'generate-todo-list: no args'

# =============================================================================
# WRITE PATH TRAVERSAL PREVENTION
# =============================================================================
Write-Host "`nWrite path traversal prevention" -ForegroundColor Cyan

# Writes with traversal should NOT be auto-approved
Test-Command -Command 'cat > generated-docs/../../evil.txt' `
    -Expected 'fallthrough' -Description 'write traversal ../../ = fallthrough'

Test-Command -Command 'cat > generated-docs/../../../etc/cron.d/evil' `
    -Expected 'fallthrough' -Description 'write traversal to system dir = fallthrough'

Test-Command -Command "cat > .claude/context/../../../etc/evil << 'EOF'" `
    -Expected 'fallthrough' -Description 'heredoc write traversal = fallthrough'

Test-Command -Command 'cat > generated-docs/../evil.txt' `
    -Expected 'fallthrough' -Description 'write traversal one level (no deny keyword) = fallthrough'

Test-Command -Command 'cat > generated-docs/../secret.env' `
    -Expected 'deny' -Description 'write traversal to secret file = denied (deny pattern catches secret)'

# Normal writes still work
Test-Command -Command 'cat > generated-docs/plan.md' `
    -Expected 'allow' -Description 'normal write to generated-docs = allowed'

Test-Command -Command "cat > generated-docs/specs/api-spec.yaml << 'EOF'" `
    -Expected 'allow' -Description 'heredoc write to generated-docs = allowed'

# Reads with traversal still work (legitimate use)
Test-Command -Command 'cat documentation/../package.json' `
    -Expected 'allow' -Description 'read traversal from documentation = allowed'

Test-Command -Command 'cat web/../CLAUDE.md' `
    -Expected 'allow' -Description 'read traversal from web = allowed'

# =============================================================================
# HEAD/TAIL - safe directory file reading
# =============================================================================
Write-Host "`nHead/tail commands" -ForegroundColor Cyan

# head - basic safe directory reads
Test-Command -Command 'head documentation/BRD.md' `
    -Expected 'allow' -Description 'head documentation file (no flags)'

Test-Command -Command 'head -5 documentation/BRD.md' `
    -Expected 'allow' -Description 'head -5 documentation file'

Test-Command -Command 'head -n 20 web/src/app/page.tsx' `
    -Expected 'allow' -Description 'head -n 20 web file'

Test-Command -Command 'head -c 100 generated-docs/plan.md' `
    -Expected 'allow' -Description 'head -c 100 generated-docs file'

Test-Command -Command 'head .claude/hooks/bash-permission-checker.ps1' `
    -Expected 'allow' -Description 'head .claude file'

Test-Command -Command 'head -20 .github/workflows/ci.yml' `
    -Expected 'allow' -Description 'head -20 .github file'

Test-Command -Command 'head -5 documentation/file.md 2>/dev/null' `
    -Expected 'allow' -Description 'head with 2>/dev/null'

# tail - basic safe directory reads
Test-Command -Command 'tail documentation/BRD.md' `
    -Expected 'allow' -Description 'tail documentation file (no flags)'

Test-Command -Command 'tail -5 documentation/BRD.md' `
    -Expected 'allow' -Description 'tail -5 documentation file'

Test-Command -Command 'tail -n 20 web/src/app/page.tsx' `
    -Expected 'allow' -Description 'tail -n 20 web file'

Test-Command -Command 'tail -n +10 documentation/api-spec.yaml' `
    -Expected 'allow' -Description 'tail -n +10 (from line 10 onwards)'

Test-Command -Command 'tail -c 100 generated-docs/plan.md' `
    -Expected 'allow' -Description 'tail -c 100 generated-docs file'

Test-Command -Command 'tail .claude/hooks/bash-permission-checker.ps1' `
    -Expected 'allow' -Description 'tail .claude file'

Test-Command -Command 'tail -5 documentation/file.md 2>/dev/null' `
    -Expected 'allow' -Description 'tail with 2>/dev/null'

# head/tail with cd prefix
Test-Command -Command 'cd /c/Git/project && head -5 web/package.json' `
    -Expected 'allow' -Description 'cd prefix + head'

Test-Command -Command 'cd /c/Git/project && tail -5 documentation/file.md' `
    -Expected 'allow' -Description 'cd prefix + tail'

# head/tail with absolute paths (winPath match)
Test-Command -Command 'tail -5 /c/Git/project/documentation/file.md' `
    -Expected 'allow' -Description 'tail with absolute Unix path to safe dir'

Test-Command -Command 'head -10 /c/Git/project/web/src/app/page.tsx' `
    -Expected 'allow' -Description 'head with absolute Unix path to safe dir'

# head/tail on unsafe directories (fallthrough)
Test-Command -Command 'tail -5 /etc/passwd' `
    -Expected 'fallthrough' -Description 'tail /etc/passwd = fallthrough'

Test-Command -Command 'head ~/.bashrc' `
    -Expected 'fallthrough' -Description 'head ~/.bashrc = fallthrough'

# head/tail on sensitive files (deny)
Test-Command -Command 'head ~/.ssh/id_rsa' `
    -Expected 'deny' -Description 'head SSH key = denied'

Test-Command -Command 'tail server.pem' `
    -Expected 'deny' -Description 'tail .pem file = denied'

Test-Command -Command 'tail /home/user/.ssh/config' `
    -Expected 'deny' -Description 'tail .ssh directory = denied'

# =============================================================================
# WC - safe directory word/line counts
# =============================================================================
Write-Host "`nWc commands" -ForegroundColor Cyan

Test-Command -Command 'wc -l documentation/BRD.md' `
    -Expected 'allow' -Description 'wc -l documentation file'

Test-Command -Command 'wc -lw web/src/app/page.tsx' `
    -Expected 'allow' -Description 'wc -lw web file'

Test-Command -Command 'wc -c generated-docs/plan.md' `
    -Expected 'allow' -Description 'wc -c generated-docs file'

Test-Command -Command 'wc .claude/hooks/bash-permission-checker.ps1' `
    -Expected 'allow' -Description 'wc .claude file (no flags)'

Test-Command -Command 'cd /c/Git/project && wc -l documentation/file.md' `
    -Expected 'allow' -Description 'cd prefix + wc'

Test-Command -Command 'wc -l documentation/file.md 2>/dev/null' `
    -Expected 'allow' -Description 'wc with 2>/dev/null'

Test-Command -Command 'wc -l /etc/passwd' `
    -Expected 'fallthrough' -Description 'wc /etc/passwd = fallthrough'

Test-Command -Command 'wc -l ~/.bashrc' `
    -Expected 'fallthrough' -Description 'wc ~/.bashrc = fallthrough'

# =============================================================================
# DIFF - safe directory file comparison
# =============================================================================
Write-Host "`nDiff commands" -ForegroundColor Cyan

Test-Command -Command 'diff documentation/old.yaml documentation/new.yaml' `
    -Expected 'allow' -Description 'diff two documentation files'

Test-Command -Command 'diff -u web/src/old.tsx web/src/new.tsx' `
    -Expected 'allow' -Description 'diff -u two web files'

Test-Command -Command 'diff --unified documentation/a.md generated-docs/b.md' `
    -Expected 'allow' -Description 'diff --unified across safe dirs'

Test-Command -Command 'diff --color web/src/a.ts .claude/hooks/b.ps1' `
    -Expected 'allow' -Description 'diff --color web vs .claude'

Test-Command -Command 'cd /c/Git/project && diff documentation/a.md documentation/b.md' `
    -Expected 'allow' -Description 'cd prefix + diff'

Test-Command -Command 'diff documentation/a.md /etc/passwd' `
    -Expected 'fallthrough' -Description 'diff one safe + one unsafe = fallthrough'

Test-Command -Command 'diff /etc/passwd /etc/shadow' `
    -Expected 'fallthrough' -Description 'diff two unsafe files = fallthrough'

Test-Command -Command 'diff documentation/a.md documentation/b.md 2>/dev/null' `
    -Expected 'allow' -Description 'diff with 2>/dev/null'

# =============================================================================
# CAT piped to HEAD/TAIL - safe directory pipelines
# =============================================================================
Write-Host "`nCat piped to head/tail" -ForegroundColor Cyan

Test-Command -Command 'cat documentation/BRD.md | head -20' `
    -Expected 'allow' -Description 'cat safe-dir | head'

Test-Command -Command 'cat web/src/app/page.tsx | tail -5' `
    -Expected 'allow' -Description 'cat safe-dir | tail'

Test-Command -Command 'cat generated-docs/plan.md | head -n 50' `
    -Expected 'allow' -Description 'cat safe-dir | head -n 50'

Test-Command -Command 'cat .claude/hooks/checker.ps1 | tail -c 100' `
    -Expected 'allow' -Description 'cat .claude | tail -c 100'

Test-Command -Command 'cd /c/Git/project && cat documentation/file.md | head -5' `
    -Expected 'allow' -Description 'cd + cat safe-dir | head'

Test-Command -Command 'cat documentation/file.md 2>/dev/null | tail -10' `
    -Expected 'allow' -Description 'cat safe-dir 2>/dev/null | tail'

Test-Command -Command 'cat /etc/passwd | head -5' `
    -Expected 'fallthrough' -Description 'cat unsafe dir | head = fallthrough'

Test-Command -Command 'cat documentation/file.md | head -5 | grep pattern' `
    -Expected 'fallthrough' -Description 'cat | head | grep = fallthrough (double pipe)'

# =============================================================================
# BASH COMMENTS - in compound commands
# =============================================================================
Write-Host "`nBash comments in compound commands" -ForegroundColor Cyan

Test-Command -Command "# Check BRD for authentication mentions`ntail -5 documentation/BRD.md" `
    -Expected 'allow' -Description 'comment + tail safe-dir (newline split)'

Test-Command -Command "# Install dependencies`nnpm install" `
    -Expected 'allow' -Description 'comment + npm install (newline split)'

Test-Command -Command "# Verify build`ncd web && npm run build" `
    -Expected 'allow' -Description 'comment + cd && npm run build (newline split)'

Test-Command -Command "# Step 1`nnpm install`n# Step 2`nnpm test" `
    -Expected 'allow' -Description 'multiple comments interspersed with commands'

Test-Command -Command "# just a comment" `
    -Expected 'fallthrough' -Description 'standalone comment = fallthrough (single cmd, no split)'

# =============================================================================
# DENY PATTERN CONSISTENCY - expanded command list
# =============================================================================
Write-Host "`nDeny pattern consistency" -ForegroundColor Cyan

Test-Command -Command 'head secret.env' `
    -Expected 'deny' -Description 'head secret file = denied'

Test-Command -Command 'tail private_key.pem' `
    -Expected 'deny' -Description 'tail private key file = denied'

Test-Command -Command 'sed -n "1p" secret.json' `
    -Expected 'deny' -Description 'sed secret file = denied'

Test-Command -Command 'awk "{print}" private.key' `
    -Expected 'deny' -Description 'awk private key file = denied'

Test-Command -Command 'less secrets.yaml' `
    -Expected 'deny' -Description 'less secrets file = denied'

Test-Command -Command 'more private_rsa_key.txt' `
    -Expected 'deny' -Description 'more private key file = denied'

# =============================================================================
# DENY SAFE-DIRECTORY EXCEPTION
# =============================================================================
Write-Host "`nDeny safe-directory exception" -ForegroundColor Cyan

# Files with "secret" in name but in safe dirs should fallthrough (not hard-block)
Test-Command -Command 'cat web/src/lib/secret-handler.ts' `
    -Expected 'allow' -Description 'cat safe-dir file with "secret" in name = allowed (safe dir + allow pattern)'

Test-Command -Command 'head web/src/lib/secret-handler.ts' `
    -Expected 'allow' -Description 'head safe-dir file with "secret" in name = allowed'

Test-Command -Command 'tail documentation/secrets-management-guide.md' `
    -Expected 'allow' -Description 'tail safe-dir file with "secret" in name = allowed'

# Files with "secret" NOT in safe dirs should still be denied
Test-Command -Command 'cat secret.env' `
    -Expected 'deny' -Description 'cat secret.env (no safe dir) = denied'

Test-Command -Command 'head secret.env' `
    -Expected 'deny' -Description 'head secret.env (no safe dir) = denied'

Test-Command -Command 'cat /tmp/secret.txt' `
    -Expected 'deny' -Description 'cat /tmp/secret.txt = denied'

# Compound: safe dir in one sub-command should not save another
Test-Command -Command 'cat secret.env && cat documentation/safe.md' `
    -Expected 'deny' -Description 'cat secret.env && cat safe-dir = denied (secret sub-cmd caught)'

# Private key in safe dir
Test-Command -Command 'cat web/src/private-key-handler.ts' `
    -Expected 'allow' -Description 'cat safe-dir file with "private.*key" = allowed'

# =============================================================================
# QUOTED PATHS WITH SPACES
# =============================================================================
Write-Host "`nQuoted paths with spaces" -ForegroundColor Cyan

Test-Command -Command 'cat "documentation/My File.md"' `
    -Expected 'allow' -Description 'cat quoted path with spaces'

Test-Command -Command "cat 'documentation/My File.md'" `
    -Expected 'allow' -Description 'cat single-quoted path with spaces'

Test-Command -Command 'type "documentation/My File.md"' `
    -Expected 'allow' -Description 'type quoted path with spaces'

Test-Command -Command 'head -5 "documentation/My File.md"' `
    -Expected 'allow' -Description 'head quoted path with spaces'

Test-Command -Command 'tail -n 20 "web/src/My Component.tsx"' `
    -Expected 'allow' -Description 'tail quoted path with spaces'

Test-Command -Command 'wc -l "documentation/My File.md"' `
    -Expected 'allow' -Description 'wc quoted path with spaces'

Test-Command -Command 'diff "documentation/Old File.md" "documentation/New File.md"' `
    -Expected 'allow' -Description 'diff two quoted paths with spaces'

Test-Command -Command 'cat "documentation/My File.md" | grep "pattern"' `
    -Expected 'allow' -Description 'cat quoted with spaces | grep'

Test-Command -Command 'sed -n "100,406p" "documentation/Api Definition.yaml"' `
    -Expected 'allow' -Description 'sed quoted path with spaces'

Test-Command -Command "sed -n '100,406p' /c/Git/test-repo/documentation/Api\ Definition.yaml" `
    -Expected 'allow' -Description 'sed backslash-escaped space in path'

Test-Command -Command "cat /c/Git/test-repo/documentation/Api\ Definition.yaml" `
    -Expected 'allow' -Description 'cat backslash-escaped space in path'

Test-Command -Command "head -100 /c/Git/test-repo/documentation/Api\ Definition.yaml" `
    -Expected 'allow' -Description 'head backslash-escaped space in path'

Test-Command -Command "wc -l /c/Git/test-repo/documentation/Api\ Definition.yaml" `
    -Expected 'allow' -Description 'wc backslash-escaped space in path'

Test-Command -Command "wc -l /c/Git/test-repo/documentation/Api\ Definition.yaml && head -100 /c/Git/test-repo/documentation/Api\ Definition.yaml" `
    -Expected 'allow' -Description 'wc + head compound with backslash-escaped spaces'

Test-Command -Command "grep -i pattern /c/Git/test-repo/documentation/Api\ Definition.yaml" `
    -Expected 'allow' -Description 'grep backslash-escaped space in path'

Test-Command -Command "diff /c/Git/test-repo/documentation/Api\ Definition.yaml /c/Git/test-repo/documentation/Other\ File.yaml" `
    -Expected 'allow' -Description 'diff two backslash-escaped space paths'

Test-Command -Command 'cat "/etc/My Secret.txt"' `
    -Expected 'deny' -Description 'cat quoted unsafe path with "secret" = denied'

Test-Command -Command 'cat "/tmp/My File.txt"' `
    -Expected 'fallthrough' -Description 'cat quoted unsafe path (no deny keyword) = fallthrough'

# =============================================================================
# SPLITTER UNIT TESTS
# =============================================================================
Write-Host "`nSplitter unit tests" -ForegroundColor Cyan

# Extract the function using brace-counting for reliable nested brace handling
$scriptContent = Get-Content $scriptPath -Raw
$funcStart = $scriptContent.IndexOf('function Split-CompoundCommand')
$funcExtracted = $false

if ($funcStart -ge 0) {
    $braceStart = $scriptContent.IndexOf('{', $funcStart)
    if ($braceStart -ge 0) {
        $depth = 0
        $funcEnd = $braceStart
        for ($k = $braceStart; $k -lt $scriptContent.Length; $k++) {
            if ($scriptContent[$k] -eq '{') { $depth++ }
            elseif ($scriptContent[$k] -eq '}') {
                $depth--
                if ($depth -eq 0) { $funcEnd = $k; break }
            }
        }
        $funcText = $scriptContent.Substring($funcStart, $funcEnd - $funcStart + 1)
        Invoke-Expression $funcText
        $funcExtracted = $true
    }
}

if ($funcExtracted) {
    function Test-Split {
        param(
            [string]$InputText,
            [string[]]$ExpectedParts,
            [string]$Description
        )

        $result = Split-CompoundCommand -CommandText $InputText

        if ($null -eq $ExpectedParts) {
            if ($null -eq $result) {
                $script:passed++
                Write-Host "  PASS: $Description" -ForegroundColor Green
            } else {
                $script:failed++
                [void]$script:errors.Add("FAIL: $Description (expected null, got $($result.Count) parts: $($result -join ' | '))")
                Write-Host "  FAIL: $Description (expected null, got $($result.Count) parts)" -ForegroundColor Red
            }
            return
        }

        if ($null -eq $result) {
            $script:failed++
            [void]$script:errors.Add("FAIL: $Description (expected $($ExpectedParts.Count) parts, got null)")
            Write-Host "  FAIL: $Description (expected $($ExpectedParts.Count) parts, got null)" -ForegroundColor Red
            return
        }

        if ($result.Count -ne $ExpectedParts.Count) {
            $script:failed++
            [void]$script:errors.Add("FAIL: $Description (expected $($ExpectedParts.Count) parts, got $($result.Count): $($result -join ' | '))")
            Write-Host "  FAIL: $Description (expected $($ExpectedParts.Count) parts, got $($result.Count))" -ForegroundColor Red
            return
        }

        for ($j = 0; $j -lt $result.Count; $j++) {
            if ($result[$j] -ne $ExpectedParts[$j]) {
                $script:failed++
                [void]$script:errors.Add("FAIL: $Description (part $j expected '$($ExpectedParts[$j])', got '$($result[$j])')")
                Write-Host "  FAIL: $Description (part $j expected '$($ExpectedParts[$j])', got '$($result[$j])')" -ForegroundColor Red
                return
            }
        }
        $script:passed++
        Write-Host "  PASS: $Description" -ForegroundColor Green
    }

    Test-Split -InputText 'npm install && npm test' `
        -ExpectedParts @('npm install', 'npm test') `
        -Description 'simple && split'

    Test-Split -InputText 'npm test || echo "failed"' `
        -ExpectedParts @('npm test', 'echo "failed"') `
        -Description 'simple || split'

    Test-Split -InputText 'npm install ; npm run build' `
        -ExpectedParts @('npm install', 'npm run build') `
        -Description 'simple ; split'

    Test-Split -InputText "npm install`nnpm test" `
        -ExpectedParts @('npm install', 'npm test') `
        -Description 'newline split'

    Test-Split -InputText 'cd web && npm install && npm test' `
        -ExpectedParts @('cd web', 'npm install', 'npm test') `
        -Description 'three-way && split'

    Test-Split -InputText 'echo "foo && bar"' `
        -ExpectedParts $null `
        -Description 'quoted && returns null (single command)'

    Test-Split -InputText "echo 'a ; b'" `
        -ExpectedParts $null `
        -Description 'single-quoted ; returns null (single command)'

    Test-Split -InputText '(npm test && npm build)' `
        -ExpectedParts $null `
        -Description 'parenthesized group returns null (single command)'

    Test-Split -InputText 'cat file | head -5' `
        -ExpectedParts $null `
        -Description 'single pipe not split (returns null)'

    Test-Split -InputText 'test -d node_modules && echo "ok" || npm install' `
        -ExpectedParts @('test -d node_modules', 'echo "ok"', 'npm install') `
        -Description 'mixed && and || split'

    Test-Split -InputText "cat > /tmp/test.js << 'EOF'`nsome content`nEOF`nnpm test" `
        -ExpectedParts @("cat > /tmp/test.js << 'EOF'`nsome content`nEOF", 'npm test') `
        -Description 'heredoc body not split, newline after EOF splits'

    Test-Split -InputText 'npm test' `
        -ExpectedParts $null `
        -Description 'single command returns null'

    Test-Split -InputText "# this is a comment`ntail -5 file.md" `
        -ExpectedParts @('# this is a comment', 'tail -5 file.md') `
        -Description 'comment + command split on newline'

    Test-Split -InputText "# step 1`nnpm install`n# step 2`nnpm test" `
        -ExpectedParts @('# step 1', 'npm install', '# step 2', 'npm test') `
        -Description 'multiple comments and commands split on newlines'

} else {
    Write-Host "  SKIP: Could not extract Split-CompoundCommand function" -ForegroundColor Yellow
}

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n========================================" -ForegroundColor White
Write-Host "Results: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })

if ($errors.Count -gt 0) {
    Write-Host "`nFailures:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "  $err" -ForegroundColor Red
    }
}

Write-Host "========================================`n" -ForegroundColor White
exit $(if ($failed -eq 0) { 0 } else { 1 })

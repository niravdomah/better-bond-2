<#
.SYNOPSIS
    PreToolUse hook that auto-approves safe Bash commands for Claude Code.

.DESCRIPTION
    Receives tool call JSON via stdin, checks against deny/allow patterns,
    and outputs permission decision JSON.

    Exit codes:
    - 0 with JSON output: Command approved
    - 0 without output: Falls through to normal permission system
    - 2: Block the command

.NOTES
    Location: .claude/hooks/bash-permission-checker.ps1
#>

param()

# Read JSON input from stdin
$inputJson = $null
try {
    $inputJson = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch {
    exit 0
}

# Only process Bash tool calls
if ($inputJson.tool_name -ne "Bash") {
    exit 0
}

$command = $inputJson.tool_input.command
if (-not $command) {
    exit 0
}

# =============================================================================
# COMPOUND COMMAND SPLITTER
# =============================================================================
# Splits compound commands on &&, ||, ;, and newlines while respecting quotes,
# heredocs, and parenthesized groups. Returns $null on ambiguity (safe fallthrough).

function Split-CompoundCommand {
    param([string]$CommandText)

    $commands = [System.Collections.ArrayList]::new()
    $current = [System.Text.StringBuilder]::new()
    $i = 0
    $len = $CommandText.Length
    $state = 'NORMAL'
    $heredocDelimiter = $null
    $parenDepth = 0

    while ($i -lt $len) {
        $c = $CommandText[$i]

        switch ($state) {
            'SINGLE_QUOTE' {
                [void]$current.Append($c)
                if ($c -eq "'") { $state = 'NORMAL' }
                $i++
                continue
            }
            'DOUBLE_QUOTE' {
                [void]$current.Append($c)
                # Handle escaped double quote
                if ($c -eq '\' -and ($i + 1) -lt $len -and $CommandText[$i + 1] -eq '"') {
                    [void]$current.Append($CommandText[$i + 1])
                    $i += 2
                    continue
                }
                if ($c -eq '"') { $state = 'NORMAL' }
                $i++
                continue
            }
            'HEREDOC' {
                [void]$current.Append($c)
                # Check if we're at a newline - the delimiter must be on its own line
                if ($c -eq "`n") {
                    # Look ahead to see if the next line is the delimiter
                    $lineEnd = $CommandText.IndexOf("`n", $i + 1)
                    if ($lineEnd -eq -1) { $lineEnd = $len }
                    $line = $CommandText.Substring($i + 1, $lineEnd - $i - 1).Trim()
                    if ($line -eq $heredocDelimiter) {
                        # Append the delimiter line and exit heredoc state
                        [void]$current.Append($CommandText.Substring($i + 1, $lineEnd - $i - 1))
                        $i = $lineEnd
                        $state = 'NORMAL'
                        $heredocDelimiter = $null
                        continue
                    }
                }
                $i++
                continue
            }
            'NORMAL' {
                # --- Quotes ---
                if ($c -eq "'" -and $parenDepth -eq 0) {
                    [void]$current.Append($c)
                    $state = 'SINGLE_QUOTE'
                    $i++
                    continue
                }
                if ($c -eq '"' -and $parenDepth -eq 0) {
                    [void]$current.Append($c)
                    $state = 'DOUBLE_QUOTE'
                    $i++
                    continue
                }

                # --- Parentheses (track depth, don't split inside) ---
                if ($c -eq '(') {
                    $parenDepth++
                    [void]$current.Append($c)
                    $i++
                    continue
                }
                if ($c -eq ')') {
                    $parenDepth = [Math]::Max(0, $parenDepth - 1)
                    [void]$current.Append($c)
                    $i++
                    continue
                }

                # Only split at depth 0
                if ($parenDepth -gt 0) {
                    [void]$current.Append($c)
                    $i++
                    continue
                }

                # --- Heredoc detection: << [-] ['"]DELIM['"] ---
                if ($c -eq '<' -and ($i + 1) -lt $len -and $CommandText[$i + 1] -eq '<') {
                    [void]$current.Append('<<')
                    $i += 2
                    # Skip optional '-' and whitespace
                    while ($i -lt $len -and ($CommandText[$i] -eq '-' -or $CommandText[$i] -match '\s') -and $CommandText[$i] -ne "`n") {
                        [void]$current.Append($CommandText[$i])
                        $i++
                    }
                    # Extract delimiter (strip surrounding quotes)
                    $quoteChar = $null
                    if ($i -lt $len -and ($CommandText[$i] -eq "'" -or $CommandText[$i] -eq '"')) {
                        $quoteChar = $CommandText[$i]
                        [void]$current.Append($CommandText[$i])
                        $i++
                    }
                    $delimStart = $i
                    while ($i -lt $len -and $CommandText[$i] -match '\w') {
                        [void]$current.Append($CommandText[$i])
                        $i++
                    }
                    $heredocDelimiter = $CommandText.Substring($delimStart, $i - $delimStart)
                    if ($quoteChar -and $i -lt $len -and $CommandText[$i] -eq $quoteChar) {
                        [void]$current.Append($CommandText[$i])
                        $i++
                    }
                    if ($heredocDelimiter.Length -gt 0) {
                        $state = 'HEREDOC'
                    }
                    continue
                }

                # --- Split on && ---
                if ($c -eq '&' -and ($i + 1) -lt $len -and $CommandText[$i + 1] -eq '&') {
                    $trimmed = $current.ToString().Trim()
                    if ($trimmed) { [void]$commands.Add($trimmed) }
                    [void]$current.Clear()
                    $i += 2
                    continue
                }

                # --- Split on || (but NOT single |) ---
                if ($c -eq '|' -and ($i + 1) -lt $len -and $CommandText[$i + 1] -eq '|') {
                    $trimmed = $current.ToString().Trim()
                    if ($trimmed) { [void]$commands.Add($trimmed) }
                    [void]$current.Clear()
                    $i += 2
                    continue
                }

                # --- Split on ; ---
                if ($c -eq ';') {
                    $trimmed = $current.ToString().Trim()
                    if ($trimmed) { [void]$commands.Add($trimmed) }
                    [void]$current.Clear()
                    $i++
                    continue
                }

                # --- Split on newline ---
                if ($c -eq "`n") {
                    $trimmed = $current.ToString().Trim()
                    if ($trimmed) { [void]$commands.Add($trimmed) }
                    [void]$current.Clear()
                    $i++
                    continue
                }

                # --- Single pipe is NOT a split point ---
                [void]$current.Append($c)
                $i++
            }
        }
    }

    # Flush remaining content
    $trimmed = $current.ToString().Trim()
    if ($trimmed) { [void]$commands.Add($trimmed) }

    # Return $null if parsing ended in a non-normal state (ambiguous)
    if ($state -ne 'NORMAL' -or $parenDepth -ne 0) { return $null }

    # Return $null if only 1 command (no point re-checking what already failed first pass)
    if ($commands.Count -le 1) { return $null }

    return [string[]]$commands
}

# =============================================================================
# PREFERENCES - read per-developer config for conditional auto-approval
# =============================================================================

function Get-Preferences {
    try {
        $configPath = Join-Path $PSScriptRoot "..\preferences.json"
        return Get-Content $configPath -Raw -ErrorAction Stop | ConvertFrom-Json
    } catch {
        return $null
    }
}

$prefs = Get-Preferences

# =============================================================================
# DENY PATTERNS - checked first, blocks matching commands (exit 2)
# =============================================================================
$fileReadCmdsBase = 'cat|type|Get-Content|more|less|head|tail|sed|awk'
$fileReadCmds = '(' + $fileReadCmdsBase + ')'
$safeDirs = '(documentation|web|generated-docs|\.claude|\.github)'
$safeDirsWrite = '(\.claude[/\\]context|generated-docs)'

$denyPatterns = @(
    'rm\s+-rf\s+/',                                        # Dangerous delete
    ($fileReadCmds + '.*id_rsa'),                          # SSH keys
    ($fileReadCmds + '.*\.pem\b'),                         # Certificates
    ($fileReadCmds + '.*credentials'),                     # Credentials
    ($fileReadCmds + '.*[/\\]\.ssh[/\\]'),                 # SSH directory
    ($fileReadCmds + '.*private.*key'),                    # Private keys
    ($fileReadCmds + '.*secret'),                          # Secrets
    'git\s+push\s+.*--force',                                          # Force push (destructive)
    'git\s+push\s+.*-f\b',                                             # Force push shorthand
    'git\s+push\s+.*--delete',                                         # Delete remote branch
    'git\s+push\s+.*--no-verify',                                      # Push bypassing hooks
    'git\s+commit\s+.*--no-verify',                                    # Commit bypassing hooks
    'git\s+commit\s+.*--amend'                                         # Amend previous commit
)

# Safe-directory file path pattern — anchored to start so it matches the actual target,
# not a decoy safe directory elsewhere in a compound string.
# $fileReadCmdsExt extends $fileReadCmds with wc and diff — those two never appear in
# deny patterns themselves, but are included here so the safe-dir check recognizes them
# if deny patterns are expanded in the future.
$fileReadCmdsExt = '(' + $fileReadCmdsBase + '|wc|diff)'
$cdPrefix = '(?:cd\s+["'']?[\w./:~\\-]+["'']?\s*&&\s*)?'
$safeDirFilePattern = '^\s*' + $cdPrefix + $fileReadCmdsExt + '\s+(?:[-+]?[\w-]+\s+)*["'']*[\w./:~\\-]*' + $safeDirs + '[/\\]'

function Test-IsSafeDirCommand {
    param([string]$Cmd)
    return [bool]($Cmd -imatch $safeDirFilePattern)
}

# Hoist once — result is invariant across the deny loop since the command doesn't change.
$isSafeDirCommand = Test-IsSafeDirCommand -Cmd $command

foreach ($pattern in $denyPatterns) {
    if ($command -imatch $pattern) {
        # File-reading deny patterns: downgrade to fallthrough if target is in a safe project directory
        if ($isSafeDirCommand) {
            continue  # skip this deny pattern, but keep checking remaining patterns
        }
        [Console]::Error.WriteLine("Blocked by security policy: Command matches deny pattern")
        exit 2
    }
}

# =============================================================================
# ALLOW PATTERNS - auto-approve safe commands
# =============================================================================
# Supports optional "cd <dir> && " prefix and full Windows paths with quotes
# ($cdPrefix is defined earlier, before $safeDirFilePattern, to keep the cd-path
# constraint consistent between the deny bypass and the allow patterns.)

$winPath = '["'']?[\w./:~\\-]*'
$subPath = '[\w./\\-]'
$subPathW = '(?:(?!\.\.[/\\])[\w./\\-])'  # write-safe: no path traversal
$subPathQ = '[\w./\\ -]'                  # subpath chars including space (quoted paths only)
$subPathE = '(?:[\w./\\-]|\\ )'           # subpath chars including backslash-escaped space
# Optional --prefix <dir> between npm and subcommand (avoids cd, keeps working directory stable)
$npmPrefix = '(?:--prefix\s+["'']?[\w./:~\\-]+["'']?\s+)?'

$allowPatterns = @(
    # --- NPM ---
    ($cdPrefix + 'npm\s+' + $npmPrefix + 'ci(?:\s+--[\w-]+)*\s*$'),
    ($cdPrefix + 'npm\s+' + $npmPrefix + 'install(?:\s+--[\w-]+)*\s*$'),
    ($cdPrefix + 'npm\s+' + $npmPrefix + 'i(?:\s+--[\w-]+)*\s*$'),
    ($cdPrefix + 'npm\s+' + $npmPrefix + 'install(?:\s+--[\w-]+)*(?:\s+@types/[\w-]+)+\s*$'),
    ($cdPrefix + 'npm\s+' + $npmPrefix + 'i(?:\s+--[\w-]+)*(?:\s+@types/[\w-]+)+\s*$'),
    ($cdPrefix + 'npm\s+' + $npmPrefix + 'install(?:\s+--[\w-]+)*(?:\s+@radix-ui/[\w-]+)+\s*$'),
    ($cdPrefix + 'npm\s+' + $npmPrefix + 'i(?:\s+--[\w-]+)*(?:\s+@radix-ui/[\w-]+)+\s*$'),
    ($cdPrefix + 'npm\s+' + $npmPrefix + 'test(?:\s+.*)?$'),
    ($cdPrefix + 'npm\s+' + $npmPrefix + 't(?:\s+.*)?$'),
    ($cdPrefix + 'npm\s+' + $npmPrefix + 'run\s+(build|lint|dev|format|test|typecheck|check|generate)(?::\w+)?(?:\s+.*)?$'),
    ($cdPrefix + 'npm\s+' + $npmPrefix + 'audit(?:\s+.*)?$'),
    # npm exec (equivalent to npx, supports -- separator for tool args)
    ($cdPrefix + 'npm\s+' + $npmPrefix + 'exec\s+(?:--\s+)?(tsc|vitest|eslint|next|msw|prettier|shadcn)(?:\s+.*)?$'),
    # Dependency check with conditional npm install (test -d, [ -d ], if exist + optional echo/npm install)
    ($cdPrefix + '(?:test\s+-d|\[\s+-d)\s+node_modules\s*\]?(?:\s*[&|]+\s*(?:echo\s+["''].*["'']|\(echo\s+["''].*["'']\)|\(?npm\s+install\)?)\s*)*$'),
    ($cdPrefix + 'if\s+exist\s+["'']?node_modules[/\\]?["'']?\s*(?:\(.*\)\s*)?(?:else\s*\(.*\)\s*)?$'),

    # --- NPX / bare dev tools ---
    ($cdPrefix + 'npx\s+tsc(?:\s+.*)?$'),
    ($cdPrefix + 'npx\s+shadcn(?:@[\w.]+)?(?:\s+.*)?$'),
    ($cdPrefix + 'npx\s+vitest(?:\s+.*)?$'),
    ($cdPrefix + 'npx\s+next(?:\s+.*)?$'),
    ($cdPrefix + 'npx\s+eslint(?:\s+.*)?$'),
    ($cdPrefix + 'npx\s+msw(?:\s+.*)?$'),
    ($cdPrefix + 'node_modules[/\\]\.bin[/\\](eslint|msw|next|tsc|vitest|prettier|shadcn)(?:\s+.*)?$'),
    ($cdPrefix + 'npx\s+prettier(?:\s+.*)?$'),
    # Bare tool invocations (same safe tools as npx, models sometimes call directly)
    ($cdPrefix + '(tsc|vitest|eslint|prettier)(?:\s+.*)?$'),

    # --- Node scripts (safe directories only) ---
    ($cdPrefix + 'node\s+' + $winPath + '\.claude[/\\]scripts[/\\]' + $subPath + '+["'']?(?:\s+.*)?$'),
    ($cdPrefix + 'node\s+' + $winPath + 'web[/\\]' + $subPath + '+["'']?(?:\s+.*)?$'),
    ($cdPrefix + 'node\s+' + $winPath + 'generated-docs[/\\]' + $subPath + '+["'']?(?:\s+.*)?$'),
    ($cdPrefix + 'node\s+' + $winPath + '\.github[/\\]scripts[/\\]' + $subPath + '+["'']?(?:\s+.*)?$'),

    # --- Directory operations ---
    ($cdPrefix + 'mkdir\s+(?:-p\s+)?' + $winPath + 'generated-docs[/\\]?' + $subPath + '*["'']?\s*$'),

    # --- File reading (safe directories only) ---
    ($cdPrefix + 'sed\s+-n\s+.+\s+' + $winPath + $safeDirs + '[/\\]' + $subPathE + '+["'']?\s*$'),
    ($cdPrefix + 'cat\s+' + $winPath + $safeDirs + '[/\\]' + $subPathE + '+["'']?(?:\s+2>/dev/null)?\s*$'),
    # Node modules type definitions (read-only, allows fallback with || and pipe to head)
    ($cdPrefix + 'cat\s+node_modules/[\w@./-]+\.d\.ts(?:\s+2>/dev/null)?(?:\s+\|\|\s+cat\s+node_modules/[\w@.*/-]+\.d\.ts)?(?:\s+\|\s+head\s+-?\d+)?\s*$'),
    ($cdPrefix + 'type\s+' + $winPath + $safeDirs + '[/\\]' + $subPathE + '+["'']?\s*$'),
    ($cdPrefix + 'cat\s+' + $winPath + '[\w.-]+\.config\.[\w]+["'']?(?:\s+2>/dev/null)?\s*$'),
    ($cdPrefix + 'type\s+' + $winPath + '[\w.-]+\.config\.[\w]+["'']?\s*$'),
    # grep on safe project directories (read-only search, supports quoted/unquoted patterns)
    ($cdPrefix + 'grep(?:\s+-[\w]+)*\s+(?:["''][^"'']*["'']|\S+)\s+' + $winPath + $safeDirs + '[/\\]' + $subPathE + '+["'']?(?:\s+2>/dev/null)?\s*$'),
    # cat <safe-dir> piped to grep (read-only pipeline)
    ($cdPrefix + 'cat\s+' + $winPath + $safeDirs + '[/\\]' + $subPathE + '+["'']?(?:\s+2>/dev/null)?\s*\|\s*grep(?:\s+-[\w]+)*\s+.+$'),
    # head/tail on safe directories (read-only, same safety as cat)
    ($cdPrefix + '(head|tail)(?:\s+[-+]?[\w]+)*\s+' + $winPath + $safeDirs + '[/\\]' + $subPathE + '+["'']?(?:\s+2>/dev/null)?\s*$'),
    # wc on safe directories (line/word/byte counts — read-only, no content revealed)
    ($cdPrefix + 'wc(?:\s+-[lwcmL]+)*\s+' + $winPath + $safeDirs + '[/\\]' + $subPathE + '+["'']?(?:\s+2>/dev/null)?\s*$'),
    # diff between safe directory files (read-only comparison, both files must be in safe dirs)
    ($cdPrefix + 'diff(?:\s+--?[\w-]+)*\s+' + $winPath + $safeDirs + '[/\\]' + $subPathE + '+["'']?\s+' + $winPath + $safeDirs + '[/\\]' + $subPathE + '+["'']?(?:\s+2>/dev/null)?\s*$'),
    # cat <safe-dir> piped to head/tail (read-only pipeline)
    ($cdPrefix + 'cat\s+' + $winPath + $safeDirs + '[/\\]' + $subPathE + '+["'']?(?:\s+2>/dev/null)?\s*\|\s*(head|tail)(?:\s+[-+]?[\w]+)*\s*$'),

    # --- Quoted paths with spaces (read-only, requires matching quotes) ---
    ($cdPrefix + 'sed\s+-n\s+.+\s+["''][\w./:~\\ -]*' + $safeDirs + '[/\\]' + $subPathQ + '+["''](?:\s+2>/dev/null)?\s*$'),
    ($cdPrefix + 'cat\s+["''][\w./:~\\ -]*' + $safeDirs + '[/\\]' + $subPathQ + '+["''](?:\s+2>/dev/null)?\s*$'),
    ($cdPrefix + 'type\s+["''][\w./:~\\ -]*' + $safeDirs + '[/\\]' + $subPathQ + '+["'']\s*$'),
    ($cdPrefix + 'cat\s+["''][\w./:~\\ -]*' + $safeDirs + '[/\\]' + $subPathQ + '+["''](?:\s+2>/dev/null)?\s*\|\s*grep(?:\s+-[\w]+)*\s+.+$'),
    ($cdPrefix + '(head|tail)(?:\s+[-+]?[\w]+)*\s+["''][\w./:~\\ -]*' + $safeDirs + '[/\\]' + $subPathQ + '+["''](?:\s+2>/dev/null)?\s*$'),
    ($cdPrefix + 'wc(?:\s+-[lwcmL]+)*\s+["''][\w./:~\\ -]*' + $safeDirs + '[/\\]' + $subPathQ + '+["''](?:\s+2>/dev/null)?\s*$'),
    ($cdPrefix + 'diff(?:\s+--?[\w-]+)*\s+["''][\w./:~\\ -]*' + $safeDirs + '[/\\]' + $subPathQ + '+["'']\s+["''][\w./:~\\ -]*' + $safeDirs + '[/\\]' + $subPathQ + '+["''](?:\s+2>/dev/null)?\s*$'),
    ($cdPrefix + 'cat\s+["''][\w./:~\\ -]*' + $safeDirs + '[/\\]' + $subPathQ + '+["''](?:\s+2>/dev/null)?\s*\|\s*(head|tail)(?:\s+[-+]?[\w]+)*\s*$'),

    # --- File writing (safe directories only, write-safe subpath blocks ../ traversal) ---
    ($cdPrefix + 'cat\s*>\s*' + $winPath + $safeDirsWrite + '[/\\]' + $subPathW + '+["'']?\s*$'),
    # Heredoc writes to safe directories (cat > file << 'EOF' - no $ anchor because heredoc body follows)
    ($cdPrefix + 'cat\s*>\s*' + $winPath + $safeDirsWrite + '[/\\]' + $subPathW + '+["'']?\s*<<\s*-?\s*[''"]?\w+[''"]?'),

    # --- Find (safe directories only, read-only flags: no -exec, -delete) ---
    ($cdPrefix + 'find\s+["'']?(?:[\w./:~\\-]*[/\\])?' + $safeDirs + '[/\\]?[\w./\\-]*["'']?(?:\s+(?:-(?:name|iname|type|maxdepth|mindepth|path)\s+["'']?[\w.*?/\\:-]+["'']?|-(?:empty|print0?)|!|-not))*(?:\s+2>/dev/null)?\s*$'),

    # --- Directory listing (allows globs like *.ts and 2>&1 redirect) ---
    ($cdPrefix + 'ls(?:\s+-[\w]+)*(?:\s+["'']?[\w./:~\\*?-]+["'']?)*(?:\s+2>&1)?\s*$'),
    # Safe directory listing with any error handling suffix (absolute or relative paths, any slash style)
    ($cdPrefix + 'ls(?:\s+-[\w]+)*\s+["'']?[\w./:~\\-]*' + $safeDirs + '[/\\]?' + $subPath + '*["'']?(?:\s+.*)?$'),
    ($cdPrefix + 'dir(?:\s+' + $winPath + '["'']?)*\s*$'),
    ($cdPrefix + 'Get-ChildItem(?:\s+.*)?$'),

    # --- PowerShell (safe directories only) ---
    ('powershell\s+-Command\s+.*(Get-Content|Select-Object).*' + $winPath + $safeDirs),
    ('powershell\s+-Command\s+.*Set-Content.*' + $winPath + $safeDirsWrite),

    # --- Utility commands ---
    ($cdPrefix + 'which\s+\w+'),
    ($cdPrefix + 'where\.exe\s+\w+'),
    ($cdPrefix + 'command\s+-v\s+\w+'),
    ($cdPrefix + 'node\s+--version\s*$'),
    ($cdPrefix + 'npm\s+--version\s*$'),
    ($cdPrefix + 'git\s+--version\s*$'),
    # Read-only git commands
    ($cdPrefix + 'git\s+status(?:\s+.*)?$'),
    ($cdPrefix + 'git\s+log(?:\s+.*)?$'),
    ($cdPrefix + 'git\s+diff(?:\s+.*)?$'),
    ($cdPrefix + 'git\s+show(?:\s+.*)?$'),
    ($cdPrefix + 'git\s+branch(?:\s+(?:-[avrl]+|--(?:list|all|remotes|contains|merged|no-merged)))*\s*$'),
    ($cdPrefix + 'git\s+rev-parse(?:\s+.*)?$'),
    ($cdPrefix + 'git\s+remote(?:\s+-v)?\s*$'),
    ($cdPrefix + 'git\s+stash\s+list(?:\s+.*)?$'),
    ($cdPrefix + 'git\s+describe(?:\s+.*)?$'),
    ($cdPrefix + 'git\s+tag(?:\s+(?:-l|--list)(?:\s+.*)?)?$'),
    # Git pull (with optional remote/branch, --rebase, --ff-only)
    ($cdPrefix + 'git\s+pull(?:\s+(?:--rebase|--ff-only|--no-rebase|[\w./-]+))*\s*$'),
    # Git add (all forms: specific files, ., -A, --all — .gitignore is the safety net)
    ($cdPrefix + 'git\s+add\s+.+$'),
    ($cdPrefix + 'pwd\s*$'),
    ($cdPrefix + 'echo\s+\$[\w]+\s*$'),

    # --- Standalone commands (for compound command splitting) ---
    # cd to any directory (standalone, not as prefix)
    'cd\s+["'']?[\w./:~\\-]+["'']?\s*$',
    # echo with quoted string or simple word
    'echo\s+["''].*["'']\s*$',
    'echo\s+[\w./:~\\-]+\s*$',
    # Temp file heredoc writes (for TDD test file creation)
    ('cat\s*>\s*["'']?/tmp/' + $subPath + '+["'']?\s*<<\s*-?\s*[''"]?\w+[''"]?'),
    # Temp file reads
    ('cat\s+["'']?/tmp/' + $subPath + '+["'']?\s*$'),
    # File/directory existence checks (all test flags are read-only, supports -o/-a compound expressions)
    '(?:test\s+-[defrsxw]|\[\s+-[defrsxw])\s+["'']?[\w./:~\\-]+["'']?(?:\s+-[oa]\s+-[defrsxw]\s+["'']?[\w./:~\\-]+["'']?)*\s*\]?\s*$',
    # Boolean commands (used in conditional chains)
    'true\s*$',
    'false\s*$'
)

# =============================================================================
# CONFIG-CONDITIONAL PATTERNS - appended based on .claude/preferences.json
# =============================================================================
# Git commit — requires -m/--message as terminal element to capture the message.
# Optional flags (-a, -v, --allow-empty) may precede it. Excludes --amend and --no-verify
# (--no-verify is in deny patterns; --amend is excluded by not listing it as an allowed flag).
if ($prefs.git.autoApproveCommit -eq $true) {
    $allowPatterns += @(
        ($cdPrefix + 'git\s+commit(?:\s+(?:-[av]|--allow-empty))*\s+(?:-m|--message)\s+.+$')
    )
}

# Git push (excludes --force, -f, and --no-verify which are in deny patterns)
if ($prefs.git.autoApprovePush -eq $true) {
    $allowPatterns += @(
        ($cdPrefix + 'git\s+push(?:\s+(?:-u|--set-upstream|--tags|[\w./-]+))*\s*$')
    )
}

# Anchor all allow patterns once (avoids "^$pattern" string interpolation per iteration)
$allowPatterns = $allowPatterns | ForEach-Object { '^' + $_ }

# Check if command matches any allow pattern
foreach ($pattern in $allowPatterns) {
    if ($command -imatch $pattern) {
        $output = @{
            hookSpecificOutput = @{
                hookEventName = "PreToolUse"
                permissionDecision = "allow"
                permissionDecisionReason = "Auto-approved: matches safe command pattern"
            }
        } | ConvertTo-Json -Depth 10 -Compress

        Write-Output $output
        exit 0
    }
}

# =============================================================================
# COMPOUND COMMAND SPLITTING - second pass for multi-command strings
# =============================================================================
# If the whole command didn't match any single pattern, try splitting on
# &&, ||, ;, and newlines, then check each sub-command individually.

# Helper: check if a single sub-command is allowed (with recursive paren-stripping)
function Test-SubCommandAllowed {
    param([string]$SubCmd)

    # Bash comments are no-ops — always safe
    if ($SubCmd -match '^\s*#') {
        return $true
    }

    # Check against deny patterns first (with safe-directory exception).
    # NOTE: Unlike the main deny loop (which uses `continue` to skip to allow patterns),
    # sub-commands return $false here — intentionally more conservative. The caller
    # treats $false as "not auto-approved", causing the entire compound command to
    # fall through to the normal permission prompt rather than being auto-approved.
    $subCmdIsSafeDir = Test-IsSafeDirCommand -Cmd $SubCmd
    foreach ($pattern in $denyPatterns) {
        if ($SubCmd -imatch $pattern) {
            if ($subCmdIsSafeDir) {
                return $false  # downgrade: don't auto-approve, but don't hard-block either
            }
            [Console]::Error.WriteLine("Blocked by security policy: Sub-command matches deny pattern")
            exit 2
        }
    }

    # Check against allow patterns
    foreach ($pattern in $allowPatterns) {
        if ($SubCmd -imatch $pattern) {
            return $true
        }
    }

    # If wrapped in parentheses, strip and recursively check inner content
    $stripped = $SubCmd
    while ($stripped -match '^\s*\((.+)\)\s*$') {
        $stripped = $Matches[1].Trim()
    }
    if ($stripped -ne $SubCmd) {
        # Try splitting the inner content into sub-commands first
        # (splitting before single-pattern match avoids loose .* patterns
        # swallowing && operators as "arguments")
        $innerCommands = Split-CompoundCommand -CommandText $stripped
        if ($null -ne $innerCommands -and $innerCommands.Count -gt 1) {
            foreach ($inner in $innerCommands) {
                if (-not (Test-SubCommandAllowed -SubCmd $inner)) {
                    return $false
                }
            }
            return $true
        }
        # If not splittable, try matching as a single command
        foreach ($pattern in $allowPatterns) {
            if ($stripped -imatch $pattern) {
                return $true
            }
        }
    }

    return $false
}

$subCommands = Split-CompoundCommand -CommandText $command

if ($null -ne $subCommands -and $subCommands.Count -gt 1) {
    $allAllowed = $true
    foreach ($subCmd in $subCommands) {
        if (-not (Test-SubCommandAllowed -SubCmd $subCmd)) {
            $allAllowed = $false
            break
        }
    }

    if ($allAllowed) {
        $output = @{
            hookSpecificOutput = @{
                hookEventName = "PreToolUse"
                permissionDecision = "allow"
                permissionDecisionReason = "Auto-approved: all sub-commands match safe patterns"
            }
        } | ConvertTo-Json -Depth 10 -Compress

        Write-Output $output
        exit 0
    }
}

# Third pass: if the whole command is wrapped in parentheses, try stripping and re-checking
if ($command -match '^\s*\(') {
    if (Test-SubCommandAllowed -SubCmd $command) {
        $output = @{
            hookSpecificOutput = @{
                hookEventName = "PreToolUse"
                permissionDecision = "allow"
                permissionDecisionReason = "Auto-approved: parenthesized command contains safe sub-commands"
            }
        } | ConvertTo-Json -Depth 10 -Compress

        Write-Output $output
        exit 0
    }
}

# No match - fall through to normal permission system
exit 0

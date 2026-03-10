#!/usr/bin/env node
/**
 * copy-with-header.js
 * Copies a file to a destination, prepending a source-traceability header line.
 *
 * Usage:
 *   node .claude/scripts/copy-with-header.js --from <source> --to <dest>
 *   node .claude/scripts/copy-with-header.js --from <source> --to <dest> --header "Custom header"
 *   node .claude/scripts/copy-with-header.js --help
 *
 * Purpose:
 *   During the DESIGN phase, user-provided artifacts (API specs, design tokens, etc.)
 *   are copied from documentation/ to generated-docs/specs/ with a traceability header.
 *   This script replaces raw bash commands (which require manual permission approval)
 *   and is auto-approved by the bash-permission-checker hook.
 *
 * Behavior:
 *   - Reads the source file
 *   - Prepends "# Source: <from-path>" (or custom --header text) as the first line
 *   - Creates destination directories if needed
 *   - Writes to the destination path
 *   - Outputs JSON result
 *
 * Security:
 *   - Destination must be under generated-docs/ (enforced)
 *   - Source must exist and be a file (not a directory)
 */

const fs = require('fs');
const path = require('path');

function showHelp() {
  console.log(`
copy-with-header.js — Copy a file with a source-traceability header

Usage:
  node .claude/scripts/copy-with-header.js --from <source> --to <dest>
  node .claude/scripts/copy-with-header.js --from <source> --to <dest> --header "Custom header"

Options:
  --from <path>     Source file path (required)
  --to <path>       Destination file path (required, must be under generated-docs/)
  --header <text>   Custom header line (default: "# Source: <from-path>")
  --help            Show this help message

Examples:
  node .claude/scripts/copy-with-header.js --from "documentation/Api Definition.yaml" --to "generated-docs/specs/api-spec.yaml"
  node .claude/scripts/copy-with-header.js --from "documentation/design-tokens.css" --to "generated-docs/specs/design-tokens.css" --header "/* Source: documentation/design-tokens.css */"
`);
  process.exit(0);
}

function parseArgs() {
  const args = process.argv.slice(2);
  let fromPath = null;
  let toPath = null;
  let header = null;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--help' || args[i] === '-h') {
      showHelp();
    } else if (args[i] === '--from' && args[i + 1]) {
      fromPath = args[i + 1];
      i++;
    } else if (args[i] === '--to' && args[i + 1]) {
      toPath = args[i + 1];
      i++;
    } else if (args[i] === '--header' && args[i + 1]) {
      header = args[i + 1];
      i++;
    }
  }

  return { fromPath, toPath, header };
}

function fail(message, suggestion) {
  console.log(JSON.stringify({
    status: 'error',
    message,
    suggestion: suggestion || null
  }, null, 2));
  process.exit(1);
}

function main() {
  const { fromPath, toPath, header } = parseArgs();

  if (!fromPath) {
    fail(
      'Missing required --from argument.',
      'Usage: node .claude/scripts/copy-with-header.js --from <source> --to <dest>'
    );
  }

  if (!toPath) {
    fail(
      'Missing required --to argument.',
      'Usage: node .claude/scripts/copy-with-header.js --from <source> --to <dest>'
    );
  }

  // Resolve paths
  const resolvedFrom = path.resolve(fromPath);
  const resolvedTo = path.resolve(toPath);
  const projectRoot = path.resolve('.');

  // Security: destination must be under generated-docs/
  const generatedDocsDir = path.join(projectRoot, 'generated-docs');
  if (!resolvedTo.startsWith(generatedDocsDir + path.sep) && resolvedTo !== generatedDocsDir) {
    fail(
      `Destination must be under generated-docs/. Got: ${toPath}`,
      'The --to path must point to a location inside the generated-docs/ directory.'
    );
  }

  // Validate source exists and is a file
  if (!fs.existsSync(resolvedFrom)) {
    fail(
      `Source file not found: ${fromPath}`,
      'Check the path and try again.'
    );
  }

  const stat = fs.statSync(resolvedFrom);
  if (!stat.isFile()) {
    fail(
      `Source is not a file: ${fromPath}`,
      'The --from path must point to a file, not a directory.'
    );
  }

  // Build header line
  const headerLine = header || `# Source: ${fromPath}`;

  // Read source content
  const content = fs.readFileSync(resolvedFrom, 'utf-8');

  // Prepend header and write
  const output = headerLine + '\n' + content;

  fs.mkdirSync(path.dirname(resolvedTo), { recursive: true });
  fs.writeFileSync(resolvedTo, output, 'utf-8');

  const sizeKB = Math.round(stat.size / 1024);

  console.log(JSON.stringify({
    status: 'ok',
    message: `Copied ${fromPath} → ${toPath} with source header`,
    from: fromPath,
    to: toPath,
    header: headerLine,
    sizeKB
  }, null, 2));
}

try {
  main();
} catch (error) {
  if (error.code === 'EACCES' || error.code === 'EPERM') {
    fail(
      `Permission denied: ${error.path || error.message}`,
      'Check file permissions on the source and destination.'
    );
  } else if (error.code === 'ENOSPC') {
    fail('Disk space full.', 'Free up disk space and try again.');
  } else {
    fail(`Unexpected error: ${error.message}`);
  }
}

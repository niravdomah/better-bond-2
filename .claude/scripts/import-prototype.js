#!/usr/bin/env node
/**
 * import-prototype.js
 * Selectively imports artifacts from a prototyping tool repository into documentation/
 *
 * Usage:
 *   node .claude/scripts/import-prototype.js --from <path-to-prototype-repo>
 *   node .claude/scripts/import-prototype.js --help
 *
 * What it copies:
 *   docs/project-docs/**          → documentation/          (requirements, design language, API specs, per-prototype docs)
 *   prototypes/tailwind.config.js → documentation/           (design token CSS reference)
 *   prototypes/prototype-*\/      → documentation/prototype-src/prototype-*\/ (React source as living wireframes)
 *
 * What it excludes:
 *   node_modules/, dist/, .git/, prototypes/src/, prototypes/components/ui/,
 *   prototypes/shared/, prototypes/lib/, root .claude/
 *
 * Source file filter (for prototype-src):
 *   Only copies: .jsx, .js, .ts, .tsx, .css, .json files
 */

const fs = require('fs');
const path = require('path');

// Extensions to include when copying prototype source files
const SOURCE_EXTENSIONS = new Set(['.jsx', '.js', '.ts', '.tsx', '.css', '.json']);

// Directories to skip when copying prototype source
const SKIP_DIRS = new Set(['node_modules', 'dist', '.git', '.next', '__pycache__', '.cache']);

function showHelp() {
  console.log(`
import-prototype.js — Import artifacts from a prototyping tool repository

Usage:
  node .claude/scripts/import-prototype.js --from <path>

Options:
  --from <path>   Path to the prototype repository (required)
  --help          Show this help message

Example:
  node .claude/scripts/import-prototype.js --from "../my-prototype"
  node .claude/scripts/import-prototype.js --from "C:\\Git\\my-prototype"
`);
  process.exit(0);
}

function parseArgs() {
  const args = process.argv.slice(2);
  let fromPath = null;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--help' || args[i] === '-h') {
      showHelp();
    } else if (args[i] === '--from' && args[i + 1]) {
      fromPath = args[i + 1];
      i++;
    }
  }

  return { fromPath };
}

function fail(message, suggestion) {
  console.log(JSON.stringify({
    status: 'error',
    message,
    suggestion: suggestion || null
  }, null, 2));
  process.exit(1);
}

/**
 * Recursively copy a directory, preserving structure.
 * For source files, applies extension filter.
 * Returns array of copied file paths (relative to destination root).
 */
function copyDirRecursive(src, dest, { filterExtensions = null } = {}) {
  const copied = [];

  if (!fs.existsSync(src)) return copied;

  const entries = fs.readdirSync(src, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) continue;

      // Create directory and recurse
      fs.mkdirSync(destPath, { recursive: true });
      const subCopied = copyDirRecursive(srcPath, destPath, { filterExtensions });
      copied.push(...subCopied);
    } else if (entry.isFile()) {
      // Apply extension filter if set
      if (filterExtensions) {
        const ext = path.extname(entry.name).toLowerCase();
        if (!filterExtensions.has(ext)) continue;
      }

      fs.mkdirSync(path.dirname(destPath), { recursive: true });
      fs.copyFileSync(srcPath, destPath);
      copied.push(destPath);
    }
  }

  return copied;
}

/**
 * Copy a single file, creating parent directories as needed.
 */
function copyFile(src, dest) {
  if (!fs.existsSync(src)) return false;
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
  return true;
}

/**
 * Detect prototype-* directories under prototypes/
 */
function detectPrototypes(prototypesDir) {
  if (!fs.existsSync(prototypesDir)) return [];

  return fs.readdirSync(prototypesDir, { withFileTypes: true })
    .filter(entry => entry.isDirectory() && entry.name.startsWith('prototype-'))
    .map(entry => entry.name);
}

/**
 * Calculate total size of files in bytes
 */
function totalSize(filePaths) {
  let total = 0;
  for (const fp of filePaths) {
    try {
      total += fs.statSync(fp).size;
    } catch {
      // Skip files that can't be stat'd
    }
  }
  return total;
}

function main() {
  const { fromPath } = parseArgs();

  if (!fromPath) {
    fail(
      'Missing required --from argument.',
      'Usage: node .claude/scripts/import-prototype.js --from <path-to-prototype-repo>'
    );
  }

  // Resolve the path (handle relative paths)
  const repoRoot = path.resolve(fromPath);
  const projectRoot = path.resolve('.');

  // Self-reference guard: prevent copying the project into itself
  if (repoRoot === projectRoot) {
    fail(
      'Source path resolves to the current project directory.',
      '--from must point to a different repository, not the current project.'
    );
  }

  // Guard against overlapping paths (source inside project or project inside source)
  const repoRootNorm = repoRoot.replace(/[\\/]+$/, '') + path.sep;
  const projectRootNorm = projectRoot.replace(/[\\/]+$/, '') + path.sep;

  if (projectRootNorm.startsWith(repoRootNorm)) {
    fail(
      `Source path (${repoRoot}) is a parent of the current project.`,
      '--from must point to a separate repository that does not contain the current project.'
    );
  }
  if (repoRootNorm.startsWith(projectRootNorm)) {
    fail(
      `Source path (${repoRoot}) is inside the current project.`,
      '--from must point to a separate repository, not a subdirectory of this project.'
    );
  }

  // Validate the prototype repo exists
  if (!fs.existsSync(repoRoot)) {
    fail(
      `Path does not exist: ${repoRoot}`,
      'Check the path and try again. Use an absolute path or a path relative to the current directory.'
    );
  }

  // Validate expected structure
  const docsDir = path.join(repoRoot, 'docs', 'project-docs');
  const prototypesDir = path.join(repoRoot, 'prototypes');

  if (!fs.existsSync(docsDir)) {
    fail(
      `Expected docs/project-docs/ directory not found at: ${docsDir}`,
      'This doesn\'t look like a prototype repo. Expected structure: docs/project-docs/ and prototypes/'
    );
  }

  if (!fs.existsSync(prototypesDir)) {
    fail(
      `Expected prototypes/ directory not found at: ${prototypesDir}`,
      'This doesn\'t look like a prototype repo. Expected structure: docs/project-docs/ and prototypes/'
    );
  }

  // Destination: documentation/ in current working directory
  const destRoot = path.resolve('documentation');
  fs.mkdirSync(destRoot, { recursive: true });

  const result = {
    docs: { count: 0, files: [] },
    tailwindConfig: false,
    prototypeSrc: { count: 0, prototypes: [], files: [] }
  };
  const allCopied = [];

  // --- Step 1: Copy docs/project-docs/** → documentation/ ---
  const docsCopied = copyDirRecursive(docsDir, destRoot);
  result.docs.count = docsCopied.length;
  result.docs.files = docsCopied.map(f => path.relative(destRoot, f));
  allCopied.push(...docsCopied);

  // --- Step 2: Copy prototypes/tailwind.config.js → documentation/ ---
  const tailwindSrc = path.join(prototypesDir, 'tailwind.config.js');
  const tailwindDest = path.join(destRoot, 'tailwind.config.js');
  if (copyFile(tailwindSrc, tailwindDest)) {
    result.tailwindConfig = true;
    allCopied.push(tailwindDest);
  }

  // --- Step 3: Copy prototype source directories ---
  const prototypeNames = detectPrototypes(prototypesDir);

  for (const name of prototypeNames) {
    const srcDir = path.join(prototypesDir, name);
    const destDir = path.join(destRoot, 'prototype-src', name);

    fs.mkdirSync(destDir, { recursive: true });
    const srcCopied = copyDirRecursive(srcDir, destDir, {
      filterExtensions: SOURCE_EXTENSIONS
    });

    if (srcCopied.length > 0) {
      result.prototypeSrc.prototypes.push(name);
      result.prototypeSrc.count += srcCopied.length;
      result.prototypeSrc.files.push(
        ...srcCopied.map(f => path.relative(destRoot, f))
      );
      allCopied.push(...srcCopied);
    }
  }

  // --- Summary ---
  const totalFiles = allCopied.length;
  const totalKB = Math.round(totalSize(allCopied) / 1024);

  console.log(JSON.stringify({
    status: 'ok',
    message: `Imported ${totalFiles} files (${totalKB} KB) from ${path.basename(repoRoot)}`,
    copied: result,
    totalFiles,
    totalSizeKB: totalKB
  }, null, 2));
}

try {
  main();
} catch (error) {
  if (error.code === 'EACCES' || error.code === 'EPERM') {
    fail(
      `Permission denied: ${error.path || error.message}`,
      'Check file permissions on the source and destination directories.'
    );
  } else if (error.code === 'ENOSPC') {
    fail('Disk space full.', 'Free up disk space and try again.');
  } else {
    fail(`Unexpected error: ${error.message}`);
  }
}

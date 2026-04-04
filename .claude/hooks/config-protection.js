#!/usr/bin/env node
/**
 * Config Protection Hook
 *
 * Blocks modifications to linter/formatter config files.
 * Agents frequently modify these to make checks pass instead of fixing
 * the actual code. This hook steers the agent back to fixing the source.
 */

'use strict';

const path = require('path');

const PROTECTED_FILES = new Set([
  '.eslintrc',
  '.eslintrc.js',
  '.eslintrc.cjs',
  '.eslintrc.json',
  '.eslintrc.yml',
  '.eslintrc.yaml',
  'eslint.config.js',
  'eslint.config.mjs',
  'eslint.config.cjs',
  'eslint.config.ts',
  'eslint.config.mts',
  'eslint.config.cts',
  '.prettierrc',
  '.prettierrc.js',
  '.prettierrc.cjs',
  '.prettierrc.json',
  '.prettierrc.yml',
  '.prettierrc.yaml',
  'prettier.config.js',
  'prettier.config.cjs',
  'prettier.config.mjs',
  'biome.json',
  'biome.jsonc',
  '.ruff.toml',
  'ruff.toml',
  '.shellcheckrc',
  '.stylelintrc',
  '.stylelintrc.json',
  '.stylelintrc.yml',
  '.markdownlint.json',
  '.markdownlint.yaml',
  '.markdownlintrc',
]);

const MAX_STDIN = 1024 * 1024;
let raw = '';
let truncated = false;

process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => {
  if (raw.length < MAX_STDIN) {
    const remaining = MAX_STDIN - raw.length;
    raw += chunk.substring(0, remaining);
    if (chunk.length > remaining) truncated = true;
  } else {
    truncated = true;
  }
});

process.stdin.on('end', () => {
  if (truncated) {
    process.stderr.write('[config-protection] Warning: stdin exceeded 1MB, skipping check\n');
    process.stdout.write(raw);
    return;
  }

  try {
    const input = raw.trim() ? JSON.parse(raw) : {};
    const filePath = input?.tool_input?.file_path || input?.tool_input?.file || '';

    if (filePath) {
      const basename = path.basename(filePath);
      if (PROTECTED_FILES.has(basename)) {
        process.stderr.write(
          `BLOCKED: Modifying ${basename} is not allowed. ` +
          `Fix the source code to satisfy linter/formatter rules instead of ` +
          `weakening the config. If this is a legitimate config change, ` +
          `disable the config-protection hook temporarily.\n`
        );
        process.exit(2);
      }
    }
  } catch {
    // Fail open on parse errors
  }

  process.stdout.write(raw);
});

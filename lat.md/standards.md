# Coding Standards

Non-negotiable rules enforced across the entire codebase. Every committed file must comply.

## Runtime Requirements

Node.js 24+ and npm 11.4+ are required. Docker images use `node:24-alpine`.

The `packageManager` field in `package.json` pins npm 11.4.1 for deterministic installs. Corepack-aware tools will enforce this version. TypeScript 5.9 runs with `incremental: true` in `tsconfig.json` for faster re-checks.

## Code Completeness

No placeholders, stubs, `// TODO`, or deferred logic markers. Every function and component must be complete and working. No dead code — delete removed code entirely rather than commenting it out.

## Type Safety

Maximum TypeScript strictness is enabled in `tsconfig.json`.

Flags: `strict`, `noImplicitAny`, `strictNullChecks`, `strictFunctionTypes`, `noUnusedLocals`, `noUnusedParameters`, `exactOptionalPropertyTypes`, `noUncheckedIndexedAccess`, `noFallthroughCasesInSwitch`.

- `any` is forbidden — use `unknown` with type guards or Zod parse
- `@ts-ignore` and `@ts-expect-error` are forbidden — fix the underlying type issue
- Non-null assertions (`!`) are forbidden — use explicit guards
- `as` casts are forbidden unless narrowing from a validated source (e.g. after Zod `.parse()`)
- `exactOptionalPropertyTypes` is enabled — use conditional spread `...(condition && { prop: value })` instead of ternaries assigning `undefined`

## File Organization

150-line limit per file (logic lines, excluding imports and types). One concern per file. Always import with `~/` path aliases (maps to `./src/`) — never relative paths.

## Immutability

Never mutate data in-place. Use `slice()`, spread operators, `map()`, or `filter()`.

Never use `.pop()`, `.push()`, `.splice()`, or direct property assignment on shared objects. Always create new objects/arrays.

## Input Validation

All external inputs must be validated with Zod before processing — tRPC inputs, form data, URL params, API responses.

- String inputs need max-length constraints in both Zod schemas and HTML form attributes
- Prefer Zod 4 top-level validators: `z.url()` over `z.string().url()`, `z.email()` over `z.string().email()`
- Use `z.treeifyError()` for error formatting (`.flatten()` and `.format()` are deprecated in Zod 4)
- tRPC mutations enforce validation via `.input(z.object({...}))` — never bypass by accessing raw request data

## Linting and Formatting

Biome handles both linting and formatting in a single tool. Configuration in `biome.json`.

- Pre-commit hook: `lint-staged` runs `biome check --write` on staged `.ts/.tsx/.js/.jsx` and `biome format --write` on staged `.json`
- Pre-push hook: `tsc --noEmit` for full type check
- Key rules: `noExplicitAny`, `noNonNullAssertion`, `noUnusedImports`, `noUnusedVariables`, `noDefaultExport` (with Next.js page/layout/route/config overrides), `noShadowRestrictedNames` (with `error.tsx` override), `noExcessiveCognitiveComplexity` (max 15), `noConsole` (with `scripts/` override), `noNestedTernary`, `noParameterAssign`, `useAwait`, `useErrorMessage`, `useThrowOnlyError`, `noEvolvingTypes`, `noImportCycles`, `noSecrets` (with `src/components/` override for Tailwind), `noFloatingPromises` (nursery)
- Formatting: 2-space indent, 100-char width, double quotes, semicolons always, trailing commas everywhere
- Scripts: `npm run lint` (check), `npm run lint:fix` (autofix), `npm run format` (format only)

## Claude Code Hooks

Project-scoped hooks in `.claude/settings.json` enforce guardrails for AI agents working on this repo.

- `validate-commit-message.sh` (PreToolUse, Bash): blocks empty commit messages, missing `-m` flag, `--allow-empty-message`, and Co-Authored-By attribution lines
- `config-protection.js` (PreToolUse, Write/Edit/MultiEdit): blocks modifications to linter/formatter config files (`biome.json`, `.eslintrc`, `.prettierrc`, etc.) — agents must fix source code instead of weakening rules

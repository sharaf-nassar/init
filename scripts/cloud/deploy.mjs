#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import path from "node:path";

import {
  getStoredVercelToken,
  loadGlobalConfig,
  saveGlobalConfig,
  withStoredVercelToken,
} from "./config.mjs";
import { confirm, generateAuthSecret, promptLine, promptSecret } from "./prompts.mjs";
import {
  addEnv,
  assertVercelInstalled,
  deployProduction,
  ensureNeonResource,
  ensureProjectLink,
  hasEnvKey,
  listNeonResources,
  listProductionEnv,
  sanitizeProjectName,
  validateVercelToken,
} from "./vercel.mjs";
import { isPlainObject } from "./utils.mjs";

function printHelp() {
  console.log(`Usage: npm run deploy:cloud -- [options]

Bootstraps missing Vercel and Neon resources for this local project, ensures
required production environment variables exist, and deploys the current
directory to Vercel without Git integration.

Options:
  -h, --help         Show this help text
  --scope <scope>    Use a specific Vercel team or account scope`);
}

function parseArgs(argv) {
  let help = false;
  let scope;

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "--help" || arg === "-h") {
      help = true;
      continue;
    }

    if (arg === "--scope") {
      const value = argv[index + 1];
      if (typeof value !== "string" || value.length === 0 || value.startsWith("-")) {
        throw new Error("`--scope` requires a value.");
      }

      scope = value;
      index += 1;
      continue;
    }

    if (arg.startsWith("--scope=")) {
      const value = arg.slice("--scope=".length).trim();
      if (value.length === 0) {
        throw new Error("`--scope` requires a value.");
      }

      scope = value;
      continue;
    }

    throw new Error(`Unknown option: ${arg}`);
  }

  if (scope !== undefined && !/^[a-zA-Z0-9_-]{1,100}$/.test(scope)) {
    throw new Error("`--scope` must be 1-100 alphanumeric characters, hyphens, or underscores.");
  }

  return { help, scope };
}

async function readTextFile(cwd, relativePath, label) {
  const filePath = path.join(cwd, relativePath);

  try {
    const raw = await readFile(filePath, "utf8");
    if (raw.trim().length === 0) {
      throw new Error(`${label} is empty.`);
    }

    return raw;
  } catch (error) {
    if (
      error instanceof Error &&
      "code" in error &&
      (error.code === "ENOENT" || error.code === "ENOTDIR")
    ) {
      throw new Error(
        `Unsupported deploy directory: missing ${label} at ${path.join(cwd, relativePath)}.`,
      );
    }

    throw error;
  }
}

async function readPackageManifest(cwd) {
  const raw = await readTextFile(cwd, "package.json", "package.json");

  try {
    const parsed = JSON.parse(raw);
    if (!isPlainObject(parsed)) {
      throw new Error("package.json must contain a JSON object.");
    }

    return parsed;
  } catch (error) {
    if (error instanceof Error && error.name === "SyntaxError") {
      throw new Error(`Unable to parse package.json: ${error.message}`);
    }

    throw error;
  }
}

function getProjectName(manifest, cwd) {
  const packageName =
    typeof manifest.name === "string" && manifest.name.trim().length > 0 ? manifest.name : null;
  return sanitizeProjectName(packageName ?? path.basename(cwd));
}

function readScriptValue(scripts, key) {
  if (!isPlainObject(scripts)) {
    return null;
  }

  const value = scripts[key];
  return typeof value === "string" && value.trim().length > 0 ? value : null;
}

async function runLocalPreflight(cwd) {
  const manifest = await readPackageManifest(cwd);
  const deployScript = readScriptValue(manifest.scripts, "deploy:cloud");
  const hasNextDependency =
    (isPlainObject(manifest.dependencies) && typeof manifest.dependencies.next === "string") ||
    (isPlainObject(manifest.devDependencies) && typeof manifest.devDependencies.next === "string");

  if (!deployScript || !deployScript.includes("scripts/cloud/deploy.mjs")) {
    throw new Error(
      "Unsupported deploy directory: package.json is missing the expected deploy:cloud script for scripts/cloud/deploy.mjs.",
    );
  }

  if (!hasNextDependency) {
    throw new Error(
      "Unsupported deploy directory: package.json does not declare Next.js, so this does not look like a supported template app.",
    );
  }

  const requiredFiles = [
    ["next.config.js", "next.config.js"],
    ["src/env.js", "src/env.js"],
    ["prisma/schema.prisma", "prisma/schema.prisma"],
    ["src/app/layout.tsx", "src/app/layout.tsx"],
  ];

  await Promise.all(
    requiredFiles.map(([relativePath, label]) => readTextFile(cwd, relativePath, label)),
  );

  return {
    projectName: getProjectName(manifest, cwd),
  };
}

async function resolveVercelToken(scope) {
  const envToken = process.env.VERCEL_TOKEN;
  if (typeof envToken === "string" && envToken.length > 0) {
    await validateVercelToken(envToken, scope);
    return envToken;
  }

  const config = await loadGlobalConfig();
  const savedToken = getStoredVercelToken(config);
  if (savedToken) {
    try {
      await validateVercelToken(savedToken, scope);
      return savedToken;
    } catch {
      console.warn("Saved Vercel token is invalid. Prompting for a replacement.");
    }
  }

  const token = await promptSecret("Enter your Vercel token");
  await validateVercelToken(token, scope);
  await saveGlobalConfig(withStoredVercelToken(config, token));
  return token;
}

async function ensureAuthSecret({ cwd, envVars, token, scope }) {
  if (hasEnvKey(envVars, "AUTH_SECRET")) {
    return false;
  }

  await addEnv({
    cwd,
    token,
    key: "AUTH_SECRET",
    value: generateAuthSecret(),
    sensitive: true,
    scope,
  });

  return true;
}

function requirePromptValue(value, key) {
  if (value.length === 0) {
    throw new Error(`${key} is required when GitHub OAuth configuration is enabled.`);
  }

  return value;
}

async function ensureGitHubEnv({ cwd, envVars, token, scope }) {
  const hasGitHubId = hasEnvKey(envVars, "AUTH_GITHUB_ID");
  const hasGitHubSecret = hasEnvKey(envVars, "AUTH_GITHUB_SECRET");

  if (hasGitHubId && hasGitHubSecret) {
    return false;
  }

  const shouldConfigureGitHub = await confirm(
    "Configure missing GitHub OAuth environment variables for production sign-in?",
    true,
  );

  if (!shouldConfigureGitHub) {
    console.warn("Continuing without GitHub OAuth. Production sign-in may remain incomplete.");
    return false;
  }

  const pendingEnvWrites = [];

  if (!hasGitHubId) {
    const gitHubId = requirePromptValue(await promptLine("Enter AUTH_GITHUB_ID"), "AUTH_GITHUB_ID");
    pendingEnvWrites.push({
      key: "AUTH_GITHUB_ID",
      value: gitHubId,
      sensitive: false,
    });
  }

  if (!hasGitHubSecret) {
    const gitHubSecret = requirePromptValue(
      await promptSecret("Enter AUTH_GITHUB_SECRET"),
      "AUTH_GITHUB_SECRET",
    );
    pendingEnvWrites.push({
      key: "AUTH_GITHUB_SECRET",
      value: gitHubSecret,
      sensitive: true,
    });
  }

  for (const pendingEnvWrite of pendingEnvWrites) {
    await addEnv({
      cwd,
      token,
      scope,
      ...pendingEnvWrite,
    });
  }

  return true;
}

async function ensureProductionEnv({ cwd, token, scope }) {
  let envVars = await listProductionEnv(cwd, token, scope);
  let neonCreated = false;

  if (!hasEnvKey(envVars, "DATABASE_URL")) {
    const neonResult = await ensureNeonResource({ cwd, token, scope });
    neonCreated = neonResult.created;
    envVars = await listProductionEnv(cwd, token, scope);
  } else {
    const neonResources = await listNeonResources(cwd, token, scope);
    if (neonResources.length === 0) {
      throw new Error(
        "Conflicting Neon state: production DATABASE_URL exists but no Neon marketplace resource was found.",
      );
    }
  }

  if (!hasEnvKey(envVars, "DATABASE_URL")) {
    throw new Error("Production DATABASE_URL is still missing after Neon provisioning.");
  }

  await ensureAuthSecret({ cwd, envVars, token, scope });
  await ensureGitHubEnv({ cwd, envVars, token, scope });

  return {
    neonCreated,
  };
}

function getProjectLabel(project) {
  if (typeof project?.name === "string" && project.name.length > 0) {
    return project.name;
  }

  if (typeof project?.projectName === "string" && project.projectName.length > 0) {
    return project.projectName;
  }

  return "unknown";
}

function getProductionUrl(deployment) {
  if (typeof deployment?.url !== "string" || deployment.url.length === 0) {
    throw new Error("Deployment completed but no production URL was returned.");
  }

  return deployment.url.startsWith("https://") ? deployment.url : `https://${deployment.url}`;
}

async function main() {
  const { help, scope } = parseArgs(process.argv.slice(2));
  if (help) {
    printHelp();
    return;
  }

  const cwd = process.cwd();
  const { projectName } = await runLocalPreflight(cwd);
  await assertVercelInstalled();
  const token = await resolveVercelToken(scope);
  const projectResult = await ensureProjectLink({ cwd, projectName, token, scope });
  const envResult = await ensureProductionEnv({ cwd, token, scope });
  const deployment = await deployProduction({ cwd, token, scope });

  console.log("");
  console.log(`Project: ${getProjectLabel(projectResult.project)}`);
  console.log(`Vercel project: ${projectResult.created ? "created" : "reused"}`);
  console.log(`Neon resource: ${envResult.neonCreated ? "created" : "reused"}`);
  console.log(`Production URL: ${getProductionUrl(deployment)}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});

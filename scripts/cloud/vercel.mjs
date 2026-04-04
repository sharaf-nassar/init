import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import { mkdir, readFile, rename, unlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";

import { isPlainObject } from "./utils.mjs";

const execFileAsync = promisify(execFile);
const PENDING_PROJECT_FILE = "init-cloud-project.json";

function toAbsolutePath(cwd) {
  return path.resolve(cwd ?? process.cwd());
}

function parseJsonOutput(command, output) {
  try {
    return JSON.parse(output);
  } catch (error) {
    throw new Error(
      `Unable to parse JSON from \`${command}\`: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
}

function normalizeVercelError(error) {
  if (error instanceof Error) {
    const stderr = "stderr" in error && typeof error.stderr === "string" ? error.stderr.trim() : "";
    const stdout = "stdout" in error && typeof error.stdout === "string" ? error.stdout.trim() : "";
    return stderr || stdout || error.message;
  }

  return String(error);
}

function normalizeProject(payload) {
  if (!isPlainObject(payload)) {
    return payload;
  }

  if (isPlainObject(payload.project)) {
    return payload.project;
  }

  return payload;
}

function normalizeArrayPayload(payload, keys) {
  if (Array.isArray(payload)) {
    return payload;
  }

  if (!isPlainObject(payload)) {
    return [];
  }

  for (const key of keys) {
    const value = payload[key];
    if (Array.isArray(value)) {
      return value;
    }
  }

  return [];
}

async function runVercelCommand(args, { cwd, token, scope } = {}) {
  if (typeof token !== "string" || token.length === 0) {
    throw new Error("A Vercel token is required.");
  }

  const workingDirectory = toAbsolutePath(cwd);
  const finalArgs = [
    "--cwd",
    workingDirectory,
    ...(typeof scope === "string" && scope.length > 0 ? ["--scope", scope] : []),
    "--token",
    token,
    "--non-interactive",
    "--no-color",
    ...args,
  ];

  try {
    const result = await execFileAsync("vercel", finalArgs, {
      cwd: workingDirectory,
      env: {
        ...process.env,
        CI: "1",
        FORCE_COLOR: "0",
      },
      maxBuffer: 10 * 1024 * 1024,
    });

    return result.stdout.trim();
  } catch (error) {
    throw new Error(normalizeVercelError(error));
  }
}

async function runVercelJson(args, options) {
  return parseJsonOutput(args.join(" "), await runVercelCommand(args, options));
}

export async function assertVercelInstalled() {
  try {
    await execFileAsync("vercel", ["--version"], {
      env: {
        ...process.env,
        CI: "1",
        FORCE_COLOR: "0",
      },
    });
  } catch (error) {
    throw new Error(`Vercel CLI is required. Install it with \`npm install -g vercel\`. ${normalizeVercelError(error)}`);
  }
}

export async function validateVercelToken(token, scope) {
  return await runVercelJson(["whoami", "--format=json"], { cwd: process.cwd(), token, scope });
}

export function sanitizeProjectName(value) {
  const cleaned = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 100);

  return cleaned.length > 0 ? cleaned : "init";
}

export async function readLinkedProject(cwd) {
  const filePath = path.join(toAbsolutePath(cwd), ".vercel", "project.json");
  try {
    const raw = await readFile(filePath, "utf8");
    const parsed = parseJsonOutput("vercel link project.json", raw);
    if (
      !isPlainObject(parsed) ||
      typeof parsed.projectId !== "string" ||
      typeof parsed.projectName !== "string"
    ) {
      return null;
    }

    return parsed;
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return null;
    }

    throw error;
  }
}

function normalizeStoredProjectReference(parsed) {
  if (
    !isPlainObject(parsed) ||
    typeof parsed.projectId !== "string" ||
    parsed.projectId.length === 0 ||
    typeof parsed.projectName !== "string" ||
    parsed.projectName.length === 0
  ) {
    return null;
  }

  return {
    projectId: parsed.projectId,
    projectName: parsed.projectName,
  };
}

async function readPendingProject(cwd) {
  const filePath = path.join(toAbsolutePath(cwd), ".vercel", PENDING_PROJECT_FILE);
  let raw;
  try {
    raw = await readFile(filePath, "utf8");
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return null;
    }

    throw error;
  }

  try {
    const pending = normalizeStoredProjectReference(parseJsonOutput("init-cloud pending project", raw));
    if (pending) {
      return pending;
    }
  } catch {
    await clearPendingProject(cwd).catch(() => {});
    return null;
  }

  await clearPendingProject(cwd).catch(() => {});
  return null;
}

async function writePendingProject(cwd, project) {
  const workingDirectory = toAbsolutePath(cwd);
  const filePath = path.join(workingDirectory, ".vercel", PENDING_PROJECT_FILE);
  const directory = path.dirname(filePath);
  const tempPath = path.join(directory, `.${PENDING_PROJECT_FILE}.${randomUUID()}.tmp`);
  await mkdir(directory, { recursive: true });

  try {
    await writeFile(
      tempPath,
      `${JSON.stringify(
        {
          projectId: project.projectId,
          projectName: project.projectName,
        },
        null,
        2,
      )}\n`,
      "utf8",
    );
    await rename(tempPath, filePath);
  } catch (error) {
    await unlink(tempPath).catch(() => {});
    throw error;
  }
}

async function clearPendingProject(cwd) {
  const filePath = path.join(toAbsolutePath(cwd), ".vercel", PENDING_PROJECT_FILE);
  try {
    await unlink(filePath);
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return;
    }

    throw error;
  }
}

export async function findProject(idOrName, { token, cwd = process.cwd(), scope } = {}) {
  try {
    const project = await runVercelJson(
      ["api", `/v9/projects/${encodeURIComponent(idOrName)}`, "--raw"],
      { cwd, token, scope },
    );
    return normalizeProject(project);
  } catch (error) {
    const message = normalizeVercelError(error).toLowerCase();
    if (message.includes("not found") || message.includes("404")) {
      return null;
    }

    throw error;
  }
}

export async function createProject(projectName, { token, cwd = process.cwd(), scope } = {}) {
  const project = await runVercelJson(
    [
      "api",
      "/v10/projects",
      "--method",
      "POST",
      "--field",
      `name=${projectName}`,
      "--field",
      "framework=nextjs",
      "--field",
      "nodeVersion=24.x",
      "--raw",
    ],
    { cwd, token, scope },
  );

  return normalizeProject(project);
}

function hasUsableId(project) {
  return isPlainObject(project) && typeof project.id === "string" && project.id.length > 0;
}

export async function ensureProjectLink({ cwd, projectName, token, scope }) {
  const safeProjectName = sanitizeProjectName(projectName);
  const linked = await readLinkedProject(cwd);
  if (linked) {
    const remoteProject = await findProject(linked.projectId, { cwd, token, scope });
    if (remoteProject) {
      await clearPendingProject(cwd);
      return {
        created: false,
        linked: false,
        project: remoteProject,
      };
    }
  }

  const pending = await readPendingProject(cwd);
  if (pending) {
    if (pending.projectName !== safeProjectName) {
      await clearPendingProject(cwd);
    } else {
      const remoteProject = await findProject(pending.projectId, { cwd, token, scope });
      if (remoteProject) {
        await runVercelCommand(["link", "--project", pending.projectId, "--yes"], {
          cwd,
          token,
          scope,
        });
        await clearPendingProject(cwd);
        return {
          created: false,
          linked: true,
          project: remoteProject,
        };
      }

      await clearPendingProject(cwd);
    }
  }

  const existing = await findProject(safeProjectName, { cwd, token, scope });
  if (existing) {
    throw new Error(
      `A Vercel project named "${safeProjectName}" already exists, but ${toAbsolutePath(cwd)} is not linked to it. Refusing to attach automatically. Restore the local .vercel link or choose a different project name.`,
    );
  }

  const project = await createProject(safeProjectName, { cwd, token, scope });
  const projectIdentifier = hasUsableId(project)
    ? project.id
    : isPlainObject(project) && typeof project.name === "string" && project.name.length > 0
      ? project.name
      : safeProjectName;

  await writePendingProject(cwd, {
    projectId: projectIdentifier,
    projectName:
      isPlainObject(project) && typeof project.name === "string" && project.name.length > 0
        ? project.name
        : safeProjectName,
  });

  try {
    await runVercelCommand(["link", "--project", projectIdentifier, "--yes"], {
      cwd,
      token,
      scope,
    });
  } finally {
    const refreshedLinked = await readLinkedProject(cwd);
    if (refreshedLinked?.projectId === projectIdentifier) {
      await clearPendingProject(cwd);
    }
  }

  return {
    created: true,
    linked: true,
    project,
  };
}

export async function listProductionEnv(cwd, token, scope) {
  const payload = await runVercelJson(["env", "list", "production", "--format=json"], {
    cwd,
    token,
    scope,
  });
  return normalizeArrayPayload(payload, ["envs", "envVars", "variables", "items"]);
}

export function hasEnvKey(envVars, key) {
  return Array.isArray(envVars) && envVars.some((envVar) => isPlainObject(envVar) && envVar.key === key);
}

export async function addEnv({ cwd, token, key, value, sensitive = false, scope }) {
  await runVercelCommand(
    [
      "env",
      "add",
      key,
      "production",
      "--value",
      value,
      "--yes",
      ...(sensitive ? ["--sensitive"] : []),
    ],
    {
      cwd,
      token,
      scope,
    },
  );
}

export async function listNeonResources(cwd, token, scope) {
  const payload = await runVercelJson(["integration", "list", "--integration", "neon", "--format=json"], {
    cwd,
    token,
    scope,
  });
  return normalizeArrayPayload(payload, ["resources", "items"]);
}

export async function ensureNeonResource({ cwd, token, scope }) {
  const productionEnv = await listProductionEnv(cwd, token, scope);
  const hasDatabaseUrl = hasEnvKey(productionEnv, "DATABASE_URL");
  const resources = await listNeonResources(cwd, token, scope);
  const hasNeonResource = resources.length > 0;

  if (hasDatabaseUrl && hasNeonResource) {
    return {
      created: false,
      resources,
    };
  }

  if (hasDatabaseUrl !== hasNeonResource) {
    throw new Error(
      hasDatabaseUrl
        ? "Conflicting Neon state: production DATABASE_URL exists but no Neon marketplace resource was found. Refusing to provision."
        : "Conflicting Neon state: Neon marketplace resource exists but production DATABASE_URL is missing. Refusing to provision.",
    );
  }

  const created = await runVercelJson(
    [
      "integration",
      "add",
      "neon",
      "--environment",
      "production",
      "--format=json",
      "--no-env-pull",
    ],
    { cwd, token, scope },
  );

  return {
    created: true,
    resources: created,
  };
}

export async function deployProduction({ cwd, token, scope }) {
  return await runVercelJson(["deploy", "--prod", "--yes", "--format=json"], {
    cwd,
    token,
    scope,
  });
}

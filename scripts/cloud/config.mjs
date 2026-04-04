import { randomUUID } from "node:crypto";
import { chmod, mkdir, readFile, rename, unlink, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { isPlainObject } from "./utils.mjs";

const CONFIG_VERSION = 1;

function getConfigRoot() {
  if (process.platform === "win32") {
    const appData = process.env.APPDATA;
    if (!appData) {
      throw new Error("APPDATA is required to store Vercel credentials on Windows.");
    }

    return path.join(appData, "init");
  }

  const xdgConfigHome = process.env.XDG_CONFIG_HOME;
  const base =
    typeof xdgConfigHome === "string" &&
    xdgConfigHome.length > 0 &&
    path.isAbsolute(xdgConfigHome)
      ? xdgConfigHome
      : path.join(os.homedir(), ".config");
  return path.join(base, "init");
}

function normalizeConfig(parsed) {
  if (typeof parsed !== "object" || parsed === null) {
    return { version: CONFIG_VERSION };
  }

  const version = typeof parsed.version === "number" ? parsed.version : CONFIG_VERSION;

  return {
    version,
    ...(isPlainObject(parsed.vercel) ? { vercel: parsed.vercel } : {}),
  };
}

export function getGlobalConfigPath() {
  return path.join(getConfigRoot(), "cloud.json");
}

export async function loadGlobalConfig() {
  try {
    const raw = await readFile(getGlobalConfigPath(), "utf8");
    return normalizeConfig(JSON.parse(raw));
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return { version: CONFIG_VERSION };
    }

    throw new Error(
      `Unable to read cloud config: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
}

export async function saveGlobalConfig(config) {
  const filePath = getGlobalConfigPath();
  const directory = path.dirname(filePath);
  const tempPath = path.join(directory, `.cloud.json.${randomUUID()}.tmp`);
  await mkdir(directory, { recursive: true, mode: 0o700 });
  if (process.platform !== "win32") {
    await chmod(directory, 0o700);
  }

  try {
    await writeFile(
      tempPath,
      `${JSON.stringify({ ...config, version: CONFIG_VERSION }, null, 2)}\n`,
      { encoding: "utf8", mode: 0o600 },
    );

    if (process.platform !== "win32") {
      await chmod(tempPath, 0o600);
    }

    await rename(tempPath, filePath);
  } catch (error) {
    await unlink(tempPath).catch(() => {});
    throw error;
  }
}

export function getStoredVercelToken(config) {
  const token = config.vercel?.token;
  return typeof token === "string" && token.length > 0 ? token : null;
}

export function withStoredVercelToken(config, token) {
  const vercel = isPlainObject(config.vercel) ? config.vercel : {};

  return {
    ...config,
    version: CONFIG_VERSION,
    vercel: {
      ...vercel,
      token,
    },
  };
}

import crypto from "node:crypto";
import { stdin as input, stdout as output } from "node:process";
import readline from "node:readline/promises";

export async function promptLine(message) {
  if (!input.isTTY || !output.isTTY) {
    throw new Error(`Cannot prompt for ${message} in a non-interactive terminal.`);
  }

  const rl = readline.createInterface({ input, output });
  try {
    return (await rl.question(`${message}: `)).trim();
  } finally {
    rl.close();
  }
}

export async function confirm(message, defaultValue = true) {
  const suffix = defaultValue ? "Y/n" : "y/N";
  const answer = (await promptLine(`${message} [${suffix}]`)).toLowerCase();
  if (answer === "") {
    return defaultValue;
  }

  return answer === "y" || answer === "yes";
}

export async function promptSecret(message) {
  if (!input.isTTY || !output.isTTY) {
    throw new Error(`Cannot prompt for ${message} in a non-interactive terminal.`);
  }

  return await new Promise((resolve, reject) => {
    const chunks = [];
    const rawMode = input.isRaw;
    let settled = false;

    function cleanup() {
      if (!rawMode) {
        input.setRawMode(false);
      }

      input.pause();
      input.removeListener("data", onData);
    }

    function onData(chunk) {
      const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      for (let i = 0; i < bytes.length; i += 1) {
        if (settled) {
          return;
        }

        const byte = bytes[i];

        if (byte === 3) {
          settled = true;
          cleanup();
          output.write("\n");
          reject(new Error("Prompt cancelled."));
          return;
        }

        if (byte === 13 || byte === 10) {
          settled = true;
          cleanup();
          output.write("\n");
          resolve(Buffer.concat(chunks).toString("utf8").trim());
          return;
        }

        if (byte === 127 || byte === 8) {
          if (chunks.length > 0) {
            chunks.pop();
          }
          continue;
        }

        chunks.push(Buffer.from([byte]));
      }
    }

    output.write(`${message}: `);

    if (!rawMode) {
      input.setRawMode(true);
    }

    input.resume();
    input.on("data", onData);
  });
}

export function generateAuthSecret() {
  return crypto.randomBytes(32).toString("base64url");
}

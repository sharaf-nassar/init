import { createEnv } from "@t3-oss/env-nextjs";
import { z } from "zod";

export const env = createEnv({
  server: {
    AUTH_DISABLED: z
      .string()
      .optional()
      .transform((v) => v === "true" && process.env.NODE_ENV !== "production"),
    AUTH_SECRET: z.string().min(32, "AUTH_SECRET must be at least 32 characters").optional(),
    AUTH_GITHUB_ID: z.string().optional(),
    AUTH_GITHUB_SECRET: z.string().optional(),
    DATABASE_URL: z.url(),
    LOG_LEVEL: z.enum(["fatal", "error", "warn", "info", "debug", "trace"]).optional(),
    NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  },
  client: {},
  createFinalSchema: (shape) =>
    z
      .object(shape)
      .refine(
        (data) =>
          data.AUTH_DISABLED ||
          (typeof data.AUTH_SECRET === "string" && data.AUTH_SECRET.length >= 32),
        {
          message: "AUTH_SECRET is required (min 32 chars) when AUTH_DISABLED is not true",
          path: ["AUTH_SECRET"],
        },
      ),
  runtimeEnv: {
    AUTH_DISABLED: process.env.AUTH_DISABLED,
    AUTH_SECRET: process.env.AUTH_SECRET,
    AUTH_GITHUB_ID: process.env.AUTH_GITHUB_ID,
    AUTH_GITHUB_SECRET: process.env.AUTH_GITHUB_SECRET,
    DATABASE_URL: process.env.DATABASE_URL,
    LOG_LEVEL: process.env.LOG_LEVEL,
    NODE_ENV: process.env.NODE_ENV,
  },
  skipValidation: !!process.env.SKIP_ENV_VALIDATION && process.env.NODE_ENV !== "production",
  emptyStringAsUndefined: true,
});

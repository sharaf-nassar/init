import "server-only";
import pino from "pino";
import { env } from "~/env";

const isProduction = env.NODE_ENV === "production";

export const logger = pino({
  level: env.LOG_LEVEL ?? (isProduction ? "info" : "debug"),
  ...(!isProduction && {
    transport: {
      target: "pino-pretty",
      options: { colorize: true },
    },
  }),
});

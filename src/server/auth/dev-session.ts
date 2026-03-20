import type { Session } from "next-auth";
import type { PrismaClient } from "~/generated/prisma/client";

/**
 * Synthetic session injected when AUTH_DISABLED=true.
 * Used by tRPC context, auth exports, and Server Components.
 * The far-future expires value prevents expiration during development.
 * image is intentionally omitted — it is optional in DefaultSession["user"].
 */
export const DEV_SESSION = {
  user: { id: "dev-user", name: "Dev User", email: "dev@localhost" },
  expires: "2099-12-31T23:59:59.999Z",
} satisfies Session;

let seeded = false;

/**
 * Ensures a User row exists for the synthetic dev session.
 * Required because Post.authorId has a foreign key to User.id.
 * Runs once per process (idempotent upsert, skipped after first call).
 */
export async function ensureDevUser(db: PrismaClient): Promise<void> {
  if (seeded) return;
  await db.user.upsert({
    where: { id: DEV_SESSION.user.id },
    update: {},
    create: {
      id: DEV_SESSION.user.id,
      email: DEV_SESSION.user.email,
      name: DEV_SESSION.user.name,
    },
  });
  seeded = true;
}

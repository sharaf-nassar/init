import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";
import NextAuth from "next-auth";
import { cache } from "react";

import { env } from "~/env";
import { authConfig } from "~/server/auth/config";
import { DEV_SESSION } from "~/server/auth/dev-session";

function initAuth() {
  if (env.AUTH_DISABLED) return null;
  return NextAuth(authConfig);
}

const authInstance = initAuth();

const auth = cache(async () => {
  if (env.AUTH_DISABLED) return DEV_SESSION;
  if (!authInstance) {
    throw new Error("Auth.js not initialized — AUTH_SECRET may be missing");
  }
  return authInstance.auth();
});

const handlers = authInstance?.handlers ?? {
  GET: async (request: NextRequest) => NextResponse.redirect(new URL("/", request.url), 303),
  POST: async (request: NextRequest) => NextResponse.redirect(new URL("/", request.url), 303),
};

const signIn = authInstance?.signIn ?? (async (): Promise<void> => {});
const signOut = authInstance?.signOut ?? (async (): Promise<void> => {});

export { auth, handlers, signIn, signOut };

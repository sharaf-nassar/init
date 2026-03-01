import { PrismaAdapter } from "@auth/prisma-adapter";
import type { DefaultSession, NextAuthConfig } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";
import GitHubProvider from "next-auth/providers/github";
import { z } from "zod";

import { db } from "~/server/db";

declare module "next-auth" {
  interface Session extends DefaultSession {
    user: {
      id: string;
    } & DefaultSession["user"];
  }
}

const credentialsEmailSchema = z.email().max(254);

/**
 * Credentials provider for local development testing only.
 * Conditionally included — never registered in production.
 */
const devCredentialsProvider = CredentialsProvider({
  name: "Dev Credentials",
  credentials: {
    email: { label: "Email", type: "email", placeholder: "dev@example.com" },
    name: { label: "Name", type: "text", placeholder: "Dev User" },
  },
  async authorize(credentials) {
    if (process.env.NODE_ENV === "production") return null;

    const parsed = credentialsEmailSchema.safeParse(credentials?.email);
    if (!parsed.success) return null;

    const email = parsed.data;
    const name = typeof credentials?.name === "string" ? credentials.name.trim() : "Dev User";

    const user = await db.user.upsert({
      where: { email },
      update: {},
      create: { email, name },
    });

    return { id: user.id, email: user.email, name: user.name };
  },
});

export const authConfig = {
  providers: [
    GitHubProvider,
    ...(process.env.NODE_ENV !== "production" ? [devCredentialsProvider] : []),
  ],
  adapter: PrismaAdapter(db),
  session: { strategy: "jwt" },
  callbacks: {
    session: ({ session, token }) => {
      if (!token.sub) {
        throw new Error("JWT token missing sub claim");
      }
      return {
        ...session,
        user: {
          ...session.user,
          id: token.sub,
        },
      };
    },
  },
} satisfies NextAuthConfig;

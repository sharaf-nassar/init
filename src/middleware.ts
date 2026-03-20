import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

const authDisabled = process.env.AUTH_DISABLED === "true" && process.env.NODE_ENV !== "production";

/**
 * Route prefixes that require authentication.
 * Add your protected routes here — any path starting with these
 * prefixes will redirect unauthenticated users to the sign-in page.
 */
const protectedPrefixes = ["/dashboard", "/settings", "/profile"];

function isProtectedRoute(pathname: string): boolean {
  return protectedPrefixes.some((prefix) => pathname.startsWith(prefix));
}

function getSessionCookie(request: NextRequest): string | undefined {
  const cookie =
    request.cookies.get("authjs.session-token") ??
    request.cookies.get("__Secure-authjs.session-token");
  return cookie?.value;
}

export function middleware(request: NextRequest) {
  if (authDisabled) return NextResponse.next();
  const { pathname } = request.nextUrl;

  if (!isProtectedRoute(pathname)) {
    return NextResponse.next();
  }

  const session = getSessionCookie(request);
  if (!session) {
    const signInUrl = new URL("/api/auth/signin", request.url);
    signInUrl.searchParams.set("callbackUrl", pathname);
    return NextResponse.redirect(signInUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|api/health).*)"],
};

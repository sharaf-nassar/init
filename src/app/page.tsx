import { CreatePostForm } from "~/app/_components/create-post-form";
import { PostList } from "~/app/_components/post-list";
import { env } from "~/env";
import { auth, signOut } from "~/server/auth";
import { api, HydrateClient } from "~/trpc/server";

export default async function Home() {
  const [session] = await Promise.all([auth(), api.post.getAll.prefetchInfinite({ limit: 20 })]);

  return (
    <HydrateClient>
      <main className="flex min-h-screen flex-col items-center bg-gradient-to-b from-[#2e026d] to-[#15162c] text-white">
        <div className="container flex max-w-2xl flex-col items-center gap-8 px-4 py-16">
          <h1 className="text-5xl font-extrabold tracking-tight sm:text-[5rem]">
            T3 <span className="text-brand">Stack</span> App
          </h1>

          <div className="flex flex-col items-center gap-4">
            {session && !env.AUTH_DISABLED ? (
              <>
                <p className="text-xl">
                  Signed in as{" "}
                  <span className="font-semibold">{session.user.name ?? session.user.email}</span>
                </p>
                <form
                  action={async () => {
                    "use server";
                    await signOut();
                  }}
                >
                  <button
                    type="submit"
                    className="rounded-full bg-white/10 px-10 py-3 font-semibold no-underline transition hover:bg-white/20"
                  >
                    Sign out
                  </button>
                </form>
              </>
            ) : session ? (
              <p className="text-xl">
                Signed in as{" "}
                <span className="font-semibold">{session.user.name ?? session.user.email}</span>
                <span className="ml-2 text-sm text-white/50">(auth disabled)</span>
              </p>
            ) : (
              <>
                <p className="text-xl">Sign in to create posts</p>
                <a
                  href="/api/auth/signin"
                  className="rounded-full bg-brand px-10 py-3 font-semibold text-white no-underline transition hover:bg-brand-hover"
                >
                  Sign in
                </a>
              </>
            )}
          </div>

          {session?.user && <CreatePostForm />}

          <div className="w-full">
            <h2 className="mb-4 text-2xl font-bold">Recent Posts</h2>
            <PostList />
          </div>
        </div>
      </main>
    </HydrateClient>
  );
}

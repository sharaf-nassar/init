"use client";

import { api } from "~/trpc/react";

const dateFormatter = new Intl.DateTimeFormat(undefined, { dateStyle: "medium" });

export function PostList() {
  const { data, isLoading, fetchNextPage, hasNextPage, isFetchingNextPage } =
    api.post.getAll.useInfiniteQuery(
      { limit: 20 },
      { getNextPageParam: (lastPage) => lastPage.nextCursor },
    );

  const posts = data?.pages.flatMap((page) => page.posts) ?? [];

  if (isLoading) {
    return <p className="text-white/60">Loading posts...</p>;
  }

  if (posts.length === 0) {
    return <p className="text-white/60">No posts yet. Be the first to create one!</p>;
  }

  return (
    <div className="flex flex-col gap-4">
      {posts.map((post) => (
        <article key={post.id} className="rounded-lg bg-white/10 p-4">
          <h3 className="text-lg font-semibold">{post.title}</h3>
          <p className="mt-1 text-white/80">{post.content}</p>
          <p className="mt-2 text-sm text-white/50">
            by {post.author.name ?? "Anonymous"} &middot;{" "}
            {dateFormatter.format(new Date(post.createdAt))}
          </p>
        </article>
      ))}
      {hasNextPage && (
        <button
          type="button"
          onClick={() => void fetchNextPage()}
          disabled={isFetchingNextPage}
          className="rounded-lg bg-white/10 px-6 py-3 font-semibold transition hover:bg-white/20 disabled:opacity-50"
        >
          {isFetchingNextPage ? "Loading..." : "Load more"}
        </button>
      )}
    </div>
  );
}

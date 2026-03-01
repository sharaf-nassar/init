"use client";

import { useState } from "react";
import { api } from "~/trpc/react";

const inputClass =
  "w-full rounded-lg bg-white/10 px-4 py-3 text-white placeholder:text-white/50 focus:outline-none focus:ring-2 focus:ring-brand";

export function CreatePostForm() {
  const utils = api.useUtils();
  const [title, setTitle] = useState("");
  const [content, setContent] = useState("");

  const createPost = api.post.create.useMutation({
    onSuccess: async () => {
      await utils.post.getAll.invalidate();
      setTitle("");
      setContent("");
    },
  });

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        createPost.mutate({ title, content });
      }}
      className="flex w-full flex-col gap-3"
    >
      <input
        type="text"
        placeholder="Post title"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        className={inputClass}
        maxLength={200}
        required
      />
      <textarea
        placeholder="Write your post content..."
        value={content}
        onChange={(e) => setContent(e.target.value)}
        rows={3}
        className={inputClass}
        maxLength={10000}
        required
      />
      <button
        type="submit"
        className="rounded-lg bg-brand px-6 py-3 font-semibold text-white transition hover:bg-brand-hover disabled:opacity-50"
        disabled={createPost.isPending}
      >
        {createPost.isPending ? "Creating..." : "Create Post"}
      </button>
      {createPost.error && <p className="text-sm text-red-400">{createPost.error.message}</p>}
    </form>
  );
}

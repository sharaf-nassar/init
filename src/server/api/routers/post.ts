import { z } from "zod";

import { createTRPCRouter, protectedProcedure, publicProcedure } from "~/server/api/trpc";

export const postRouter = createTRPCRouter({
  getAll: publicProcedure
    .input(
      z.object({
        limit: z.number().min(1).max(100).default(20),
        cursor: z.number().optional(),
      }),
    )
    .query(async ({ ctx, input }) => {
      const { limit, cursor } = input;

      const posts = await ctx.db.post.findMany({
        take: limit + 1,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        orderBy: { createdAt: "desc" },
        select: {
          id: true,
          title: true,
          content: true,
          createdAt: true,
          author: { select: { name: true } },
        },
      });

      const hasNextPage = posts.length > limit;
      const page = hasNextPage ? posts.slice(0, limit) : posts;
      const lastPost = page[page.length - 1];
      const nextCursor = hasNextPage ? lastPost?.id : undefined;

      return { posts: page, nextCursor };
    }),

  create: protectedProcedure
    .input(
      z.object({
        title: z.string().min(1, "Title is required").max(200),
        content: z.string().min(1, "Content is required").max(10000),
      }),
    )
    .mutation(async ({ ctx, input }) => {
      return await ctx.db.post.create({
        data: {
          title: input.title,
          content: input.content,
          authorId: ctx.session.user.id,
        },
      });
    }),
});

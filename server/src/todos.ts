// Task 2.3 — Todo lists（待辦清單）
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { PrismaClient, User } from "@prisma/client";
import { userFromRequest } from "./auth.js";

async function requireUser(prisma: PrismaClient, req: FastifyRequest, reply: FastifyReply): Promise<User | null> {
  const user = await userFromRequest(prisma, req);
  if (!user) {
    await reply.code(401).send({ error: "unauthorized" });
    return null;
  }
  return user;
}

async function requireMember(prisma: PrismaClient, calendarId: string, userId: string) {
  return prisma.calendarMember.findUnique({
    where: { calendarId_userId: { calendarId, userId } },
  });
}

async function listForMember(prisma: PrismaClient, listId: string, userId: string) {
  const list = await prisma.todoList.findUnique({ where: { id: listId } });
  if (!list) return null;
  const member = await requireMember(prisma, list.calendarId, userId);
  return member ? list : null;
}

async function emitEvent(prisma: PrismaClient, type: string, aggregateId: string, payload: object) {
  await prisma.outboxEvent.create({ data: { type, aggregateId, payload: JSON.stringify(payload) } });
}

function publicList(l: { id: string; calendarId: string; title: string; items: { id: string; text: string; done: boolean }[] }) {
  const done = l.items.filter((i) => i.done).length;
  return {
    id: l.id,
    calendarId: l.calendarId,
    title: l.title,
    total: l.items.length,
    done,
    items: l.items.map((i) => ({ id: i.id, text: i.text, done: i.done })),
  };
}

export function registerTodoRoutes(app: FastifyInstance, prisma: PrismaClient) {
  // 列出行事曆所有清單（連 items）
  app.get("/v1/calendars/:id/todos", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    const lists = await prisma.todoList.findMany({
      where: { calendarId: id },
      include: { items: { orderBy: { createdAt: "asc" } } },
      orderBy: { createdAt: "asc" },
    });
    return reply.send({ lists: lists.map(publicList) });
  });

  // 開清單
  app.post("/v1/calendars/:id/todos", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    if (!(await requireMember(prisma, id, user.id))) return reply.code(404).send({ error: "calendar not found" });
    const body = (req.body ?? {}) as { title?: string };
    if (!body.title?.trim()) return reply.code(400).send({ error: "title is required" });
    const list = await prisma.todoList.create({
      data: { calendarId: id, title: body.title.trim(), creatorId: user.id },
      include: { items: true },
    });
    await emitEvent(prisma, "todo.list_created", id, { listId: list.id, actorId: user.id });
    return reply.code(201).send({ list: publicList(list) });
  });

  // 刪清單
  app.delete("/v1/todos/:id", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const list = await listForMember(prisma, id, user.id);
    if (!list) return reply.code(404).send({ error: "list not found" });
    await prisma.todoList.delete({ where: { id } });
    await emitEvent(prisma, "todo.list_deleted", list.calendarId, { listId: id, actorId: user.id });
    return reply.code(204).send();
  });

  // 加 item
  app.post("/v1/todos/:id/items", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const list = await listForMember(prisma, id, user.id);
    if (!list) return reply.code(404).send({ error: "list not found" });
    const body = (req.body ?? {}) as { text?: string };
    if (!body.text?.trim()) return reply.code(400).send({ error: "text is required" });
    const item = await prisma.todoItem.create({
      data: { listId: id, text: body.text.trim() },
    });
    await emitEvent(prisma, "todo.item_created", list.calendarId, { listId: id, itemId: item.id, actorId: user.id });
    return reply.code(201).send({ item: { id: item.id, text: item.text, done: item.done } });
  });

  // 切換 done / 改 text
  app.patch("/v1/todo-items/:id", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const item = await prisma.todoItem.findUnique({ where: { id }, include: { list: true } });
    if (!item) return reply.code(404).send({ error: "item not found" });
    if (!(await requireMember(prisma, item.list.calendarId, user.id))) return reply.code(404).send({ error: "item not found" });
    const body = (req.body ?? {}) as { done?: boolean; text?: string };
    const updated = await prisma.todoItem.update({
      where: { id },
      data: {
        ...(body.done !== undefined ? { done: body.done, doneById: body.done ? user.id : null } : {}),
        ...(body.text?.trim() ? { text: body.text.trim() } : {}),
      },
    });
    if (body.done !== undefined) {
      await emitEvent(prisma, body.done ? "todo.item_done" : "todo.item_undone", item.list.calendarId, { itemId: id, actorId: user.id });
    }
    return reply.send({ item: { id: updated.id, text: updated.text, done: updated.done } });
  });

  // 刪 item
  app.delete("/v1/todo-items/:id", async (req, reply) => {
    const user = await requireUser(prisma, req, reply);
    if (!user) return;
    const { id } = req.params as { id: string };
    const item = await prisma.todoItem.findUnique({ where: { id }, include: { list: true } });
    if (!item) return reply.code(404).send({ error: "item not found" });
    if (!(await requireMember(prisma, item.list.calendarId, user.id))) return reply.code(404).send({ error: "item not found" });
    await prisma.todoItem.delete({ where: { id } });
    return reply.code(204).send();
  });
}

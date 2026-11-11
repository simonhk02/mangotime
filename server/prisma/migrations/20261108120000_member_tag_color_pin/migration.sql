-- CreateTable
CREATE TABLE "EventMember" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "eventId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    CONSTRAINT "EventMember_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "EventMember_eventId_userId_key" ON "EventMember"("eventId", "userId");

-- AlterTable
ALTER TABLE "CalendarMember" ADD COLUMN "color" TEXT;

-- AlterTable
ALTER TABLE "Event" ADD COLUMN "pinned" BOOLEAN NOT NULL DEFAULT false;

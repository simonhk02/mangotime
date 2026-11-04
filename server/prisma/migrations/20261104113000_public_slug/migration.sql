-- Task 5.2 publicSlug
ALTER TABLE "Calendar" ADD COLUMN "publicSlug" TEXT;
CREATE UNIQUE INDEX "Calendar_publicSlug_key" ON "Calendar"("publicSlug");

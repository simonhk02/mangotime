-- CreateTable
CREATE TABLE "PublicLike" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "publicSlug" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "PublicLike_publicSlug_userId_key" ON "PublicLike"("publicSlug", "userId");
CREATE INDEX "PublicLike_userId_idx" ON "PublicLike"("userId");

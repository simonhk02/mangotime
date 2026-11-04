-- Social auth：passwordHash nullable + SocialAccount table
CREATE TABLE "SocialAccount" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "provider" TEXT NOT NULL,
    "providerSub" TEXT NOT NULL,
    "email" TEXT,
    "userId" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "SocialAccount_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "SocialAccount_provider_providerSub_key" ON "SocialAccount"("provider", "providerSub");
CREATE INDEX "SocialAccount_userId_idx" ON "SocialAccount"("userId");
-- SQLite 改唔到 column nullable：rebuild User table
PRAGMA foreign_keys=off;
CREATE TABLE "User_new" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "email" TEXT NOT NULL,
    "displayName" TEXT NOT NULL,
    "avatarUrl" TEXT,
    "passwordHash" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO "User_new" SELECT "id","email","displayName","avatarUrl","passwordHash","createdAt" FROM "User";
DROP TABLE "User";
ALTER TABLE "User_new" RENAME TO "User";
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");
PRAGMA foreign_keys=on;

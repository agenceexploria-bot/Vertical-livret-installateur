-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_PointControle" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "chantierId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "libelle" TEXT NOT NULL,
    "categorie" TEXT NOT NULL DEFAULT 'generale',
    "critique" BOOLEAN NOT NULL DEFAULT false,
    "photoRequise" BOOLEAN NOT NULL DEFAULT true,
    "status" TEXT NOT NULL DEFAULT 'vide',
    "photoPath" TEXT,
    "validePar" TEXT,
    "valideAt" DATETIME,
    "ordre" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "PointControle_chantierId_fkey" FOREIGN KEY ("chantierId") REFERENCES "Chantier" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
INSERT INTO "new_PointControle" ("chantierId", "id", "libelle", "ordre", "photoPath", "photoRequise", "status", "type") SELECT "chantierId", "id", "libelle", "ordre", "photoPath", "photoRequise", "status", "type" FROM "PointControle";
DROP TABLE "PointControle";
ALTER TABLE "new_PointControle" RENAME TO "PointControle";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;

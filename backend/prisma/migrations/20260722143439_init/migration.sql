-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "nom" TEXT NOT NULL,
    "prenom" TEXT NOT NULL,
    "mobile" TEXT NOT NULL,
    "email" TEXT,
    "passwordHash" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "status" TEXT,
    "societe" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT false,
    "suspendu" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "Habilitation" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "titre" TEXT NOT NULL,
    "dateExpiration" DATETIME NOT NULL,
    "userId" TEXT NOT NULL,
    CONSTRAINT "Habilitation_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "token" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "expiresAt" DATETIME NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "Chantier" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "reference" TEXT NOT NULL,
    "client" TEXT NOT NULL,
    "adresse" TEXT NOT NULL,
    "ville" TEXT NOT NULL,
    "dateDebut" DATETIME NOT NULL,
    "dateFin" DATETIME NOT NULL,
    "contactNom" TEXT NOT NULL,
    "contactTel" TEXT NOT NULL,
    "horaires" TEXT NOT NULL,
    "consignes" TEXT NOT NULL,
    "typeMonteCharge" TEXT NOT NULL,
    "capacite" TEXT NOT NULL,
    "niveaux" INTEGER NOT NULL,
    "referenceAffaire" TEXT NOT NULL,
    "syncStatus" TEXT NOT NULL DEFAULT 'nouveau',
    "rexValide" BOOLEAN NOT NULL DEFAULT false,
    "rexTranscription" TEXT,
    "pvSigne" BOOLEAN NOT NULL DEFAULT false,
    "pvSigneur" TEXT,
    "pvSigneAt" DATETIME,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "livretsOuvertsJson" TEXT NOT NULL DEFAULT '[]'
);

-- CreateTable
CREATE TABLE "ChantierInstallateur" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "chantierId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "rattacheAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ChantierInstallateur_chantierId_fkey" FOREIGN KEY ("chantierId") REFERENCES "Chantier" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "ChantierInstallateur_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "PointControle" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "chantierId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "libelle" TEXT NOT NULL,
    "photoRequise" BOOLEAN NOT NULL DEFAULT true,
    "status" TEXT NOT NULL DEFAULT 'vide',
    "photoPath" TEXT,
    "ordre" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "PointControle_chantierId_fkey" FOREIGN KEY ("chantierId") REFERENCES "Chantier" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "DocumentTerrain" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "chantierId" TEXT NOT NULL,
    "titre" TEXT NOT NULL,
    "categorie" TEXT NOT NULL,
    "filePath" TEXT,
    "auteurId" TEXT NOT NULL,
    "horodatage" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "DocumentTerrain_chantierId_fkey" FOREIGN KEY ("chantierId") REFERENCES "Chantier" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "DocumentTerrain_auteurId_fkey" FOREIGN KEY ("auteurId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "User_mobile_key" ON "User"("mobile");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "RefreshToken_token_key" ON "RefreshToken"("token");

-- CreateIndex
CREATE UNIQUE INDEX "Chantier_reference_key" ON "Chantier"("reference");

-- CreateIndex
CREATE UNIQUE INDEX "ChantierInstallateur_chantierId_userId_key" ON "ChantierInstallateur"("chantierId", "userId");

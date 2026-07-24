-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('installateur', 'chargeAffaires', 'qualite', 'direction', 'admin');

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('salarie', 'sousTraitant');

-- CreateEnum
CREATE TYPE "PointType" AS ENUM ('reception', 'autoControle');

-- CreateEnum
CREATE TYPE "PointStatus" AS ENUM ('vide', 'conforme', 'nonConforme');

-- CreateEnum
CREATE TYPE "CategorieDocument" AS ENUM ('bonLivraison', 'documentClient', 'habilitation', 'constat', 'autre');

-- CreateEnum
CREATE TYPE "TypeDocumentChantier" AS ENUM ('securite', 'technique');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "nom" TEXT NOT NULL,
    "prenom" TEXT NOT NULL,
    "mobile" TEXT,
    "email" TEXT,
    "passwordHash" TEXT NOT NULL,
    "role" "UserRole" NOT NULL,
    "status" "UserStatus",
    "societe" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT false,
    "suspendu" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Habilitation" (
    "id" TEXT NOT NULL,
    "titre" TEXT NOT NULL,
    "dateExpiration" TIMESTAMP(3) NOT NULL,
    "filePath" TEXT,
    "userId" TEXT NOT NULL,

    CONSTRAINT "Habilitation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EmailVerificationCode" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EmailVerificationCode_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Chantier" (
    "id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "client" TEXT NOT NULL,
    "adresse" TEXT NOT NULL,
    "ville" TEXT NOT NULL,
    "dateDebut" TIMESTAMP(3) NOT NULL,
    "dateFin" TIMESTAMP(3) NOT NULL,
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
    "rexAudioPath" TEXT,
    "rexSoumisAt" TIMESTAMP(3),
    "pvSigne" BOOLEAN NOT NULL DEFAULT false,
    "pvSigneur" TEXT,
    "pvSigneAt" TIMESTAMP(3),
    "pvSignatureImagePath" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "livretsOuvertsJson" TEXT NOT NULL DEFAULT '[]',

    CONSTRAINT "Chantier_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ChantierInstallateur" (
    "id" TEXT NOT NULL,
    "chantierId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "rattacheAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ChantierInstallateur_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PointControle" (
    "id" TEXT NOT NULL,
    "chantierId" TEXT NOT NULL,
    "type" "PointType" NOT NULL,
    "libelle" TEXT NOT NULL,
    "categorie" TEXT NOT NULL DEFAULT 'generale',
    "critique" BOOLEAN NOT NULL DEFAULT false,
    "photoRequise" BOOLEAN NOT NULL DEFAULT true,
    "status" "PointStatus" NOT NULL DEFAULT 'vide',
    "photoPath" TEXT,
    "validePar" TEXT,
    "valideAt" TIMESTAMP(3),
    "ordre" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "PointControle_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DocumentTerrain" (
    "id" TEXT NOT NULL,
    "chantierId" TEXT NOT NULL,
    "titre" TEXT NOT NULL,
    "categorie" "CategorieDocument" NOT NULL,
    "filePath" TEXT,
    "auteurId" TEXT NOT NULL,
    "horodatage" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DocumentTerrain_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DocumentChantier" (
    "id" TEXT NOT NULL,
    "chantierId" TEXT NOT NULL,
    "type" "TypeDocumentChantier" NOT NULL,
    "nom" TEXT NOT NULL,
    "filePath" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DocumentChantier_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_mobile_key" ON "User"("mobile");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "EmailVerificationCode_email_idx" ON "EmailVerificationCode"("email");

-- CreateIndex
CREATE UNIQUE INDEX "RefreshToken_token_key" ON "RefreshToken"("token");

-- CreateIndex
CREATE UNIQUE INDEX "Chantier_reference_key" ON "Chantier"("reference");

-- CreateIndex
CREATE UNIQUE INDEX "ChantierInstallateur_chantierId_userId_key" ON "ChantierInstallateur"("chantierId", "userId");

-- AddForeignKey
ALTER TABLE "Habilitation" ADD CONSTRAINT "Habilitation_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChantierInstallateur" ADD CONSTRAINT "ChantierInstallateur_chantierId_fkey" FOREIGN KEY ("chantierId") REFERENCES "Chantier"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChantierInstallateur" ADD CONSTRAINT "ChantierInstallateur_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PointControle" ADD CONSTRAINT "PointControle_chantierId_fkey" FOREIGN KEY ("chantierId") REFERENCES "Chantier"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DocumentTerrain" ADD CONSTRAINT "DocumentTerrain_chantierId_fkey" FOREIGN KEY ("chantierId") REFERENCES "Chantier"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DocumentTerrain" ADD CONSTRAINT "DocumentTerrain_auteurId_fkey" FOREIGN KEY ("auteurId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DocumentChantier" ADD CONSTRAINT "DocumentChantier_chantierId_fkey" FOREIGN KEY ("chantierId") REFERENCES "Chantier"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateEnum
CREATE TYPE "ChantierType" AS ENUM ('installation', 'sav');

-- AlterTable
ALTER TABLE "Chantier" ADD COLUMN     "descriptionIntervention" TEXT,
ADD COLUMN     "parentReference" TEXT,
ADD COLUMN     "piecesRemplacees" TEXT,
ADD COLUMN     "savDate" TIMESTAMP(3),
ADD COLUMN     "type" "ChantierType" NOT NULL DEFAULT 'installation';

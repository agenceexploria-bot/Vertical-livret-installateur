-- AlterTable
ALTER TABLE "Chantier" ADD COLUMN     "chargeAffairesId" TEXT;

-- AddForeignKey
ALTER TABLE "Chantier" ADD CONSTRAINT "Chantier_chargeAffairesId_fkey" FOREIGN KEY ("chargeAffairesId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

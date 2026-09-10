-- AlterTable
ALTER TABLE "Rex" ADD COLUMN     "auteurId" TEXT;

-- AddForeignKey
ALTER TABLE "Rex" ADD CONSTRAINT "Rex_auteurId_fkey" FOREIGN KEY ("auteurId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

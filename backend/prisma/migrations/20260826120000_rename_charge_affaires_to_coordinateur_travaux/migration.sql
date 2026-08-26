-- Renommage du rôle "Chargé d'affaires" en "Coordinateur travaux" : on
-- renomme la valeur d'enum et la colonne plutôt que de les recréer, pour ne
-- perdre aucune donnée existante (comptes déjà en base avec ce rôle,
-- chantiers déjà rattachés à un chargé d'affaires).
ALTER TYPE "UserRole" RENAME VALUE 'chargeAffaires' TO 'coordinateurTravaux';

ALTER TABLE "Chantier" RENAME COLUMN "chargeAffairesId" TO "coordinateurTravauxId";
ALTER TABLE "Chantier" RENAME CONSTRAINT "Chantier_chargeAffairesId_fkey" TO "Chantier_coordinateurTravauxId_fkey";

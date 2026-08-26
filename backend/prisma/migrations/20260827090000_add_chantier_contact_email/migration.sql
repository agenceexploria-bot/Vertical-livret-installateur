-- Email du contact sur place, extrait par le collage intelligent (voir
-- BoNewChantierScreen._parseCollage) en plus du nom/téléphone déjà existants.
ALTER TABLE "Chantier" ADD COLUMN "contactEmail" TEXT;

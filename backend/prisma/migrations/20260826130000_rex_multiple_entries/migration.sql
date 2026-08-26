-- REX multiples par chantier : remplace les colonnes scalaires
-- (rexValide/rexTranscription/rexAudioPath/rexSoumisAt) par une table dédiée,
-- pour permettre plusieurs retours REX par chantier au lieu d'un seul.
CREATE TABLE "Rex" (
    "id" TEXT NOT NULL,
    "chantierId" TEXT NOT NULL,
    "transcription" TEXT,
    "audioPath" TEXT,
    "soumisAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Rex_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "Rex" ADD CONSTRAINT "Rex_chantierId_fkey" FOREIGN KEY ("chantierId") REFERENCES "Chantier"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Reprise des REX déjà soumis avant la migration (un seul par chantier, vu
-- l'ancien modèle) — aucune donnée existante n'est perdue.
INSERT INTO "Rex" ("id", "chantierId", "transcription", "audioPath", "soumisAt")
SELECT md5(random()::text || clock_timestamp()::text), "id", "rexTranscription", "rexAudioPath", COALESCE("rexSoumisAt", CURRENT_TIMESTAMP)
FROM "Chantier"
WHERE "rexValide" = true;

ALTER TABLE "Chantier" DROP COLUMN "rexValide";
ALTER TABLE "Chantier" DROP COLUMN "rexTranscription";
ALTER TABLE "Chantier" DROP COLUMN "rexAudioPath";
ALTER TABLE "Chantier" DROP COLUMN "rexSoumisAt";

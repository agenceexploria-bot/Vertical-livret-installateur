-- Verrou de connexion persistant par compte (voir revue de sécurité :
-- authRateLimit est un rate-limit en mémoire par IP, non fiable en
-- environnement serverless).
ALTER TABLE "User" ADD COLUMN "loginFailedAttempts" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "User" ADD COLUMN "loginLockedUntil" TIMESTAMP(3);

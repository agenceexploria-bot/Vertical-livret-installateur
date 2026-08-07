import 'dotenv/config';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Script ponctuel de bootstrap d'un compte Admin — il n'existe aucune route
// API pour créer un compte admin/direction/qualite (voir backend/src/routes/
// auth.ts : POST /auth/signup crée toujours role='installateur',
// POST /auth/signup-interne n'accepte que role='chargeAffaires') : ces rôles
// à privilèges ne sont volontairement pas self-service. Seul le seed
// (prisma/seed.ts) ou ce type de script, exécuté manuellement contre la
// base cible, peut en créer un.
//
// Email/mot de passe lus depuis l'environnement — jamais codés en dur ici,
// pour ne rien laisser de secret dans l'historique Git de ce fichier.
// Usage : ADMIN_EMAIL="..." ADMIN_PASSWORD="..." npx tsx prisma/createAdmin.ts
//
// Upsert sur `email` (colonne unique) : si ce compte existe déjà, RIEN n'est
// modifié (update: {}) — aucune donnée existante n'est écrasée, exécuter ce
// script plusieurs fois est sans danger.
async function main() {
  const email = process.env.ADMIN_EMAIL;
  const password = process.env.ADMIN_PASSWORD;
  const nom = process.env.ADMIN_NOM ?? 'Admin';
  const prenom = process.env.ADMIN_PRENOM ?? 'Vertical';

  if (!email || !password) {
    console.error('Usage : ADMIN_EMAIL="..." ADMIN_PASSWORD="..." npx tsx prisma/createAdmin.ts');
    process.exit(1);
  }
  if (password.length < 6) {
    console.error('ADMIN_PASSWORD doit faire au moins 6 caractères (même règle que /auth/signup).');
    process.exit(1);
  }

  const passwordHash = await bcrypt.hash(password, 10);

  const admin = await prisma.user.upsert({
    where: { email },
    update: {},
    create: { nom, prenom, email, passwordHash, role: 'admin', isActive: true },
  });

  console.log('Compte admin prêt :', { id: admin.id, email: admin.email, role: admin.role });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

import type { Express } from 'express';
import request from 'supertest';
import { prisma } from '../prisma';

export async function resetDb() {
  await prisma.documentTerrain.deleteMany();
  await prisma.documentChantier.deleteMany();
  await prisma.pointControle.deleteMany();
  await prisma.chantierInstallateur.deleteMany();
  await prisma.chantier.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.habilitation.deleteMany();
  await prisma.emailVerificationCode.deleteMany();
  await prisma.user.deleteMany();
}

/// Enchaîne le parcours complet d'inscription (demande de code → vérification
/// → création du compte) pour les tests — le code est récupéré directement
/// dans la réponse de /request-email-code, renvoyé en clair uniquement parce
/// que NODE_ENV=test (voir authRouter). Évite de dupliquer ce ballet dans
/// chaque fichier de test.
export async function signup(app: Express, body: Record<string, unknown>) {
  const email = body.email as string;
  const codeRes = await request(app).post('/auth/request-email-code').send({ email });
  if (codeRes.status !== 200) return codeRes;

  const verifyRes = await request(app).post('/auth/verify-email-code').send({ email, code: codeRes.body.code });
  if (verifyRes.status !== 200) return verifyRes;

  return request(app)
    .post('/auth/signup')
    .send({ ...body, verificationTicket: verifyRes.body.verificationTicket });
}

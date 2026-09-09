import type { Express } from 'express';
import request from 'supertest';
import { vi } from 'vitest';
import { prisma } from '../prisma';

export const GROQ_TRANSCRIPTION_URL = 'https://api.groq.com/openai/v1/audio/transcriptions';
export const OPENAI_TRANSCRIPTION_URL = 'https://api.openai.com/v1/audio/transcriptions';

// GROQ_API_KEY/OPENAI_API_KEY sont explicitement absentes en test (voir
// vitest.setup.ts) — ce helper les renseigne temporairement et intercepte
// l'appel Whisper pour ne jamais faire de vrai appel réseau (voir
// chantiers.test.ts et transcribeSegment.test.ts, qui la réactivent
// explicitement toutes les deux).
export async function withStubbedTranscription<T>(
  envVar: 'GROQ_API_KEY' | 'OPENAI_API_KEY',
  providerUrl: string,
  providerResponse: Response,
  run: () => Promise<T>,
): Promise<T> {
  const previousValue = process.env[envVar];
  const previousFetch = globalThis.fetch;
  process.env[envVar] = 'test-api-key';
  globalThis.fetch = vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : input.toString();
    if (url === providerUrl) return providerResponse;
    return previousFetch(input, init);
  }) as typeof fetch;
  try {
    return await run();
  } finally {
    globalThis.fetch = previousFetch;
    if (previousValue === undefined) delete process.env[envVar];
    else process.env[envVar] = previousValue;
  }
}

// Mêmes listes par défaut que la migration checklist_template_items — `db
// push` (utilisé par les tests, voir vitest.setup.ts) ne rejoue jamais le SQL
// des migrations, seulement le schéma : sans ce ré-ensemencement, la table
// resterait vide en test et POST /chantiers créerait des chantiers sans
// aucun point de contrôle.
const RECEPTION_POINTS_DEFAULTS = Array.from({ length: 5 }, (_, i) => ({
  type: 'reception' as const,
  categorie: 'Réception',
  libelle: `Réception point ${i + 1}`,
  critique: false,
  ordre: i,
}));

const AUTO_CONTROLE_POINTS_DEFAULTS = [
  { categorie: 'Mécanique', libelle: 'Fixation du treuil et des poulies', critique: false },
  { categorie: 'Mécanique', libelle: 'Alignement des rails de guidage', critique: false },
  { categorie: 'Mécanique', libelle: 'Serrage des attaches de câbles', critique: false },
  { categorie: 'Mécanique', libelle: 'Niveau et aplomb de la structure', critique: false },
  { categorie: 'Portes palières', libelle: 'Verrouillage des portes palières', critique: true },
  { categorie: 'Portes palières', libelle: 'Serrures de gâches', critique: true },
  { categorie: 'Portes palières', libelle: 'Asservissement porte/cabine', critique: true },
  { categorie: 'Portes palières', libelle: 'Étanchéité des seuils de porte', critique: false },
  { categorie: 'Essais', libelle: 'Essai de charge nominale', critique: false },
  { categorie: 'Essais', libelle: 'Essai des fins de course', critique: false },
  { categorie: 'Essais', libelle: "Essai du dispositif d'arrêt d'urgence", critique: true },
].map((p, i) => ({ type: 'autoControle' as const, ordre: i, ...p }));

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
  await prisma.checklistTemplateItem.deleteMany();
  await prisma.checklistTemplateItem.createMany({ data: [...RECEPTION_POINTS_DEFAULTS, ...AUTO_CONTROLE_POINTS_DEFAULTS] });
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

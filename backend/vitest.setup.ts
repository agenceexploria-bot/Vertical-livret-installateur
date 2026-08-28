import 'dotenv/config';
import { execSync } from 'child_process';
import { vi } from 'vitest';

// Le schéma est en Postgres (voir schema.prisma) — les tests ont besoin de
// leur propre base, distincte de DATABASE_URL, pour ne pas écraser les
// données de dev à chaque `db push`.
if (!process.env.TEST_DATABASE_URL) {
  throw new Error(
    'TEST_DATABASE_URL manquant (voir backend/.env) — les tests ont besoin de leur propre base Postgres.',
  );
}
// Les tests font un reset complet du schéma (voir `prisma db push
// --accept-data-loss` plus bas) — si TEST_DATABASE_URL pointait par erreur
// (mauvais copier-coller dans .env) vers la même base que DATABASE_URL, ça
// écraserait la production à chaque `npm test`.
if (process.env.DATABASE_URL && process.env.DATABASE_URL === process.env.TEST_DATABASE_URL) {
  throw new Error('TEST_DATABASE_URL est identique à DATABASE_URL — vérifiez backend/.env avant de lancer les tests.');
}
process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
process.env.JWT_ACCESS_SECRET = 'test-access-secret';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';
// isOwnBlobUrl (voir imageStorage.ts) dérive le hostname attendu du store à
// partir de ce jeton — le mock `put` ci-dessous doit renvoyer des URLs sur ce
// même hostname pour rester reconnues comme "notre" store en test.
process.env.BLOB_READ_WRITE_TOKEN = 'vercel_blob_rw_teststoreid_testsecret';
// Transcription (Whisper) désactivée par défaut en test — sans ça, un
// OPENAI_API_KEY présent dans le .env local du développeur déclencherait un
// vrai appel réseau payant à chaque run de la suite REX (voir chantiers.test.ts
// pour les tests qui la réactivent explicitement, jeton et fetch mockés).
delete process.env.OPENAI_API_KEY;

// Pas d'appel réseau réel vers Vercel Blob en test — voir imageStorage.ts.
// Un Map en mémoire tient lieu de stockage : `put` y écrit le contenu reçu et
// `fetch` (mocké plus bas) le relit par URL — nécessaire depuis que la fusion
// du PV (voir pvMerge.ts) retélécharge le gabarit déposé via `put` pour le
// fusionner avec la signature côté serveur.
const blobStore = new Map<string, Buffer>();

vi.mock('@vercel/blob', () => ({
  put: vi.fn(async (filename: string, body: Buffer) => {
    const url = `https://teststoreid.public.blob.vercel-storage.com/test/${filename}`;
    blobStore.set(url, Buffer.isBuffer(body) ? body : Buffer.from(body));
    return { url };
  }),
  del: vi.fn(async (url: string) => {
    blobStore.delete(url);
  }),
}));

const realFetch = globalThis.fetch;
vi.stubGlobal('fetch', async (input: RequestInfo | URL, init?: RequestInit) => {
  const url = typeof input === 'string' ? input : input.toString();
  const stored = blobStore.get(url);
  if (stored) return new Response(stored, { status: 200 });
  return realFetch(input, init);
});

execSync('npx prisma db push --skip-generate --accept-data-loss', {
  stdio: 'inherit',
  cwd: __dirname,
  env: process.env,
});

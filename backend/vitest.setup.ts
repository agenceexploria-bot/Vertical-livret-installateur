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
process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
process.env.JWT_ACCESS_SECRET = 'test-access-secret';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';

// Pas d'appel réseau réel vers Vercel Blob en test — voir imageStorage.ts.
// Un Map en mémoire tient lieu de stockage : `put` y écrit le contenu reçu et
// `fetch` (mocké plus bas) le relit par URL — nécessaire depuis que la fusion
// du PV (voir pvMerge.ts) retélécharge le gabarit déposé via `put` pour le
// fusionner avec la signature côté serveur.
const blobStore = new Map<string, Buffer>();

vi.mock('@vercel/blob', () => ({
  put: vi.fn(async (filename: string, body: Buffer) => {
    const url = `https://blob.vercel-storage.com/test/${filename}`;
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

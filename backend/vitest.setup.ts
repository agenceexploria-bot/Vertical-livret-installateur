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
vi.mock('@vercel/blob', () => ({
  put: vi.fn(async (filename: string) => ({ url: `https://blob.vercel-storage.com/test/${filename}` })),
}));

execSync('npx prisma db push --skip-generate --accept-data-loss', {
  stdio: 'inherit',
  cwd: __dirname,
  env: process.env,
});

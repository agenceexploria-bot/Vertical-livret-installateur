import { execSync } from 'child_process';
import path from 'path';
import fs from 'fs';

const testDbPath = path.join(__dirname, 'prisma', 'test.db');
if (fs.existsSync(testDbPath)) fs.unlinkSync(testDbPath);

process.env.DATABASE_URL = `file:${testDbPath}`;
process.env.JWT_ACCESS_SECRET = 'test-access-secret';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';

execSync('npx prisma db push --skip-generate', {
  stdio: 'inherit',
  cwd: __dirname,
  env: process.env,
});

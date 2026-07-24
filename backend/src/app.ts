import express from 'express';
import cors from 'cors';
import { authRouter } from './routes/auth';
import { comptesRouter } from './routes/comptes';
import { chantiersRouter } from './routes/chantiers';
import { adminRouter } from './routes/admin';

export function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  app.use('/auth', authRouter);
  app.use('/comptes', comptesRouter);
  app.use('/chantiers', chantiersRouter);
  app.use('/admin', adminRouter);

  return app;
}

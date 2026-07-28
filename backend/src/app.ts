import express from 'express';
import cors from 'cors';
import { authRouter } from './routes/auth';
import { comptesRouter } from './routes/comptes';
import { chantiersRouter } from './routes/chantiers';
import { adminRouter } from './routes/admin';

// Frontend et backend sont servis sur la même origine en production (voir
// vercel.json) : ce CORS ne sert qu'au dev local (Flutter Web sur un port
// localhost variable) et ne s'applique de toute façon pas à l'app mobile
// (CORS est une restriction imposée par le navigateur, pas par le serveur).
const PROD_ORIGIN = 'https://vertical-livret-installateur.vercel.app';
const isAllowedOrigin = (origin?: string) => !origin || origin === PROD_ORIGIN || /^http:\/\/localhost(:\d+)?$/.test(origin);

export function createApp() {
  const app = express();

  // Nécessaire pour que le rate-limiter (authRateLimit) lise la bonne IP
  // cliente via X-Forwarded-For — l'app tourne toujours derrière le proxy
  // Vercel (prod) ou aucun proxy (dev local), donc un seul niveau de confiance.
  app.set('trust proxy', 1);

  app.use(cors({ origin: (origin, callback) => callback(null, isAllowedOrigin(origin)) }));
  app.use(express.json());

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  app.use('/auth', authRouter);
  app.use('/comptes', comptesRouter);
  app.use('/chantiers', chantiersRouter);
  app.use('/admin', adminRouter);

  return app;
}

import 'express-async-errors';
import express from 'express';
import cors from 'cors';
import { authRouter } from './routes/auth';
import { comptesRouter } from './routes/comptes';
import { chantiersRouter } from './routes/chantiers';
import { adminRouter } from './routes/admin';
import { notificationsRouter } from './routes/notifications';
import { pusherRouter } from './routes/pusherAuth';
import { uploadsRouter } from './routes/uploads';
import { checklistTemplatesRouter } from './routes/checklistTemplates';

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
  // Les fichiers (documents, photos, notes vocales, vidéos) ne transitent
  // plus par cette fonction serverless — voir routes/uploads.ts, qui délivre
  // un jeton pour un dépôt direct de l'app vers Vercel Blob, contournant la
  // limite de 4,5 Mo (non configurable) que Vercel impose au corps des
  // requêtes des fonctions serverless. Seule l'image de la signature du PV
  // (voir POST .../pv/signature) reste en base64 dans le JSON : elle doit
  // être traitée immédiatement côté serveur pour la fusion avec le PDF
  // gabarit, et reste de toute façon minuscule (tracé vectoriel simple).
  app.use(express.json({ limit: '5mb' }));

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  app.use('/auth', authRouter);
  app.use('/comptes', comptesRouter);
  app.use('/chantiers', chantiersRouter);
  app.use('/admin', adminRouter);
  app.use('/notifications', notificationsRouter);
  app.use('/pusher', pusherRouter);
  app.use('/uploads', uploadsRouter);
  app.use('/checklist-templates', checklistTemplatesRouter);

  // Filet de sécurité : la plupart des handlers n'ont pas leur propre
  // try/catch (revue de sécurité) — sans `express-async-errors` (importé en
  // tête de fichier, patch le routeur pour transmettre ici tout rejet de
  // promesse d'un handler async), une exception non interceptée y laisserait
  // la requête sans réponse jusqu'au timeout de la fonction serverless
  // plutôt que de renvoyer une erreur JSON propre.
  app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    console.error('Erreur non interceptée sur une route', err);
    if (res.headersSent) return;
    res.status(500).json({ error: 'Une erreur inattendue est survenue.' });
  });

  return app;
}

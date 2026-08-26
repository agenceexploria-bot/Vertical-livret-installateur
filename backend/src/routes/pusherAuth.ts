import { Router } from 'express';
import { z } from 'zod';
import { requireAuth, AuthedRequest } from '../middleware/auth';
import { authorizeChannel, CHANTIER_CHANGES_CHANNEL, NOTIFICATIONS_CHANNEL } from '../lib/pusher';

export const pusherRouter = Router();

const authSchema = z.object({
  socket_id: z.string().min(1),
  channel_name: z.string().min(1),
});

// Autorisation d'abonnement aux channels privés Pusher — appelée par le
// client (voir RealtimeService.onAuthorizer côté Flutter) à chaque tentative
// de souscription, jamais par Pusher lui-même. `private-app-events`
// (changements de chantier) est ouvert à tout utilisateur authentifié :
// même un installateur doit être notifié des changements sur SES chantiers.
// `private-notifications` (alertes internes) reste réservé à CT/Admin, pour
// rester cohérent avec la restriction déjà en place sur GET /notifications.
pusherRouter.post('/auth', requireAuth, (req: AuthedRequest, res) => {
  const parsed = authSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const { socket_id, channel_name } = parsed.data;

  const isCT = req.auth!.role === 'coordinateurTravaux' || req.auth!.role === 'admin';
  const allowedChannels = isCT ? [CHANTIER_CHANGES_CHANNEL, NOTIFICATIONS_CHANNEL] : [CHANTIER_CHANGES_CHANNEL];
  if (!allowedChannels.includes(channel_name)) {
    return res.status(403).json({ error: 'Accès refusé à ce canal' });
  }

  const authResponse = authorizeChannel(socket_id, channel_name);
  if (!authResponse) return res.status(503).json({ error: 'Temps réel non configuré' });

  res.json(authResponse);
});

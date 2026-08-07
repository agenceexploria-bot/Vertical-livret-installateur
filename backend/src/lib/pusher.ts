import Pusher from 'pusher';

const REQUIRED_VARS = ['PUSHER_APP_ID', 'PUSHER_KEY', 'PUSHER_SECRET', 'PUSHER_CLUSTER'] as const;
const missingVars = REQUIRED_VARS.filter((key) => !process.env[key]);

// Le temps réel est une amélioration, pas une dépendance dure : tant que le
// compte Pusher n'est pas configuré (variables absentes), l'app continue de
// fonctionner normalement — simplement sans diffusion instantanée aux autres
// clients connectés (voir triggerChantierChanged/triggerNotificationCreated).
const pusher = missingVars.length === 0
  ? new Pusher({
      appId: process.env.PUSHER_APP_ID!,
      key: process.env.PUSHER_KEY!,
      secret: process.env.PUSHER_SECRET!,
      cluster: process.env.PUSHER_CLUSTER!,
      useTLS: true,
    })
  : null;

if (!pusher) {
  console.warn(`Pusher non configuré (variables manquantes : ${missingVars.join(', ')}) — diffusion temps réel désactivée.`);
}

// Deux channels privés (voir routes/pusherAuth.ts pour l'autorisation) —
// séparés selon qui a le droit de recevoir quoi, pas par commodité technique :
// CHANTIER_CHANGES concerne tout utilisateur authentifié (un installateur doit
// être notifié des changements sur SES chantiers), alors que NOTIFICATIONS
// (alertes internes type "auto-contrôle à 80%") reste réservé à CA/Admin,
// comme l'impose déjà GET /notifications côté REST — avant cette séparation,
// tout transitait sur un unique channel public, ce qui exposait le contenu
// des notifications internes à quiconque récupérait la clé Pusher publique
// (embarquée côté client), sans même avoir de compte Vertical.
export const CHANTIER_CHANGES_CHANNEL = 'private-app-events';
export const NOTIFICATIONS_CHANNEL = 'private-notifications';

async function trigger(channel: string, event: string, data: unknown): Promise<void> {
  if (!pusher) return;
  try {
    await pusher.trigger(channel, event, data);
  } catch (err) {
    // Une diffusion ratée ne doit jamais faire échouer la mutation elle-même.
    console.error('Échec de diffusion Pusher', err);
  }
}

// Signale qu'un chantier a été créé/modifié — le client réagit en refetchant
// ce seul chantier (voir ChantierState.handleRealtimeChange côté Flutter),
// plutôt que de transmettre l'objet complet (taille imprévisible, risque de
// dépasser la limite de payload Pusher sur les chantiers avec beaucoup de
// documents/points).
export function triggerChantierChanged(reference: string): Promise<void> {
  return trigger(CHANTIER_CHANGES_CHANNEL, 'chantier-changed', { reference });
}

export function triggerChantierDeleted(reference: string): Promise<void> {
  return trigger(CHANTIER_CHANGES_CHANNEL, 'chantier-deleted', { reference });
}

export function triggerNotificationCreated(notification: unknown): Promise<void> {
  return trigger(NOTIFICATIONS_CHANNEL, 'notification-created', { notification });
}

// Signature d'autorisation d'abonnement à un channel privé — voir
// routes/pusherAuth.ts, qui décide QUELS channels un rôle donné peut demander
// avant même d'appeler cette fonction (elle ne fait que signer, aucun
// contrôle d'accès ici). `null` si Pusher n'est pas configuré (pas de secret
// disponible pour signer).
export function authorizeChannel(socketId: string, channel: string): Pusher.ChannelAuthResponse | null {
  if (!pusher) return null;
  return pusher.authorizeChannel(socketId, channel);
}

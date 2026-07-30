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

// Un seul channel public pour toute l'app : plus simple qu'un channel par
// chantier, et suffisant vu le volume (petite équipe, pas de contrainte de
// confidentialité entre chantiers côté CA/Admin qui les voient tous).
export const APP_CHANNEL = 'app-events';

async function trigger(event: string, data: unknown): Promise<void> {
  if (!pusher) return;
  try {
    await pusher.trigger(APP_CHANNEL, event, data);
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
  return trigger('chantier-changed', { reference });
}

export function triggerChantierDeleted(reference: string): Promise<void> {
  return trigger('chantier-deleted', { reference });
}

export function triggerNotificationCreated(notification: unknown): Promise<void> {
  return trigger('notification-created', { notification });
}

import { Router } from 'express';
import { handleUpload, type HandleUploadBody } from '@vercel/blob/client';
import { verifyAccessToken } from '../auth/tokens';
import { AuthedRequest } from '../middleware/auth';

export const uploadsRouter = Router();

// Seule protection appliquée aux kinds en liste noire (voir
// documentChantier/documentTerrain ci-dessous) : le reste du fichier — type,
// taille, rôle — est décidé par KIND_CONFIG comme pour les autres kinds.
// Vérifiée sur l'extension du pathname (voir onBeforeGenerateToken), qui est
// tout ce qu'on connaît côté serveur avant l'upload effectif.
const DANGEROUS_EXTENSIONS = ['exe', 'bat', 'sh', 'msi'];

// Types, tailles ET rôles autorisés par nature de pièce jointe — décidés
// côté serveur uniquement (jamais à partir de ce que le client déclare, à
// part le choix du `kind` lui-même), pour qu'un client ne puisse pas
// s'accorder un type de fichier, une taille ou un jeton non prévus en
// trafiquant sa requête. `allowedRoles: undefined` = tout utilisateur
// authentifié (cas des pièces jointes "libre-service" : avatar,
// habilitation, ou déposées par l'installateur lui-même sur le terrain) ;
// pvDocument/documentChantier sont réservés au même périmètre que leurs
// routes d'attachement (voir routes/chantiers.ts).
const KIND_CONFIG: Record<string, { allowedContentTypes?: string[]; maximumSizeInBytes: number; allowedRoles?: string[] }> = {
  avatar: { allowedContentTypes: ['image/jpeg', 'image/png'], maximumSizeInBytes: 10 * 1024 * 1024 },
  habilitation: { allowedContentTypes: ['application/pdf', 'image/jpeg', 'image/png'], maximumSizeInBytes: 25 * 1024 * 1024 },
  pointPhoto: { allowedContentTypes: ['image/jpeg', 'image/png'], maximumSizeInBytes: 25 * 1024 * 1024 },
  // audio/webm : Web (MediaRecorder du navigateur) ; audio/ogg : Android
  // (encodeur Opus natif, conteneur OGG — voir record_android, jamais du
  // webm malgré l'ancien nom de fichier) ; audio/mp4 : iOS le cas échéant
  // (Opus dans un conteneur M4A côté AVFoundation).
  rexAudio: { allowedContentTypes: ['audio/webm', 'audio/ogg', 'audio/mp4'], maximumSizeInBytes: 50 * 1024 * 1024 },
  // allowedContentTypes OMIS (clé absente) = n'importe quel Content-Type
  // (documents terrain/chantier peuvent être des photos, vidéos, fichiers
  // bureautique, archives, plans CAO...). ANCIEN BUG : ce kind portait
  // `allowedContentTypes: ['*']` — mais côté @vercel/blob, ce tableau
  // n'accepte que des types MIME exacts ou des wildcards type/sous-type
  // (ex. 'image/*') ; un simple '*' n'est PAS un glob reconnu et est
  // comparé littéralement au Content-Type réel de chaque fichier, donc TOUT
  // était rejeté (ex. "pdf is not allowed" pour un vrai PDF) — la faille de
  // sécurité qu'on croyait ouvrir avec `['*']` n'a donc jamais laissé
  // passer le moindre fichier. Omettre la clé est la façon documentée de ne
  // poser aucune restriction de type ; seuls les exécutables dangereux
  // restent bloqués via DANGEROUS_EXTENSIONS ci-dessus — liste noire plutôt
  // que blanche, contrairement aux autres kinds de ce fichier qui restent
  // volontairement restreints (avatar, photo de contrôle, gabarit PV
  // officiel...).
  documentTerrain: {
    maximumSizeInBytes: 500 * 1024 * 1024,
  },
  pvDocument: {
    allowedContentTypes: ['application/pdf'],
    maximumSizeInBytes: 25 * 1024 * 1024,
    allowedRoles: ['coordinateurTravaux', 'direction', 'admin'],
  },
  documentChantier: {
    maximumSizeInBytes: 500 * 1024 * 1024,
    allowedRoles: ['coordinateurTravaux', 'direction', 'admin'],
  },
};

// Génère un jeton d'upload direct app -> Vercel Blob : le fichier ne
// transite plus jamais par cette fonction serverless, ce qui contourne la
// limite (4,5 Mo, non configurable) que Vercel impose au corps des requêtes
// de ses fonctions — voir https://vercel.com/docs/functions/limitations.
// L'app envoie d'abord {type: 'blob.generate-client-token', payload} pour
// obtenir un jeton, dépose ensuite le fichier directement sur Vercel Blob
// avec ce jeton, puis crée/rattache la ressource via l'API normale
// (POST/PATCH existants) avec l'URL obtenue.
//
// L'authentification n'est vérifiée que pour cet évènement
// (blob.generate-client-token) : l'autre évènement possible,
// blob.upload-completed, est un webhook appelé par Vercel lui-même (jamais
// par l'app) une fois l'upload terminé — il est déjà protégé par la
// vérification de signature HMAC faite en interne par handleUpload.
uploadsRouter.post('/token', async (req: AuthedRequest, res) => {
  const body = req.body as HandleUploadBody;
  let role: string | undefined;

  if (body.type === 'blob.generate-client-token') {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Authentification requise' });
    }
    try {
      role = verifyAccessToken(header.slice('Bearer '.length)).role;
    } catch {
      return res.status(401).json({ error: 'Session invalide ou expirée' });
    }
  }

  try {
    const jsonResponse = await handleUpload({
      body,
      request: req,
      onBeforeGenerateToken: async (pathname, clientPayload) => {
        const { kind } = JSON.parse(clientPayload ?? '{}') as { kind?: string };
        const config = kind ? KIND_CONFIG[kind] : undefined;
        if (!config) throw new Error('Type de pièce jointe inconnu');
        if (config.allowedRoles && !config.allowedRoles.includes(role ?? '')) {
          throw new Error('Rôle non autorisé pour ce type de pièce jointe');
        }
        const extension = pathname.split('.').pop()?.toLowerCase();
        if (extension && DANGEROUS_EXTENSIONS.includes(extension)) {
          throw new Error('Ce type de fichier n\'est pas autorisé pour des raisons de sécurité');
        }
        return {
          ...(config.allowedContentTypes ? { allowedContentTypes: config.allowedContentTypes } : {}),
          maximumSizeInBytes: config.maximumSizeInBytes,
          addRandomSuffix: true,
        };
      },
      onUploadCompleted: async () => {
        // Rien à faire : le client crée/rattache la ressource via l'API
        // normale juste après l'upload direct — ce webhook n'est
        // qu'informatif et n'est de toute façon pas joignable en local.
      },
    });
    res.json(jsonResponse);
  } catch (error) {
    res.status(400).json({ error: (error as Error).message });
  }
});

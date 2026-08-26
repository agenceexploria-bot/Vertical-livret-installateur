import { Router } from 'express';
import { handleUpload, type HandleUploadBody } from '@vercel/blob/client';
import { verifyAccessToken } from '../auth/tokens';
import { AuthedRequest } from '../middleware/auth';

export const uploadsRouter = Router();

// Types, tailles ET rôles autorisés par nature de pièce jointe — décidés
// côté serveur uniquement (jamais à partir de ce que le client déclare, à
// part le choix du `kind` lui-même), pour qu'un client ne puisse pas
// s'accorder un type de fichier, une taille ou un jeton non prévus en
// trafiquant sa requête. `allowedRoles: undefined` = tout utilisateur
// authentifié (cas des pièces jointes "libre-service" : avatar,
// habilitation, ou déposées par l'installateur lui-même sur le terrain) ;
// pvDocument/documentChantier sont réservés au même périmètre que leurs
// routes d'attachement (voir routes/chantiers.ts).
const KIND_CONFIG: Record<string, { allowedContentTypes: string[]; maximumSizeInBytes: number; allowedRoles?: string[] }> = {
  avatar: { allowedContentTypes: ['image/jpeg', 'image/png'], maximumSizeInBytes: 10 * 1024 * 1024 },
  habilitation: { allowedContentTypes: ['application/pdf', 'image/jpeg', 'image/png'], maximumSizeInBytes: 25 * 1024 * 1024 },
  pointPhoto: { allowedContentTypes: ['image/jpeg', 'image/png'], maximumSizeInBytes: 25 * 1024 * 1024 },
  rexAudio: { allowedContentTypes: ['audio/webm'], maximumSizeInBytes: 50 * 1024 * 1024 },
  documentTerrain: {
    allowedContentTypes: ['application/pdf', 'image/jpeg', 'image/png', 'video/mp4', 'video/webm'],
    maximumSizeInBytes: 100 * 1024 * 1024,
  },
  pvDocument: {
    allowedContentTypes: ['application/pdf'],
    maximumSizeInBytes: 25 * 1024 * 1024,
    allowedRoles: ['coordinateurTravaux', 'direction', 'admin'],
  },
  documentChantier: {
    allowedContentTypes: ['application/pdf', 'image/jpeg', 'image/png', 'video/mp4', 'video/webm'],
    maximumSizeInBytes: 100 * 1024 * 1024,
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
      onBeforeGenerateToken: async (_pathname, clientPayload) => {
        const { kind } = JSON.parse(clientPayload ?? '{}') as { kind?: string };
        const config = kind ? KIND_CONFIG[kind] : undefined;
        if (!config) throw new Error('Type de pièce jointe inconnu');
        if (config.allowedRoles && !config.allowedRoles.includes(role ?? '')) {
          throw new Error('Rôle non autorisé pour ce type de pièce jointe');
        }
        return {
          allowedContentTypes: config.allowedContentTypes,
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

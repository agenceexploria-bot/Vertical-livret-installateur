import { Router } from 'express';
import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import { z } from 'zod';
import { requireAuth, AuthedRequest } from '../middleware/auth';
import { transcribeBytes } from '../lib/transcription';

export const transcribeSegmentRouter = Router();

// Transcription EN DIRECT d'un court segment audio (~5s) pendant
// l'enregistrement d'un REX (voir lib/core/voice_recorder.dart,
// WebRecordingSession) — appelée plusieurs fois par minute et par
// utilisateur, contrairement à transcribeAudio (une fois par REX envoyé).
// Rate-limit défensif : 1 requête / 3s / utilisateur — protection partielle
// seulement en environnement serverless (état en mémoire non partagé entre
// invocations froides, voir authRateLimit dans routes/auth.ts). keyGenerator
// suppose que requireAuth (qui remplit req.auth) tourne AVANT ce middleware.
const segmentRateLimit = rateLimit({
  windowMs: 3_000,
  limit: 1,
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => process.env.NODE_ENV === 'test',
  // ipKeyGenerator (et non req.ip brut) : express-rate-limit l'exige pour
  // normaliser une adresse IPv6 (sinon plusieurs représentations de la même
  // adresse contourneraient la limite) — sans ce garde-fou explicite, la
  // construction du limiteur lève une ValidationError (ERR_ERL_KEY_GEN_IPV6)
  // au premier chargement du module, avant même la première requête.
  keyGenerator: (req: AuthedRequest) => req.auth?.userId ?? ipKeyGenerator(req.ip ?? '0.0.0.0'),
});

const segmentSchema = z.object({ audio: z.string() });

// Même format que celui utilisé côté client pour tout dépôt de fichier (voir
// ApiClient.uploadFile) — mais ici le segment est bien trop petit (~5-20 Ko)
// pour justifier un aller-retour par Vercel Blob : il est envoyé tel quel
// dans le corps JSON (limite globale 5 Mo, voir app.ts).
const DATA_URL_PATTERN = /^data:([\w-]+\/[\w.+-]+);base64,(.+)$/;

/// Contrairement à /chantiers/:reference/rex, cette route ne touche aucune
/// donnée de chantier — un simple passe-plat vers Whisper protégé par
/// requireAuth (n'importe quel compte authentifié), sans rattachement à
/// vérifier.
transcribeSegmentRouter.post('/', requireAuth, segmentRateLimit, async (req: AuthedRequest, res) => {
  const parsed = segmentSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const match = DATA_URL_PATTERN.exec(parsed.data.audio);
  if (!match) return res.status(400).json({ error: 'Segment audio invalide' });

  const mimeType = match[1];
  const extension = mimeType.split('/').pop() ?? 'webm';
  const audioBuffer = Buffer.from(match[2], 'base64');

  const text = await transcribeBytes(audioBuffer, mimeType, extension);
  res.json({ text });
});

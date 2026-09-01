/// Transcription automatique des notes vocales REX via l'API Whisper
/// d'OpenAI. La reconnaissance vocale en direct côté app (speech_to_text,
/// voir rex_screen.dart) est best-effort — réseau, navigateur/OS — et reste
/// vide si elle échoue ; ceci est le filet de sécurité qui tourne côté
/// serveur sur l'audio déjà déposé, indépendamment de ce que le client a pu
/// capter en direct. Nécessite OPENAI_API_KEY (voir .env.example) ; sans
/// cette variable, la fonction ne fait rien et la note vocale reste sans
/// transcription, comme avant.
const OPENAI_TRANSCRIPTION_URL = 'https://api.openai.com/v1/audio/transcriptions';

// Whisper refuse tout fichier de plus de 25 Mo — inutile de tenter l'appel
// au-delà (les notes vocales REX sont plafonnées à 50 Mo côté upload, voir
// KIND_CONFIG.rexAudio dans routes/uploads.ts).
const MAX_TRANSCRIBABLE_BYTES = 25 * 1024 * 1024;

// Le conteneur réel dépend de la plateforme qui a enregistré la note vocale
// (voir lib/core/voice_recorder.dart) : webm/opus sur le Web, ogg/opus sur
// Android — jamais forcément webm. Whisper se base sur l'extension du nom de
// fichier fourni pour choisir son démuxeur ; un mauvais type ici peut faire
// échouer ou dégrader la transcription (voir KIND_CONFIG.rexAudio).
const EXTENSION_TO_MIME: Record<string, string> = {
  webm: 'audio/webm',
  ogg: 'audio/ogg',
  m4a: 'audio/mp4',
  mp4: 'audio/mp4',
};

export async function transcribeAudio(audioUrl: string): Promise<string | null> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    console.log('transcribeAudio: OPENAI_API_KEY absent, transcription désactivée');
    return null;
  }

  try {
    const audioResponse = await fetch(audioUrl);
    if (!audioResponse.ok) {
      console.log(`transcribeAudio: téléchargement de l'audio échoué — HTTP ${audioResponse.status} sur ${audioUrl}`);
      return null;
    }
    const audioBuffer = Buffer.from(await audioResponse.arrayBuffer());
    console.log(`transcribeAudio: audio téléchargé — ${audioBuffer.byteLength} octets depuis ${audioUrl}`);
    if (audioBuffer.byteLength === 0) {
      console.log('transcribeAudio: fichier audio vide (0 octet) — capture côté client probablement en cause');
      return null;
    }
    if (audioBuffer.byteLength > MAX_TRANSCRIBABLE_BYTES) {
      console.log(`transcribeAudio: fichier trop volumineux pour Whisper (${audioBuffer.byteLength} > ${MAX_TRANSCRIBABLE_BYTES})`);
      return null;
    }

    const extension = new URL(audioUrl).pathname.split('.').pop()?.toLowerCase() ?? 'webm';
    const mimeType = EXTENSION_TO_MIME[extension] ?? 'audio/webm';
    console.log(`transcribeAudio: extension=${extension} mimeType envoyé à Whisper=${mimeType}`);

    const form = new FormData();
    form.append('file', new Blob([audioBuffer], { type: mimeType }), `rex.${extension}`);
    form.append('model', 'whisper-1');
    // Sans ce paramètre, Whisper détecte la langue automatiquement et peut se
    // tromper (notamment sur un audio court ou bruité) — le REX est toujours
    // en français, donc jamais utile de laisser la détection deviner.
    form.append('language', 'fr');

    // Le REX est déjà enregistré avant cet appel (voir routes/chantiers.ts),
    // mais celui-ci reste dans le chemin de la requête HTTP — un délai trop
    // généreux risquerait de dépasser le temps d'exécution maximum d'une
    // fonction serverless Vercel (10 s par défaut sur le plan Hobby).
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8_000);
    let response: Response;
    try {
      response = await fetch(OPENAI_TRANSCRIPTION_URL, {
        method: 'POST',
        headers: { Authorization: `Bearer ${apiKey}` },
        body: form,
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeout);
    }
    if (!response.ok) {
      // Jamais avalé sans trace : un fichier au mauvais format, un
      // Content-Type rejeté ou une clé invalide donnent chacun un message
      // différent dans le corps — impossible à diagnostiquer sans lui.
      const body = await response.text().catch(() => '<corps illisible>');
      console.log(`transcribeAudio: Whisper a refusé la requête — HTTP ${response.status} — ${body}`);
      return null;
    }

    const data = (await response.json()) as { text?: string };
    const text = data.text?.trim();
    console.log(`transcribeAudio: réponse Whisper reçue — ${text ? `${text.length} caractères` : 'texte vide'}`);
    return text && text.length > 0 ? text : null;
  } catch (error) {
    // Réseau indisponible, clé invalide... — jamais bloquant pour la
    // création du REX, qui reste possible avec l'audio seul (voir
    // routes/chantiers.ts). L'abandon du contrôleur ci-dessus (dépassement
    // des 8 s) atterrit aussi ici, sous la forme d'une AbortError — distingué
    // du reste pour ne pas le confondre avec un vrai échec réseau/API.
    const isTimeout = error instanceof Error && error.name === 'AbortError';
    console.log(`transcribeAudio: échec — ${isTimeout ? 'délai de 8s dépassé (timeout)' : String(error)}`);
    return null;
  }
}

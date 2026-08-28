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

export async function transcribeAudio(audioUrl: string): Promise<string | null> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return null;

  try {
    const audioResponse = await fetch(audioUrl);
    if (!audioResponse.ok) return null;
    const audioBuffer = Buffer.from(await audioResponse.arrayBuffer());
    if (audioBuffer.byteLength === 0 || audioBuffer.byteLength > MAX_TRANSCRIBABLE_BYTES) return null;

    const form = new FormData();
    form.append('file', new Blob([audioBuffer], { type: 'audio/webm' }), 'rex.webm');
    form.append('model', 'whisper-1');
    form.append('language', 'fr');

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20_000);
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
    if (!response.ok) return null;

    const data = (await response.json()) as { text?: string };
    const text = data.text?.trim();
    return text && text.length > 0 ? text : null;
  } catch {
    // Réseau indisponible, timeout, clé invalide... — jamais bloquant pour la
    // création du REX, qui reste possible avec l'audio seul (voir
    // routes/chantiers.ts).
    return null;
  }
}

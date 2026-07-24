import { put } from '@vercel/blob';

const EXTENSION_BY_MIME: Record<string, string> = {
  'application/pdf': 'pdf',
};

/// Décode un fichier encodé en data URL base64 (ex. "data:image/jpeg;base64,...",
/// "data:application/pdf;base64,...", "data:audio/webm;base64,...") et le
/// dépose sur Vercel Blob (le système de fichiers des functions serverless est
/// en lecture seule, pas de stockage disque possible). Retourne l'URL publique
/// complète du fichier.
export async function saveBase64File(dataUrl: string, prefix: string): Promise<string> {
  const match = dataUrl.match(/^data:([\w-]+)\/([\w.+-]+);base64,(.+)$/);
  const mime = match ? `${match[1]}/${match[2]}` : '';
  const extension = EXTENSION_BY_MIME[mime] ?? (match ? match[2] : 'bin');
  const base64 = match ? match[3] : dataUrl;
  const filename = `${prefix}-${Date.now()}-${Math.round(Math.random() * 1e6)}.${extension}`;
  const blob = await put(filename, Buffer.from(base64, 'base64'), {
    access: 'public',
    contentType: mime || undefined,
  });
  return blob.url;
}

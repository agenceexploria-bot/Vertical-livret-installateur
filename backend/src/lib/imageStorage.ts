import { put, del } from '@vercel/blob';

const EXTENSION_BY_MIME: Record<string, string> = {
  'application/pdf': 'pdf',
};

/// Types de fichiers réellement produits par l'app (photos JPEG, certificats/
/// documents PDF, signatures PNG, notes vocales webm) — toute autre valeur
/// déclarée dans le data URL est refusée avant stockage, pour empêcher le
/// dépôt d'un fichier HTML/SVG malveillant servi ensuite publiquement avec
/// son content-type d'origine.
const ALLOWED_MIME_TYPES = new Set(['application/pdf', 'image/jpeg', 'image/png', 'audio/webm']);

export function isAllowedFileDataUrl(dataUrl: string): boolean {
  const match = dataUrl.match(/^data:([\w-]+\/[\w.+-]+);base64,/);
  return !!match && ALLOWED_MIME_TYPES.has(match[1]);
}

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
  return saveBuffer(Buffer.from(base64, 'base64'), prefix, mime, extension);
}

/// Dépose un buffer déjà décodé sur Vercel Blob — utilisé pour les fichiers
/// produits côté serveur (ex. le PDF du PV fusionné avec la signature, voir
/// pvMerge.ts) plutôt que reçus tels quels en base64 depuis l'app.
export async function saveBuffer(buffer: Buffer, prefix: string, mime: string, extension?: string): Promise<string> {
  const resolvedExtension = extension ?? EXTENSION_BY_MIME[mime] ?? mime.split('/')[1] ?? 'bin';
  const filename = `${prefix}-${Date.now()}-${Math.round(Math.random() * 1e6)}.${resolvedExtension}`;
  const blob = await put(filename, buffer, {
    access: 'public',
    contentType: mime || undefined,
  });
  return blob.url;
}

/// Supprime un fichier de Vercel Blob par son URL publique — utilisé quand un
/// document est supprimé ou remplacé, pour ne pas laisser de fichiers
/// orphelins facturés indéfiniment. Silencieux si le fichier n'existe déjà
/// plus (ex. suppression relancée après un échec réseau partiel).
export async function deleteBlobFile(url: string): Promise<void> {
  try {
    await del(url);
  } catch {
    // Déjà supprimé ou URL invalide : pas bloquant pour l'action en cours.
  }
}

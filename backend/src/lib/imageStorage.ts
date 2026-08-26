import { put, del } from '@vercel/blob';

const EXTENSION_BY_MIME: Record<string, string> = {
  'application/pdf': 'pdf',
};

/// Vérifie qu'une URL de fichier fournie par le client (après un upload
/// direct vers Vercel Blob, voir routes/uploads.ts) pointe bien vers notre
/// propre store Blob — sans ce contrôle, un client pourrait fournir
/// n'importe quelle URL arbitraire et la faire enregistrer comme si elle
/// avait été légitimement déposée.
export function isOwnBlobUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:' && parsed.hostname.endsWith('vercel-storage.com');
  } catch {
    return false;
  }
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

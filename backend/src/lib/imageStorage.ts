import fs from 'fs/promises';
import path from 'path';

const UPLOADS_DIR = path.join(__dirname, '..', '..', 'uploads');

const EXTENSION_BY_MIME: Record<string, string> = {
  'application/pdf': 'pdf',
};

/// Décode un fichier encodé en data URL base64 (ex. "data:image/jpeg;base64,...",
/// "data:application/pdf;base64,...", "data:audio/webm;base64,...") et l'écrit
/// dans le dossier uploads. Retourne le chemin public ("/uploads/...").
export async function saveBase64File(dataUrl: string, prefix: string): Promise<string> {
  const match = dataUrl.match(/^data:([\w-]+)\/([\w.+-]+);base64,(.+)$/);
  const mime = match ? `${match[1]}/${match[2]}` : '';
  const extension = EXTENSION_BY_MIME[mime] ?? (match ? match[2] : 'bin');
  const base64 = match ? match[3] : dataUrl;
  const filename = `${prefix}-${Date.now()}-${Math.round(Math.random() * 1e6)}.${extension}`;
  await fs.writeFile(path.join(UPLOADS_DIR, filename), Buffer.from(base64, 'base64'));
  return `/uploads/${filename}`;
}

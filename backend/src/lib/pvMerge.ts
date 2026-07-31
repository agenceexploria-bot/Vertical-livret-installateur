import { PDFDocument } from 'pdf-lib';
import { PvTemplateConfig } from './pvTemplateConfig';

/// Télécharge un fichier déjà déposé sur Vercel Blob (le gabarit PV, dont
/// seule l'URL publique est conservée en base) pour pouvoir le manipuler
/// côté serveur.
export async function fetchBlobFile(url: string): Promise<Buffer> {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Téléchargement du fichier distant échoué (HTTP ${response.status})`);
  return Buffer.from(await response.arrayBuffer());
}

/// Superpose l'image de la signature sur le PDF gabarit, aux coordonnées
/// fixes de [PvTemplateConfig] — via pdf-lib, qui édite le PDF existant en
/// place (ajoute un calque image) sans jamais rasteriser son contenu :
/// texte, vecteurs et mise en page du gabarit original restent strictement
/// intacts, contrairement à l'ancienne fusion côté app qui re-rendait
/// chaque page en image avant de reconstruire un nouveau PDF.
export async function fusionnerSignatureDansPdf(gabaritBytes: Buffer, signaturePngBytes: Buffer): Promise<Buffer> {
  const pdfDoc = await PDFDocument.load(gabaritBytes);
  const pages = pdfDoc.getPages();
  if (pages.length === 0) throw new Error('Le PDF gabarit ne contient aucune page');

  const targetIndex = Math.min(
    Math.max((PvTemplateConfig.signaturePageNumber ?? pages.length) - 1, 0),
    pages.length - 1,
  );
  const page = pages[targetIndex];
  const signatureImage = await pdfDoc.embedPng(signaturePngBytes);

  page.drawImage(signatureImage, {
    x: PvTemplateConfig.signatureX,
    y: PvTemplateConfig.signatureY,
    width: PvTemplateConfig.signatureWidth,
    height: PvTemplateConfig.signatureHeight,
  });

  return Buffer.from(await pdfDoc.save());
}

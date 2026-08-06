import { PDFDocument } from 'pdf-lib';

/// Emplacement de la signature sur le PDF gabarit, calculé côté app à partir
/// de la position réelle du tracé du client sur le document affiché (voir
/// lib/screens/client/signature_screen.dart) — il n'y a plus de zone de
/// signature à coordonnées fixes, le client signe directement sur le PDF.
///
/// Unité : points PDF (1 point = 1/72 pouce ; une page A4 fait 595 x 842 pts),
/// mesurés depuis le coin BAS-GAUCHE de la page — convention standard PDF
/// (pdf-lib utilise la même convention pour Page.drawImage).
export interface SignaturePlacement {
  /// Page où insérer la signature (1 = première page).
  pageNumber: number;
  x: number;
  y: number;
  width: number;
  height: number;
}

/// Télécharge un fichier déjà déposé sur Vercel Blob (le gabarit PV, dont
/// seule l'URL publique est conservée en base) pour pouvoir le manipuler
/// côté serveur.
export async function fetchBlobFile(url: string): Promise<Buffer> {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Téléchargement du fichier distant échoué (HTTP ${response.status})`);
  return Buffer.from(await response.arrayBuffer());
}

/// Superpose l'image de la signature sur le PDF gabarit, à l'emplacement
/// dynamique [placement] — via pdf-lib, qui édite le PDF existant en place
/// (ajoute un calque image) sans jamais rasteriser son contenu : texte,
/// vecteurs et mise en page du gabarit original restent strictement intacts,
/// contrairement à l'ancienne fusion côté app qui re-rendait chaque page en
/// image avant de reconstruire un nouveau PDF.
export async function fusionnerSignatureDansPdf(
  gabaritBytes: Buffer,
  signaturePngBytes: Buffer,
  placement: SignaturePlacement,
): Promise<Buffer> {
  const pdfDoc = await PDFDocument.load(gabaritBytes);
  const pages = pdfDoc.getPages();
  if (pages.length === 0) throw new Error('Le PDF gabarit ne contient aucune page');

  const targetIndex = Math.min(Math.max(placement.pageNumber - 1, 0), pages.length - 1);
  const page = pages[targetIndex];
  const signatureImage = await pdfDoc.embedPng(signaturePngBytes);

  page.drawImage(signatureImage, {
    x: placement.x,
    y: placement.y,
    width: placement.width,
    height: placement.height,
  });

  return Buffer.from(await pdfDoc.save());
}

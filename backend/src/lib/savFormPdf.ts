import { PDFDocument, StandardFonts } from 'pdf-lib';
import { VERTICAL_LOGO_PNG_BASE64 } from './verticalLogoPng';
import { PdfWriter, identiteRow, ENCRE, ACIER, MARGIN, CONTENT_WIDTH } from './pdfWriter';

/// Contrairement au PV de réception (checklist du gabarit officiel), le PV
/// SAV n'a pas de structure prédéfinie à respecter — texte libre décrivant
/// l'intervention réalisée, comme sur un rapport d'intervention papier.
const SAV_MENTIONS_LEGALES = [
  "En signant ce document, le client reconnaît que l'intervention décrite ci-dessus a bien été réalisée par l'installateur mentionné.",
  "Ce document ne remplace pas l'entretien périodique obligatoire de l'installation, à la charge du client conformément à la notice du fabricant.",
];

export interface SavFormChantierIdentite {
  reference: string;
  client: string;
  adresse: string;
  referenceAffaire: string;
  parentReference: string;
}

export async function genererPdfSavFormulaire(params: {
  chantier: SavFormChantierIdentite;
  descriptionIntervention: string;
  piecesRemplacees?: string | null;
  savDate: Date;
  nomSignataire: string;
  fonctionSignataire: string;
  signaturePngBytes: Buffer;
  // Chaque élément est une image déjà décodée (PNG ou JPEG) — voir
  // routes/chantiers.ts, qui télécharge les blobs avant d'appeler cette
  // fonction (pdf-lib a besoin des octets, pas d'une URL).
  photos: { bytes: Buffer; isPng: boolean }[];
}): Promise<Buffer> {
  const { chantier, descriptionIntervention, piecesRemplacees, savDate, nomSignataire, fonctionSignataire, signaturePngBytes, photos } = params;

  const doc = await PDFDocument.create();
  const fontRegular = await doc.embedFont(StandardFonts.Helvetica);
  const fontBold = await doc.embedFont(StandardFonts.HelveticaBold);
  const logo = await doc.embedPng(Buffer.from(VERTICAL_LOGO_PNG_BASE64, 'base64'));
  const signature = await doc.embedPng(signaturePngBytes);

  const w = new PdfWriter(doc, fontRegular, fontBold);

  // -- En-tête : logo + titre --
  const logoWidth = 130;
  const logoHeight = (logo.height / logo.width) * logoWidth;
  w.page.drawImage(logo, { x: MARGIN, y: w.y - logoHeight, width: logoWidth, height: logoHeight });
  w.page.drawText('Procès-verbal d\'intervention SAV', {
    x: MARGIN + logoWidth + 20,
    y: w.y - logoHeight / 2 - 6,
    size: 15,
    font: fontBold,
    color: ENCRE,
  });
  w.page.drawText(`Intervention ${chantier.reference}`, {
    x: MARGIN + logoWidth + 20,
    y: w.y - logoHeight / 2 - 24,
    size: 10,
    font: fontRegular,
    color: ACIER,
  });
  w.y -= logoHeight + 14;
  w.line();

  // -- Identité --
  identiteRow(w, 'CHANTIER D\'ORIGINE', chantier.parentReference);
  identiteRow(w, 'CLIENT', chantier.client);
  identiteRow(w, 'ADRESSE', chantier.adresse);
  identiteRow(w, 'AFFAIRE N°', chantier.referenceAffaire);
  identiteRow(w, 'DATE D\'INTERVENTION', new Intl.DateTimeFormat('fr-FR', { dateStyle: 'long', timeZone: 'UTC' }).format(savDate));
  w.spacer(4);

  // -- Description --
  w.sectionTitle('Description de l\'intervention');
  w.wrapped(descriptionIntervention.trim() || '—', { size: 9.5 });

  w.sectionTitle('Pièces remplacées');
  w.wrapped(piecesRemplacees?.trim() || 'Aucune.', { size: 9.5 });

  // -- Photos --
  if (photos.length > 0) {
    w.sectionTitle('Photos');
    for (const photo of photos) {
      const image = photo.isPng ? await doc.embedPng(photo.bytes) : await doc.embedJpg(photo.bytes);
      const maxWidth = CONTENT_WIDTH;
      const maxHeight = 260;
      const scale = Math.min(maxWidth / image.width, maxHeight / image.height, 1);
      const width = image.width * scale;
      const height = image.height * scale;
      w.ensureSpace(height + 10);
      w.page.drawImage(image, { x: MARGIN, y: w.y - height, width, height });
      w.y -= height + 10;
    }
  }

  // -- Signature --
  w.ensureSpace(22 + 2 * 14 + 6 + 90 + 20);
  w.sectionTitle('Signature');
  identiteRow(w, 'NOM DU SIGNATAIRE (CLIENT)', nomSignataire);
  identiteRow(w, 'FONCTION DU SIGNATAIRE', fonctionSignataire);
  w.spacer(6);

  const boxWidth = (CONTENT_WIDTH - 16) / 2;
  const boxHeight = 90;
  w.ensureSpace(boxHeight + 20);
  const boxTop = w.y;
  const boxLabels = ['Cachet et signature Vertical', 'Cachet et signature du client'];
  const boxXs = boxLabels.map((_, i) => MARGIN + i * (boxWidth + 16));
  for (const [i, label] of boxLabels.entries()) {
    const boxX = boxXs[i];
    w.page.drawRectangle({ x: boxX, y: boxTop - boxHeight, width: boxWidth, height: boxHeight, borderColor: ACIER, borderWidth: 1 });
    w.page.drawText(label, { x: boxX + 6, y: boxTop - 12, size: 8, font: fontBold, color: ACIER });
  }
  const [stampBoxX, clientBoxX] = boxXs;
  const maxStampWidth = boxWidth - 24;
  const maxStampHeight = boxHeight - 30;
  const stampScale = Math.min(maxStampWidth / logo.width, maxStampHeight / logo.height, 1);
  const stampWidth = logo.width * stampScale;
  const stampHeight = logo.height * stampScale;
  w.page.drawImage(logo, {
    x: stampBoxX + (boxWidth - stampWidth) / 2,
    y: boxTop - boxHeight / 2 - stampHeight / 2 - 4,
    width: stampWidth,
    height: stampHeight,
  });
  const maxSigWidth = boxWidth - 24;
  const maxSigHeight = boxHeight - 30;
  const sigScale = Math.min(maxSigWidth / signature.width, maxSigHeight / signature.height, 1);
  const sigWidth = signature.width * sigScale;
  const sigHeight = signature.height * sigScale;
  w.page.drawImage(signature, {
    x: clientBoxX + (boxWidth - sigWidth) / 2,
    y: boxTop - boxHeight / 2 - sigHeight / 2 - 4,
    width: sigWidth,
    height: sigHeight,
  });
  w.y = boxTop - boxHeight - 16;

  // -- Mentions légales --
  w.line();
  for (const paragraphe of SAV_MENTIONS_LEGALES) {
    w.wrapped(paragraphe, { size: 7, color: ACIER });
    w.spacer(2);
  }

  const bytes = await doc.save();
  return Buffer.from(bytes);
}

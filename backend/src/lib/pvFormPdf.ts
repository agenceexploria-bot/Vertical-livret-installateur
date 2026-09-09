import { PDFDocument, StandardFonts } from 'pdf-lib';
import { VERTICAL_LOGO_PNG_BASE64 } from './verticalLogoPng';
import { PdfWriter, identiteRow, wrapText, ENCRE, ACIER, LIGNES, VERT, ROUGE, MARGIN, CONTENT_WIDTH, PAGE_WIDTH } from './pdfWriter';
import {
  PV_SECTION_1,
  PV_SECTION_1_TITRE,
  PV_SECTION_2,
  PV_SECTION_2_TITRE,
  PV_SECTION_3,
  PV_SECTION_3_TITRE,
  PV_TEMOIGNAGE_MENTION,
  PV_MENTIONS_LEGALES,
  PvChecklistItemDef,
} from './pvFormulaireDefinition';

export interface PvFormChecklistReponse {
  id: string;
  reponse: 'oui' | 'non' | null;
  observation?: string | null;
}

export interface PvFormReponses {
  identite: { maitreOeuvre?: string | null; operation?: string | null; lot?: string | null };
  receptionInstallation: PvFormChecklistReponse[];
  documentsRemis: PvFormChecklistReponse[];
  servicesSupplementaires: PvFormChecklistReponse[];
  natureDePose: string[];
  quantite?: string | null;
  reserves?: string | null;
  remarques?: string | null;
  temoignageClient?: string | null;
}

export interface PvFormChantierIdentite {
  reference: string;
  client: string;
  adresse: string;
  referenceAffaire: string;
  contactNom: string;
}

/// Une ligne "libellé — Oui/Non — observation" de checklist (sections 1 à 3
/// du gabarit) — l'observation ne s'affiche que si elle est renseignée.
function checklistRow(w: PdfWriter, def: PvChecklistItemDef, reponse: PvFormChecklistReponse | undefined) {
  const size = 9.5;
  const reponseWidth = 60;
  const labelMaxWidth = CONTENT_WIDTH - reponseWidth - 4;
  // Pré-calcule la hauteur du libellé (potentiellement multi-lignes) pour
  // réserver la place AVANT de dessiner, afin que le libellé et la réponse
  // Oui/Non alignée à droite ne puissent jamais se retrouver sur deux pages
  // différentes après un saut de page automatique.
  // TODO(2026-08-31) : wrapText() est recalculé une seconde fois à l'identique
  // dans w.wrapped() juste en dessous (mesure puis dessin) — à factoriser
  // (ex. wrapped() pourrait accepter les lignes déjà calculées) au prochain
  // tour de nettoyage.
  const lines = wrapText(`${def.id}  ${def.libelle}`, w.fontRegular, size, labelMaxWidth);
  const rowHeight = Math.max(lines.length * (size + 3), size + 3);
  w.ensureSpace(rowHeight + 4);
  const topY = w.y;

  w.wrapped(`${def.id}  ${def.libelle}`, { size, maxWidth: labelMaxWidth });
  const reponseLabel = reponse?.reponse === 'oui' ? 'Oui' : reponse?.reponse === 'non' ? 'Non' : '—';
  const reponseColor = reponse?.reponse === 'oui' ? VERT : reponse?.reponse === 'non' ? ROUGE : ACIER;
  w.page.drawText(reponseLabel, {
    x: PAGE_WIDTH - MARGIN - reponseWidth + 10,
    y: topY - size,
    size,
    font: w.fontBold,
    color: reponseColor,
  });

  const observation = reponse?.observation?.trim();
  if (observation) {
    w.wrapped(`Observation : ${observation}`, { size: 8.5, color: ACIER, x: MARGIN + 10, maxWidth: CONTENT_WIDTH - 10 });
  }
  w.spacer(3);
}

function checklistSection(w: PdfWriter, titre: string, defs: PvChecklistItemDef[], reponses: PvFormChecklistReponse[]) {
  w.sectionTitle(titre);
  const byId = new Map(reponses.map((r) => [r.id, r]));
  for (const def of defs) checklistRow(w, def, byId.get(def.id));
}

export async function genererPdfPvFormulaire(params: {
  chantier: PvFormChantierIdentite;
  reponses: PvFormReponses;
  dateReception: Date;
  nomSignataire: string;
  fonctionSignataire: string;
  signaturePngBytes: Buffer;
}): Promise<Buffer> {
  const { chantier, reponses, dateReception, nomSignataire, fonctionSignataire, signaturePngBytes } = params;

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
  w.page.drawText('Procès-verbal de réception', {
    x: MARGIN + logoWidth + 20,
    y: w.y - logoHeight / 2 - 6,
    size: 15,
    font: fontBold,
    color: ENCRE,
  });
  w.page.drawText(`Chantier ${chantier.reference}`, {
    x: MARGIN + logoWidth + 20,
    y: w.y - logoHeight / 2 - 24,
    size: 10,
    font: fontRegular,
    color: ACIER,
  });
  w.y -= logoHeight + 14;
  w.line();

  // -- Identité chantier --
  identiteRow(w, 'CLIENT / MAÎTRE D\'OUVRAGE', chantier.client);
  identiteRow(w, 'ADRESSE CHANTIER', chantier.adresse);
  identiteRow(w, 'AFFAIRE N°', chantier.referenceAffaire);
  identiteRow(w, 'MAÎTRE D\'ŒUVRE', reponses.identite.maitreOeuvre ?? '');
  identiteRow(w, 'CONTACT CLIENT', chantier.contactNom);
  identiteRow(w, 'OPÉRATION', reponses.identite.operation ?? '');
  identiteRow(w, 'LOT', reponses.identite.lot ?? '');
  w.spacer(4);

  // -- Sections 1, 2, 3 --
  checklistSection(w, PV_SECTION_1_TITRE, PV_SECTION_1, reponses.receptionInstallation);
  checklistSection(w, PV_SECTION_2_TITRE, PV_SECTION_2, reponses.documentsRemis);
  checklistSection(w, PV_SECTION_3_TITRE, PV_SECTION_3, reponses.servicesSupplementaires);

  // -- Nature de la pose --
  w.sectionTitle('Nature de la pose');
  w.wrapped(reponses.natureDePose.length > 0 ? reponses.natureDePose.join(', ') : '—', { size: 9.5 });
  if (reponses.quantite?.trim()) {
    w.wrapped(`Quantité(s) : ${reponses.quantite.trim()}`, { size: 9.5, color: ACIER });
  }

  // -- Zones de texte libre --
  w.sectionTitle('Réserves');
  w.wrapped(reponses.reserves?.trim() || 'Aucune réserve.', { size: 9.5 });

  w.sectionTitle('Remarques');
  w.wrapped(reponses.remarques?.trim() || 'Aucune remarque.', { size: 9.5 });

  w.sectionTitle('Témoignage client');
  w.wrapped(PV_TEMOIGNAGE_MENTION, { size: 8, color: ACIER });
  w.spacer(2);
  w.wrapped(reponses.temoignageClient?.trim() || '—', { size: 9.5 });

  // -- Signature --
  // Réserve la place du bloc entier (titre + champs + cases) en une fois,
  // pour éviter qu'un saut de page automatique ne sépare le titre "Signature"
  // des cases qui vont avec.
  w.ensureSpace(22 + 3 * 14 + 6 + 90 + 20);
  w.sectionTitle('Signature');
  identiteRow(w, 'DATE DE RÉCEPTION', new Intl.DateTimeFormat('fr-FR', { dateStyle: 'long', timeZone: 'UTC' }).format(dateReception));
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
    w.page.drawRectangle({ x: boxX, y: boxTop - boxHeight, width: boxWidth, height: boxHeight, borderColor: LIGNES, borderWidth: 1 });
    w.page.drawText(label, { x: boxX + 6, y: boxTop - 12, size: 8, font: fontBold, color: ACIER });
  }
  const [stampBoxX, clientBoxX] = boxXs;
  // Logo Vertical dans la case "Cachet et signature Vertical" — pas de vrai
  // tampon numérisé disponible, voir la discussion avec l'utilisateur. Le
  // ratio largeur/hauteur est préservé (comme pour la signature ci-dessous) :
  // brider seulement la hauteur sans réduire la largeur à l'identique aurait
  // déformé le logo.
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
  // Signature tactile du client, mise à l'échelle pour tenir dans sa case.
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
  for (const paragraphe of PV_MENTIONS_LEGALES) {
    w.wrapped(paragraphe, { size: 7, color: ACIER });
    w.spacer(2);
  }

  const bytes = await doc.save();
  return Buffer.from(bytes);
}

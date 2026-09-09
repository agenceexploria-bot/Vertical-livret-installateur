import { PDFDocument, PDFFont, PDFPage, StandardFonts, rgb, RGB } from 'pdf-lib';

/// Utilitaires de mise en page PDF communs à tous les documents générés de
/// toutes pièces (pas de gabarit) — extrait de pvFormPdf.ts pour être
/// réutilisé par savFormPdf.ts sans dupliquer la mécanique de pagination.

export const ENCRE = rgb(0.13, 0.13, 0.13);
export const ACIER = rgb(0.4, 0.42, 0.45);
export const LIGNES = rgb(0.85, 0.86, 0.88);
export const VERT = rgb(0.16, 0.5, 0.28);
export const ROUGE = rgb(0.72, 0.16, 0.16);

export const PAGE_WIDTH = 595.28; // A4 portrait, en points
export const PAGE_HEIGHT = 841.89;
export const MARGIN = 42;
export const CONTENT_WIDTH = PAGE_WIDTH - MARGIN * 2;

/// Découpe [text] en lignes qui tiennent chacune dans [maxWidth] à la taille
/// donnée — pdf-lib ne fait aucun retour à la ligne automatique.
export function wrapText(text: string, font: PDFFont, size: number, maxWidth: number): string[] {
  const words = text.split(/\s+/).filter(Boolean);
  if (words.length === 0) return [''];
  const lines: string[] = [];
  let current = '';
  for (const word of words) {
    const attempt = current ? `${current} ${word}` : word;
    if (current && font.widthOfTextAtSize(attempt, size) > maxWidth) {
      lines.push(current);
      current = word;
    } else {
      current = attempt;
    }
  }
  if (current) lines.push(current);
  return lines;
}

/// Gère la position d'écriture courante et les sauts de page automatiques —
/// le contenu (nombre variable d'observations, remarques, photos...) n'a pas
/// de longueur connue à l'avance, contrairement à un gabarit PDF à positions
/// fixes.
export class PdfWriter {
  private doc: PDFDocument;
  fontRegular: PDFFont;
  fontBold: PDFFont;
  page: PDFPage;
  y: number;

  constructor(doc: PDFDocument, fontRegular: PDFFont, fontBold: PDFFont) {
    this.doc = doc;
    this.fontRegular = fontRegular;
    this.fontBold = fontBold;
    this.page = doc.addPage([PAGE_WIDTH, PAGE_HEIGHT]);
    this.y = PAGE_HEIGHT - MARGIN;
  }

  ensureSpace(height: number) {
    if (this.y - height < MARGIN) {
      this.page = this.doc.addPage([PAGE_WIDTH, PAGE_HEIGHT]);
      this.y = PAGE_HEIGHT - MARGIN;
    }
  }

  spacer(height: number) {
    this.y -= height;
  }

  line(color: RGB = LIGNES) {
    this.ensureSpace(8);
    this.page.drawLine({ start: { x: MARGIN, y: this.y }, end: { x: PAGE_WIDTH - MARGIN, y: this.y }, thickness: 0.75, color });
    this.y -= 10;
  }

  text(value: string, opts: { size?: number; bold?: boolean; color?: RGB; x?: number } = {}) {
    const size = opts.size ?? 10;
    const font = opts.bold ? this.fontBold : this.fontRegular;
    this.ensureSpace(size + 5);
    this.page.drawText(value, { x: opts.x ?? MARGIN, y: this.y - size, size, font, color: opts.color ?? ENCRE });
    this.y -= size + 5;
  }

  wrapped(value: string, opts: { size?: number; bold?: boolean; color?: RGB; x?: number; maxWidth?: number } = {}) {
    const size = opts.size ?? 10;
    const font = opts.bold ? this.fontBold : this.fontRegular;
    const maxWidth = opts.maxWidth ?? CONTENT_WIDTH - (opts.x ?? MARGIN) + MARGIN;
    for (const line of wrapText(value, font, size, maxWidth)) {
      this.ensureSpace(size + 4);
      this.page.drawText(line, { x: opts.x ?? MARGIN, y: this.y - size, size, font, color: opts.color ?? ENCRE });
      this.y -= size + 4;
    }
  }

  sectionTitle(titre: string) {
    this.spacer(6);
    this.ensureSpace(22);
    this.page.drawRectangle({ x: MARGIN, y: this.y - 18, width: CONTENT_WIDTH, height: 18, color: rgb(0.11, 0.13, 0.18) });
    this.page.drawText(titre, { x: MARGIN + 6, y: this.y - 13.5, size: 10.5, font: this.fontBold, color: rgb(1, 1, 1) });
    this.y -= 22;
  }
}

/// Une ligne "libellé — valeur" alignée (identité chantier, dates...) —
/// repliée sur plusieurs lignes si la valeur est longue, plutôt que
/// débordée hors de la page.
export function identiteRow(w: PdfWriter, label: string, value: string) {
  const size = 9.5;
  const valueX = MARGIN + 130;
  const valueMaxWidth = CONTENT_WIDTH - 130;
  const lines = wrapText(value || '—', w.fontRegular, size, valueMaxWidth);
  const rowHeight = Math.max(lines.length * (size + 4), 14);
  w.ensureSpace(rowHeight);
  const topY = w.y;
  w.page.drawText(label, { x: MARGIN, y: topY - 9, size: 8.5, font: w.fontBold, color: ACIER });
  w.wrapped(value || '—', { size, x: valueX, maxWidth: valueMaxWidth });
  w.y = Math.min(w.y, topY - rowHeight);
}

export { StandardFonts };

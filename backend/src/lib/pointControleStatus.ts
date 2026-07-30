import { PointControle } from '@prisma/client';

// Règle commune à tous les modules de contrôle (réception marchandises et
// auto-contrôle) : un point conforme n'a plus besoin de photo pour être
// complet ; seule une anomalie (nonConforme) exige une photo, pour en
// apporter la preuve.
export function isPointComplete(p: PointControle): boolean {
  return p.status === 'conforme' || (p.status === 'nonConforme' && p.photoPath != null);
}

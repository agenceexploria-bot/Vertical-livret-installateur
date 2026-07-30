import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../prisma';
import { serializeUser } from '../serializers';
import { requireAuth, requireRole, AuthedRequest } from '../middleware/auth';
import { deleteBlobFile } from '../lib/imageStorage';

export const adminRouter = Router();

const INTERNAL_VALIDATION_ROLES = ['chargeAffaires', 'qualite'] as const;

adminRouter.get('/comptes-internes', requireAuth, requireRole('admin'), async (_req, res) => {
  const users = await prisma.user.findMany({
    where: { role: { in: [...INTERNAL_VALIDATION_ROLES] } },
    include: { habilitations: true },
    orderBy: { createdAt: 'asc' },
  });
  res.json({ comptesInternes: users.map(serializeUser) });
});

adminRouter.post('/comptes-internes/:id/valider', requireAuth, requireRole('admin'), async (req, res) => {
  const target = await prisma.user.findUnique({ where: { id: req.params.id } });
  if (!target) return res.status(404).json({ error: 'Compte introuvable' });
  if (!INTERNAL_VALIDATION_ROLES.includes(target.role as (typeof INTERNAL_VALIDATION_ROLES)[number])) {
    return res.status(400).json({ error: 'Ce compte n\'est pas soumis à validation par un administrateur' });
  }

  const user = await prisma.user.update({
    where: { id: req.params.id },
    data: { isActive: true, suspendu: false },
    include: { habilitations: true },
  });
  res.json({ user: serializeUser(user) });
});

// Gestion globale des comptes : contrairement à /comptes (comptes.ts), réservé
// au CA/Direction/Admin et limité aux installateurs, l'Admin a ici le contrôle
// total sur TOUS les comptes du système à l'exception des autres comptes
// Admin — jamais touchable, ni même consultable via ces routes.
async function findManageableAccountOrNull(id: string) {
  const user = await prisma.user.findUnique({ where: { id } });
  return user && user.role !== 'admin' ? user : null;
}

adminRouter.get('/comptes', requireAuth, requireRole('admin'), async (_req, res) => {
  const users = await prisma.user.findMany({
    where: { role: { not: 'admin' } },
    include: { habilitations: true },
    orderBy: { createdAt: 'asc' },
  });
  res.json({ comptes: users.map(serializeUser) });
});

// Fiche détaillée d'un compte — n'importe quel rôle sauf Admin (voir
// findManageableAccountOrNull). Utilisée par la fiche de consultation
// générique de l'Admin (BoAdminCompteDetailScreen), en complément de la liste
// /comptes qui charge déjà tous les comptes d'un coup.
adminRouter.get('/comptes/:id', requireAuth, requireRole('admin'), async (req, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.params.id },
    include: { habilitations: true },
  });
  if (!user || user.role === 'admin') return res.status(404).json({ error: 'Compte introuvable' });
  res.json({ compte: serializeUser(user) });
});

adminRouter.post('/comptes/:id/suspendre', requireAuth, requireRole('admin'), async (req, res) => {
  if (!(await findManageableAccountOrNull(req.params.id))) return res.status(404).json({ error: 'Compte introuvable' });

  const user = await prisma.user.update({
    where: { id: req.params.id },
    data: { suspendu: true },
    include: { habilitations: true },
  });
  res.json({ user: serializeUser(user) });
});

adminRouter.post('/comptes/:id/reactiver', requireAuth, requireRole('admin'), async (req, res) => {
  if (!(await findManageableAccountOrNull(req.params.id))) return res.status(404).json({ error: 'Compte introuvable' });

  const user = await prisma.user.update({
    where: { id: req.params.id },
    data: { isActive: true, suspendu: false },
    include: { habilitations: true },
  });
  res.json({ user: serializeUser(user) });
});

const adminResetPasswordSchema = z.object({ password: z.string().min(6) });

// Réinitialisation par l'Admin — même logique que /comptes/:id/reinitialiser-
// mot-de-passe (comptes.ts) mais ouverte à tout compte non-admin (CA compris).
adminRouter.post(
  '/comptes/:id/reinitialiser-mot-de-passe',
  requireAuth,
  requireRole('admin'),
  async (req, res) => {
    const parsed = adminResetPasswordSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    if (!(await findManageableAccountOrNull(req.params.id))) return res.status(404).json({ error: 'Compte introuvable' });

    const passwordHash = await bcrypt.hash(parsed.data.password, 10);
    await prisma.user.update({ where: { id: req.params.id }, data: { passwordHash } });
    res.status(204).send();
  },
);

// Suppression définitive — le contrôle du self-delete précède la recherche du
// compte pour renvoyer un message explicite plutôt qu'un 404 générique (le
// ciblé serait de toute façon exclu par findManageableAccountOrNull puisque
// l'appelant est lui-même Admin).
adminRouter.delete('/comptes/:id', requireAuth, requireRole('admin'), async (req: AuthedRequest, res) => {
  if (req.params.id === req.auth!.userId) {
    return res.status(400).json({ error: 'Vous ne pouvez pas supprimer votre propre compte' });
  }
  if (!(await findManageableAccountOrNull(req.params.id))) return res.status(404).json({ error: 'Compte introuvable' });

  const existing = await prisma.user.findUnique({
    where: { id: req.params.id },
    include: { habilitations: true, documentsTerrain: true },
  });
  const filePaths = [
    ...(existing?.habilitations.map((h) => h.filePath) ?? []),
    ...(existing?.documentsTerrain.map((d) => d.filePath) ?? []),
  ].filter((p): p is string => !!p);
  await Promise.all(filePaths.map((p) => deleteBlobFile(p)));

  await prisma.user.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

// Tableau de bord d'activité : agrège les flux déjà présents en base
// (inscriptions, points en anomalie, PV signés, REX soumis) plutôt que de
// dupliquer ces événements dans une table de log séparée à maintenir.
adminRouter.get('/activity', requireAuth, requireRole('admin'), async (_req, res) => {
  const [inscriptionsInstallateurs, inscriptionsInternes, anomalies, pvRecents, rexEnAttente] = await Promise.all([
    prisma.user.findMany({ where: { role: 'installateur', isActive: false }, orderBy: { createdAt: 'asc' } }),
    prisma.user.findMany({
      where: { role: { in: [...INTERNAL_VALIDATION_ROLES] }, isActive: false },
      orderBy: { createdAt: 'asc' },
    }),
    prisma.pointControle.findMany({
      where: { status: 'nonConforme' },
      include: { chantier: true },
      orderBy: { valideAt: 'desc' },
      take: 50,
    }),
    prisma.chantier.findMany({
      where: { pvSigne: true },
      orderBy: { pvSigneAt: 'desc' },
      take: 20,
    }),
    prisma.chantier.findMany({
      where: { rexValide: true },
      orderBy: { rexSoumisAt: 'desc' },
      take: 20,
    }),
  ]);

  res.json({
    inscriptionsEnAttente: [...inscriptionsInstallateurs, ...inscriptionsInternes]
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
      .map((u) => ({ id: u.id, fullName: `${u.prenom} ${u.nom}`, role: u.role, createdAt: u.createdAt })),
    anomalies: anomalies.map((p) => ({
      chantierReference: p.chantier.reference,
      client: p.chantier.client,
      libelle: p.libelle,
      categorie: p.categorie,
      critique: p.critique,
      validePar: p.validePar,
      valideAt: p.valideAt,
    })),
    pvRecents: pvRecents.map((c) => ({
      chantierReference: c.reference,
      client: c.client,
      pvSigneur: c.pvSigneur,
      pvFonctionSignataire: c.pvFonctionSignataire,
      pvSigneAt: c.pvSigneAt,
      pvSignatureImagePath: c.pvSignatureImagePath,
    })),
    rexEnAttente: rexEnAttente.map((c) => ({
      chantierReference: c.reference,
      client: c.client,
      rexTranscription: c.rexTranscription,
      rexSoumisAt: c.rexSoumisAt,
    })),
  });
});

const STATS_WEEKS = 8;

/// Lundi de la semaine ISO contenant [date] (minuit UTC).
function startOfIsoWeek(date: Date): Date {
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = d.getUTCDay();
  d.setUTCDate(d.getUTCDate() + (day === 0 ? -6 : 1 - day));
  return d;
}

// Séries hebdomadaires pour les graphiques du dashboard Admin — calculées à
// la volée sur les 8 dernières semaines glissantes (pas de table de log
// séparée à maintenir, même logique que /activity).
adminRouter.get('/stats', requireAuth, requireRole('admin'), async (_req, res) => {
  const rangeStart = startOfIsoWeek(new Date(Date.now() - (STATS_WEEKS - 1) * 7 * 24 * 60 * 60 * 1000));

  const [pvSignes, rexSoumis, anomalies] = await Promise.all([
    prisma.chantier.findMany({ where: { pvSigne: true, pvSigneAt: { gte: rangeStart } }, select: { pvSigneAt: true } }),
    prisma.chantier.findMany({ where: { rexValide: true, rexSoumisAt: { gte: rangeStart } }, select: { rexSoumisAt: true } }),
    prisma.pointControle.findMany({
      where: { status: 'nonConforme', valideAt: { gte: rangeStart } },
      select: { valideAt: true },
    }),
  ]);

  const weeks = Array.from({ length: STATS_WEEKS }, (_, i) => {
    const weekStart = new Date(rangeStart.getTime() + i * 7 * 24 * 60 * 60 * 1000);
    const weekEnd = new Date(weekStart.getTime() + 7 * 24 * 60 * 60 * 1000);
    const inWeek = (d: Date | null) => d != null && d >= weekStart && d < weekEnd;
    return {
      weekStart: weekStart.toISOString().slice(0, 10),
      pvSignes: pvSignes.filter((c) => inWeek(c.pvSigneAt)).length,
      rexSoumis: rexSoumis.filter((c) => inWeek(c.rexSoumisAt)).length,
      anomalies: anomalies.filter((p) => inWeek(p.valideAt)).length,
    };
  });

  res.json({ weeks });
});

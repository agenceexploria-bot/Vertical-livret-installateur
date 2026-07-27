import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../prisma';
import { serializeUser } from '../serializers';
import { requireAuth, requireRole, AuthedRequest } from '../middleware/auth';
import { saveBase64File } from '../lib/imageStorage';

export const comptesRouter = Router();

const INTERNAL_ROLES = ['chargeAffaires', 'qualite', 'direction', 'admin'];

comptesRouter.get('/', requireAuth, requireRole(...INTERNAL_ROLES), async (_req, res) => {
  const users = await prisma.user.findMany({
    where: { role: 'installateur' },
    include: { habilitations: true },
    orderBy: { createdAt: 'asc' },
  });
  res.json({ installateurs: users.map(serializeUser) });
});

comptesRouter.post('/:id/valider', requireAuth, requireRole('chargeAffaires', 'direction', 'admin'), async (req, res) => {
  const user = await prisma.user.update({
    where: { id: req.params.id },
    data: { isActive: true, suspendu: false },
    include: { habilitations: true },
  });
  res.json({ user: serializeUser(user) });
});

comptesRouter.post('/:id/suspendre', requireAuth, requireRole('chargeAffaires', 'direction', 'admin'), async (req, res) => {
  const user = await prisma.user.update({
    where: { id: req.params.id },
    data: { suspendu: true },
    include: { habilitations: true },
  });
  res.json({ user: serializeUser(user) });
});

comptesRouter.post('/:id/reactiver', requireAuth, requireRole('chargeAffaires', 'direction', 'admin'), async (req, res) => {
  const user = await prisma.user.update({
    where: { id: req.params.id },
    data: { isActive: true, suspendu: false },
    include: { habilitations: true },
  });
  res.json({ user: serializeUser(user) });
});

// Suppression définitive d'un compte — réservée à l'Admin (nouvelle capacité
// de la refonte des rôles back-office, distincte de la suspension qui reste
// réversible). Un Admin ne peut pas se supprimer lui-même via cette route.
comptesRouter.delete('/:id', requireAuth, requireRole('admin'), async (req: AuthedRequest, res) => {
  if (req.params.id === req.auth!.userId) {
    return res.status(400).json({ error: 'Vous ne pouvez pas supprimer votre propre compte' });
  }

  const existing = await prisma.user.findUnique({ where: { id: req.params.id } });
  if (!existing) return res.status(404).json({ error: 'Compte introuvable' });

  await prisma.user.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

const resetPasswordSchema = z.object({ password: z.string().min(6) });

// Réinitialisation du mot de passe d'un installateur par le CA/Admin — le
// nouveau mot de passe est choisi par le CA/Admin et communiqué ensuite à
// l'installateur (pas de flux d'email de réinitialisation dans cette V1).
comptesRouter.post(
  '/:id/reinitialiser-mot-de-passe',
  requireAuth,
  requireRole('chargeAffaires', 'direction', 'admin'),
  async (req, res) => {
    const parsed = resetPasswordSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    const existing = await prisma.user.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Compte introuvable' });

    const passwordHash = await bcrypt.hash(parsed.data.password, 10);
    await prisma.user.update({ where: { id: req.params.id }, data: { passwordHash } });
    res.status(204).send();
  },
);

const updateProfileSchema = z.object({
  nom: z.string().min(1).optional(),
  prenom: z.string().min(1).optional(),
  email: z.string().email('Email invalide').optional(),
  mobile: z.string().min(6).optional(),
  societe: z.string().optional().nullable(),
});

// Un utilisateur (tout rôle) modifie ses propres informations de profil —
// pas de changement de mot de passe ni de rôle ici, hors sujet de cette action.
comptesRouter.patch('/moi', requireAuth, async (req: AuthedRequest, res) => {
  const parsed = updateProfileSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const { email, mobile } = parsed.data;

  if (email || mobile) {
    const existing = await prisma.user.findFirst({
      where: {
        id: { not: req.auth!.userId },
        OR: [...(email ? [{ email }] : []), ...(mobile ? [{ mobile }] : [])],
      },
    });
    if (existing) return res.status(409).json({ error: 'Cet email ou ce mobile est déjà utilisé par un autre compte' });
  }

  const user = await prisma.user.update({
    where: { id: req.auth!.userId },
    data: parsed.data,
    include: { habilitations: true },
  });
  res.json({ user: serializeUser(user) });
});

// Le CA/Admin modifie le profil d'un installateur depuis le back-office
// (distinct de /moi, réservé à l'auto-modification) — pas de changement de
// mot de passe ni de rôle ici non plus.
comptesRouter.patch('/:id', requireAuth, requireRole('chargeAffaires', 'direction', 'admin'), async (req, res) => {
  const parsed = updateProfileSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const { email, mobile } = parsed.data;

  if (email || mobile) {
    const existing = await prisma.user.findFirst({
      where: {
        id: { not: req.params.id },
        OR: [...(email ? [{ email }] : []), ...(mobile ? [{ mobile }] : [])],
      },
    });
    if (existing) return res.status(409).json({ error: 'Cet email ou ce mobile est déjà utilisé par un autre compte' });
  }

  const user = await prisma.user.update({
    where: { id: req.params.id },
    data: parsed.data,
    include: { habilitations: true },
  });
  res.json({ user: serializeUser(user) });
});

const habilitationSchema = z.object({
  titre: z.string().min(1),
  dateExpiration: z.string(), // ISO date
  file: z.string().min(1, 'Le certificat (PDF ou image) est requis'),
});

// Un installateur ajoute son propre certificat (EX-13) ; consulté par soi-même
// via /auth/me, et par le CA/Qualité/Admin via /comptes et /comptes/moi.
// Le fichier réel (PDF ou image) est stocké sur le serveur — l'Admin et le CA
// doivent pouvoir l'ouvrir depuis le back-office.
comptesRouter.post('/moi/habilitations', requireAuth, async (req: AuthedRequest, res) => {
  const parsed = habilitationSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const filePath = await saveBase64File(parsed.data.file, `habilitation-${req.auth!.userId}`);

  const habilitation = await prisma.habilitation.create({
    data: {
      titre: parsed.data.titre,
      dateExpiration: new Date(parsed.data.dateExpiration),
      filePath,
      userId: req.auth!.userId,
    },
  });
  res.status(201).json({ habilitation });
});

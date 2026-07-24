import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { serializeUser } from '../serializers';
import { requireAuth, requireRole, AuthedRequest } from '../middleware/auth';
import { saveBase64File } from '../lib/imageStorage';

export const comptesRouter = Router();

const INTERNAL_ROLES = ['chargeAffaires', 'qualite', 'direction'];

comptesRouter.get('/', requireAuth, requireRole(...INTERNAL_ROLES), async (_req, res) => {
  const users = await prisma.user.findMany({
    where: { role: 'installateur' },
    include: { habilitations: true },
    orderBy: { createdAt: 'asc' },
  });
  res.json({ installateurs: users.map(serializeUser) });
});

comptesRouter.post('/:id/valider', requireAuth, requireRole('chargeAffaires', 'direction'), async (req, res) => {
  const user = await prisma.user.update({
    where: { id: req.params.id },
    data: { isActive: true, suspendu: false },
    include: { habilitations: true },
  });
  res.json({ user: serializeUser(user) });
});

comptesRouter.post('/:id/suspendre', requireAuth, requireRole('chargeAffaires', 'direction'), async (req, res) => {
  const user = await prisma.user.update({
    where: { id: req.params.id },
    data: { suspendu: true },
    include: { habilitations: true },
  });
  res.json({ user: serializeUser(user) });
});

comptesRouter.post('/:id/reactiver', requireAuth, requireRole('chargeAffaires', 'direction'), async (req, res) => {
  const user = await prisma.user.update({
    where: { id: req.params.id },
    data: { isActive: true, suspendu: false },
    include: { habilitations: true },
  });
  res.json({ user: serializeUser(user) });
});

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

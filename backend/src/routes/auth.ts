import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../prisma';
import { serializeUser } from '../serializers';
import { signAccessToken, signRefreshToken, verifyRefreshToken, REFRESH_TOKEN_TTL_DAYS } from '../auth/tokens';
import { requireAuth, AuthedRequest } from '../middleware/auth';

export const authRouter = Router();

function normalizeMobile(value: string): string {
  return value.replace(/\D/g, '');
}

const signupSchema = z.object({
  nom: z.string().min(1),
  prenom: z.string().min(1),
  mobile: z.string().min(6),
  email: z.string().email('Email invalide'),
  password: z.string().min(6),
  sousTraitant: z.boolean().optional().default(false),
  societe: z.string().optional().nullable(),
});

authRouter.post('/signup', async (req, res) => {
  const parsed = signupSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const { nom, prenom, email, password, sousTraitant, societe } = parsed.data;
  const mobile = normalizeMobile(parsed.data.mobile);

  const existing = await prisma.user.findFirst({ where: { OR: [{ mobile }, { email }] } });
  if (existing) return res.status(409).json({ error: 'Un compte existe déjà avec ce mobile ou cet email' });

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({
    data: {
      nom,
      prenom,
      mobile,
      email,
      passwordHash,
      role: 'installateur',
      status: sousTraitant ? 'sousTraitant' : 'salarie',
      societe: sousTraitant ? (societe ?? undefined) : undefined,
      isActive: false,
    },
  });

  const tokens = await issueTokens(user.id, user.role);
  res.status(201).json({ user: serializeUser(user), ...tokens });
});

const signupInterneSchema = z.object({
  nom: z.string().min(1),
  prenom: z.string().min(1),
  mobile: z.string().min(6),
  email: z
    .string()
    .email('Email invalide')
    .refine((e) => e.toLowerCase().endsWith('@actiwork.fr'), 'Email professionnel @actiwork.fr requis'),
  password: z.string().min(6),
  role: z.enum(['chargeAffaires', 'qualite']),
});

// Demande d'accès pour un compte interne (CA / Qualité) : créé immédiatement
// mais isActive=false — le compte ne peut se connecter au back-office tant
// qu'un Admin ne l'a pas validé (voir /admin/comptes-internes).
authRouter.post('/signup-interne', async (req, res) => {
  const parsed = signupInterneSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const { nom, prenom, email, password, role } = parsed.data;
  const mobile = normalizeMobile(parsed.data.mobile);

  const existing = await prisma.user.findFirst({ where: { OR: [{ mobile }, { email }] } });
  if (existing) return res.status(409).json({ error: 'Un compte existe déjà avec ce mobile ou cet email' });

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({
    data: { nom, prenom, mobile, email, passwordHash, role, isActive: false },
  });

  const tokens = await issueTokens(user.id, user.role);
  res.status(201).json({ user: serializeUser(user), ...tokens });
});

const loginSchema = z.object({
  identifier: z.string().min(1),
  password: z.string().min(1),
});

authRouter.post('/login', async (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const { identifier, password } = parsed.data;
  const normalizedMobile = normalizeMobile(identifier);

  const user = await prisma.user.findFirst({
    where: { OR: [{ email: identifier }, { mobile: normalizedMobile }] },
    include: { habilitations: true },
  });
  if (!user) return res.status(401).json({ error: 'Identifiants incorrects' });

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) return res.status(401).json({ error: 'Identifiants incorrects' });

  const tokens = await issueTokens(user.id, user.role);
  res.json({ user: serializeUser(user), ...tokens });
});

const refreshSchema = z.object({ refreshToken: z.string().min(1) });

authRouter.post('/refresh', async (req, res) => {
  const parsed = refreshSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const { refreshToken } = parsed.data;

  try {
    verifyRefreshToken(refreshToken);
  } catch {
    return res.status(401).json({ error: 'Session hors-ligne expirée, reconnexion nécessaire' });
  }

  const stored = await prisma.refreshToken.findUnique({ where: { token: refreshToken } });
  if (!stored || stored.expiresAt < new Date()) {
    return res.status(401).json({ error: 'Session hors-ligne expirée, reconnexion nécessaire' });
  }

  const user = await prisma.user.findUnique({ where: { id: stored.userId } });
  if (!user) return res.status(401).json({ error: 'Compte introuvable' });

  const accessToken = signAccessToken({ userId: user.id, role: user.role });
  res.json({ accessToken });
});

authRouter.post('/logout', async (req, res) => {
  const { refreshToken } = req.body ?? {};
  if (refreshToken) {
    await prisma.refreshToken.deleteMany({ where: { token: refreshToken } });
  }
  res.status(204).send();
});

authRouter.get('/me', requireAuth, async (req: AuthedRequest, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.auth!.userId },
    include: { habilitations: true },
  });
  if (!user) return res.status(404).json({ error: 'Compte introuvable' });
  res.json({ user: serializeUser(user) });
});

async function issueTokens(userId: string, role: string) {
  const accessToken = signAccessToken({ userId, role });
  const refreshToken = signRefreshToken({ userId, role });
  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000);
  await prisma.refreshToken.create({ data: { token: refreshToken, userId, expiresAt } });
  return { accessToken, refreshToken };
}

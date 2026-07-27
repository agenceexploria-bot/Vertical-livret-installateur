import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { randomInt } from 'crypto';
import { z } from 'zod';
import { prisma } from '../prisma';
import { serializeUser } from '../serializers';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  REFRESH_TOKEN_TTL_DAYS,
  signEmailVerificationTicket,
  verifyEmailVerificationTicket,
} from '../auth/tokens';
import { requireAuth, AuthedRequest } from '../middleware/auth';
import { sendVerificationCodeEmail } from '../lib/mailer';

export const authRouter = Router();

function normalizeMobile(value: string | undefined): string | undefined {
  return value ? value.replace(/\D/g, '') : undefined;
}

const CODE_TTL_MINUTES = 10;
const MAX_CODE_ATTEMPTS = 5;

const requestEmailCodeSchema = z.object({ email: z.string().email('Email invalide') });

// Étape 1/2 de l'inscription (EX-2FA) : envoie un code à 6 chiffres par email
// — bloque immédiatement si l'email est déjà pris, avant même de faire
// saisir un mot de passe à quelqu'un qui a déjà un compte.
authRouter.post('/request-email-code', async (req, res) => {
  const parsed = requestEmailCodeSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const { email } = parsed.data;

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) return res.status(409).json({ error: 'Un compte existe déjà avec cet email' });

  const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
  const codeHash = await bcrypt.hash(code, 10);

  await prisma.emailVerificationCode.deleteMany({ where: { email } });
  await prisma.emailVerificationCode.create({
    data: { email, codeHash, expiresAt: new Date(Date.now() + CODE_TTL_MINUTES * 60 * 1000) },
  });

  await sendVerificationCodeEmail(email, code);

  // Le code n'est renvoyé en clair qu'en environnement de test, pour que la
  // suite automatisée puisse vérifier le flux sans lire une boîte mail — ne
  // jamais l'exposer en dev/prod.
  res.json({ sent: true, ...(process.env.NODE_ENV === 'test' ? { code } : {}) });
});

const verifyEmailCodeSchema = z.object({ email: z.string().email(), code: z.string().length(6) });

authRouter.post('/verify-email-code', async (req, res) => {
  const parsed = verifyEmailCodeSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const { email, code } = parsed.data;

  const record = await prisma.emailVerificationCode.findFirst({ where: { email }, orderBy: { createdAt: 'desc' } });
  if (!record || record.expiresAt < new Date()) {
    return res.status(400).json({ error: 'Code expiré ou introuvable — veuillez en redemander un.' });
  }

  if (record.attempts >= MAX_CODE_ATTEMPTS) {
    await prisma.emailVerificationCode.delete({ where: { id: record.id } });
    return res.status(429).json({ error: 'Trop de tentatives — veuillez redemander un code.' });
  }

  const valid = await bcrypt.compare(code, record.codeHash);
  if (!valid) {
    await prisma.emailVerificationCode.update({ where: { id: record.id }, data: { attempts: { increment: 1 } } });
    return res.status(400).json({ error: 'Code incorrect.' });
  }

  await prisma.emailVerificationCode.delete({ where: { id: record.id } });
  res.json({ verificationTicket: signEmailVerificationTicket(email) });
});

const signupSchema = z.object({
  nom: z.string().min(1),
  prenom: z.string().min(1),
  mobile: z.string().min(6).optional(),
  email: z.string().email('Email invalide'),
  password: z.string().min(6),
  sousTraitant: z.boolean().optional().default(false),
  societe: z.string().optional().nullable(),
  verificationTicket: z.string().min(1),
});

authRouter.post('/signup', async (req, res) => {
  const parsed = signupSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const { nom, prenom, email, password, sousTraitant, societe, verificationTicket } = parsed.data;
  const mobile = normalizeMobile(parsed.data.mobile);

  let ticketPayload;
  try {
    ticketPayload = verifyEmailVerificationTicket(verificationTicket);
  } catch {
    return res.status(400).json({ error: 'Vérification email requise ou expirée — recommencez l\'inscription.' });
  }
  if (ticketPayload.email !== email || ticketPayload.purpose !== 'signup-email-verified') {
    return res.status(400).json({ error: 'Vérification email requise ou expirée — recommencez l\'inscription.' });
  }

  const existing = await prisma.user.findFirst({
    where: { OR: [...(mobile ? [{ mobile }] : []), { email }] },
  });
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
  // Le rôle Qualité a été fusionné dans l'espace CA (refonte des rôles
  // back-office) — il n'est plus proposé à l'inscription, seul chargeAffaires
  // l'est. L'enum du schéma Prisma garde 'qualite' pour ne pas casser un
  // compte déjà existant avec ce rôle (redirigé côté front vers l'espace CA).
  role: z.enum(['chargeAffaires']),
});

// Demande d'accès pour un compte interne (CA) : créé immédiatement mais
// isActive=false — le compte ne peut se connecter au back-office tant qu'un
// Admin ne l'a pas validé (voir /admin/comptes-internes).
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

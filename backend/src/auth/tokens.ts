import jwt from 'jsonwebtoken';
import { randomUUID } from 'crypto';

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET!;
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET!;

export const ACCESS_TOKEN_TTL = '15m';
export const REFRESH_TOKEN_TTL_DAYS = 30;

export interface AccessTokenPayload {
  userId: string;
  role: string;
}

export function signAccessToken(payload: AccessTokenPayload): string {
  return jwt.sign(payload, ACCESS_SECRET, { expiresIn: ACCESS_TOKEN_TTL, jwtid: randomUUID() });
}

export function verifyAccessToken(token: string): AccessTokenPayload {
  return jwt.verify(token, ACCESS_SECRET) as AccessTokenPayload;
}

export function signRefreshToken(payload: AccessTokenPayload): string {
  // jwtid garantit l'unicité même pour deux connexions du même utilisateur
  // dans la même seconde (le token stocké en base est UNIQUE).
  return jwt.sign(payload, REFRESH_SECRET, { expiresIn: `${REFRESH_TOKEN_TTL_DAYS}d`, jwtid: randomUUID() });
}

export function verifyRefreshToken(token: string): AccessTokenPayload {
  return jwt.verify(token, REFRESH_SECRET) as AccessTokenPayload;
}

export interface EmailVerificationTicketPayload {
  email: string;
  purpose: 'signup-email-verified';
}

/// Ticket signé de courte durée prouvant qu'un code envoyé à [email] a été
/// vérifié — transmis par le client à /auth/signup pour prouver la
/// vérification sans avoir à re-soumettre le code à la création du compte.
export function signEmailVerificationTicket(email: string): string {
  const payload: EmailVerificationTicketPayload = { email, purpose: 'signup-email-verified' };
  return jwt.sign(payload, ACCESS_SECRET, { expiresIn: '15m' });
}

export function verifyEmailVerificationTicket(token: string): EmailVerificationTicketPayload {
  return jwt.verify(token, ACCESS_SECRET) as EmailVerificationTicketPayload;
}

import { Request, Response, NextFunction } from 'express';
import { verifyAccessToken } from '../auth/tokens';

export interface AuthedRequest extends Request {
  auth?: { userId: string; role: string };
}

export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentification requise' });
  }
  const token = header.slice('Bearer '.length);
  try {
    const payload = verifyAccessToken(token);
    req.auth = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Session invalide ou expirée' });
  }
}

export function requireRole(...roles: string[]) {
  return (req: AuthedRequest, res: Response, next: NextFunction) => {
    if (!req.auth || !roles.includes(req.auth.role)) {
      return res.status(403).json({ error: 'Accès refusé' });
    }
    next();
  };
}

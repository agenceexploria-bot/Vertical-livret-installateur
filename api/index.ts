import { createApp } from '../backend/src/app';

// Miroir de la vérification faite par backend/src/server.ts (dev local) :
// sur Vercel, ce fichier est le point d'entrée réellement invoqué (server.ts,
// avec son app.listen, ne tourne jamais ici), donc le garde SMTP doit être
// répété pour échouer bruyamment dès le cold start plutôt qu'à la première
// tentative d'envoi.
const REQUIRED_SMTP_VARS = ['SMTP_HOST', 'SMTP_PORT', 'SMTP_USER', 'SMTP_PASS', 'SMTP_FROM'] as const;
const missingSmtpVars = REQUIRED_SMTP_VARS.filter((key) => !process.env[key]);
if (missingSmtpVars.length > 0) {
  throw new Error(`Configuration SMTP manquante sur Vercel : ${missingSmtpVars.join(', ')}`);
}

const app = createApp();

// vercel.json route /api/(.*) vers cette function en conservant le préfixe
// /api dans l'URL reçue ici, alors que les routes Express sont montées à la
// racine (/auth, /comptes...) — on retire donc ce préfixe avant de déléguer.
// (Pas d'import 'express' ici volontairement : ce fichier vit à la racine du
// repo, qui n'a pas son propre node_modules — seul backend/src/app.ts, lui
// physiquement dans backend/, peut résoudre 'express' via backend/node_modules.)
export default function handler(req: any, res: any) {
  req.url = req.url?.replace(/^\/api/, '') || '/';
  app(req, res);
}

import 'dotenv/config';
import { createApp } from './app';

// Le 2FA email (voir /auth/request-email-code) dépend d'un vrai SMTP — pas de
// fallback de simulation : mieux vaut échouer bruyamment au démarrage que
// silencieusement à la première inscription.
const REQUIRED_SMTP_VARS = ['SMTP_HOST', 'SMTP_PORT', 'SMTP_USER', 'SMTP_PASS', 'SMTP_FROM'] as const;
const missingSmtpVars = REQUIRED_SMTP_VARS.filter((key) => !process.env[key]);
if (missingSmtpVars.length > 0) {
  console.error(
    `Configuration SMTP manquante dans backend/.env : ${missingSmtpVars.join(', ')}.\n` +
      'Le 2FA par email (inscription) ne peut pas fonctionner sans un vrai serveur SMTP — voir les commentaires dans .env.',
  );
  process.exit(1);
}

const app = createApp();
const port = Number(process.env.PORT) || 3000;
app.listen(port, () => {
  console.log(`Vertical App backend listening on http://localhost:${port}`);
});

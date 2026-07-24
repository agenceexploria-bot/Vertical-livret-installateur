import nodemailer, { Transporter } from 'nodemailer';

let transporter: Transporter | null = null;

/// Le transport est construit une seule fois à partir des variables SMTP du
/// .env — leur présence est déjà garantie au démarrage par server.ts (voir
/// REQUIRED_SMTP_VARS), donc pas de re-validation ici.
function getTransporter(): Transporter {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT),
      secure: Number(process.env.SMTP_PORT) === 465,
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    });
  }
  return transporter;
}

export async function sendVerificationCodeEmail(to: string, code: string): Promise<void> {
  // En test, aucun envoi réel : le code est déjà renvoyé en clair dans la
  // réponse HTTP (voir authRouter) et la suite ne dépend donc pas du réseau.
  if (process.env.NODE_ENV === 'test') return;

  await getTransporter().sendMail({
    from: process.env.SMTP_FROM,
    to,
    subject: 'Votre code de vérification Vertical',
    text: `Votre code de vérification est : ${code}\n\nCe code expire dans 10 minutes.`,
    html: `<p>Votre code de vérification est : <strong style="font-size:20px">${code}</strong></p><p>Ce code expire dans 10 minutes.</p>`,
  });
}

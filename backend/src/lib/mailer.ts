import nodemailer, { Transporter } from 'nodemailer';

let transporterPromise: Promise<{ transporter: Transporter; isEthereal: boolean }> | null = null;

/// En dev/test, si aucun SMTP n'est configuré (.env), on crée à la volée un
/// compte de test Ethereal — aucune configuration manuelle requise, l'email
/// n'est jamais réellement délivré mais consultable via l'URL de prévisualisation
/// loguée après chaque envoi. Si SMTP_HOST est renseigné (ex. Mailtrap), on
/// l'utilise à la place.
function getTransporter() {
  if (!transporterPromise) {
    transporterPromise = (async () => {
      if (process.env.SMTP_HOST) {
        const transporter = nodemailer.createTransport({
          host: process.env.SMTP_HOST,
          port: Number(process.env.SMTP_PORT ?? 587),
          secure: Number(process.env.SMTP_PORT) === 465,
          auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
        });
        return { transporter, isEthereal: false };
      }

      const testAccount = await nodemailer.createTestAccount();
      const transporter = nodemailer.createTransport({
        host: testAccount.smtp.host,
        port: testAccount.smtp.port,
        secure: testAccount.smtp.secure,
        auth: { user: testAccount.user, pass: testAccount.pass },
      });
      return { transporter, isEthereal: true };
    })();
  }
  return transporterPromise;
}

export async function sendVerificationCodeEmail(to: string, code: string): Promise<void> {
  // En test, le code est déjà renvoyé en clair dans la réponse HTTP (voir
  // authRouter) — inutile de dépendre du réseau (création de compte Ethereal,
  // envoi SMTP réel) qui ralentirait ou rendrait la suite flaky.
  if (process.env.NODE_ENV === 'test') return;

  const { transporter, isEthereal } = await getTransporter();

  const info = await transporter.sendMail({
    from: process.env.SMTP_FROM ?? '"Vertical" <no-reply@vertical.fr>',
    to,
    subject: 'Votre code de vérification Vertical',
    text: `Votre code de vérification est : ${code}\n\nCe code expire dans 10 minutes.`,
    html: `<p>Votre code de vérification est : <strong style="font-size:20px">${code}</strong></p><p>Ce code expire dans 10 minutes.</p>`,
  });

  if (isEthereal) {
    // eslint-disable-next-line no-console
    console.log(`[mailer] Email de test — prévisualisation : ${nodemailer.getTestMessageUrl(info)}`);
  }
}

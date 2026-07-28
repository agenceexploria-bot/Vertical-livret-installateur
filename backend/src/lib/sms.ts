import twilio from 'twilio';

const APP_URL = 'https://vertical-livret-installateur.vercel.app';

/// Les mobiles sont stockés normalisés en 10 chiffres locaux (ex.
/// "0652417890", voir normalizeMobile dans auth.ts) — Twilio exige le format
/// E.164 (ex. "+33652417890"). Toute l'app cible des numéros français ; un
/// numéro déjà international (commençant par "+") est laissé tel quel.
function toE164(mobile: string): string {
  if (mobile.startsWith('+')) return mobile;
  const digits = mobile.replace(/\D/g, '');
  if (digits.length === 10 && digits.startsWith('0')) return `+33${digits.slice(1)}`;
  return `+${digits}`;
}

/// Envoie un SMS de relance à un installateur qui n'a pas ouvert son livret
/// chantier. Lève une erreur si la configuration Twilio est incomplète ou si
/// l'envoi échoue — à charge de l'appelant de traduire ça en réponse HTTP.
export async function sendRelanceSms(mobile: string): Promise<void> {
  const { TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER } = process.env;
  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_PHONE_NUMBER) {
    throw new Error(
      'Configuration Twilio manquante (TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN / TWILIO_PHONE_NUMBER)',
    );
  }

  const client = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
  await client.messages.create({
    to: toE164(mobile),
    from: TWILIO_PHONE_NUMBER,
    body: `Bonjour, veuillez ouvrir votre livret chantier sur l'application Vertical. Lien : ${APP_URL}`,
  });
}

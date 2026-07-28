import twilio from 'twilio';

const APP_URL = 'https://vertical-livret-installateur.vercel.app';

// Numéro déjà au format E.164 (international, valable pour tous les pays) :
// "+" suivi de l'indicatif pays puis du numéro national.
const E164_REGEX = /^\+[1-9]\d{7,14}$/;

// Format local français historique (ex. "0652417890", voir normalizeMobile
// dans auth.ts) — conservé pour ne pas casser les comptes créés avant
// l'ouverture à l'international.
const FR_LOCAL_REGEX = /^0\d{9}$/;

export function isValidMobileInput(value: string): boolean {
  return E164_REGEX.test(value) || FR_LOCAL_REGEX.test(value);
}

// Retire la mise en forme (espaces, tirets, parenthèses...) d'un numéro saisi
// par un utilisateur, en préservant le "+" de tête s'il est présent.
export function normalizePhoneInput(value: string): string {
  const trimmed = value.trim();
  const digits = trimmed.replace(/\D/g, '');
  return trimmed.startsWith('+') ? `+${digits}` : digits;
}

export const MOBILE_FORMAT_ERROR =
  "Numéro de mobile invalide — veuillez le saisir avec l'indicatif pays au format international (ex : +33612345678, +237677123456).";

/// Les mobiles sont stockés soit au format local français historique (ex.
/// "0652417890", voir normalizeMobile dans auth.ts), soit en E.164 (ex.
/// "+237677123456") depuis l'ouverture à l'international. Twilio exige le
/// format E.164 — impossible de deviner l'indicatif pays d'un numéro qui n'a
/// ni "+" ni le format local français connu, donc on lève une erreur plutôt
/// que d'envoyer au mauvais pays.
function toE164(mobile: string): string {
  if (mobile.startsWith('+')) return mobile;
  if (FR_LOCAL_REGEX.test(mobile)) return `+33${mobile.slice(1)}`;
  throw new Error(MOBILE_FORMAT_ERROR);
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
